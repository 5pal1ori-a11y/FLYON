import Foundation

struct Store: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: BusinessKind
    var district: DistrictID
    var name: String
    var level: Int = 1
    var staff: Int = 0
    var invested: Double = 0
    var openedDay: Int = 1
    var improvements: [String] = []
    /// 임대차 갱신 때마다 누적되는 임대료 배율
    var rentFactor: Double = 1
    /// 현재 임대차 계약을 시작한 날
    var leaseStart: Int = 1
    /// 건물주에게 맡긴 보증금 (팔거나 건물을 사면 돌려받음)
    var deposit: Double = 0
    /// 시설 노후도 0~100
    var wear: Double = 0

    var displayName: String {
        kind == .holdings ? name : "\(name) \(district.info.short)점"
    }

    func has(_ improvement: String) -> Bool { improvements.contains(improvement) }
}

extension Store {
    private enum CodingKeys: String, CodingKey {
        case id, kind, district, name, level, staff, invested, openedDay, improvements
        case rentFactor, leaseStart, deposit, wear
    }

    // 예전 저장 파일에는 improvements가 없다
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(BusinessKind.self, forKey: .kind)
        district = try c.decode(DistrictID.self, forKey: .district)
        name = try c.decode(String.self, forKey: .name)
        level = try c.decode(Int.self, forKey: .level)
        staff = try c.decode(Int.self, forKey: .staff)
        invested = try c.decode(Double.self, forKey: .invested)
        openedDay = try c.decode(Int.self, forKey: .openedDay)
        improvements = try c.decodeIfPresent([String].self, forKey: .improvements) ?? []
        rentFactor = try c.decodeIfPresent(Double.self, forKey: .rentFactor) ?? 1
        leaseStart = try c.decodeIfPresent(Int.self, forKey: .leaseStart) ?? openedDay
        deposit = try c.decodeIfPresent(Double.self, forKey: .deposit) ?? 0
        wear = try c.decodeIfPresent(Double.self, forKey: .wear) ?? 0
    }
}

struct OwnedBuilding: Identifiable, Codable, Hashable {
    var id: String            // BuildingSpec.id
    var district: DistrictID
    var purchasePrice: Double
    var boughtDay: Int
}

struct Listing: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: BusinessKind
    var district: DistrictID
    var name: String
    var level: Int
    var staff: Int
    var price: Double
    var postedDay: Int
    var expiresDay: Int
    var story: String
}

struct DistrictMarket: Identifiable, Codable, Hashable {
    var id: DistrictID
    var index: Double = 1.0
    var history: [Double] = [1.0]

    var change: Double {
        guard history.count >= 2 else { return 0 }
        let prev = history[history.count - 2]
        return prev == 0 ? 0 : (index - prev) / prev
    }
}

enum EventEffect: Codable, Hashable {
    case traffic(DistrictID, Double)
    case business(BusinessKind, Double)
    case economy(Double)
}

struct MarketEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var effect: EventEffect
    var daysLeft: Int
    var headline: String
}

struct NewsItem: Identifiable, Codable, Hashable {
    enum Tone: String, Codable { case good, bad, neutral }
    var id = UUID()
    var day: Int
    var headline: String
    var detail: String
    var tone: Tone
}

struct DayReport: Identifiable, Codable, Hashable {
    var day: Int
    var revenue: Double = 0
    /// 원가 포함 총매출 (예전 저장 파일엔 없음)
    var gross: Double? = 0
    var buildingIncome: Double = 0
    var rent: Double = 0
    var wages: Double = 0
    var interest: Double = 0

    var id: Int { day }
    var net: Double { revenue + buildingIncome - rent - wages - interest }
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case buy, sell, open, upgrade, hire, loan, repay, settle }
    var id = UUID()
    var day: Int
    var kind: Kind
    var title: String
    var amount: Double
}

