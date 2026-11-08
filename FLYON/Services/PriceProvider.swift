import Foundation

/// 가격 데이터 소스. 앱에는 어떤 API 토큰도 넣지 않는다.
/// 실제 데이터는 자체 서버(Supabase)가 수집해 두고, 앱은 그 서버만 호출한다.
protocol PriceProvider {
    var isSample: Bool { get }
    func history(origin: Airport, destination: Airport, days: Int, airlines: Set<Airline>, cabin: Cabin) async throws -> [PricePoint]
    func calendar(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [CalendarDay]
    func flights(origin: Airport, destination: Airport, date: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [Flight]
    func deals(origin: Airport, cabin: Cabin) async throws -> [Deal]
    /// 선택한 출발일 하루의 수집일별 가격
    func dayHistory(origin: Airport, destination: Airport, date: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [PricePoint]
    /// 선택일 앞뒤 며칠의 날짜별 최저가 (서버가 그 날짜들의 항공편도 함께 채운다)
    func range(origin: Airport, destination: Airport, date: Date, days: Int, airlines: Set<Airline>, cabin: Cabin) async throws -> [CalendarDay]
    /// 그 날짜의 특정 항공권(편명) 가격 기록
    func flightHistory(origin: Airport, destination: Airport, date: Date, flight: Flight, cabin: Cabin) async throws -> [PricePoint]
}

enum PriceError: LocalizedError {
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .http(let code): return "HTTP \(code)"
        case .decoding: return "decoding"
        }
    }
}

// MARK: - 샘플 데이터 (서버 설정이 없을 때)

struct MockPriceProvider: PriceProvider {
    var isSample: Bool { true }

    func history(origin: Airport, destination: Airport, days: Int, airlines: Set<Airline>, cabin: Cabin) async throws -> [PricePoint] {
        try await Task.sleep(for: .milliseconds(300))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed, cabin: cabin))
        let phase = Double(seed % 628) / 100
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<days).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            let wave = sin(Double(offset) / 5.5 + phase) * 0.10
            let noise = (Double(Self.seed("\(seed)-\(offset)") % 100) / 100 - 0.5) * 0.06
            return PricePoint(date: date, price: Int((base * (1 + wave + noise) / 100).rounded()) * 100)
        }
    }

    func calendar(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [CalendarDay] {
        try await Task.sleep(for: .milliseconds(300))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed, cabin: cabin))
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let count = cal.range(of: .day, in: .month, for: start)?.count ?? 28
        let today = cal.startOfDay(for: .now)
        return (0..<count).compactMap { d in
            guard let date = cal.date(byAdding: .day, value: d, to: start), date >= today else { return nil }
            let weekday = cal.component(.weekday, from: date)
            let weekend = (weekday == 6 || weekday == 7 || weekday == 1) ? 0.12 : 0
            let noise = Double(Self.seed("\(seed)-c\(d)") % 100) / 100 * 0.3
            return CalendarDay(date: date, price: Int((base * (0.85 + weekend + noise) / 100).rounded()) * 100)
        }
    }

    func flights(origin: Airport, destination: Airport, date: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [Flight] {
        try await Task.sleep(for: .milliseconds(250))
        let seed = Self.seed("\(origin.code)\(destination.code)")
        let base = Double(Self.basePrice(origin, destination, seed: seed, cabin: cabin))
        let domestic = origin.isDomestic && destination.isDomestic
        let candidates = Catalog.airlines.filter(\.isKorean) + (domestic ? [] : ["JL", "NH", "CX", "SQ", "TG", "VN"].compactMap(Catalog.airline))
        let list = airlines.isEmpty ? Array(candidates.prefix(7)) : Array(airlines)
        let dayKey = Calendar.current.component(.day, from: date)
        return list.map { airline in
            let s = Self.seed("\(seed)\(airline.code)\(dayKey)")
            return Flight(
                airline: airline,
                flightNumber: "\(airline.code)\(100 + s % 800)",
                departureTime: String(format: "%02d:%02d", 6 + (s % 15), (s / 7 % 4) * 15),
                durationMinutes: domestic ? 65 : 100 + (seed % 400),
                price: Int((base * (0.88 + Double(s % 40) / 100) / 100).rounded()) * 100,
                transfers: domestic ? 0 : (s % 5 == 0 ? 1 : 0)
            )
        }
        .sorted { $0.price < $1.price }
    }

    func deals(origin: Airport, cabin: Cabin) async throws -> [Deal] {
        try await Task.sleep(for: .milliseconds(300))
        let cal = Calendar.current
        let destinations = Catalog.popularAirports.filter { $0 != origin }.prefix(8)
        return destinations.enumerated().compactMap { index, dest in
            let seed = Self.seed("\(origin.code)\(dest.code)")
            let average = Self.basePrice(origin, dest, seed: seed, cabin: cabin)
            let lowest = Int(Double(average) * (0.62 + Double(seed % 20) / 100) / 100) * 100
            guard let date = cal.date(byAdding: .day, value: 14 + index * 3, to: cal.startOfDay(for: .now)) else { return nil }
            return Deal(destination: dest, lowest: lowest, average: average, lowestDate: date)
        }
    }

    func dayHistory(origin: Airport, destination: Airport, date: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [PricePoint] {
        let points = try await history(origin: origin, destination: destination, days: 14, airlines: airlines, cabin: cabin)
        let shift = Calendar.current.component(.day, from: date) % 7
        return points.map { PricePoint(date: $0.date, price: $0.price + shift * 1_000) }
    }

    func range(origin: Airport, destination: Airport, date: Date, days: Int, airlines: Set<Airline>, cabin: Cabin) async throws -> [CalendarDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let month = try await calendar(origin: origin, destination: destination, month: date, airlines: airlines, cabin: cabin)
        let next = cal.date(byAdding: .month, value: 1, to: date) ?? date
        let more = try await calendar(origin: origin, destination: destination, month: next, airlines: airlines, cabin: cabin)
        return (month + more).filter {
            let d = cal.dateComponents([.day], from: date, to: $0.date).day ?? 99
            return abs(d) <= days && $0.date >= today
        }
    }

    func flightHistory(origin: Airport, destination: Airport, date: Date, flight: Flight, cabin: Cabin) async throws -> [PricePoint] {
        let points = try await history(origin: origin, destination: destination, days: 10, airlines: [], cabin: cabin)
        guard let last = points.last else { return [] }
        return points.map { PricePoint(date: $0.date, price: flight.price + ($0.price - last.price)) }
    }

    private static func basePrice(_ a: Airport, _ b: Airport, seed: Int, cabin: Cabin) -> Int {
        let multiplier: Double = cabin == .economy ? 1 : (cabin == .business ? 3.2 : 6)
        let base = (a.isDomestic && b.isDomestic) ? 55_000 + (seed % 40) * 1_000 : 150_000 + (seed % 450) * 1_000
        return Int(Double(base) * multiplier)
    }

    /// 실행마다 값이 바뀌지 않는 해시
    private static func seed(_ s: String) -> Int {
        var h: UInt64 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt64(b) }
        return Int(h % 1_000_003)
    }
}

