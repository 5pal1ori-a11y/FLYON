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
    enum Kind: String, Codable { case signupBonus, exchange }
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

// MARK: - 거래소별 계좌

struct ExchangeAccount: Codable, Equatable {
    var krw: Double = 0                       // 현물 원화
    var holdings: [String: Holding] = [:]
    var trades: [TradeRecord] = []
    var futuresKRW: Double = 0                // 선물 지갑 (주문 가능 증거금)
    var positions: [FuturesPosition] = []
    var futuresHistory: [FuturesRecord] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        krw = try c.decodeIfPresent(Double.self, forKey: .krw) ?? 0
        holdings = try c.decodeIfPresent([String: Holding].self, forKey: .holdings) ?? [:]
        trades = try c.decodeIfPresent([TradeRecord].self, forKey: .trades) ?? []
        futuresKRW = try c.decodeIfPresent(Double.self, forKey: .futuresKRW) ?? 0
        positions = try c.decodeIfPresent([FuturesPosition].self, forKey: .positions) ?? []
        futuresHistory = try c.decodeIfPresent([FuturesRecord].self, forKey: .futuresHistory) ?? []
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

    init() {}

    private enum CodingKeys: String, CodingKey {
        case tradex, accounts, tradexHistory, grantedTradex, predictions, daily
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
    }
}

struct AppUser: Codable, Equatable {
    let id: String
    var displayName: String
    let provider: String   // "apple" | "guest"
}
