import Foundation
import Observation

/// 가상 지갑 — 실제 돈·코인과 연결되지 않는다.
/// ⚠️ TRADEX와 모의 원화는 현금·상품·실제 코인으로 바꾸거나, 유료로 팔거나, 사용자끼리 주고받게 만들지 말 것.
@MainActor
@Observable
final class Wallet {
    private(set) var state: WalletState
    @ObservationIgnored private let fileURL: URL

    enum WalletError: LocalizedError {
        case minOrder, insufficientKRW, insufficientQty, insufficientTradex, invalid
        var errorDescription: String? {
            switch self {
            case .minOrder: return "최소 주문 금액은 \(Fmt.krw(TradexRules.minOrderKRW))이에요."
            case .insufficientKRW: return "주문 가능한 원화가 부족해요."
            case .insufficientQty: return "보유 수량이 부족해요."
            case .insufficientTradex: return "TRADEX가 부족해요."
            case .invalid: return "올바른 값을 입력해 주세요."
            }
        }
    }

    init(userID: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wallets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = userID.replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
        fileURL = dir.appendingPathComponent("\(safe).json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(WalletState.self, from: data) {
            state = saved
        } else {
            state = WalletState()
        }
    }

    var isNew: Bool { state.grantedTradex == 0 }

    // MARK: - TRADEX

    /// 첫 로그인 보너스 지급 (한 계정당 1회)
    @discardableResult
    func grantSignupBonusIfNeeded() -> Bool {
        guard !state.tradexHistory.contains(where: { $0.kind == .signupBonus }) else { return false }
        state.tradex += TradexRules.signupBonus
        state.grantedTradex += TradexRules.signupBonus
        state.tradexHistory.insert(TradexRecord(kind: .signupBonus, amount: TradexRules.signupBonus, date: .now), at: 0)
        save()
        return true
    }

    /// TRADEX → 모의 원화 교환 (단방향, 되돌릴 수 없음)
    func exchange(tradex count: Int) throws {
        guard count > 0 else { throw WalletError.invalid }
        guard count <= state.tradex else { throw WalletError.insufficientTradex }
        state.tradex -= count
        state.krw += Double(count) * TradexRules.krwPerTradex
        state.tradexHistory.insert(TradexRecord(kind: .exchange, amount: -count, date: .now), at: 0)
        save()
    }

    // MARK: - 매매 (시장가)

    /// 원화 금액만큼 시장가 매수. 수수료는 별도로 차감.
    func buy(market: Market, krwAmount: Double, price: Double) throws {
        guard krwAmount > 0, price > 0 else { throw WalletError.invalid }
        try buy(market: market, quantity: floor(krwAmount / price * 1e8) / 1e8, price: price)
    }

    /// 코인 개수만큼 시장가 매수. 수수료는 별도로 차감.
    func buy(market: Market, quantity: Double, price: Double) throws {
        let qty = floor(quantity * 1e8) / 1e8
        guard qty > 0, price > 0 else { throw WalletError.invalid }
        let cost = qty * price
        guard cost >= TradexRules.minOrderKRW else { throw WalletError.minOrder }
        let fee = cost * TradexRules.feeRate
        guard cost + fee <= state.krw + 0.000001 else { throw WalletError.insufficientKRW }

        var h = state.holdings[market.market] ?? Holding(quantity: 0, averagePrice: 0, koreanName: market.koreanName)
        h.averagePrice = (h.averagePrice * h.quantity + cost) / (h.quantity + qty)
        h.quantity += qty
        state.holdings[market.market] = h
        state.krw = max(0, state.krw - cost - fee)
        state.trades.insert(TradeRecord(side: .buy, market: market.market, koreanName: market.koreanName,
                                        price: price, quantity: qty, fee: fee, date: .now), at: 0)
        save()
    }

    /// 수량만큼 시장가 매도
    func sell(market: Market, quantity: Double, price: Double) throws {
        guard quantity > 0, price > 0 else { throw WalletError.invalid }
        guard var h = state.holdings[market.market], h.quantity + 1e-9 >= quantity else { throw WalletError.insufficientQty }
        let amount = quantity * price
        guard amount >= TradexRules.minOrderKRW || abs(h.quantity - quantity) < 1e-9 else { throw WalletError.minOrder }
        let fee = amount * TradexRules.feeRate
        let pnl = (price - h.averagePrice) * quantity - fee

        h.quantity -= quantity
        if h.quantity < 1e-8 { state.holdings[market.market] = nil } else { state.holdings[market.market] = h }
        state.krw += amount - fee
        state.trades.insert(TradeRecord(side: .sell, market: market.market, koreanName: market.koreanName,
                                        price: price, quantity: quantity, fee: fee, date: .now, realizedPnL: pnl), at: 0)
        save()
    }

