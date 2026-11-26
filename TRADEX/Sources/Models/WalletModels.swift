import Foundation

enum TradexRules {
    /// 1 TRADEX = 모의투자 원화 5,000,000원
    static let krwPerTradex: Double = 5_000_000
    /// 예전 버전(1 TRADEX = 10,000원)에서 교환한 기록의 환율
    static let legacyKrwPerTradex: Double = 10_000
    /// 첫 로그인 지급량
    static let signupBonus = 10
    /// 매매 수수료 (업비트 원화마켓 일반 수수료와 동일한 0.05%로 가정)
    static let feeRate: Double = 0.0005
    /// 최소 주문 금액
    static let minOrderKRW: Double = 5_000
    /// 미니게임 적중 보상 (모의투자 원화)
    static let predictionRewardKRW: Double = 10_000
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
}

/// 디스크에 저장되는 지갑 상태
struct WalletState: Codable {
    var tradex: Int = 0
    var krw: Double = 0
    var holdings: [String: Holding] = [:]
    var trades: [TradeRecord] = []
    var tradexHistory: [TradexRecord] = []
    /// 지금까지 지급된 TRADEX 총량 (수익률 기준)
    var grantedTradex: Int = 0
    /// 미니게임 예측 기록
    var predictions: [Prediction] = []
    /// 출석·미션·퀴즈
    var daily = DailyState()
}

extension WalletState {
    /// 예전 버전에서 저장한 파일(새 필드 없음)도 그대로 읽히도록 모든 필드를 선택적으로 디코딩
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tradex = try c.decodeIfPresent(Int.self, forKey: .tradex) ?? 0
        krw = try c.decodeIfPresent(Double.self, forKey: .krw) ?? 0
        holdings = try c.decodeIfPresent([String: Holding].self, forKey: .holdings) ?? [:]
        trades = try c.decodeIfPresent([TradeRecord].self, forKey: .trades) ?? []
        tradexHistory = try c.decodeIfPresent([TradexRecord].self, forKey: .tradexHistory) ?? []
        grantedTradex = try c.decodeIfPresent(Int.self, forKey: .grantedTradex) ?? 0
        predictions = try c.decodeIfPresent([Prediction].self, forKey: .predictions) ?? []
        daily = try c.decodeIfPresent(DailyState.self, forKey: .daily) ?? DailyState()
    }
}

struct AppUser: Codable, Equatable {
    let id: String
    var displayName: String
    let provider: String   // "apple" | "guest"
}
