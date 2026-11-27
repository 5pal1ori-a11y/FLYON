import Foundation
import Observation

/// 가상 지갑 — 실제 돈·코인과 연결되지 않는다.
/// ⚠️ TRADEX와 모의 원화는 현금·상품·실제 코인으로 바꾸거나, 유료로 팔거나, 사용자끼리 주고받게 만들지 말 것.
@MainActor
@Observable
final class Wallet {
    private(set) var state: WalletState
    @ObservationIgnored private let fileURL: URL
    /// 방금 오른 등급 (축하 화면 표시 후 nil로)
    var pendingLevelUp: TraderLevel?

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

    // MARK: - 계좌

    func account(_ ex: ExchangeID) -> ExchangeAccount { state.accounts[ex.rawValue] ?? ExchangeAccount() }

    private func update(_ ex: ExchangeID, _ body: (inout ExchangeAccount) throws -> Void) rethrows {
        var a = account(ex)
        try body(&a)
        state.accounts[ex.rawValue] = a
    }

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

    /// TRADEX → 거래소 계좌(현물 또는 선물)로 충전 (단방향, 되돌릴 수 없음)
    func charge(tradex count: Int, to ex: ExchangeID, futures: Bool) throws {
        guard count > 0 else { throw WalletError.invalid }
        guard count <= state.tradex else { throw WalletError.insufficientTradex }
        state.tradex -= count
        let krw = Double(count) * TradexRules.krwPerTradex
        update(ex) { if futures { $0.futuresKRW += krw } else { $0.krw += krw } }
        state.tradexHistory.insert(TradexRecord(kind: .exchange, amount: -count, date: .now,
                                                krwPerTradex: TradexRules.krwPerTradex,
                                                exchange: ex, toFutures: futures), at: 0)
        save()
    }

    /// 같은 거래소 안에서 현물 ↔ 선물 원화 이동
    func transfer(_ amount: Double, in ex: ExchangeID, toFutures: Bool) throws {
        let a = account(ex)
        guard amount > 0 else { throw WalletError.invalid }
        guard amount <= (toFutures ? a.krw : a.futuresKRW) + 0.000001 else { throw WalletError.insufficientKRW }
        update(ex) {
            if toFutures { $0.krw -= amount; $0.futuresKRW += amount } else { $0.futuresKRW -= amount; $0.krw += amount }
        }
        save()
    }

    // MARK: - 현물 매매 (시장가)

    /// 원화 금액만큼 시장가 매수. 수수료는 별도로 차감.
    func buy(market: Market, krwAmount: Double, price: Double, on ex: ExchangeID) throws {
        guard krwAmount > 0, price > 0 else { throw WalletError.invalid }
        try buy(market: market, quantity: floor(krwAmount / price * 1e8) / 1e8, price: price, on: ex)
    }

    /// 코인 개수만큼 시장가 매수. 수수료는 별도로 차감.
    func buy(market: Market, quantity: Double, price: Double, on ex: ExchangeID) throws {
        let qty = floor(quantity * 1e8) / 1e8
        guard qty > 0, price > 0 else { throw WalletError.invalid }
        let cost = qty * price
        guard cost >= TradexRules.minOrderKRW else { throw WalletError.minOrder }
        let fee = cost * TradexRules.feeRate
        guard cost + fee <= account(ex).krw + 0.000001 else { throw WalletError.insufficientKRW }

        update(ex) { a in
            var h = a.holdings[market.market] ?? Holding(quantity: 0, averagePrice: 0, koreanName: market.koreanName)
            h.averagePrice = (h.averagePrice * h.quantity + cost) / (h.quantity + qty)
            h.quantity += qty
            a.holdings[market.market] = h
            a.krw = max(0, a.krw - cost - fee)
            a.trades.insert(TradeRecord(side: .buy, market: market.market, koreanName: market.koreanName,
                                        price: price, quantity: qty, fee: fee, date: .now), at: 0)
        }
        recordEvent("buy")
        gainXP(.trade)
        save()
    }

