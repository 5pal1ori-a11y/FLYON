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

    var displayName: String {
        kind == .holdings ? name : "\(name) \(district.info.short)점"
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
}