struct Stats: Codable, Hashable {
    var taps: Int = 0
    var tapEarnings: Double = 0
    var totalRevenue: Double = 0
    var trades: Int = 0
    var tradeProfit: Double = 0
    var storesOpened: Int = 0
    var peakNetWorth: Double = 0
    var sells: Int = 0
    var decisionsMade: Int = 0
    var improvementsBought: Int = 0
    var missionsDone: Int = 0
    var bestDailyNet: Double = 0
    var kindsOwned: [String] = []
    var vipServed: Int = 0
    var bestCombo: Int = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case taps, tapEarnings, totalRevenue, trades, tradeProfit, storesOpened, peakNetWorth
        case sells, decisionsMade, improvementsBought, missionsDone, bestDailyNet, kindsOwned
        case vipServed, bestCombo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        taps = try c.decodeIfPresent(Int.self, forKey: .taps) ?? 0
        tapEarnings = try c.decodeIfPresent(Double.self, forKey: .tapEarnings) ?? 0
        totalRevenue = try c.decodeIfPresent(Double.self, forKey: .totalRevenue) ?? 0
        trades = try c.decodeIfPresent(Int.self, forKey: .trades) ?? 0
        tradeProfit = try c.decodeIfPresent(Double.self, forKey: .tradeProfit) ?? 0
        storesOpened = try c.decodeIfPresent(Int.self, forKey: .storesOpened) ?? 0
        peakNetWorth = try c.decodeIfPresent(Double.self, forKey: .peakNetWorth) ?? 0
        sells = try c.decodeIfPresent(Int.self, forKey: .sells) ?? 0
        decisionsMade = try c.decodeIfPresent(Int.self, forKey: .decisionsMade) ?? 0
        improvementsBought = try c.decodeIfPresent(Int.self, forKey: .improvementsBought) ?? 0
        missionsDone = try c.decodeIfPresent(Int.self, forKey: .missionsDone) ?? 0
        bestDailyNet = try c.decodeIfPresent(Double.self, forKey: .bestDailyNet) ?? 0
        kindsOwned = try c.decodeIfPresent([String].self, forKey: .kindsOwned) ?? []
        vipServed = try c.decodeIfPresent(Int.self, forKey: .vipServed) ?? 0
        bestCombo = try c.decodeIfPresent(Int.self, forKey: .bestCombo) ?? 0
    }
}

struct PendingDecision: Codable, Hashable {
    var id: String
    var scale: Double
    var day: Int
}

struct DecisionResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let text: String
    let good: Bool
    let lines: [String]
}

struct OfflineReport: Identifiable, Hashable {
    let id = UUID()
    let seconds: Double
    let earned: Double
}

struct SaleOffer: Identifiable, Hashable {
    let id = UUID()
    let buyer: String
    let note: String
    let price: Double
}

/// 디스크에 저장되는 모든 것
struct SaveData: Codable {
    var version = 1
    var companyName: String
    var started: Bool
    var cash: Double
    var debt: Double
    var day: Int
    var dayClock: Double
    var tapLevel: Int
    var stores: [Store]
    var buildings: [OwnedBuilding]
    var markets: [DistrictMarket]
    var listings: [Listing]
    var events: [MarketEvent]
    var news: [NewsItem]
    var history: [DayReport]
    var today: DayReport
    var ledger: [LedgerEntry]
    var stats: Stats
    var highestRank: Int
    var lastActive: Date
    var hapticsOn: Bool
    // v0.2에서 추가 — 예전 저장 파일엔 없으므로 옵셔널
    var reputation: Double?
    var weather: Weather?
    var talents: [String]?
    var pendingDecision: PendingDecision?
    var missions: [Mission]?
    var progress: DailyProgress?
    var claimedAchievements: [String]?
    // v0.3 — 현실 규칙
    var isCorporation: Bool?
    var baseRate: Double?
    var minimumWage: Double?
    var wageIndex: Double?
    var vatBase: Double?
    var incomeTaxBase: Double?
    var taxBill: TaxBill?
    var taxesPaid: Double?
    // v0.4 — 재미 장치
    var streak: Int?
    var lastLoginDay: String?
    var legacy: Int?
    var generation: Int?
    var notificationsOn: Bool?
}