    /// 수량만큼 시장가 매도
    func sell(market: Market, quantity: Double, price: Double, on ex: ExchangeID) throws {
        guard quantity > 0, price > 0 else { throw WalletError.invalid }
        guard let h = account(ex).holdings[market.market], h.quantity + 1e-9 >= quantity else { throw WalletError.insufficientQty }
        let amount = quantity * price
        guard amount >= TradexRules.minOrderKRW || abs(h.quantity - quantity) < 1e-9 else { throw WalletError.minOrder }
        let fee = amount * TradexRules.feeRate
        let pnl = (price - h.averagePrice) * quantity - fee

        update(ex) { a in
            var left = h
            left.quantity -= quantity
            a.holdings[market.market] = left.quantity < 1e-8 ? nil : left
            a.krw += amount - fee
            a.trades.insert(TradeRecord(side: .sell, market: market.market, koreanName: market.koreanName,
                                        price: price, quantity: quantity, fee: fee, date: .now, realizedPnL: pnl), at: 0)
        }
        gainXP(.trade)
        save()
    }

    /// 수수료 포함해서 지금 살 수 있는 최대 원화 금액
    func maxBuyKRW(_ ex: ExchangeID) -> Double { floor(account(ex).krw / (1 + TradexRules.feeRate)) }

    // MARK: - 선물 (모의, 격리 마진, 수수료·펀딩비 없음)

    enum FuturesError: LocalizedError {
        case insufficientMargin, minMargin, invalidLeverage, notFound
        var errorDescription: String? {
            switch self {
            case .insufficientMargin: return "선물 지갑의 원화가 부족해요. 충전하거나 현물에서 옮겨 주세요."
            case .minMargin: return "최소 증거금은 \(Fmt.krw(TradexRules.minOrderKRW))이에요."
            case .invalidLeverage: return "레버리지는 1~\(TradexRules.maxLeverage)배까지 가능해요."
            case .notFound: return "포지션을 찾을 수 없어요."
            }
        }
    }

    func openPosition(market: Market, side: PositionSide, leverage: Int, margin: Double, price: Double, on ex: ExchangeID) throws {
        guard price > 0, margin > 0 else { throw WalletError.invalid }
        guard (1...TradexRules.maxLeverage).contains(leverage) else { throw FuturesError.invalidLeverage }
        guard margin >= TradexRules.minOrderKRW else { throw FuturesError.minMargin }
        guard margin <= account(ex).futuresKRW + 0.000001 else { throw FuturesError.insufficientMargin }
        let position = FuturesPosition(market: market.market, koreanName: market.koreanName, side: side, leverage: leverage,
                                       margin: margin, entryPrice: price, quantity: margin * Double(leverage) / price,
                                       openedAt: .now)
        update(ex) { a in
            a.futuresKRW = max(0, a.futuresKRW - margin)
            a.positions.insert(position, at: 0)
        }
        recordEvent("futures")
        gainXP(.futures)
        save()
    }

    /// 포지션 종료. 돌려받은 금액(증거금 + 손익)을 선물 지갑에 넣는다.
    @discardableResult
    func closePosition(id: UUID, price: Double, on ex: ExchangeID, liquidated: Bool = false) throws -> FuturesRecord {
        guard let p = account(ex).positions.first(where: { $0.id == id }) else { throw FuturesError.notFound }
        let exit = liquidated ? p.liquidationPrice : price
        let pnl = liquidated ? -p.margin : p.pnl(at: exit)
        let record = FuturesRecord(market: p.market, koreanName: p.koreanName, side: p.side, leverage: p.leverage,
                                   margin: p.margin, entryPrice: p.entryPrice, exitPrice: exit, pnl: max(pnl, -p.margin),
                                   closedAt: .now, liquidated: liquidated || p.isLiquidated(at: exit))
        update(ex) { a in
            a.positions.removeAll { $0.id == id }
            a.futuresKRW += max(0, p.margin + pnl)
            a.futuresHistory.insert(record, at: 0)
        }
        save()
        return record
    }

    /// 현재가로 청산 조건을 확인해 청산된 포지션을 돌려준다.
    @discardableResult
    func checkLiquidations(prices: [String: Ticker], on ex: ExchangeID) -> [FuturesRecord] {
        var done: [FuturesRecord] = []
        for p in account(ex).positions {
            guard let price = prices[p.market]?.tradePrice, p.isLiquidated(at: price) else { continue }
            if let r = try? closePosition(id: p.id, price: price, on: ex, liquidated: true) { done.append(r) }
        }
        return done
    }