    /// 수수료 포함해서 지금 살 수 있는 최대 원화 금액
    var maxBuyKRW: Double { floor(state.krw / (1 + TradexRules.feeRate)) }

    // MARK: - 평가

    struct Valuation {
        var coinValue: Double
        var coinCost: Double
        var krw: Double
        var tradexValue: Double
        var total: Double { coinValue + krw + tradexValue }
        var coinPnL: Double { coinValue - coinCost }
    }

    func valuation(prices: [String: Ticker]) -> Valuation {
        var value = 0.0, cost = 0.0
        for (code, h) in state.holdings {
            let p = prices[code]?.tradePrice ?? h.averagePrice
            value += p * h.quantity
            cost += h.averagePrice * h.quantity
        }
        return Valuation(coinValue: value, coinCost: cost, krw: state.krw,
                         tradexValue: Double(state.tradex) * TradexRules.krwPerTradex)
    }

    /// 지급받은 TRADEX 가치 대비 총 수익
    var baseValue: Double { Double(state.grantedTradex) * TradexRules.krwPerTradex }

    /// 처음 상태로 되돌리기 (보너스는 다시 지급하지 않고 지급 총량으로 복원)
    func reset() {
        let granted = state.grantedTradex
        // 미니게임 기록은 유지 (같은 라운드에 다시 참여하지 못하게)
        state = WalletState(tradex: granted, krw: 0, holdings: [:], trades: [],
                            tradexHistory: [TradexRecord(kind: .signupBonus, amount: granted, date: .now)],
                            grantedTradex: granted, predictions: state.predictions)
        save()
    }

    // MARK: - 미니게임

    enum PredictionError: LocalizedError {
        case closed, already, noServerTime
        var errorDescription: String? {
            switch self {
            case .closed: return "참여 시간이 지났어요. 다음 라운드에 참여해 주세요."
            case .already: return "이번 라운드에는 이미 참여했어요."
            case .noServerTime: return "서버 시간을 확인하지 못했어요. 네트워크를 확인해 주세요."
            }
        }
    }

    func prediction(for roundKey: String) -> Prediction? {
        state.predictions.first { $0.roundKey == roundKey }
    }

    /// 예측 참여. serverNow는 기기 시계가 아니라 업비트 서버 시간을 쓴다 (시계 조작 방지).
    func placePrediction(round: PredictionRound, market: Market, choice: PredictionChoice, serverNow: Date) throws {
        guard serverNow < round.start else { throw PredictionError.closed }
        guard prediction(for: round.key) == nil else { throw PredictionError.already }
        state.predictions.insert(Prediction(roundKey: round.key, market: market.market, koreanName: market.koreanName,
                                            choice: choice, createdAt: serverNow), at: 0)
        save()
    }

    /// 결과가 나온 예측을 판정하고 적중 시 모의 원화 지급. 새로 판정된 예측을 돌려준다.
    func settlePendingPredictions() async -> [Prediction] {
        let pending = state.predictions.filter { $0.status == .pending }
        guard !pending.isEmpty, let now = try? await UpbitAPI.serverNow() else { return [] }
        var settled: [Prediction] = []
        for p in pending {
            guard let round = PredictionRound(key: p.roundKey), now >= round.end else { continue }
            let days = Int(now.timeIntervalSince(round.start) / 86_400) + 2
            guard days <= 200,
                  let candles = try? await UpbitAPI.dayCandles(market: p.market, count: days),
                  let candle = candles.first(where: { $0.candleDateTimeKst == round.candleTimeKST })
            else { continue }
            if let result = settle(id: p.id, changeRate: candle.changeRate) { settled.append(result) }
        }
        return settled
    }

    private func settle(id: UUID, changeRate: Double) -> Prediction? {
        guard let i = state.predictions.firstIndex(where: { $0.id == id }),
              state.predictions[i].status == .pending else { return nil }
        var p = state.predictions[i]
        p.changeRate = changeRate
        if changeRate == 0 {
            p.status = .draw
        } else if (changeRate > 0) == (p.choice == .up) {
            p.status = .won
            p.reward = TradexRules.predictionRewardKRW
            state.krw += p.reward
        } else {
            p.status = .lost
        }
        state.predictions[i] = p
        save()
        return p
    }

    func deleteFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("지갑 저장 실패:", error)
        }
    }
}
