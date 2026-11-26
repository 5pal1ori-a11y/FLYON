import Foundation

// 출석체크 · 일일 미션 · 오늘의 퀴즈
// 보상은 모두 앱 안에서만 쓰는 모의투자금(원)이며 현금·상품으로 바꿀 수 없다.

enum DailyRules {
    static let checkInReward: Double = 2_000
    /// 7일 연속 출석할 때마다 추가 보너스
    static let streakBonus: Double = 10_000
    static let streakBonusEvery = 7
    static let quizReward: Double = 1_000
    static let quizPerDay = 3
}

/// 날짜 키 (한국시간 yyyy-MM-dd)
extension KST {
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func dayKey(_ d: Date) -> String { dayKeyFormatter.string(from: d) }
    static func previousDayKey(_ key: String) -> String? {
        guard let d = dayKeyFormatter.date(from: key) else { return nil }
        return dayKey(d.addingTimeInterval(-86_400 + 3_600))  // 하루 전 (DST 없음, 여유 1시간)
    }
}

struct DailyState: Codable, Equatable {
    var checkInDays: [String] = []        // 출석한 날 (최근 60개, 최신순)
    var streak: Int = 0
    var eventsDay: String = ""
    var events: [String] = []             // 오늘 한 일: "buy", "predict", "chart:KRW-BTC"
    var claimedDay: String = ""
    var claimedMissions: [String] = []
    var quizDay: String = ""
    var quizAnswers: [String: Int] = [:]  // 문제 id → 고른 보기

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checkInDays = try c.decodeIfPresent([String].self, forKey: .checkInDays) ?? []
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        eventsDay = try c.decodeIfPresent(String.self, forKey: .eventsDay) ?? ""
        events = try c.decodeIfPresent([String].self, forKey: .events) ?? []
        claimedDay = try c.decodeIfPresent(String.self, forKey: .claimedDay) ?? ""
        claimedMissions = try c.decodeIfPresent([String].self, forKey: .claimedMissions) ?? []
        quizDay = try c.decodeIfPresent(String.self, forKey: .quizDay) ?? ""
        quizAnswers = try c.decodeIfPresent([String: Int].self, forKey: .quizAnswers) ?? [:]
    }
}

struct Mission: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let goal: Int
    let reward: Double

    static let all: [Mission] = [
        Mission(id: "buy", title: "코인 1번 매수하기", icon: "cart.fill", goal: 1, reward: 3_000),
        Mission(id: "predict", title: "오를까 내릴까 참여하기", icon: "chart.line.uptrend.xyaxis", goal: 1, reward: 2_000),
        Mission(id: "chart", title: "코인 차트 3개 살펴보기", icon: "chart.xyaxis.line", goal: 3, reward: 1_000),
        Mission(id: "quiz", title: "오늘의 퀴즈 모두 풀기", icon: "questionmark.circle.fill", goal: DailyRules.quizPerDay, reward: 2_000),
    ]
}

struct QuizQuestion: Identifiable, Hashable {
    let id: String
    let question: String
    let choices: [String]
    let answer: Int
    let explanation: String

    /// 날짜별로 정해진 문제 3개
    static func today(_ dayKey: String) -> [QuizQuestion] {
        let seed = dayKey.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        let start = seed % bank.count
        return (0..<DailyRules.quizPerDay).map { bank[(start + $0 * 7) % bank.count] }
    }

