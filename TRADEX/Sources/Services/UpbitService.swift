import Foundation

/// 업비트 공개 시세(Quotation) API — API 키 불필요.
/// 출시 전 각 거래소 Open API 이용약관에서 제3자 앱 표시 허용 범위를 반드시 확인할 것.
/// (미니게임 판정·서버 시간은 항상 업비트 기준)
enum UpbitAPI {
    static let baseURL = URL(string: "https://api.upbit.com/v1/")!
    static let socketURL = URL(string: "wss://api.upbit.com/websocket/v1")!

    /// 키 변환 전략은 쓰지 않는다 (모델의 CodingKeys가 snake_case 키를 직접 지정)
    static let decoder = JSONDecoder()

    enum APIError: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(429): return "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."
            case .http(let code): return "시세 서버 오류 (\(code))"
            }
        }
    }

    private static func get<T: Decodable>(_ path: String, query: [URLQueryItem], on ex: ExchangeID = .upbit) async throws -> T {
        var comps = URLComponents(url: ex.restBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
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
    static func krwMarkets(on ex: ExchangeID = .upbit) async throws -> [Market] {
        let all: [Lossy<Market>] = try await get("market/all", query: [URLQueryItem(name: "isDetails", value: "false")], on: ex)
        return all.compactMap(\.value).filter { $0.market.hasPrefix("KRW-") }
    }

    /// 현재 시세 (여러 마켓 한 번에, 100개씩 나눠 요청)
    static func tickers(_ markets: [String], on ex: ExchangeID = .upbit) async throws -> [Ticker] {
        var result: [Ticker] = []
        for start in stride(from: 0, to: markets.count, by: 100) {
            let chunk = markets[start..<min(start + 100, markets.count)]
            let rows: [Lossy<RestTicker>] = try await get("ticker", query: [URLQueryItem(name: "markets", value: chunk.joined(separator: ","))], on: ex)
            result += rows.compactMap { $0.value?.ticker }
        }
        return result
    }

    /// 업비트 서버 시간 (응답의 Date 헤더) — 미니게임 마감 판정용
    static func serverNow() async throws -> Date {
        var comps = URLComponents(url: baseURL.appendingPathComponent("ticker"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "markets", value: "KRW-BTC")]
        var req = URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let header = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Date"),
              let date = httpDate.date(from: header) else { throw URLError(.badServerResponse) }
        return date
    }

    private static let httpDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    /// 일봉 (최신순)
    static func dayCandles(market: String, count: Int, on ex: ExchangeID = .upbit) async throws -> [DayCandle] {
        let rows: [Lossy<DayCandle>] = try await get("candles/days", query: [
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "count", value: String(min(max(count, 1), 200))),
        ], on: ex)
        return rows.compactMap(\.value)
    }

    /// 호가 (최대 30단계)
    static func orderbook(market: String, on ex: ExchangeID = .upbit) async throws -> Orderbook? {
        let rows: [Lossy<Orderbook>] = try await get("orderbook", query: [URLQueryItem(name: "markets", value: market)], on: ex)
        return rows.first?.value
    }

    /// 1시간 봉 고가·저가 (선물 청산 확인용, 최신순)
    static func highLow(market: String, hours: Int, on ex: ExchangeID) async throws -> [HighLowCandle] {
        let rows: [Lossy<HighLowCandle>] = try await get("candles/minutes/60", query: [
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "count", value: String(min(max(hours, 1), 200))),
        ], on: ex)
        return rows.compactMap(\.value)
    }

    /// 1시간 봉 종가 (오래된 순) — 과거 차트 맞히기용
    static func hourCloses(market: String, count: Int, on ex: ExchangeID) async throws -> [ChartPoint] {
        let rows: [Lossy<Candle>] = try await get("candles/minutes/60", query: [
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "count", value: String(min(max(count, 1), 200))),
        ], on: ex)
        return rows.compactMap(\.value).map { ChartPoint(date: $0.date, price: $0.tradePrice) }.sorted { $0.date < $1.date }
    }

    /// 봉 차트용 캔들 (오래된 순)
    static func ohlc(market: String, range: ChartRange, on ex: ExchangeID = .upbit) async throws -> [OHLCCandle] {
        let (path, count) = range.request
        let rows: [Lossy<OHLCCandle>] = try await get(path, query: [
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "count", value: String(count)),
        ], on: ex)
        return rows.compactMap(\.value).sorted { $0.date < $1.date }
    }

    /// 차트용 캔들 (오래된 순으로 정렬해서 반환)
    static func candles(market: String, range: ChartRange, on ex: ExchangeID = .upbit) async throws -> [ChartPoint] {
        let (path, count) = range.request
        let rows: [Lossy<Candle>] = try await get(path, query: [
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "count", value: String(count)),
        ], on: ex)
        return rows.compactMap(\.value).map { ChartPoint(date: $0.date, price: $0.tradePrice) }.sorted { $0.date < $1.date }
    }
}

/// 업비트 실시간 시세 WebSocket
enum UpbitSocket {
    /// 연결이 끊기거나 작업이 취소될 때까지 시세를 onTicker로 전달한다.
    static func listen(codes: [String], on ex: ExchangeID = .upbit, onTicker: @escaping @Sendable (Ticker) async -> Void) async throws {
        let task = URLSession.shared.webSocketTask(with: ex.socketURL)
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
