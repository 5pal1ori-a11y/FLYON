import Foundation

/// 거래 가능한 코인 (원화마켓)
struct Market: Codable, Identifiable, Hashable, Sendable {
    let market: String        // 예: "KRW-BTC"
    let koreanName: String
    let englishName: String

    var id: String { market }
    var symbol: String { String(market.split(separator: "-").last ?? "") }
}

/// 실시간 시세 (REST·WebSocket 공통 형태)
struct Ticker: Equatable, Sendable {
    let market: String
    let tradePrice: Double          // 현재가
    let change: String              // RISE / EVEN / FALL
    let signedChangePrice: Double   // 전일 대비
    let signedChangeRate: Double    // 전일 대비 등락률 (0.0123 = 1.23%)
    let highPrice: Double
    let lowPrice: Double
    let prevClosingPrice: Double
    let accTradePrice24h: Double    // 24시간 거래대금
}

/// REST /v1/ticker 응답
struct RestTicker: Decodable {
    let market: String
    let tradePrice: Double
    let change: String
    let signedChangePrice: Double
    let signedChangeRate: Double
    let highPrice: Double
    let lowPrice: Double
    let prevClosingPrice: Double
    let accTradePrice24h: Double

    var ticker: Ticker {
        Ticker(market: market, tradePrice: tradePrice, change: change,
               signedChangePrice: signedChangePrice, signedChangeRate: signedChangeRate,
               highPrice: highPrice, lowPrice: lowPrice, prevClosingPrice: prevClosingPrice,
               accTradePrice24h: accTradePrice24h)
    }
}

/// WebSocket ticker 응답 (DEFAULT 포맷: 마켓 코드가 "code" 필드)
struct SocketTicker: Decodable {
    let type: String
    let code: String
    let tradePrice: Double
    let change: String
    let signedChangePrice: Double
    let signedChangeRate: Double
    let highPrice: Double
    let lowPrice: Double
    let prevClosingPrice: Double
    let accTradePrice24h: Double

    var ticker: Ticker {
        Ticker(market: code, tradePrice: tradePrice, change: change,
               signedChangePrice: signedChangePrice, signedChangeRate: signedChangeRate,
               highPrice: highPrice, lowPrice: lowPrice, prevClosingPrice: prevClosingPrice,
               accTradePrice24h: accTradePrice24h)
    }
}

struct Candle: Decodable, Identifiable, Sendable {
    let candleDateTimeUtc: String
    let tradePrice: Double
    var id: String { candleDateTimeUtc }

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()
    var date: Date { Candle.parser.date(from: candleDateTimeUtc) ?? .distantPast }
}

/// 차트 기간
enum ChartRange: String, CaseIterable, Identifiable {
    case hour = "1H", day = "1D", week = "1W", month = "1M", year = "1Y"
    var id: String { rawValue }

    /// 업비트 캔들 API 경로와 개수 (최대 200개)
    var request: (path: String, count: Int) {
        switch self {
        case .hour:  return ("candles/minutes/1", 60)
        case .day:   return ("candles/minutes/10", 144)
        case .week:  return ("candles/minutes/60", 168)
        case .month: return ("candles/days", 30)
        case .year:  return ("candles/days", 200)
        }
    }
}

struct ChartPoint: Identifiable, Equatable {
    let date: Date
    let price: Double
    var id: Date { date }
}
