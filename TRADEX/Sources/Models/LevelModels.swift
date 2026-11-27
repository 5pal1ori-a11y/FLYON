import Foundation

/// 트레이더 등급: 입문자 → 분석가 → 전략가 → 전문가 → 마스터
/// 경험치(XP)는 앱 안 활동으로만 쌓이고, 등급 보상은 TRADEX(모의투자금)로만 준다.
struct TraderLevel: Identifiable, Equatable {
    let index: Int
    let name: String
    let minXP: Int
    let icon: String
    let rewardTradex: Int
    let summary: String
    var id: Int { index }

    static let all: [TraderLevel] = [
        TraderLevel(index: 0, name: "입문자", minXP: 0, icon: "leaf", rewardTradex: 0,
                    summary: "모의투자를 막 시작했어요"),
        TraderLevel(index: 1, name: "분석가", minXP: 300, icon: "magnifyingglass", rewardTradex: 1,
                    summary: "차트와 시세를 읽기 시작했어요"),
        TraderLevel(index: 2, name: "전략가", minXP: 1_000, icon: "map", rewardTradex: 2,
                    summary: "지정가·손절로 계획을 세워 투자해요"),
        TraderLevel(index: 3, name: "전문가", minXP: 3_000, icon: "chart.line.uptrend.xyaxis", rewardTradex: 3,
                    summary: "선물과 적립식까지 다룰 줄 알아요"),
        TraderLevel(index: 4, name: "마스터", minXP: 8_000, icon: "crown", rewardTradex: 5,
                    summary: "꾸준함으로 정상에 올랐어요"),
    ]

    static func level(for xp: Int) -> TraderLevel {
        all.last { xp >= $0.minXP } ?? all[0]
    }

    var next: TraderLevel? { index + 1 < TraderLevel.all.count ? TraderLevel.all[index + 1] : nil }

    /// 3D 아이콘
    var emoji3D: String { ["seedling", "magnifier", "map", "brain", "crown"][min(index, 4)] }

    /// 다음 등급까지 진행률 (0~1)
    func progress(xp: Int) -> Double {
        guard let next else { return 1 }
        return Double(xp - minXP) / Double(next.minXP - minXP)
    }
}

/// 경험치 규칙
enum XPRule: CaseIterable {
    case trade, order, futures, attendance, quiz, mission, predict, predictWin, chartGame, chartGameWin

    var amount: Int {
        switch self {
        case .trade: return 10
        case .order: return 15
        case .futures: return 15
        case .attendance: return 30
        case .quiz: return 20
        case .mission: return 25
        case .predict: return 20
        case .predictWin: return 50
        case .chartGame: return 5
        case .chartGameWin: return 15
        }
    }

    var title: String {
        switch self {
        case .trade: return "현물 매수·매도"
        case .order: return "지정가·손절·익절 주문"
        case .futures: return "선물 포지션 진입"
        case .attendance: return "출석체크"
        case .quiz: return "퀴즈 정답"
        case .mission: return "미션 보상 받기"
        case .predict: return "오를까 내릴까 참여"
        case .predictWin: return "오를까 내릴까 적중"
        case .chartGame: return "차트 맞히기 참여"
        case .chartGameWin: return "차트 맞히기 정답"
        }
    }

    /// 거래 관련 경험치는 하루 상한이 있다 (사고팔기 반복으로 등급을 올리지 못하게)
    var isTradeCapped: Bool { self == .trade || self == .order || self == .futures }
    static let dailyTradeCap = 100
}

enum ChartGameRules {
    /// 보상이 있는 판 수 (하루)
    static let rewardedPerDay = 10
    static let reward: Double = 50_000
    static let visible = 40     // 보여 주는 1시간 봉 수
    static let hidden = 10      // 맞혀야 하는 구간
}

// MARK: - 시즌 (한 분기 = 한 시즌) · AP

/// 시즌: 1~3월(1시즌), 4~6월(2시즌), 7~9월(3시즌), 10~12월(4시즌). 한국시간 기준.
/// 시즌 동안 활동하면 AP(Activity Point)가 쌓이고, 시즌이 바뀌면 AP는 0부터 다시 시작한다.
struct Season: Equatable {
    let year: Int
    let quarter: Int