    /// 앱이 꺼져 있던 동안 청산 가격을 지나갔는지 1시간 봉의 고가·저가로 확인
    @discardableResult
    func reconcileLiquidations(on ex: ExchangeID) async -> [FuturesRecord] {
        var done: [FuturesRecord] = []
        for p in account(ex).positions {
            let hours = Int(Date().timeIntervalSince(p.openedAt) / 3_600) + 2
            guard let candles = try? await UpbitAPI.highLow(market: p.market, hours: min(hours, 200), on: ex) else { continue }
            let crossed = candles.contains { c in
                // 진입 이후에 시작한 봉만 사용 (진입 전 가격으로 잘못 청산하지 않도록)
                c.date >= p.openedAt &&
                    (p.side == .long ? c.low <= p.liquidationPrice : c.high >= p.liquidationPrice)
            }
            if crossed, let r = try? closePosition(id: p.id, price: p.liquidationPrice, on: ex, liquidated: true) {
                done.append(r)
            }
        }
        return done
    }

    // MARK: - 예약 주문 (지정가 · 손절 · 익절)

    enum OrderError: LocalizedError {
        case invalidPrice, notFound
        var errorDescription: String? {
            switch self {
            case .invalidPrice: return "주문 가격을 확인해 주세요."
            case .notFound: return "주문을 찾을 수 없어요."
            }
        }
    }

    /// 지정가 매수: 원화(수수료 포함)를 잠가 두고, 현재가가 지정가 이하가 되면 체결
    func placeLimitBuy(market: Market, limitPrice: Double, krwAmount: Double, on ex: ExchangeID) throws {
        guard limitPrice > 0 else { throw OrderError.invalidPrice }
        guard krwAmount >= TradexRules.minOrderKRW else { throw WalletError.minOrder }
        let lock = krwAmount * (1 + TradexRules.feeRate)
        guard lock <= account(ex).krw + 0.000001 else { throw WalletError.insufficientKRW }
        let order = PendingOrder(kind: .limitBuy, market: market.market, koreanName: market.koreanName,
                                 triggerPrice: limitPrice, krwAmount: krwAmount, lockedKRW: lock,
                                 quantity: 0, averagePrice: 0, createdAt: .now)
        update(ex) { a in
            a.krw = max(0, a.krw - lock)
            a.orders.insert(order, at: 0)
        }
        gainXP(.order)
        save()
    }

    /// 지정가 매도 · 손절 · 익절: 코인 수량을 잠가 두고 조건이 되면 체결
    func placeSellOrder(_ kind: OrderKind, market: Market, triggerPrice: Double, quantity: Double, on ex: ExchangeID) throws {
        guard !kind.isBuy, triggerPrice > 0 else { throw OrderError.invalidPrice }
        let qty = floor(quantity * 1e8) / 1e8
        guard qty > 0 else { throw WalletError.invalid }
        guard let h = account(ex).holdings[market.market], h.quantity + 1e-9 >= qty else { throw WalletError.insufficientQty }
        let all = abs(h.quantity - qty) < 1e-8
        guard qty * triggerPrice >= TradexRules.minOrderKRW || all else { throw WalletError.minOrder }
        let order = PendingOrder(kind: kind, market: market.market, koreanName: market.koreanName,
                                 triggerPrice: triggerPrice, krwAmount: 0, lockedKRW: 0,
                                 quantity: all ? h.quantity : qty, averagePrice: h.averagePrice, createdAt: .now)
        update(ex) { a in
            var left = h
            left.quantity -= order.quantity
            a.holdings[market.market] = left.quantity < 1e-8 ? nil : left
            a.orders.insert(order, at: 0)
        }
        gainXP(.order)
        save()
    }

