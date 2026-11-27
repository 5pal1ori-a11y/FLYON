import Foundation

enum TradexRules {
    /// 1 TRADEX = 모의투자 원화 5,000,000원
    static let krwPerTradex: Double = 5_000_000
    /// 예전 버전(1 TRADEX = 10,000원)에서 교환한 기록의 환율
    static let legacyKrwPerTradex: Double = 10_000
    /// 첫 로그인 지급량
    static let signupBonus = 10
    /// 현물 매매 수수료 (모의, 0.05%)
    static let feeRate: Double = 0.0005
    /// 최소 주문 금액
    static let minOrderKRW: Double = 5_000
    /// 미니게임 적중 보상 (모의투자 원화)
    static let predictionRewardKRW: Double = 1_000_000
    /// 선물 최대 레버리지 (모의, 수수료·펀딩비 없음)
    static let maxLeverage = 20
    static let leverageSteps = [1, 2, 3, 5, 10, 20]
}

struct Holding: Codable, Equatable {
    var quantity: Double
    var averagePrice: Double
    var koreanName: String
}

enum TradeSide: String, Codable { case buy, sell }

struct TradeRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    let side: TradeSide
    let market: String
    let koreanName: String
    let price: Double
    let quantity: Double
    let fee: Double
    let date: Date
    var realizedPnL: Double? = nil
}

struct TradexRecord: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case signupBonus, exchange, levelReward, seasonReward }
    var id = UUID()
    let kind: Kind
    let amount: Int   // +지급 / -교환
    let date: Date
    /// 교환 당시 1 TRADEX의 원화 가치 (예전 기록은 nil → 10,000원)
    var krwPerTradex: Double? = nil
    /// 충전한 거래소·지갑 (예전 기록은 nil → 업비트 현물)
    var exchange: ExchangeID? = nil
    var toFutures: Bool? = nil
}

// MARK: - 선물 (모의)

enum PositionSide: String, Codable {
    case long, short
    var title: String { self == .long ? "롱" : "숏" }
}

/// 격리 마진 포지션. 증거금을 모두 잃으면(가격이 1/레버리지만큼 반대로 움직이면) 청산.
struct FuturesPosition: Codable, Identifiable, Equatable {
    var id = UUID()
    let market: String
    let koreanName: String
    let side: PositionSide
    let leverage: Int
    let margin: Double
    let entryPrice: Double
    let quantity: Double
    let openedAt: Date

    var symbol: String { String(market.split(separator: "-").last ?? "") }
    var size: Double { quantity * entryPrice }
    func pnl(at price: Double) -> Double { (price - entryPrice) * quantity * (side == .long ? 1 : -1) }
    func roe(at price: Double) -> Double { margin > 0 ? pnl(at: price) / margin : 0 }
    func value(at price: Double) -> Double { max(0, margin + pnl(at: price)) }
    var liquidationPrice: Double {
        side == .long ? entryPrice * (1 - 1 / Double(leverage)) : entryPrice * (1 + 1 / Double(leverage))
    }
    func isLiquidated(at price: Double) -> Bool {
        side == .long ? price <= liquidationPrice : price >= liquidationPrice
    }
}

struct FuturesRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    let market: String
    let koreanName: String
    let side: PositionSide
    let leverage: Int
    let margin: Double
    let entryPrice: Double
    let exitPrice: Double
    let pnl: Double
    let closedAt: Date
    let liquidated: Bool
}

// MARK: - 예약 주문 (지정가 · 손절 · 익절)

enum OrderKind: String, Codable, CaseIterable {
    case limitBuy, limitSell, stopLoss, takeProfit

    var title: String {
        switch self {
        case .limitBuy: return "지정가 매수"
        case .limitSell: return "지정가 매도"
        case .stopLoss: return "손절"
        case .takeProfit: return "익절"
        }
    }
    var isBuy: Bool { self == .limitBuy }

    /// 체결 조건: 매수·손절은 가격이 기준 이하로, 매도·익절은 기준 이상으로
    func isTriggered(price: Double, trigger: Double) -> Bool {
        switch self {
        case .limitBuy, .stopLoss: return price <= trigger
        case .limitSell, .takeProfit: return price >= trigger
        }
    }
}

