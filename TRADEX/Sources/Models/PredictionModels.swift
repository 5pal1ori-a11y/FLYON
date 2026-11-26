import Foundation

/// 미니게임: "내일 오를까? 내릴까?"
///
/// 라운드 규칙 (업비트 일봉 기준, 한국시간)
/// - 라운드 D = D일 09:00 → D+1일 09:00 일봉
/// - 참여: D일 09:00 전까지 (일봉이 시작되기 전에 마감 → 이미 움직인 가격을 보고 고를 수 없음)
/// - 결과: D+1일 09:00 이후, D일 일봉 종가가 전일 종가보다 높으면 '오른다', 낮으면 '내린다', 같으면 무승부
/// - 참여는 무료, 보상은 모의투자금(원)만. 현금·상품으로 바꿀 수 없음.
enum PredictionChoice: String, Codable {
    case up, down
    var title: String { self == .up ? "오른다" : "내린다" }
}

enum PredictionStatus: String, Codable {
    case pending, won, lost, draw
}

struct Prediction: Codable, Identifiable, Equatable {
    var id = UUID()
    let roundKey: String        // "2026-11-27" — 기준 일봉 날짜(한국시간)
    let market: String
    let koreanName: String
    let choice: PredictionChoice
    let createdAt: Date
    var status: PredictionStatus = .pending
    var changeRate: Double? = nil
    var reward: Double = 0
}

struct PredictionRound: Equatable {
    let key: String
    let start: Date   // 참여 마감 = 기준 일봉 시작 (D일 09:00 KST)
    let end: Date     // 결과 확정 (D+1일 09:00 KST)

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        c.locale = Locale(identifier: "ko_KR")
        return c
    }()

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 지금 참여할 수 있는 라운드 (다음 09:00에 시작하는 일봉)
    static func upcoming(at now: Date) -> PredictionRound {
        var start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        if now >= start { start = calendar.date(byAdding: .day, value: 1, to: start)! }
        return make(start: start)
    }

    init?(key: String) {
        guard let day = PredictionRound.keyFormatter.date(from: key),
              let start = PredictionRound.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) else { return nil }
        self = PredictionRound.make(start: start)
    }

    private init(key: String, start: Date, end: Date) {
        self.key = key; self.start = start; self.end = end
    }

    private static func make(start: Date) -> PredictionRound {
        PredictionRound(key: keyFormatter.string(from: start), start: start,
                        end: calendar.date(byAdding: .day, value: 1, to: start)!)
    }

    /// 업비트 일봉의 candle_date_time_kst 값
    var candleTimeKST: String { "\(key)T09:00:00" }

    /// 라운드별 코인 — 주요 코인을 날짜마다 돌아가며 출제
    static let pool = ["KRW-BTC", "KRW-ETH", "KRW-XRP", "KRW-SOL", "KRW-DOGE", "KRW-ADA",
                       "KRW-TRX", "KRW-LINK", "KRW-AVAX", "KRW-SUI", "KRW-XLM", "KRW-DOT"]

    func market(from available: [Market]) -> Market? {
        let markets = PredictionRound.pool.compactMap { code in available.first { $0.market == code } }
        guard !markets.isEmpty else { return nil }
        let dayIndex = Int(start.timeIntervalSince1970 / 86_400)
        return markets[dayIndex % markets.count]
    }
}

/// 업비트 일봉 (결과 판정용)
struct DayCandle: Decodable {
    let candleDateTimeKst: String
    let tradePrice: Double          // 해당 일봉 종가(진행 중이면 현재가)
    let prevClosingPrice: Double    // 전일 종가
    let openingPrice: Double        // 시가 (적립식 자동 매수 체결가)

    var changeRate: Double { prevClosingPrice > 0 ? tradePrice / prevClosingPrice - 1 : 0 }

    enum CodingKeys: String, CodingKey {
        case candleDateTimeKst = "candle_date_time_kst"
        case tradePrice = "trade_price"
        case prevClosingPrice = "prev_closing_price"
        case openingPrice = "opening_price"
    }
}