    /// 주문 취소: 잠가 둔 원화·코인을 돌려준다
    func cancelOrder(id: UUID, on ex: ExchangeID) throws {
        guard let o = account(ex).orders.first(where: { $0.id == id }) else { throw OrderError.notFound }
        update(ex) { a in
            a.orders.removeAll { $0.id == id }
            if o.kind.isBuy {
                a.krw += o.lockedKRW
            } else {
                var h = a.holdings[o.market] ?? Holding(quantity: 0, averagePrice: 0, koreanName: o.koreanName)
                h.averagePrice = (h.averagePrice * h.quantity + o.averagePrice * o.quantity) / (h.quantity + o.quantity)
                h.quantity += o.quantity
                a.holdings[o.market] = h
            }
        }
        save()
    }

    /// 주문 체결 (잠가 둔 자산으로 처리)
    @discardableResult
    private func fill(_ o: PendingOrder, at price: Double, on ex: ExchangeID) -> OrderFill? {
        guard price > 0, account(ex).orders.contains(where: { $0.id == o.id }) else { return nil }
        var filledQty = 0.0
        update(ex) { a in
            a.orders.removeAll { $0.id == o.id }
            if o.kind.isBuy {
                let qty = floor(o.krwAmount / price * 1e8) / 1e8
                let cost = qty * price
                let fee = cost * TradexRules.feeRate
                a.krw += max(0, o.lockedKRW - cost - fee)   // 남은 돈 돌려주기
                var h = a.holdings[o.market] ?? Holding(quantity: 0, averagePrice: 0, koreanName: o.koreanName)
                h.averagePrice = (h.averagePrice * h.quantity + cost) / (h.quantity + qty)
                h.quantity += qty
                a.holdings[o.market] = h
                a.trades.insert(TradeRecord(side: .buy, market: o.market, koreanName: o.koreanName,
                                            price: price, quantity: qty, fee: fee, date: .now), at: 0)
                filledQty = qty
            } else {
                let amount = o.quantity * price
                let fee = amount * TradexRules.feeRate
                a.krw += amount - fee
                a.trades.insert(TradeRecord(side: .sell, market: o.market, koreanName: o.koreanName,
                                            price: price, quantity: o.quantity, fee: fee, date: .now,
                                            realizedPnL: (price - o.averagePrice) * o.quantity - fee), at: 0)
                filledQty = o.quantity
            }
        }
        save()
        return OrderFill(kind: o.kind, koreanName: o.koreanName, price: price, quantity: filledQty)
    }

    /// 현재가로 체결 조건 확인 (앱이 켜져 있는 동안 1초마다)
    @discardableResult
    func checkOrders(prices: [String: Ticker], on ex: ExchangeID) -> [OrderFill] {
        var fills: [OrderFill] = []
        for o in account(ex).orders {
            guard let p = prices[o.market]?.tradePrice, o.kind.isTriggered(price: p, trigger: o.triggerPrice) else { continue }
            if let f = fill(o, at: p, on: ex) { fills.append(f) }
        }
        return fills
    }

    /// 앱이 꺼져 있던 동안 조건이 됐는지 1시간 봉 고가·저가로 확인 (지정한 가격에 체결)
    @discardableResult
    func reconcileOrders(on ex: ExchangeID) async -> [OrderFill] {
        var fills: [OrderFill] = []
        for o in account(ex).orders {
            let hours = Int(Date().timeIntervalSince(o.createdAt) / 3_600) + 2
            guard let candles = try? await UpbitAPI.highLow(market: o.market, hours: min(hours, 200), on: ex) else { continue }
            let hit = candles.contains { c in
                c.date >= o.createdAt &&
                    (o.kind == .limitBuy || o.kind == .stopLoss ? c.low <= o.triggerPrice : c.high >= o.triggerPrice)
            }
            if hit, let f = fill(o, at: o.triggerPrice, on: ex) { fills.append(f) }
        }
        return fills
    }

    // MARK: - 적립식 자동 매수

    /// 지금 이후 첫 실행일 (오전 9시 기준)
    static func firstRunKey(frequency: RecurringPlan.Frequency, weekday: Int, after now: Date) -> String {
        let cal = PredictionRound.calendar
        var day = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        if day <= now { day = cal.date(byAdding: .day, value: 1, to: day)! }
        if frequency == .weekly {
            while cal.component(.weekday, from: day) != weekday { day = cal.date(byAdding: .day, value: 1, to: day)! }
        }
        return KST.dayKey(day)
    }

