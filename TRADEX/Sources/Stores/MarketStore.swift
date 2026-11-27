import Foundation
import Observation

/// 수신한 시세를 모아 두었다가 일정 간격으로 화면에 반영 (초당 수백 건을 그대로 그리면 버벅임)
actor TickerBuffer {
    private var pending: [String: Ticker] = [:]
    /// 마지막으로 웹소켓에서 시세를 받은 시각
    private(set) var lastSocket = Date.distantPast
    func put(_ t: Ticker, fromSocket: Bool = true) {
        pending[t.market] = t
        if fromSocket { lastSocket = Date() }
    }
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
    /// 지금 시세를 보고 있는 거래소
    private(set) var exchange: ExchangeID = .upbit
    /// 위젯에서 열 코인 (거래소 탭이 처리 후 nil)
    var pendingCoin: String?
    /// 다른 거래소의 마지막 시세 (자산 평가용)
    private(set) var otherTickers: [ExchangeID: [String: Ticker]] = [:]

    @ObservationIgnored private var liveTask: Task<Void, Never>?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let buffer = TickerBuffer()
    @ObservationIgnored private var marketIndex: [String: Market] = [:]
    /// 거래소를 바꾸면 증가 — 바꾸기 전에 시작된 요청 결과를 버리기 위함
    @ObservationIgnored private var generation = 0

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? ["KRW-BTC", "KRW-ETH", "KRW-XRP"])
        exchange = .upbit   // 빗썸은 뺐다 (예전에 빗썸을 골라 둔 경우도 업비트로)
        UserDefaults.standard.removeObject(forKey: "exchange")
    }

    /// 거래소별 시세 (선택된 거래소는 실시간, 아니면 마지막 스냅샷)
    func prices(for ex: ExchangeID) -> [String: Ticker] {
        ex == exchange ? tickers : (otherTickers[ex] ?? [:])
    }

    /// 거래소 전환: 실시간 연결을 끊고 새 거래소 시세로 다시 시작
    func select(_ ex: ExchangeID) async {
        guard ex != exchange else { return }
        stopLive()
        _ = await buffer.drain()
        otherTickers[exchange] = tickers
        generation += 1
        exchange = ex
        UserDefaults.standard.set(ex.rawValue, forKey: "exchange")
        tickers = otherTickers[ex] ?? [:]
        markets = []
        marketIndex = [:]
        await bootstrap()
    }

    /// 선택되지 않은 거래소의 특정 마켓 시세를 한 번 받아 둔다 (자산 평가용)
    func refreshSnapshot(for ex: ExchangeID, markets codes: [String]) async {
        guard ex != exchange, !codes.isEmpty,
              let rows = try? await UpbitAPI.tickers(codes, on: ex) else { return }
        var copy = otherTickers[ex] ?? [:]
        for t in rows { copy[t.market] = t }
        otherTickers[ex] = copy
    }

    func market(_ code: String) -> Market? { marketIndex[code] }

    /// 앱 시작 시: 마켓 목록 + 현재 시세를 받고 실시간 연결 시작
    func bootstrap() async {
        guard markets.isEmpty else { return }
        let gen = generation, ex = exchange
        do {
            let list = try await UpbitAPI.krwMarkets(on: ex)
            let snapshot = try await UpbitAPI.tickers(list.map(\.market), on: ex)
            guard gen == generation else { return }   // 그 사이 거래소가 바뀜
            guard !list.isEmpty, !snapshot.isEmpty else { throw URLError(.cannotParseResponse) }
            // 목록과 시세를 둘 다 받은 뒤에 한 번에 반영 (시세 없이 목록만 뜨는 상태를 만들지 않음)
            marketIndex = Dictionary(uniqueKeysWithValues: list.map { ($0.market, $0) })
            tickers = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.market, $0) })
            markets = list
            loadError = nil
            startLive()
        } catch {
            guard gen == generation else { return }
            loadError = "\(ex.name) 시세를 불러오지 못했어요. 네트워크를 확인해 주세요."
            #if DEBUG
            print("bootstrap 실패:", error)
            #endif
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
        let ex = exchange

        liveTask = Task { [weak self] in
            var backoff: Double = 1
            while !Task.isCancelled {
                self?.isConnected = true
                do {
                    try await UpbitSocket.listen(codes: codes, on: ex) { t in await buffer.put(t) }
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

        // 실시간 연결이 6초 넘게 조용하면 REST로 5초마다 시세를 받아 온다 (웹소켓이 막힌 환경 대비)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard self != nil, Date().timeIntervalSince(await buffer.lastSocket) > 6,
                      let rows = try? await UpbitAPI.tickers(codes, on: ex) else { continue }
                for t in rows { await buffer.put(t, fromSocket: false) }
            }
        }
    }

    func stopLive() {
        liveTask?.cancel(); liveTask = nil
        flushTask?.cancel(); flushTask = nil
        pollTask?.cancel(); pollTask = nil
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