    var id: String { "\(year)-Q\(quarter)" }
    var name: String { "\(year) 시즌 \(quarter)" }
    var monthsText: String { "\(quarter * 3 - 2)~\(quarter * 3)월" }

    static func current(at date: Date = .now) -> Season {
        let cal = PredictionRound.calendar
        let c = cal.dateComponents([.year, .month], from: date)
        return Season(year: c.year ?? 2026, quarter: ((c.month ?? 1) - 1) / 3 + 1)
    }

    /// 시즌 종료 시각 (다음 분기 1일 0시, 한국시간)
    var end: Date {
        let cal = PredictionRound.calendar
        var c = DateComponents(year: year, month: quarter * 3 + 1, day: 1)
        if quarter == 4 { c.year = year + 1; c.month = 1 }
        return cal.date(from: c) ?? .distantFuture
    }

    func daysLeft(from date: Date = .now) -> Int {
        max(0, Int(ceil(end.timeIntervalSince(date) / 86_400)))
    }
}

extension XPRule {
    /// 시즌 AP (랭킹용). 하루 상한이 있다.
    var ap: Int {
        switch self {
        case .attendance: return 10
        case .quiz: return 5
        case .mission: return 10
        case .predict: return 5
        case .predictWin: return 20
        case .chartGame: return 2
        case .chartGameWin: return 5
        case .trade: return 2
        case .order: return 3
        case .futures: return 3
        }
    }
    static let dailyAPCap = 150
}

/// 지난 시즌 기록
struct SeasonRecord: Codable, Identifiable, Equatable {
    let id: String      // "2026-Q4"
    let ap: Int

    var displayName: String { id.replacingOccurrences(of: "-Q", with: " 시즌 ") }
}

/// 시즌 종료 등급 (그 시즌 AP 기준)
enum SeasonTier: Int, Codable, CaseIterable, Comparable {
    case none = 0, bronze, silver, gold, diamond

    static func < (a: SeasonTier, b: SeasonTier) -> Bool { a.rawValue < b.rawValue }

    static func tier(for ap: Int) -> SeasonTier {
        allCases.last { ap >= $0.minAP } ?? .none
    }

    var minAP: Int {
        switch self {
        case .none: return 0
        case .bronze: return 300
        case .silver: return 1_000
        case .gold: return 3_000
        case .diamond: return 6_000
        }
    }
    var name: String {
        switch self {
        case .none: return "참가"
        case .bronze: return "브론즈"
        case .silver: return "실버"
        case .gold: return "골드"
        case .diamond: return "다이아"
        }
    }
    var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .bronze: return "medal"
        case .silver: return "medal"
        case .gold: return "trophy"
        case .diamond: return "diamond"
        }
    }
    var emoji3D: String {
        switch self {
        case .none: return "star"
        case .bronze: return "bronze"
        case .silver: return "silver"
        case .gold: return "gold"
        case .diamond: return "diamond"
        }
    }
    var rewardTradex: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 최종 순위 보너스 (랭킹 참가자)
    static func rankBonus(_ rank: Int?) -> Int {
        guard let rank else { return 0 }
        if rank == 1 { return 5 }
        if rank <= 10 { return 3 }
        if rank <= 100 { return 1 }
        return 0
    }
}

/// 받은 시즌 보상 (배지로 표시)
struct SeasonResult: Codable, Identifiable, Equatable {
    let id: String
    let ap: Int
    let tier: SeasonTier
    let rank: Int?
    let rewardTradex: Int
}

struct SeasonState: Codable, Equatable {
    var id: String = ""
    var ap: Int = 0
    var apDay: String = ""
    var apToday: Int = 0
    var history: [SeasonRecord] = []
    var results: [SeasonResult] = []   // 보상 받은 시즌

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        ap = try c.decodeIfPresent(Int.self, forKey: .ap) ?? 0
        apDay = try c.decodeIfPresent(String.self, forKey: .apDay) ?? ""
        apToday = try c.decodeIfPresent(Int.self, forKey: .apToday) ?? 0
        history = try c.decodeIfPresent([SeasonRecord].self, forKey: .history) ?? []
        results = try c.decodeIfPresent([SeasonResult].self, forKey: .results) ?? []
    }
}
