// CI 전용: 앱의 모델(MarketModels.swift)로 업비트 실제 응답을 디코딩해 본다.
// swiftc TRADEX/Sources/Models/MarketModels.swift TRADEX/ci/DecodeCheck.swift -o decodecheck && ./decodecheck
import Foundation

@main
struct DecodeCheck {
    static func fetch(_ s: String) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: URL(string: s)!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    static func main() async throws {
        print("참고: \\"24h\\".capitalized =", "24h".capitalized, "(convertFromSnakeCase를 쓰면 안 되는 이유)")
        let dec = JSONDecoder()
        let markets = try dec.decode([Market].self, from: try await fetch("https://api.upbit.com/v1/market/all?isDetails=false"))
            .filter { $0.market.hasPrefix("KRW-") }
        print("원화마켓:", markets.count)
        let codes = markets.prefix(100).map(\\.market).joined(separator: ",")
        let tickers = try dec.decode([RestTicker].self, from: try await fetch("https://api.upbit.com/v1/ticker?markets=\\(codes)"))
        print("시세:", tickers.count, "예:", tickers[0].market, tickers[0].tradePrice, tickers[0].accTradePrice24h)
        let candles = try dec.decode([Candle].self, from: try await fetch("https://api.upbit.com/v1/candles/minutes/10?market=KRW-BTC&count=5"))
        print("캔들:", candles.count, candles[0].date)
        precondition(!markets.isEmpty && !tickers.isEmpty && !candles.isEmpty)
        print("디코딩 확인 OK")
    }
}
