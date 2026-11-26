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
