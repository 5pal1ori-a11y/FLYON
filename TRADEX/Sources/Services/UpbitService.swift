import Foundation

/// 업비트 공개 시세(Quotation) API — API 키 불필요.
/// 출시 전 업비트 Open API 이용약관에서 제3자 앱 표시 허용 범위를 반드시 확인할 것.
enum UpbitAPI {
    static let baseURL = URL(string: "https://api.upbit.com/v1/")!
    static let socketURL = URL(string: "wss://api.upbit.com/websocket/v1")!

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    enum APIError: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(429): return "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."
            case .http(let code): return "시세 서버 오류 (\(code))"
            }
        }
    }

    private static func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }

    /// 원화마켓 목록
    static func krwMarkets() async throws -> [Market] {
        let all: [Market] = try await get("market/all", query: [URLQueryItem(name: "isDetails", value: "false")])
        return all.filter { $0.market.hasPrefix("KRW-") }
    }

    /// 현재 시세 (여러 마켓 한 번에, 100개씩 나눠 요청)
    static func tickers(_ markets: [String]) async throws -> [Ticker] {
        var result: [Ticker] = []
        for start in stride(from: 0, to: markets.count, by: 100) {
            let chunk = markets[start..<min(start + 100, markets.count)]
            let rows: [RestTicker] = try await get("ticker", query: [URLQueryItem(name: "markets", value: chunk.joined(separator: ","))])
            result += rows.map(\.ticker)
        }
        return result
    }

    /// 차트용 캔들 (오래된 순으로 정렬해서 반환)
    static func candles(market: String, range: ChartRange) async throws -> [ChartPoint] {
        let (path, count) = range.request
        let rows: [Candle] = try await get(path, query: [
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "count", value: String(count)),
        ])
        return rows.map { ChartPoint(date: $0.date, price: $0.tradePrice) }.sorted { $0.date < $1.date }
    }
}

/// 업비트 실시간 시세 WebSocket
enum UpbitSocket {
    /// 연결이 끊기거나 작업이 취소될 때까지 시세를 onTicker로 전달한다.
    static func listen(codes: [String], onTicker: @escaping @Sendable (Ticker) async -> Void) async throws {
        let task = URLSession.shared.webSocketTask(with: UpbitAPI.socketURL)
        task.resume()

        let subscribe: [[String: Any]] = [
            ["ticket": "tradex-\(UUID().uuidString)"],
            ["type": "ticker", "codes": codes],
        ]
        let payload = String(data: try JSONSerialization.data(withJSONObject: subscribe), encoding: .utf8)!

        try await withTaskCancellationHandler {
            try await task.send(.string(payload))

            // 업비트는 약 120초간 데이터가 없으면 연결을 끊으므로 주기적으로 ping
            let pinger = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    task.sendPing { _ in }
                }
            }
            defer { pinger.cancel() }

            while !Task.isCancelled {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .data(let d): data = d
                case .string(let s): data = Data(s.utf8)
                @unknown default: continue
                }
                if let t = try? UpbitAPI.decoder.decode(SocketTicker.self, from: data) {
                    await onTicker(t.ticker)
                }
            }
        } onCancel: {
            task.cancel(with: .goingAway, reason: nil)
        }
    }
}
