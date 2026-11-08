import Foundation

struct PriceAlert: Identifiable, Hashable, Decodable {
    let id: String
    let origin: String
    let destination: String
    let departDate: String?
    let departMonth: String?
    let airlines: [String]?
    let cabin: Int
    let targetPrice: Int
    let baselinePrice: Int?
    let active: Bool
    let currentPrice: Int?
    let foundDate: String?

    var reached: Bool { currentPrice.map { $0 <= targetPrice } ?? false }
    var cabinValue: Cabin { Cabin(rawValue: cabin) ?? .economy }

    /// "12월 5일" 또는 "12월 전체"
    var periodText: String {
        if let d = departDate, let date = ServerPriceProvider.dayParser.date(from: d) { return date.dayTitle }
        if let m = departMonth, let date = ServerPriceProvider.dayParser.date(from: m) { return "\(date.monthShort) 전체" }
        return "전체 기간"
    }

    var airlineText: String {
        guard let airlines, !airlines.isEmpty else { return "전체 항공사" }
        let names = airlines.map { Catalog.airlineOrUnknown($0).name }
        return names.count == 1 ? names[0] : "\(names[0]) 외 \(names.count - 1)곳"
    }
}

struct NewAlert: Encodable {
    let deviceToken: String
    let origin: String
    let destination: String
    let departDate: String?
    let departMonth: String?
    let airlines: [String]?
    let cabin: Int
    let targetPrice: Int
    let baselinePrice: Int?
}

/// 서버의 "alerts" 함수 호출
struct AlertsClient {
    let baseURL: URL
    let anonKey: String

    private struct ListResponse: Decodable { let alerts: [PriceAlert] }

    func list(token: String) async throws -> [PriceAlert] {
        let data = try await send("GET", query: ["device_token": token])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ListResponse.self, from: data).alerts
    }

    func create(_ alert: NewAlert) async throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        _ = try await send("POST", body: try encoder.encode(alert))
    }

    func delete(id: String, token: String) async throws {
        _ = try await send("DELETE", query: ["device_token": token, "id": id])
    }

    func deleteAll(token: String) async throws {
        _ = try await send("DELETE", query: ["device_token": token, "all": "1"])
    }

    private func send(_ method: String, query: [String: String] = [:], body: Data? = nil) async throws -> Data {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            print("[alerts] \(method) HTTP \(code)")
            throw PriceError.http(code)
        }
        return data
    }
}
