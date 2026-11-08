import Foundation

/// 가격 데이터 소스 추상화.
/// 앱에는 어떤 API 토큰도 넣지 않는다. 실제 데이터는 직접 운영하는 서버(ServerPriceProvider)가
/// Travelpayouts 등에서 수집해 DB에 쌓고, 앱은 그 서버만 호출한다.
protocol PriceProvider {
    /// true면 화면에 "샘플 데이터" 배지를 표시한다.
    var isSample: Bool { get }
    /// 수집일별 최저가 이력 (airlines가 비어 있으면 전체 항공사)
    func history(origin: Airport, destination: Airport, days: Int, airlines: Set<Airline>) async throws -> [PricePoint]
    /// 해당 월의 출발일별 최저가
    func calendar(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [CalendarDay]
    /// 해당 월 항공사별 최저가
    func quotes(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [PriceQuote]
}

enum PriceError: LocalizedError {
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .http(let code): return "서버 응답 오류 \(code)"
        case .decoding: return "서버 응답을 읽지 못함"
        }
    }
}

// MARK: - 샘플 데이터 (개발용)

struct MockPriceProvider: PriceProvider {
    var isSample: Bool { true }

    func history(origin: Airport, destination: Airport, days: Int, airlines: Set<Airline>) async throws -> [PricePoint] {
        try await Task.sleep(for: .milliseconds(300))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed))
        let phase = Double(seed % 628) / 100
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<days).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            let wave = sin(Double(offset) / 5.5 + phase) * 0.10
            let noise = (Double(Self.seed("\(seed)-\(offset)") % 100) / 100 - 0.5) * 0.06
            let price = Int((base * (1 + wave + noise) / 100).rounded()) * 100
            return PricePoint(date: date, price: price)
        }
    }

    func calendar(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [CalendarDay] {
        try await Task.sleep(for: .milliseconds(300))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed))
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let count = cal.range(of: .day, in: .month, for: start)?.count ?? 28
        let today = cal.startOfDay(for: .now)
        return (0..<count).compactMap { d in
            guard let date = cal.date(byAdding: .day, value: d, to: start), date >= today else { return nil }
            let weekday = cal.component(.weekday, from: date)
            let weekend = (weekday == 6 || weekday == 7 || weekday == 1) ? 0.12 : 0
            let noise = Double(Self.seed("\(seed)-c\(d)") % 100) / 100 * 0.3
            let price = Int((base * (0.85 + weekend + noise) / 100).rounded()) * 100
            return CalendarDay(date: date, price: price)
        }
    }

    func quotes(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [PriceQuote] {
        try await Task.sleep(for: .milliseconds(300))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed))
        let domestic = origin.isDomestic && destination.isDomestic
        let candidates = Catalog.airlines.filter(\.isKorean) + (domestic ? [] : ["JL", "NH", "CX", "SQ", "TG", "VN"].compactMap(Catalog.airline))
        let list = airlines.isEmpty ? candidates : Array(airlines)
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let dayCount = cal.range(of: .day, in: .month, for: start)?.count ?? 28

        return list.map { airline in
            let s = Self.seed("\(seed)\(airline.code)\(start.timeIntervalSince1970)")
            let factor = 0.88 + Double(s % 40) / 100
            let date = cal.date(byAdding: .day, value: s % dayCount, to: start) ?? start
            let price = Int((base * factor / 100).rounded()) * 100
            return PriceQuote(airline: airline, price: price, departureDate: date,
                              transfers: domestic ? 0 : (s % 4 == 0 ? 1 : 0))
        }
        .sorted { $0.price < $1.price }
    }

    private static func basePrice(_ a: Airport, _ b: Airport, seed: Int) -> Int {
        if a.isDomestic && b.isDomestic { return 55_000 + (seed % 40) * 1_000 }
        return 150_000 + (seed % 450) * 1_000
    }

    /// 실행마다 값이 바뀌지 않는 해시 (Swift의 hashValue는 실행마다 달라짐)
    private static func seed(_ s: String) -> Int {
        var h: UInt64 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt64(b) }
        return Int(h % 1_000_003)
    }
}

// MARK: - 자체 서버 연동 (실제 데이터)

/// 자체 서버 API 계약:
///   GET {base}/history?origin=ICN&destination=CJU&days=90[&airlines=KE,OZ]
///     -> { "points": [ { "date": "2026-11-01", "price": 58000 } ] }
///   GET {base}/calendar?origin=ICN&destination=CJU&month=2026-12[&airlines=KE]
///     -> { "days": [ { "date": "2026-12-05", "price": 61000 } ] }
///   GET {base}/quotes?origin=ICN&destination=CJU&month=2026-12[&airlines=KE]
///     -> { "quotes": [ { "airline": "KE", "price": 61000, "departure_date": "2026-12-05", "transfers": 0 } ] }
struct ServerPriceProvider: PriceProvider {
    let baseURL: URL
    let anonKey: String
    var isSample: Bool { false }

    private struct HistoryResponse: Decodable {
        struct Point: Decodable { let date: String; let price: Int }
        let points: [Point]
    }
    private struct CalendarResponse: Decodable {
        struct Day: Decodable { let date: String; let price: Int }
        let days: [Day]
    }
    private struct QuotesResponse: Decodable {
        struct Quote: Decodable {
            let airline: String
            let price: Int
            let departure_date: String
            let transfers: Int
        }
        let quotes: [Quote]
    }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func history(origin: Airport, destination: Airport, days: Int, airlines: Set<Airline>) async throws -> [PricePoint] {
        let res: HistoryResponse = try await get("history", base(origin, destination, airlines, extra: ["days": "\(days)"]))
        return res.points.compactMap { p in
            Self.dayParser.date(from: p.date).map { PricePoint(date: $0, price: p.price) }
        }
    }

    func calendar(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [CalendarDay] {
        let res: CalendarResponse = try await get("calendar", base(origin, destination, airlines, extra: ["month": monthString(month)]))
        return res.days.compactMap { d in
            Self.dayParser.date(from: d.date).map { CalendarDay(date: $0, price: d.price) }
        }
    }

    func quotes(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [PriceQuote] {
        let res: QuotesResponse = try await get("quotes", base(origin, destination, airlines, extra: ["month": monthString(month)]))
        return res.quotes.compactMap { q in
            let airline = Catalog.airlineOrUnknown(q.airline)
            guard airlines.isEmpty || airlines.contains(airline),
                  let date = Self.dayParser.date(from: q.departure_date) else { return nil }
            return PriceQuote(airline: airline, price: q.price, departureDate: date, transfers: q.transfers)
        }
        .sorted { $0.price < $1.price }
    }

    private func monthString(_ date: Date) -> String {
        String(Self.dayParser.string(from: date).prefix(7))
    }

    private func base(_ o: Airport, _ d: Airport, _ airlines: Set<Airline>, extra: [String: String]) -> [String: String] {
        var q = ["origin": o.code, "destination": d.code]
        if !airlines.isEmpty { q["airlines"] = airlines.map(\.code).sorted().joined(separator: ",") }
        return q.merging(extra) { _, new in new }
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 60   // 처음 조회하는 노선은 서버가 수집하느라 몇 초 걸릴 수 있다
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else { throw PriceError.http(code) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PriceError.decoding
        }
    }
}