// MARK: - 자체 서버 (Supabase Edge Function "prices")

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
    private struct FlightsResponse: Decodable {
        struct Item: Decodable {
            let airline: String
            let flight_number: String
            let departure_time: String?
            let duration_min: Int?
            let price: Int
            let transfers: Int
        }
        let flights: [Item]
    }
    private struct DealsResponse: Decodable {
        struct Item: Decodable {
            let destination: String
            let lowest: Int
            let average: Int
            let lowest_date: String
        }
        let deals: [Item]
    }

    static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func history(origin: Airport, destination: Airport, days: Int, airlines: Set<Airline>, cabin: Cabin) async throws -> [PricePoint] {
        let res: HistoryResponse = try await get("history", query(origin, destination, airlines, cabin, ["days": "\(days)"]))
        return res.points.compactMap { p in Self.dayParser.date(from: p.date).map { PricePoint(date: $0, price: p.price) } }
    }

    func calendar(origin: Airport, destination: Airport, month: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [CalendarDay] {
        let monthString = String(Self.dayParser.string(from: month).prefix(7))
        let res: CalendarResponse = try await get("calendar", query(origin, destination, airlines, cabin, ["month": monthString]))
        return res.days.compactMap { d in Self.dayParser.date(from: d.date).map { CalendarDay(date: $0, price: d.price) } }
    }

    func flights(origin: Airport, destination: Airport, date: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [Flight] {
        let res: FlightsResponse = try await get("flights", query(origin, destination, airlines, cabin, ["date": Self.dayParser.string(from: date)]))
        return res.flights.map { f in
            Flight(airline: Catalog.airlineOrUnknown(f.airline), flightNumber: f.flight_number,
                   departureTime: f.departure_time, durationMinutes: f.duration_min,
                   price: f.price, transfers: f.transfers)
        }
        .sorted { $0.price < $1.price }
    }

    func deals(origin: Airport, cabin: Cabin) async throws -> [Deal] {
        let res: DealsResponse = try await get("deals", ["origin": origin.code, "cabin": "\(cabin.rawValue)"])
        return res.deals.compactMap { d in
            guard let dest = Catalog.airport(d.destination), let date = Self.dayParser.date(from: d.lowest_date) else { return nil }
            return Deal(destination: dest, lowest: d.lowest, average: d.average, lowestDate: date)
        }
    }

    func dayHistory(origin: Airport, destination: Airport, date: Date, airlines: Set<Airline>, cabin: Cabin) async throws -> [PricePoint] {
        let res: HistoryResponse = try await get("day", query(origin, destination, airlines, cabin, ["date": Self.dayParser.string(from: date)]))
        return res.points.compactMap { p in Self.dayParser.date(from: p.date).map { PricePoint(date: $0, price: p.price) } }
    }

    func range(origin: Airport, destination: Airport, date: Date, days: Int, airlines: Set<Airline>, cabin: Cabin) async throws -> [CalendarDay] {
        let res: CalendarResponse = try await get("range", query(origin, destination, airlines, cabin, [
            "date": Self.dayParser.string(from: date), "days": "\(days)",
        ]))
        return res.days.compactMap { d in Self.dayParser.date(from: d.date).map { CalendarDay(date: $0, price: d.price) } }
    }

    func flightHistory(origin: Airport, destination: Airport, date: Date, flight: Flight, cabin: Cabin) async throws -> [PricePoint] {
        let res: HistoryResponse = try await get("flight", [
            "origin": origin.code, "destination": destination.code, "cabin": "\(cabin.rawValue)",
            "date": Self.dayParser.string(from: date), "airline": flight.airline.code,
            "flight_number": flight.flightNumber.filter { $0.isLetter || $0.isNumber },
        ])
        return res.points.compactMap { p in Self.dayParser.date(from: p.date).map { PricePoint(date: $0, price: p.price) } }
    }

    private func query(_ o: Airport, _ d: Airport, _ airlines: Set<Airline>, _ cabin: Cabin, _ extra: [String: String]) -> [String: String] {
        var q = ["origin": o.code, "destination": d.code, "cabin": "\(cabin.rawValue)"]
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
        guard code == 200 else {
            print("[prices] \(path) HTTP \(code)")
            throw PriceError.http(code)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[prices] \(path) decoding failed: \(error)")
            throw PriceError.decoding
        }
    }
}