    static let bank: [QuizQuestion] = [
        .init(id: "q01", question: "‘시장가 주문’은 어떤 주문일까요?",
              choices: ["지금 거래되는 가격으로 바로 체결되는 주문", "내가 정한 가격이 되면 체결되는 주문", "다음 날 아침에 체결되는 주문"],
              answer: 0, explanation: "시장가 주문은 가격을 정하지 않고 지금 거래 가능한 가격에 바로 사거나 파는 주문이에요."),
        .init(id: "q02", question: "‘지정가 주문’의 특징은?",
              choices: ["무조건 즉시 체결된다", "원하는 가격을 정해 두고 그 가격에 도달하면 체결된다", "수수료가 없다"],
              answer: 1, explanation: "지정가 주문은 원하는 가격을 정해 두는 방식이라, 그 가격에 닿지 않으면 체결되지 않을 수 있어요."),
        .init(id: "q03", question: "분산투자를 하는 주된 이유는?",
              choices: ["수익을 반드시 늘리기 위해", "한 자산에 몰렸을 때의 위험을 줄이기 위해", "수수료를 아끼기 위해"],
              answer: 1, explanation: "여러 자산에 나눠 투자하면 한 자산이 크게 떨어져도 전체 손실을 줄이는 데 도움이 돼요. 손실이 없어지는 건 아니에요."),
        .init(id: "q04", question: "업비트에서 등락률 +5%는 무엇과 비교한 값일까요?",
              choices: ["전일 종가(오전 9시 기준)", "상장 첫날 가격", "내가 산 가격"],
              answer: 0, explanation: "업비트 원화마켓의 등락률은 매일 오전 9시를 기준으로 한 전일 종가 대비 변동이에요."),
        .init(id: "q05", question: "수수료가 0.05%일 때 100만 원어치를 사면 수수료는?",
              choices: ["50원", "500원", "5,000원"],
              answer: 1, explanation: "1,000,000원 × 0.0005 = 500원이에요."),
        .init(id: "q06", question: "‘평균 매수가(평단가)’란?",
              choices: ["가장 최근에 산 가격", "여러 번 산 가격을 수량으로 가중평균한 가격", "오늘의 최고가"],
              answer: 1, explanation: "여러 번 나눠 샀다면 각 가격에 산 수량을 반영해 평균을 낸 값이 평단가예요."),
        .init(id: "q07", question: "‘손절’의 의미로 가장 알맞은 것은?",
              choices: ["손실을 더 키우지 않으려고 정해 둔 기준에서 파는 것", "무조건 오를 때까지 기다리는 것", "수수료를 돌려받는 것"],
              answer: 0, explanation: "손절은 손실을 일정 수준에서 제한하려고 미리 정한 기준에서 매도하는 원칙이에요."),
        .init(id: "q08", question: "스테이블코인(예: USDT, USDC)의 특징은?",
              choices: ["가격 변동이 가장 큰 코인", "달러 같은 법정화폐 가치에 연동되도록 설계된 코인", "채굴로만 얻을 수 있는 코인"],
              answer: 1, explanation: "스테이블코인은 1달러 등 기준 자산 가치를 따라가도록 설계돼요. 다만 연동이 깨질 위험도 있어요."),
        .init(id: "q09", question: "비트코인의 최대 발행량은?",
              choices: ["1,000만 개", "2,100만 개", "제한 없음"],
              answer: 1, explanation: "비트코인은 프로토콜상 최대 2,100만 개까지만 발행되도록 정해져 있어요."),
        .init(id: "q10", question: "비트코인 ‘반감기’란?",
              choices: ["가격이 절반으로 떨어지는 날", "채굴 보상이 절반으로 줄어드는 시점", "거래 수수료가 절반이 되는 기간"],
              answer: 1, explanation: "약 4년(21만 블록)마다 새 블록 채굴 보상이 절반으로 줄어요."),
        .init(id: "q11", question: "‘김치 프리미엄’이란?",
              choices: ["국내 거래소 가격이 해외보다 높은 현상", "김치 관련 코인의 가격", "국내 거래소 수수료 할인"],
              answer: 0, explanation: "같은 코인이 국내 거래소에서 해외보다 비싸게 거래되는 현상을 말해요."),
        .init(id: "q12", question: "‘베어마켓(bear market)’은?",
              choices: ["상승장", "하락장", "횡보장"],
              answer: 1, explanation: "곰이 앞발을 아래로 내려치는 모습에 빗대 하락장을 베어마켓이라고 해요. 상승장은 불마켓이에요."),
        .init(id: "q13", question: "-50% 손실이 난 뒤 원금을 회복하려면 몇 % 올라야 할까요?",
              choices: ["+50%", "+100%", "+150%"],
              answer: 1, explanation: "100만 원이 50만 원이 되면, 다시 100만 원이 되려면 50만 원의 100%가 올라야 해요."),
        .init(id: "q14", question: "레버리지 투자의 위험으로 알맞은 것은?",
              choices: ["손실도 배수만큼 커질 수 있다", "손실이 생기지 않는다", "수익이 줄어든다"],
              answer: 0, explanation: "레버리지는 수익뿐 아니라 손실도 확대해요. 원금 전부를 잃을 수도 있어요."),
        .init(id: "q15", question: "개인 지갑의 시드 문구(복구 문구)는?",
              choices: ["고객센터가 물어보면 알려줘도 된다", "누구에게도 알려주면 안 된다", "SNS에 백업해 두면 안전하다"],
              answer: 1, explanation: "시드 문구를 아는 사람은 지갑의 자산을 모두 옮길 수 있어요. 누구에게도 알려주면 안 돼요."),
        .init(id: "q16", question: "‘평가손익’이란?",
              choices: ["이미 팔아서 확정된 손익", "아직 팔지 않은 보유분의 현재 가격 기준 손익", "수수료 합계"],
              answer: 1, explanation: "팔지 않은 코인을 지금 가격으로 계산한 손익이 평가손익, 팔아서 확정된 손익이 실현손익이에요."),
        .init(id: "q17", question: "거래량이 적은(유동성이 낮은) 코인의 위험은?",
              choices: ["원하는 가격에 사고팔기 어려울 수 있다", "가격이 절대 변하지 않는다", "수수료가 더 싸다"],
              answer: 0, explanation: "거래가 적으면 주문 한 번에도 가격이 크게 움직이거나, 원하는 가격에 체결되지 않을 수 있어요."),
        .init(id: "q18", question: "‘물타기’란?",
              choices: ["가격이 내렸을 때 더 사서 평단가를 낮추는 것", "코인을 다른 지갑으로 옮기는 것", "수익이 나면 모두 파는 것"],
              answer: 0, explanation: "물타기는 평단가를 낮출 수 있지만, 계속 하락하면 손실이 더 커질 수 있어요."),
        .init(id: "q19", question: "거래소의 ‘유의 종목’ 지정은 무엇을 뜻할까요?",
              choices: ["곧 크게 오를 종목", "상장폐지 등 위험이 있을 수 있어 주의가 필요한 종목", "수수료가 면제되는 종목"],
              answer: 1, explanation: "유의 종목은 거래 지원 종료 가능성 등 위험 요인이 있어 투자자 주의가 필요하다는 표시예요."),
        .init(id: "q20", question: "블록체인의 특징으로 알맞은 것은?",
              choices: ["한 회사 서버에만 기록이 저장된다", "여러 참여자가 같은 거래 기록(분산 원장)을 나눠 가진다", "기록을 누구나 쉽게 고칠 수 있다"],
              answer: 1, explanation: "블록체인은 거래 기록을 여러 곳에 나눠 저장해, 한 곳에서 몰래 고치기 어렵게 만든 기술이에요."),
        .init(id: "q21", question: "‘24시간 거래대금’이 크다는 것은?",
              choices: ["가격이 반드시 오른다는 뜻", "그동안 거래가 활발했다는 뜻", "코인 발행량이 많다는 뜻"],
              answer: 1, explanation: "거래대금은 거래된 금액의 합계예요. 활발하다는 뜻일 뿐, 오르내림과는 별개예요."),
    ]
}
