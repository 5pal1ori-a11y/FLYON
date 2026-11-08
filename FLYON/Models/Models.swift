import Foundation
import SwiftUI

private let koLocale = Locale(identifier: "ko_KR")

struct Airport: Identifiable, Hashable {
    let code: String        // IATA
    let name: String        // 공항명(영문)
    let city: String        // 화면 표시용 도시명 (한글 우선)
    let englishCity: String
    let countryCode: String
    let country: String     // 한글 국가명
    let searchKey: String

    var id: String { code }
    var isDomestic: Bool { countryCode == "KR" }

    init(code: String, name: String, englishCity: String, countryCode: String) {
        // "Paris (Roissy-en-France)", "Honolulu, Oahu" 처럼 지저분한 영문 도시명을 정리
        let cleaned = englishCity
            .components(separatedBy: " (")[0]
            .components(separatedBy: ",")[0]
            .trimmingCharacters(in: .whitespaces)
        let ko = KoreanNames.city[code]
        self.code = code
        self.name = name
        self.englishCity = cleaned
        self.city = ko ?? cleaned
        self.countryCode = countryCode
        self.country = koLocale.localizedString(forRegionCode: countryCode) ?? countryCode
        self.searchKey = [code, name, cleaned, ko ?? "", self.country, KoreanNames.aliases[code] ?? ""]
            .joined(separator: " ")
            .lowercased()
    }

    static func == (lhs: Airport, rhs: Airport) -> Bool { lhs.code == rhs.code }
    func hash(into hasher: inout Hasher) { hasher.combine(code) }
}

struct Airline: Identifiable, Hashable {
    let code: String
    let name: String
    let englishName: String
    let isKorean: Bool
    let searchKey: String

    var id: String { code }
    var isLowCost: Bool { AirlineData.lowCostCodes.contains(code) }

    init(code: String, name: String, englishName: String) {
        self.code = code
        self.name = name
        self.englishName = englishName
        self.isKorean = AirlineData.koreanCodes.contains(code)
        self.searchKey = [code, name, englishName].joined(separator: " ").lowercased()
    }

    /// 목록에 없는 항공사는 코드 그대로 보여 준다
    static func unknown(_ code: String) -> Airline {
        Airline(code: code, name: code.isEmpty ? "항공사 미상" : code, englishName: code)
    }

    static func == (lhs: Airline, rhs: Airline) -> Bool { lhs.code == rhs.code }
    func hash(into hasher: inout Hasher) { hasher.combine(code) }
}

enum Cabin: Int, CaseIterable, Identifiable, Hashable {
    case economy = 0, business = 1, first = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .economy: return "일반석"
        case .business: return "비즈니스"
        case .first: return "일등석"
        }
    }
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
    var date: Date? = nil        // 처음 선택해 둘 출발일
    var cabin: Cabin = .economy
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

struct Flight: Identifiable, Hashable {
    let id = UUID()
    let airline: Airline
    let flightNumber: String
    let departureTime: String?   // 출발지 현지 시각 "15:20"
    let durationMinutes: Int?
    let price: Int
    let transfers: Int

    var durationText: String? {
        guard let m = durationMinutes, m > 0 else { return nil }
        let h = m / 60, rest = m % 60
        if h == 0 { return "\(rest)분" }
        return rest == 0 ? "\(h)시간" : "\(h)시간 \(rest)분"
    }

    /// 도착 시각 (출발 시각 + 소요시간, 현지 시간대 차이는 반영하지 않음)
    var arrivalTime: (text: String, nextDay: Bool)? {
        guard let dep = departureTime, let m = durationMinutes else { return nil }
        let parts = dep.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let total = parts[0] * 60 + parts[1] + m
        return (String(format: "%02d:%02d", (total / 60) % 24, total % 60), total >= 1440)
    }
}

/// 출발지별 특가: 앞으로의 출발일 중 최저가와 평균
struct Deal: Identifiable, Hashable {
    let destination: Airport
    let lowest: Int
    let average: Int
    let lowestDate: Date

    var id: String { destination.code }
    var savings: Int { max(average - lowest, 0) }
    var savingsPercent: Int { average == 0 ? 0 : Int((Double(savings) / Double(average) * 100).rounded()) }
}

struct CalendarDay: Identifiable, Hashable {
    let date: Date
    let price: Int
    var id: Date { date }
}

struct PriceAnalysis {
    enum Verdict {
        case cheap, normal, expensive, collecting

        var title: String {
            switch self {
            case .cheap: return "평소보다 저렴해요"
            case .normal: return "평소 수준이에요"
            case .expensive: return "평소보다 비싸요"
            case .collecting: return "가격 이력을 모으는 중"
            }
        }
        var symbol: String {
            switch self {
            case .cheap: return "arrow.down.right"
            case .normal: return "equal"
            case .expensive: return "arrow.up.right"
            case .collecting: return "hourglass"
            }
        }
        var color: Color {
            switch self {
            case .cheap: return Theme.cheap
            case .normal: return Theme.mid
            case .expensive: return Theme.expensive
            case .collecting: return Theme.normal
            }
        }
    }

