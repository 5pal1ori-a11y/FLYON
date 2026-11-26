import Foundation

enum TradexRules {
    /// 1 TRADEX = 모의투자 원화 10,000원
    static let krwPerTradex: Double = 10_000
    /// 첫 로그인 지급량
    static let signupBonus = 10
    /// 매매 수수료 (업비트 원화마켓 일반 수수료와 동일한 0.05%로 가정)
    static let feeRate: Double = 0.0005
    /// 최소 주문 금액
    static let minOrderKRW: Double = 5_000
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
}

struct AppUser: Codable, Equatable {
    let id: String
    var displayName: String
    let provider: String   // "apple" | "guest"
}
