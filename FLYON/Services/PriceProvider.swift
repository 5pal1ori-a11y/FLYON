import Foundation

/// 가격 데이터 소스 추상화.
/// 앱에는 어떤 API 토큰도 넣지 않는다. 실제 데이터는 직접 운영하는 서버(ServerPriceProvider)가
/// Travelpayouts 등에서 수집해 DB에 쌓고, 앱은 그 서버만 호출한다.
protocol PriceProvider {
    /// true면 화면에 "샘플 데이터" 배지를 표시한다.
    var isSample: Bool { get }
    func history(origin: Airport, destination: Airport, days: Int) async throws -> [PricePoint]
    func quotes(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [PriceQuote]
}

// MARK: - 샘플 데이터 (개발용)

struct MockPriceProvider: PriceProvider {
    var isSample: Bool { true }

    func history(origin: Airport, destination: Airport, days: Int) async throws -> [PricePoint] {
        try await Task.sleep(for: .milliseconds(350))
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

    func quotes(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [PriceQuote] {
        try await Task.sleep(for: .milliseconds(350))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed))
        let list = airlines.isEmpty ? Catalog.airlines : Catalog.airlines.filter(airlines.contains)
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let dayCount = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 28

        return list.map { airline in
            let s = Self.seed("\(seed)\(airline.code)\(monthStart.timeIntervalSince1970)")
            let factor = 0.88 + Double(s % 40) / 100
            let day = s % dayCount
            let date = cal.date(byAdding: .day, value: day, to: monthStart) ?? monthStart
            let price = Int((base * factor / 100).rounded()) * 100
            let transfers = (origin.isDomestic && destination.isDomestic) ? 0 : (s % 4 == 0 ? 1 : 0)
            return PriceQuote(airline: airline, price: price, departureDate: date, transfers: transfers)
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

/// 자체 서버 API 계약(예시):
///   GET {baseURL}/history?origin=ICN&destination=CJU&days=30
///     -> { "points": [ { "date": "2026-11-01", "price": 58000 } ] }
///   GET {baseURL}/quotes?origin=ICN&destination=CJU&month=2026-12
///     -> { "quotes": [ { "airline": "KE", "price": 61000, "departure_date": "2026-12-05", "transfers": 0 } ] }
struct ServerPriceProvider: PriceProvider {
    let baseURL: URL
    let anonKey: String
    var isSample: Bool { false }

    private struct HistoryResponse: Decodable {
        struct Point: Decodable { let date: String; let price: Int }
        let points: [Point]
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

    func history(origin: Airport, destination: Airport, days: Int) async throws -> [PricePoint] {
        let res: HistoryResponse = try await get("history", [
            "origin": origin.code, "destination": destination.code, "days": "\(days)",
        ])
        return res.points.compactMap { p in
            Self.dayParser.date(from: p.date).map { PricePoint(date: $0, price: p.price) }
        }
    }

    func quotes(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>) async throws -> [PriceQuote] {
        let monthString = String(Self.dayParser.string(from: month).prefix(7))
        let res: QuotesResponse = try await get("quotes", [
            "origin": origin.code, "destination": destination.code, "month": monthString,
        ])
        return res.quotes.compactMap { q in
            guard let airline = Catalog.airline(q.airline),
                  airlines.isEmpty || airlines.contains(airline),
                  let date = Self.dayParser.date(from: q.departure_date) else { return nil }
            return PriceQuote(airline: airline, price: q.price, departureDate: date, transfers: q.transfers)
        }
        .sorted { $0.price < $1.price }
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: comps.url!)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