/// 미체결 주문. 매수는 원화(수수료 포함)를, 매도는 코인 수량을 주문하는 순간 잠가 둔다.
struct PendingOrder: Codable, Identifiable, Equatable {
    var id = UUID()
    let kind: OrderKind
    let market: String
    let koreanName: String
    let triggerPrice: Double
    let krwAmount: Double      // 매수: 쓸 원화 (수수료 제외)
    let lockedKRW: Double      // 매수: 잠근 원화 (수수료 포함)
    let quantity: Double       // 매도: 잠근 수량
    let averagePrice: Double   // 매도: 잠근 수량의 평균 매수가 (취소 시 복원)
    let createdAt: Date

    var symbol: String { String(market.split(separator: "-").last ?? "") }
}

/// 체결 알림용 요약
struct OrderFill: Identifiable {
    let id = UUID()
    let kind: OrderKind
    let koreanName: String
    let price: Double
    let quantity: Double
}

// MARK: - 적립식 자동 매수

/// 정해진 날 오전 9시(한국시간)에 정해진 금액만큼 산다.
/// 앱이 꺼져 있던 날은 다음에 앱을 열 때 그날 일봉 시가로 처리한다.
struct RecurringPlan: Codable, Identifiable, Equatable {
    enum Frequency: String, Codable, CaseIterable, Identifiable {
        case daily, weekly
        var id: String { rawValue }
        var title: String { self == .daily ? "매일" : "매주" }
    }

    var id = UUID()
    let market: String
    let koreanName: String
    var krwAmount: Double
    var frequency: Frequency
    var weekday: Int            // 매주일 때 요일 (1=일 ... 7=토)
    var nextRunKey: String      // 다음 실행일 (yyyy-MM-dd, 한국시간)
    var paused = false
    var runs = 0
    var totalSpent = 0.0
    var lastResult: String? = nil
    let createdAt: Date

    var symbol: String { String(market.split(separator: "-").last ?? "") }

    static let weekdayNames = ["", "일", "월", "화", "수", "목", "금", "토"]
    var scheduleText: String {
        frequency == .daily ? "매일 오전 9시" : "매주 \(RecurringPlan.weekdayNames[weekday])요일 오전 9시"
    }
}

// MARK: - 거래소별 계좌

struct ExchangeAccount: Codable, Equatable {
    var krw: Double = 0                       // 현물 원화
    var holdings: [String: Holding] = [:]
    var trades: [TradeRecord] = []
    var futuresKRW: Double = 0                // 선물 지갑 (주문 가능 증거금)
    var positions: [FuturesPosition] = []
    var futuresHistory: [FuturesRecord] = []
    var orders: [PendingOrder] = []
    var plans: [RecurringPlan] = []

    init() {}

    /// 다른 계좌를 이 계좌로 합친다 (빗썸 계좌 정리용)
    mutating func merge(_ other: ExchangeAccount) {
        krw += other.krw
        futuresKRW += other.futuresKRW
        for (code, h) in other.holdings {
            if var mine = holdings[code] {
                mine.averagePrice = (mine.averagePrice * mine.quantity + h.averagePrice * h.quantity) / (mine.quantity + h.quantity)
                mine.quantity += h.quantity
                holdings[code] = mine
            } else {
                holdings[code] = h
            }
        }
        trades = (trades + other.trades).sorted { $0.date > $1.date }
        futuresHistory = (futuresHistory + other.futuresHistory).sorted { $0.closedAt > $1.closedAt }
        positions += other.positions
        orders += other.orders
        plans += other.plans
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        krw = try c.decodeIfPresent(Double.self, forKey: .krw) ?? 0
        holdings = try c.decodeIfPresent([String: Holding].self, forKey: .holdings) ?? [:]
        trades = try c.decodeIfPresent([TradeRecord].self, forKey: .trades) ?? []
        futuresKRW = try c.decodeIfPresent(Double.self, forKey: .futuresKRW) ?? 0
        positions = try c.decodeIfPresent([FuturesPosition].self, forKey: .positions) ?? []
        futuresHistory = try c.decodeIfPresent([FuturesRecord].self, forKey: .futuresHistory) ?? []
        orders = try c.decodeIfPresent([PendingOrder].self, forKey: .orders) ?? []
        plans = try c.decodeIfPresent([RecurringPlan].self, forKey: .plans) ?? []
    }
}

