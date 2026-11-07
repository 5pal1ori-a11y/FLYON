import Foundation
import SwiftUI

struct Airport: Identifiable, Hashable, Codable {
    let code: String      // IATA
    let city: String
    let name: String
    let country: String
    var id: String { code }
    var isDomestic: Bool { country == "대한민국" }
}

struct Airline: Identifiable, Hashable, Codable {
    let code: String      // IATA
    let name: String
    var id: String { code }
}

struct FavoriteRoute: Identifiable, Hashable, Codable {
    let originCode: String
    let destinationCode: String
    var id: String { "\(originCode)-\(destinationCode)" }

    var origin: Airport? { Catalog.airport(originCode) }
    var destination: Airport? { Catalog.airport(destinationCode) }
}

struct RouteSearch: Hashable {
    let origin: Airport
    let destination: Airport
    let month: Date
    let airlines: Set<Airline>   // 비어 있으면 전체
}

struct PriceQuote: Identifiable, Hashable {
    let id = UUID()
    let airline: Airline
    let price: Int
    let departureDate: Date
    let transfers: Int
}

struct PricePoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let price: Int
}

struct PriceAnalysis {
    enum Verdict {
        case cheap, normal, expensive

        var title: String {
            switch self {
            case .cheap: return "평소보다 저렴해요"
            case .normal: return "평소 수준이에요"
            case .expensive: return "평소보다 비싸요"
            }
        }
        var symbol: String {
            switch self {
            case .cheap: return "arrow.down.right"
            case .normal: return "equal"
            case .expensive: return "arrow.up.right"
            }
        }
        var color: Color {
            switch self {
            case .cheap: return Theme.cheap
            case .normal: return Theme.normal
            case .expensive: return Theme.expensive
            }
        }
    }

    let current: Int
    let average: Int
    let lowest: Int
    let highest: Int

    init?(history: [PricePoint]) {
        let prices = history.map(\.price)
        guard let last = history.sorted(by: { $0.date < $1.date }).last,
              let lo = prices.min(), let hi = prices.max(), !prices.isEmpty else { return nil }
        current = last.price
        lowest = lo
        highest = hi
        average = prices.reduce(0, +) / prices.count
    }

    /// 평균 대비 현재가 편차 (-0.09 = 9% 저렴)
    var deviation: Double {
        average == 0 ? 0 : Double(current - average) / Double(average)
    }

    var verdict: Verdict {
        if deviation <= -0.07 { return .cheap }
        if deviation >= 0.07 { return .expensive }
        return .normal
    }

    var deviationText: String {
        let pct = Int((abs(deviation) * 100).rounded())
        if pct == 0 { return "평균과 비슷" }
        return deviation < 0 ? "평균 대비 \(pct)% 낮음" : "평균 대비 \(pct)% 높음"
    }
}

// MARK: - Catalog

enum Catalog {
    static let airports: [Airport] = [
        Airport(code: "ICN", city: "인천", name: "인천국제공항", country: "대한민국"),
        Airport(code: "GMP", city: "서울(김포)", name: "김포국제공항", country: "대한민국"),
        Airport(code: "CJU", city: "제주", name: "제주국제공항", country: "대한민국"),
        Airport(code: "PUS", city: "부산", name: "김해국제공항", country: "대한민국"),
        Airport(code: "TAE", city: "대구", name: "대구국제공항", country: "대한민국"),
        Airport(code: "CJJ", city: "청주", name: "청주국제공항", country: "대한민국"),
        Airport(code: "KWJ", city: "광주", name: "광주공항", country: "대한민국"),
        Airport(code: "NRT", city: "도쿄(나리타)", name: "나리타국제공항", country: "일본"),
        Airport(code: "HND", city: "도쿄(하네다)", name: "하네다공항", country: "일본"),
        Airport(code: "KIX", city: "오사카", name: "간사이국제공항", country: "일본"),
        Airport(code: "FUK", city: "후쿠오카", name: "후쿠오카공항", country: "일본"),
        Airport(code: "CTS", city: "삿포로", name: "신치토세공항", country: "일본"),
        Airport(code: "BKK", city: "방콕", name: "수완나품공항", country: "태국"),
        Airport(code: "SGN", city: "호치민", name: "탄손낫국제공항", country: "베트남"),
        Airport(code: "DAD", city: "다낭", name: "다낭국제공항", country: "베트남"),
        Airport(code: "TPE", city: "타이베이", name: "타오위안국제공항", country: "대만"),
        Airport(code: "HKG", city: "홍콩", name: "홍콩국제공항", country: "홍콩"),
        Airport(code: "SIN", city: "싱가포르", name: "창이공항", country: "싱가포르"),
        Airport(code: "GUM", city: "괌", name: "안토니오 B. 원 팻 공항", country: "미국"),
        Airport(code: "LAX", city: "로스앤젤레스", name: "로스앤젤레스국제공항", country: "미국"),
        Airport(code: "JFK", city: "뉴욕", name: "존 F. 케네디국제공항", country: "미국"),
        Airport(code: "CDG", city: "파리", name: "샤를 드 골 공항", country: "프랑스"),
        Airport(code: "LHR", city: "런던", name: "히스로공항", country: "영국"),
    ]

    static let airlines: [Airline] = [
        Airline(code: "KE", name: "대한항공"),
        Airline(code: "OZ", name: "아시아나항공"),
        Airline(code: "7C", name: "제주항공"),
        Airline(code: "LJ", name: "진에어"),
        Airline(code: "TW", name: "티웨이항공"),
        Airline(code: "BX", name: "에어부산"),
        Airline(code: "RS", name: "에어서울"),
        Airline(code: "ZE", name: "이스타항공"),
    ]

    static func airport(_ code: String) -> Airport? { airports.first { $0.code == code } }
    static func airline(_ code: String) -> Airline? { airlines.first { $0.code == code } }

    static let popularRoutes: [(String, String)] = [
        ("ICN", "CJU"), ("GMP", "CJU"), ("PUS", "CJU"),
        ("ICN", "NRT"), ("ICN", "KIX"), ("ICN", "BKK"),
    ]
}