    /// 판정에 필요한 최소 데이터 일수
    static let minimumSamples = 7

    let current: Int
    let average: Int
    let lowest: Int
    let highest: Int
    let sampleCount: Int
    let lastDate: Date

    init?(history: [PricePoint]) {
        let sorted = history.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return nil }
        let prices = sorted.map(\.price)
        current = last.price
        lastDate = last.date
        lowest = prices.min() ?? last.price
        highest = prices.max() ?? last.price
        average = prices.reduce(0, +) / prices.count
        sampleCount = prices.count
    }

    /// 평균 대비 현재가 편차 (-0.09 = 9% 저렴)
    var deviation: Double {
        average == 0 ? 0 : Double(current - average) / Double(average)
    }

    var verdict: Verdict {
        if sampleCount < Self.minimumSamples { return .collecting }
        if deviation <= -0.07 { return .cheap }
        if deviation >= 0.07 { return .expensive }
        return .normal
    }

    var deviationText: String {
        if verdict == .collecting { return "\(sampleCount)일치 데이터" }
        let pct = Int((abs(deviation) * 100).rounded())
        if pct == 0 { return "평균과 비슷" }
        return deviation < 0 ? "평균보다 \(pct)% 낮음" : "평균보다 \(pct)% 높음"
    }
}

// MARK: - Catalog

enum Catalog {
    static let airports: [Airport] = loadAirports()
    static let airlines: [Airline] = AirlineData.raw.map { Airline(code: $0.code, name: $0.ko, englishName: $0.en) }

    private static let airportsByCode: [String: Airport] =
        Dictionary(airports.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    private static let airlinesByCode: [String: Airline] =
        Dictionary(airlines.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })

    static func airport(_ code: String) -> Airport? { airportsByCode[code] }
    static func airline(_ code: String) -> Airline? { airlinesByCode[code] }
    static func airlineOrUnknown(_ code: String) -> Airline { airlinesByCode[code] ?? .unknown(code) }

    static let popularAirportCodes = [
        "ICN", "GMP", "CJU", "PUS", "NRT", "HND", "KIX", "FUK", "CTS", "OKA", "BKK", "DAD", "SGN", "HAN",
        "TPE", "HKG", "SIN", "MNL", "CEB", "GUM", "HNL", "LAX", "JFK", "SFO", "CDG", "LHR", "FCO", "BCN",
    ]
    static var popularAirports: [Airport] { popularAirportCodes.compactMap(airport) }
    static var domesticAirports: [Airport] { airports.filter(\.isDomestic) }

    /// 서버가 수집하는 기본 노선 (인기 노선 타일)
    static let popularRoutes: [(String, String)] = [
        ("ICN", "CJU"), ("GMP", "CJU"), ("PUS", "CJU"),
        ("ICN", "NRT"), ("ICN", "KIX"), ("ICN", "FUK"),
        ("ICN", "BKK"), ("ICN", "DAD"), ("ICN", "TPE"),
    ]

    /// 코드, 한글/영문 도시명, 공항명, 국가로 검색. 코드 일치와 이름 앞부분 일치를 위로 올린다.
    static func searchAirports(_ query: String, excluding: Airport? = nil, limit: Int = 80) -> [Airport] {
        let tokens = query.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }
        let q = tokens.joined(separator: " ")

        func rank(_ a: Airport) -> Int {
            if a.code.lowercased() == q { return 0 }
            if a.city.lowercased().hasPrefix(q) || a.englishCity.lowercased().hasPrefix(q) { return 1 }
            if a.code.lowercased().hasPrefix(q) { return 2 }
            return 3
        }

        return airports
            .filter { a in a != excluding && tokens.allSatisfy { a.searchKey.contains($0) } }
            .sorted { (rank($0), $0.city) < (rank($1), $1.city) }
            .prefix(limit)
            .map { $0 }
    }

    private static func loadAirports() -> [Airport] {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([[String]].self, from: data) else {
            return [
                Airport(code: "ICN", name: "Incheon International Airport", englishCity: "Incheon", countryCode: "KR"),
                Airport(code: "GMP", name: "Gimpo International Airport", englishCity: "Seoul", countryCode: "KR"),
                Airport(code: "CJU", name: "Jeju International Airport", englishCity: "Jeju", countryCode: "KR"),
            ]
        }
        return rows.compactMap { r in
            guard r.count >= 4 else { return nil }
            return Airport(code: r[0], name: r[1], englishCity: r[2], countryCode: r[3])
        }
    }
}