/// 디스크에 저장되는 지갑 상태
struct WalletState: Codable {
    var tradex: Int = 0
    var accounts: [String: ExchangeAccount] = [:]   // key: ExchangeID.rawValue
    var tradexHistory: [TradexRecord] = []
    /// 지금까지 지급된 TRADEX 총량
    var grantedTradex: Int = 0
    /// 미니게임 예측 기록
    var predictions: [Prediction] = []
    /// 출석·미션·퀴즈
    var daily = DailyState()
    /// 경험치와 보상을 받은 최고 등급
    var xp = 0
    var rewardedLevel = 0
    /// 이번 시즌 AP와 지난 시즌 기록
    var season = SeasonState()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case tradex, accounts, tradexHistory, grantedTradex, predictions, daily, xp, rewardedLevel, season
        case krw, holdings, trades   // 예전 버전(거래소 구분 없음) 필드
    }

    /// 예전 버전 파일도 읽히도록 모든 필드를 선택적으로 디코딩하고,
    /// 거래소 구분이 없던 시절의 원화·보유 코인·거래 내역은 업비트 계좌로 옮긴다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tradex = try c.decodeIfPresent(Int.self, forKey: .tradex) ?? 0
        accounts = try c.decodeIfPresent([String: ExchangeAccount].self, forKey: .accounts) ?? [:]
        tradexHistory = try c.decodeIfPresent([TradexRecord].self, forKey: .tradexHistory) ?? []
        grantedTradex = try c.decodeIfPresent(Int.self, forKey: .grantedTradex) ?? 0
        predictions = try c.decodeIfPresent([Prediction].self, forKey: .predictions) ?? []
        daily = try c.decodeIfPresent(DailyState.self, forKey: .daily) ?? DailyState()
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        rewardedLevel = try c.decodeIfPresent(Int.self, forKey: .rewardedLevel) ?? 0
        season = try c.decodeIfPresent(SeasonState.self, forKey: .season) ?? SeasonState()
        // 빗썸을 뺀 버전: 빗썸 계좌의 원화·코인·포지션·주문·적립식을 업비트 계좌로 합친다
        if let bithumb = accounts[ExchangeID.bithumb.rawValue] {
            var upbit = accounts[ExchangeID.upbit.rawValue] ?? ExchangeAccount()
            upbit.merge(bithumb)
            accounts[ExchangeID.upbit.rawValue] = upbit
            accounts[ExchangeID.bithumb.rawValue] = nil
        }
        if accounts.isEmpty {
            var legacy = ExchangeAccount()
            legacy.krw = try c.decodeIfPresent(Double.self, forKey: .krw) ?? 0
            legacy.holdings = try c.decodeIfPresent([String: Holding].self, forKey: .holdings) ?? [:]
            legacy.trades = try c.decodeIfPresent([TradeRecord].self, forKey: .trades) ?? []
            if legacy != ExchangeAccount() { accounts[ExchangeID.upbit.rawValue] = legacy }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tradex, forKey: .tradex)
        try c.encode(accounts, forKey: .accounts)
        try c.encode(tradexHistory, forKey: .tradexHistory)
        try c.encode(grantedTradex, forKey: .grantedTradex)
        try c.encode(predictions, forKey: .predictions)
        try c.encode(daily, forKey: .daily)
        try c.encode(xp, forKey: .xp)
        try c.encode(rewardedLevel, forKey: .rewardedLevel)
        try c.encode(season, forKey: .season)
    }
}

struct AppUser: Codable, Equatable {
    let id: String
    var displayName: String
    let provider: String   // "apple" | "guest"
}