    func addPlan(market: Market, krwAmount: Double, frequency: RecurringPlan.Frequency, weekday: Int, on ex: ExchangeID) throws {
        guard krwAmount >= TradexRules.minOrderKRW else { throw WalletError.minOrder }
        let plan = RecurringPlan(market: market.market, koreanName: market.koreanName, krwAmount: krwAmount,
                                 frequency: frequency, weekday: weekday,
                                 nextRunKey: Wallet.firstRunKey(frequency: frequency, weekday: weekday, after: .now),
                                 createdAt: .now)
        update(ex) { $0.plans.insert(plan, at: 0) }
        save()
    }

    func setPlanPaused(_ id: UUID, _ paused: Bool, on ex: ExchangeID) {
        update(ex) { a in
            guard let i = a.plans.firstIndex(where: { $0.id == id }) else { return }
            a.plans[i].paused = paused
            if !paused {   // 다시 켜면 다음 실행일부터 (멈춘 동안의 회차는 건너뜀)
                let p = a.plans[i]
                a.plans[i].nextRunKey = Wallet.firstRunKey(frequency: p.frequency, weekday: p.weekday, after: .now)
            }
        }
        save()
    }

    func deletePlan(_ id: UUID, on ex: ExchangeID) {
        update(ex) { $0.plans.removeAll { $0.id == id } }
        save()
    }

    /// 실행일이 지난 적립식을 처리한다. 체결가는 그날 일봉 시가 (오늘이면 현재가).
    /// 한 번에 최대 30회까지 따라잡고, 잔액이 부족한 회차는 건너뛴다. 처리 결과 문구를 돌려준다.
    @discardableResult
    func runDuePlans(on ex: ExchangeID, currentPrices: [String: Ticker]) async -> [String] {
        let now = (try? await UpbitAPI.serverNow()) ?? Date()
        let cal = PredictionRound.calendar
        var notes: [String] = []
        for plan in account(ex).plans where !plan.paused {
            guard let first = PredictionRound(key: plan.nextRunKey)?.start, first <= now else { continue }
            let days = Int(now.timeIntervalSince(first) / 86_400) + 2
            let candles = (try? await UpbitAPI.dayCandles(market: plan.market, count: min(days, 200), on: ex)) ?? []
            var key = plan.nextRunKey
            var runs = 0, bought = 0, skipped = 0
            while runs < 30, let start = PredictionRound(key: key)?.start, start <= now {
                // 업비트 일봉은 오전 9시, 빗썸 일봉은 0시 시작 → 날짜로 찾는다
                let price = candles.first(where: { $0.candleDateTimeKst.hasPrefix(key) })?.openingPrice
                    ?? currentPrices[plan.market]?.tradePrice ?? 0
                let m = Market(market: plan.market, koreanName: plan.koreanName, englishName: plan.koreanName)
                if price > 0, (try? buy(market: m, krwAmount: plan.krwAmount, price: price, on: ex)) != nil {
                    bought += 1
                } else {
                    skipped += 1
                }
                let step = plan.frequency == .daily ? 1 : 7
                key = KST.dayKey(cal.date(byAdding: .day, value: step, to: start)!)
                runs += 1
            }
            let b = bought, s = skipped, next = key
            update(ex) { a in
                guard let i = a.plans.firstIndex(where: { $0.id == plan.id }) else { return }
                a.plans[i].nextRunKey = next
                a.plans[i].runs += b
                a.plans[i].totalSpent += Double(b) * plan.krwAmount
                a.plans[i].lastResult = s > 0 ? "잔액 부족으로 \(s)회 건너뜀" : "\(b)회 매수 완료"
            }
            save()
            if b > 0 { notes.append("\(plan.koreanName) 적립식 \(b)회 매수 (\(Fmt.krw(Double(b) * plan.krwAmount)))") }
            if s > 0 { notes.append("\(plan.koreanName) 적립식 \(s)회는 현물 잔액이 부족해 건너뛰었어요") }
        }
        return notes
    }

    // MARK: - 평가

