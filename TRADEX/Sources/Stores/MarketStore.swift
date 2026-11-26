import Foundation
import Observation

/// 수신한 시세를 모아 두었다가 일정 간격으로 화면에 반영 (초당 수백 건을 그대로 그리면 버벅임)
actor TickerBuffer {
    private var pending: [String: Ticker] = [:]
    func put(_ t: Ticker) { pending[t.market] = t }
    func drain() -> [String: Ticker] {
        defer { pending.removeAll(keepingCapacity: true) }
        return pending
    }
}

enum SortKey: String, CaseIterable, Identifiable {
    case volume = "거래대금", rate = "등락률", name = "이름"
    var id: String { rawValue }
}

@MainActor
@Observable
final class MarketStore {
    private(set) var markets: [Market] = []
    private(set) var tickers: [String: Ticker] = [:]
    private(set) var isConnected = false
    private(set) var loadError: String?
    private(set) var favorites: Set<String> = []

    @ObservationIgnored private var liveTask: Task<Void, Never>?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private let buffer = TickerBuffer()
    @ObservationIgnored private var marketIndex: [String: Market] = [:]

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? ["KRW-BTC", "KRW-ETH", "KRW-XRP"])
    }

    func market(_ code: String) -> Market? { marketIndex[code] }

    /// 앱 시작 시: 마켓 목록 + 현재 시세를 받고 실시간 연결 시작
    func bootstrap() async {
        guard markets.isEmpty else { return }
        do {
            let list = try await UpbitAPI.krwMarkets()
            markets = list
            marketIndex = Dictionary(uniqueKeysWithValues: list.map { ($0.market, $0) })
            let snapshot = try await UpbitAPI.tickers(list.map(\.market))
            tickers = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.market, $0) })
            loadError = nil
            startLive()
        } catch {
            loadError = "시세를 불러오지 못했어요. 네트워크를 확인해 주세요."
        }
    }

    func retry() async {
        markets = []
        await bootstrap()
    }

    func startLive() {
        guard liveTask == nil, !markets.isEmpty else { return }
        let codes = markets.map(\.market)
        let buffer = self.buffer

        liveTask = Task { [weak self] in
            var backoff: Double = 1
            while !Task.isCancelled {
                self?.isConnected = true
                do {
                    try await UpbitSocket.listen(codes: codes) { t in await buffer.put(t) }
                } catch {
                    // 연결 끊김 → 아래에서 재연결
                }
                self?.isConnected = false
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, 30)
            }
        }

        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                let updates = await buffer.drain()
                guard let self, !updates.isEmpty else { continue }
                var copy = self.tickers
                for (k, v) in updates { copy[k] = v }
                self.tickers = copy
            }
        }
    }

    func stopLive() {
        liveTask?.cancel(); liveTask = nil
        flushTask?.cancel(); flushTask = nil
        isConnected = false
    }

    func toggleFavorite(_ code: String) {
        if favorites.contains(code) { favorites.remove(code) } else { favorites.insert(code) }
        saveFavorites()
    }

    func sorted(_ list: [Market], by key: SortKey, ascending: Bool = false) -> [Market] {
        let result: [Market]
        switch key {
        case .volume: result = list.sorted { (tickers[$0.market]?.accTradePrice24h ?? 0) > (tickers[$1.market]?.accTradePrice24h ?? 0) }
        case .rate:   result = list.sorted { (tickers[$0.market]?.signedChangeRate ?? 0) > (tickers[$1.market]?.signedChangeRate ?? 0) }
        case .name:   result = list.sorted { $0.koreanName.localizedCompare($1.koreanName) == .orderedAscending }
        }
        return ascending ? result.reversed() : result
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favorites), forKey: "favorites")
    }
}
