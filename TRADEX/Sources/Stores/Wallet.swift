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
        guard krwAmount >= TradexRules.minOrderKRW else { throw WalletError.minOrder }
        let fee = krwAmount * TradexRules.feeRate
        guard krwAmount + fee <= state.krw + 0.000001 else { throw WalletError.insufficientKRW }
        let qty = floor(krwAmount / price * 1e8) / 1e8

        var h = state.holdings[market.market] ?? Holding(quantity: 0, averagePrice: 0, koreanName: market.koreanName)
        h.averagePrice = (h.averagePrice * h.quantity + price * qty) / (h.quantity + qty)
        h.quantity += qty
        state.holdings[market.market] = h
        state.krw = max(0, state.krw - krwAmount - fee)
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
        state = WalletState(tradex: granted, krw: 0, holdings: [:], trades: [],
                            tradexHistory: [TradexRecord(kind: .signupBonus, amount: granted, date: .now)],
                            grantedTradex: granted)
        save()
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