    struct Valuation {
        var coinValue = 0.0
        var coinCost = 0.0
        var krw = 0.0              // 현물 원화
        var futuresKRW = 0.0       // 선물 지갑 원화
        var positionValue = 0.0    // 포지션 평가 (증거금 + 미실현 손익)
        var positionMargin = 0.0
        var tradexValue = 0.0
        var cashAndPositions: Double { krw + futuresKRW + positionValue }
        var total: Double { coinValue + krw + futuresKRW + positionValue + tradexValue }
        var coinPnL: Double { coinValue - coinCost }
        var futuresPnL: Double { positionValue - positionMargin }
    }

    /// 한 거래소 계좌 평가 (TRADEX 제외)
    func valuation(_ ex: ExchangeID, prices: [String: Ticker]) -> Valuation {
        let a = account(ex)
        var v = Valuation(krw: a.krw, futuresKRW: a.futuresKRW)
        for (code, h) in a.holdings {
            let p = prices[code]?.tradePrice ?? h.averagePrice
            v.coinValue += p * h.quantity
            v.coinCost += h.averagePrice * h.quantity
        }
        // 미체결 주문에 잠가 둔 원화·코인도 내 자산
        for o in a.orders {
            if o.kind.isBuy {
                v.krw += o.lockedKRW
            } else {
                let p = prices[o.market]?.tradePrice ?? o.averagePrice
                v.coinValue += p * o.quantity
                v.coinCost += o.averagePrice * o.quantity
            }
        }
        for pos in a.positions {
            let p = prices[pos.market]?.tradePrice ?? pos.entryPrice
            v.positionValue += pos.value(at: p)
            v.positionMargin += pos.margin
        }
        return v
    }

    /// 전체 평가 (모든 거래소 + 남은 TRADEX). pricesFor: 거래소별 마지막 시세
    func totalValuation(pricesFor: (ExchangeID) -> [String: Ticker]) -> Valuation {
        var total = Valuation(tradexValue: Double(state.tradex) * TradexRules.krwPerTradex)
        for ex in ExchangeID.allCases {
            let v = valuation(ex, prices: pricesFor(ex))
            total.coinValue += v.coinValue; total.coinCost += v.coinCost
            total.krw += v.krw; total.futuresKRW += v.futuresKRW
            total.positionValue += v.positionValue; total.positionMargin += v.positionMargin
        }
        return total
    }

    /// 지급받은 TRADEX 가치 대비 총 수익
    /// = 지금까지 충전한 원화(충전 당시 환율) + 아직 남은 TRADEX의 현재 가치
    var baseValue: Double {
        let exchanged = state.tradexHistory
            .filter { $0.kind == .exchange }
            .reduce(0.0) { $0 + Double(-$1.amount) * ($1.krwPerTradex ?? TradexRules.legacyKrwPerTradex) }
        return exchanged + Double(state.tradex) * TradexRules.krwPerTradex
    }

    /// 처음 상태로 되돌리기 (보너스는 다시 지급하지 않고 지급 총량으로 복원)
    func reset() {
        let granted = state.grantedTradex
        var fresh = WalletState()
        fresh.tradex = granted
        fresh.grantedTradex = granted
        fresh.tradexHistory = [TradexRecord(kind: .signupBonus, amount: granted, date: .now)]
        // 미니게임·출석 기록은 유지 (같은 라운드·같은 날 보상을 다시 받지 못하게)
        fresh.predictions = state.predictions
        fresh.daily = state.daily
        fresh.xp = state.xp
        fresh.rewardedLevel = state.rewardedLevel
        fresh.season = state.season
        state = fresh
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
        recordEvent("predict", day: KST.dayKey(serverNow))
        gainXP(.predict)
        save()
    }

