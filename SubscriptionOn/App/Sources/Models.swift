import SwiftUI

enum Category: String, CaseIterable, Codable, Identifiable {
    case ott = "OTT", ai = "AI", game = "게임", membership = "멤버십"
    case insurance = "보험", life = "생활", health = "건강", etc = "기타"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .ott: "play.tv.fill"
        case .ai: "sparkles"
        case .game: "gamecontroller.fill"
        case .membership: "creditcard.fill"
        case .insurance: "shield.fill"
        case .life: "house.fill"
        case .health: "heart.fill"
        case .etc: "ellipsis.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .ott: Color(hex: 0x3182F6)
        case .ai: Color(hex: 0x8B5CF6)
        case .game: Color(hex: 0xF97316)
        case .membership: Color(hex: 0x10B981)
        case .insurance: Color(hex: 0x06B6D4)
        case .life: Color(hex: 0xF59E0B)
        case .health: Color(hex: 0xEF4444)
        case .etc: Color(hex: 0x9CA3AF)
        }
    }
}

enum Cycle: String, CaseIterable, Codable, Identifiable {
    case weekly = "매주", monthly = "매월", yearly = "매년"
    var id: String { rawValue }
    var monthlyFactor: Double {
        switch self { case .weekly: 52.0 / 12.0; case .monthly: 1; case .yearly: 1.0 / 12.0 }
    }
    func next(after d: Date) -> Date {
        let c = Calendar.current
        switch self {
        case .weekly: return c.date(byAdding: .day, value: 7, to: d)!
        case .monthly: return c.date(byAdding: .month, value: 1, to: d)!
        case .yearly: return c.date(byAdding: .year, value: 1, to: d)!
        }
    }
}

enum SubStatus: String, Codable { case active = "이용 중", paused = "일시중지", cancelled = "해지함" }

struct PricePoint: Codable, Hashable { var date: Date; var price: Int }

struct Subscription: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var price: Int
    var category: Category
    var cycle: Cycle = .monthly
    var nextDate: Date
    var startDate: Date = Date()
    var payMethod: String = ""
    var people: Int = 1
    var memo: String = ""
    var status: SubStatus = .active
    var trialEnd: Date? = nil
    var payCount: Int = 0
    var history: [PricePoint] = []

    var monthly: Double { Double(price) * cycle.monthlyFactor }
    var yearly: Double { monthly * 12 }
    var isActive: Bool { status == .active }
    var dDay: Int {
        let c = Calendar.current
        return c.dateComponents([.day], from: c.startOfDay(for: Date()), to: c.startOfDay(for: nextDate)).day ?? 0
    }
    var totalPaid: Int { price * payCount }
    var service: Service? { Catalog.find(name) }
    var priceHike: (from: Int, to: Int)? {
        guard history.count >= 2, let last = history.last, let prev = history.dropLast().last, last.price > prev.price else { return nil }
        return (prev.price, last.price)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Int {
    var won: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return (f.string(from: NSNumber(value: self)) ?? "\(self)") + "원"
    }
}
extension Double { var won: String { Int(self.rounded()).won } }