    /// 결과가 나온 예측을 판정하고 적중 시 모의 원화 지급. 새로 판정된 예측을 돌려준다.
    func settlePendingPredictions(creditTo ex: ExchangeID) async -> [Prediction] {
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
            if let result = settle(id: p.id, changeRate: candle.changeRate, creditTo: ex) { settled.append(result) }
        }
        return settled
    }

    private func settle(id: UUID, changeRate: Double, creditTo ex: ExchangeID) -> Prediction? {
        guard let i = state.predictions.firstIndex(where: { $0.id == id }),
              state.predictions[i].status == .pending else { return nil }
        var p = state.predictions[i]
        p.changeRate = changeRate
        if changeRate == 0 {
            p.status = .draw
        } else if (changeRate > 0) == (p.choice == .up) {
            p.status = .won
            p.reward = TradexRules.predictionRewardKRW
            let reward = p.reward
            update(ex) { $0.krw += reward }
            gainXP(.predictWin)
        } else {
            p.status = .lost
        }
        state.predictions[i] = p
        save()
        return p
    }

    // MARK: - 출석 · 미션 · 퀴즈

    enum DailyError: LocalizedError {
        case alreadyCheckedIn, notComplete, alreadyClaimed, alreadyAnswered
        var errorDescription: String? {
            switch self {
            case .alreadyCheckedIn: return "오늘은 이미 출석했어요."
            case .notComplete: return "아직 미션을 완료하지 않았어요."
            case .alreadyClaimed: return "이미 보상을 받았어요."
            case .alreadyAnswered: return "이미 푼 문제예요."
            }
        }
    }

    /// 미션 진행 기록. 날짜가 바뀌면 새로 시작.
    func recordEvent(_ event: String, day: String = KST.dayKey(.now)) {
        if state.daily.eventsDay != day {
            state.daily.eventsDay = day
            state.daily.events = []
        }
        if !state.daily.events.contains(event) { state.daily.events.append(event) }
        save()
    }

    func checkedIn(on day: String) -> Bool { state.daily.checkInDays.first == day }

    /// 출석 (서버 시간 기준 날짜). 지급액(기본 + 연속 보너스)을 돌려준다.
    func checkIn(serverNow: Date, creditTo ex: ExchangeID) throws -> (reward: Double, bonus: Double, streak: Int) {
        let today = KST.dayKey(serverNow)
        guard !checkedIn(on: today) else { throw DailyError.alreadyCheckedIn }
        let continued = state.daily.checkInDays.first == KST.previousDayKey(today)
        state.daily.streak = continued ? state.daily.streak + 1 : 1
        state.daily.checkInDays.insert(today, at: 0)
        state.daily.checkInDays = Array(state.daily.checkInDays.prefix(60))
        let bonus = state.daily.streak % DailyRules.streakBonusEvery == 0 ? DailyRules.streakBonus : 0
        update(ex) { $0.krw += DailyRules.checkInReward + bonus }
        gainXP(.attendance)
        save()
        return (DailyRules.checkInReward, bonus, state.daily.streak)
    }

    /// 출석이 끊겼는지 반영한 현재 연속 출석일
    func currentStreak(today: String) -> Int {
        guard let last = state.daily.checkInDays.first else { return 0 }
        return (last == today || last == KST.previousDayKey(today)) ? state.daily.streak : 0
    }

    func missionProgress(_ m: Mission, today: String) -> Int {
        let events = state.daily.eventsDay == today ? state.daily.events : []
        let count: Int
        switch m.id {
        case "chart": count = events.filter { $0.hasPrefix("chart:") }.count
        case "quiz": count = state.daily.quizDay == today ? state.daily.quizAnswers.count : 0
        default: count = events.contains(m.id) ? 1 : 0
        }
        return min(count, m.goal)
    }

    func missionClaimed(_ m: Mission, today: String) -> Bool {
        state.daily.claimedDay == today && state.daily.claimedMissions.contains(m.id)
    }

    func claimMission(_ m: Mission, serverNow: Date, creditTo ex: ExchangeID) throws {
        let today = KST.dayKey(serverNow)
        guard !missionClaimed(m, today: today) else { throw DailyError.alreadyClaimed }
        guard missionProgress(m, today: today) >= m.goal else { throw DailyError.notComplete }
        if state.daily.claimedDay != today {
            state.daily.claimedDay = today
            state.daily.claimedMissions = []
        }
        state.daily.claimedMissions.append(m.id)
        update(ex) { $0.krw += m.reward }
        gainXP(.mission)
        save()
    }

    func quizAnswer(_ q: QuizQuestion, today: String) -> Int? {
        state.daily.quizDay == today ? state.daily.quizAnswers[q.id] : nil
    }

    /// 퀴즈 답 제출. 맞히면 보상 지급 후 true.
    func answerQuiz(_ q: QuizQuestion, choice: Int, serverNow: Date, creditTo ex: ExchangeID) throws -> Bool {
        let today = KST.dayKey(serverNow)
        guard QuizQuestion.today(today).contains(q) else { throw DailyError.alreadyAnswered }
        if state.daily.quizDay != today {
            state.daily.quizDay = today
            state.daily.quizAnswers = [:]
        }
        guard state.daily.quizAnswers[q.id] == nil else { throw DailyError.alreadyAnswered }
        state.daily.quizAnswers[q.id] = choice
        let correct = choice == q.answer
        if correct {
            update(ex) { $0.krw += DailyRules.quizReward }
            gainXP(.quiz)
        }
        save()
        return correct
    }

    // MARK: - 등급 · 경험치

    var level: TraderLevel { TraderLevel.level(for: state.xp) }

    /// 경험치 적립. 거래 관련은 하루 상한, 등급이 오르면 TRADEX 보너스 지급.
    func gainXP(_ rule: XPRule, day: String = KST.dayKey(.now)) {
        var amount = rule.amount
        if rule.isTradeCapped {
            if state.daily.tradeXPDay != day {
                state.daily.tradeXPDay = day
                state.daily.tradeXP = 0
            }
            amount = min(amount, XPRule.dailyTradeCap - state.daily.tradeXP)
            guard amount > 0 else { return }
            state.daily.tradeXP += amount
        }
        gainAP(rule, day: day)
        let before = level
        state.xp += amount
        let after = level
        // 한 번에 여러 등급이 올라도 아직 보상받지 않은 등급만 지급
        if after.index > before.index, after.index > state.rewardedLevel {
            let bonus = TraderLevel.all[(state.rewardedLevel + 1)...after.index].reduce(0) { $0 + $1.rewardTradex }
            state.rewardedLevel = after.index
            if bonus > 0 {
                state.tradex += bonus
                state.grantedTradex += bonus
                state.tradexHistory.insert(TradexRecord(kind: .levelReward, amount: bonus, date: .now), at: 0)
            }
            pendingLevelUp = after
        }
        save()
    }

    // MARK: - 시즌 AP

    /// 이번 시즌 (시즌이 바뀌었으면 지난 시즌을 기록하고 AP를 0으로)
    var season: Season { Season.current() }
    var seasonAP: Int { state.season.id == season.id ? state.season.ap : 0 }

    func rollSeasonIfNeeded() {
        let current = Season.current().id
        guard state.season.id != current else { return }
        if !state.season.id.isEmpty, state.season.ap > 0 {
            state.season.history.insert(SeasonRecord(id: state.season.id, ap: state.season.ap), at: 0)
        }
        state.season.id = current
        state.season.ap = 0
        state.season.apToday = 0
        state.season.apDay = ""
    }

    /// AP 적립 (하루 상한). 경험치와 같은 활동에서 함께 쌓인다.
    private func gainAP(_ rule: XPRule, day: String) {
        rollSeasonIfNeeded()
        if state.season.apDay != day {
            state.season.apDay = day
            state.season.apToday = 0
        }
        let amount = min(rule.ap, XPRule.dailyAPCap - state.season.apToday)
        guard amount > 0 else { return }
        state.season.apToday += amount
        state.season.ap += amount
    }

    // MARK: - 과거 차트 맞히기

    func chartGameRewardedLeft(today: String) -> Int {
        let plays = state.daily.chartGameDay == today ? state.daily.chartGamePlays : 0
        return max(0, ChartGameRules.rewardedPerDay - plays)
    }

    /// 한 판 결과 기록. 보상 가능한 판이면 정답 시 모의 원화·경험치 지급. 지급액을 돌려준다.
    @discardableResult
    func recordChartGame(correct: Bool, today: String, creditTo ex: ExchangeID) -> Double {
        guard chartGameRewardedLeft(today: today) > 0 else { return 0 }
        if state.daily.chartGameDay != today {
            state.daily.chartGameDay = today
            state.daily.chartGamePlays = 0
        }
        state.daily.chartGamePlays += 1
        gainXP(.chartGame, day: today)
        guard correct else { save(); return 0 }
        update(ex) { $0.krw += ChartGameRules.reward }
        gainXP(.chartGameWin, day: today)
        save()
        return ChartGameRules.reward
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
