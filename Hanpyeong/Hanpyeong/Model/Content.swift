import Foundation

// MARK: - 시설 투자 (점포별 1회 구매)

struct Improvement: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// 업종 개업비 대비 비용
    let costFactor: Double
    let incomeBoost: Double
    let wageCut: Double
    let minLevel: Int
    let reputation: Double

    static let all: [Improvement] = [
        Improvement(id: "sign", title: "LED 간판", detail: "멀리서도 보이는 새 간판. 매출 +10%",
                    symbol: "lightbulb.fill", costFactor: 0.15, incomeBoost: 0.10, wageCut: 0, minLevel: 1, reputation: 1),
        Improvement(id: "delivery", title: "배달 앱 입점", detail: "매출 +15%, 비·눈 오는 날 손님이 줄지 않음",
                    symbol: "bicycle", costFactor: 0.10, incomeBoost: 0.15, wageCut: 0, minLevel: 1, reputation: 0),
        Improvement(id: "sns", title: "SNS 마케팅", detail: "'인스타 맛집' 태그. 매출 +12%, 평판 +4",
                    symbol: "camera.fill", costFactor: 0.20, incomeBoost: 0.12, wageCut: 0, minLevel: 5, reputation: 4),
        Improvement(id: "interior", title: "인테리어 리모델링", detail: "사진 찍고 싶은 가게. 매출 +25%",
                    symbol: "paintbrush.fill", costFactor: 0.60, incomeBoost: 0.25, wageCut: 0, minLevel: 10, reputation: 2),
        Improvement(id: "kiosk", title: "키오스크 도입", detail: "주문은 기계가. 인건비 30% 절감",
                    symbol: "creditcard.fill", costFactor: 0.25, incomeBoost: 0, wageCut: 0.30, minLevel: 10, reputation: 0),
        Improvement(id: "loyalty", title: "단골 적립 카드", detail: "열 번 오면 한 번 공짜. 매출 +15%, 평판 +2",
                    symbol: "star.circle.fill", costFactor: 0.30, incomeBoost: 0.15, wageCut: 0, minLevel: 20, reputation: 2),
        Improvement(id: "premium", title: "프리미엄 설비", detail: "최고급 장비로 전부 교체. 매출 +40%",
                    symbol: "rosette", costFactor: 1.50, incomeBoost: 0.40, wageCut: 0, minLevel: 50, reputation: 3)
    ]

    static func find(_ id: String) -> Improvement? { all.first { $0.id == id } }

    func cost(for kind: BusinessKind) -> Double { kind.info.openCost * costFactor }

    func applies(to kind: BusinessKind) -> Bool {
        if id == "kiosk" { return kind.info.maxStaff > 0 }
        if id == "delivery" { return kind.info.trait != .unmanned && kind != .holdings }
        return true
    }
}

// MARK: - 인재

enum TalentEffect: Hashable {
    case kinds([BusinessKind], Double)
    case allIncome(Double)
    case tap(Double)
    case costCut(Double)
    case broker
    case influencer
    case offline(Double)
    case banker
    case buildingRent(Double)
}

struct Talent: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let quote: String
    let effectText: String
    let symbol: String
    let unlockRank: Int
    let cost: Double
    let effect: TalentEffect

    /// 일당 — 할머니는 공짜
    var salary: Double { id == "grandma" ? 0 : cost * 0.004 }

    static let all: [Talent] = [
        Talent(id: "grandma", name: "김순자", role: "옆집 할머니", quote: "장사는 말이야, 사람 장사여.",
               effectText: "구멍가게·붕어빵 노점 매출 ×1.5, 일당 없음", symbol: "heart.fill", unlockRank: 0,
               cost: 300_000, effect: .kinds([.cornerShop, .bungeoppang], 1.5)),
        Talent(id: "minji", name: "박민지", role: "주말 알바생", quote: "사장님, 계산은 제가 할게요!",
               effectText: "손님 계산 금액 ×1.6", symbol: "hand.tap.fill", unlockRank: 0,
               cost: 800_000, effect: .tap(1.6)),
        Talent(id: "deoksu", name: "최덕수", role: "떡볶이 장인", quote: "국물은 사흘 끓여야 제맛이지.",
               effectText: "분식집 매출 ×1.8", symbol: "flame", unlockRank: 1,
               cost: 15_000_000, effect: .kinds([.snackBar], 1.8)),
        Talent(id: "soyul", name: "한소율", role: "라떼아트 챔피언", quote: "하트 하나에 단골 하나.",
               effectText: "동네 카페 매출 ×1.8", symbol: "cup.and.saucer", unlockRank: 2,
               cost: 120_000_000, effect: .kinds([.cafe], 1.8)),
        Talent(id: "sangcheol", name: "배상철", role: "튀김 30년 경력", quote: "기름 온도는 손이 기억혀.",
               effectText: "치킨집·고깃집 매출 ×1.6", symbol: "frying.pan", unlockRank: 2,
               cost: 180_000_000, effect: .kinds([.chicken, .bbq], 1.6)),
        Talent(id: "doyun", name: "김도윤", role: "프로게이머 출신 점장", quote: "새벽 세 시가 골든타임입니다.",
               effectText: "PC방 매출 ×1.8", symbol: "gamecontroller.fill", unlockRank: 2,
               cost: 200_000_000, effect: .kinds([.pcBang], 1.8)),
        Talent(id: "daeho", name: "정대호", role: "세무사", quote: "새는 돈만 막아도 부자 됩니다.",
               effectText: "임대료·인건비 20% 절감", symbol: "doc.text.magnifyingglass", unlockRank: 2,
               cost: 250_000_000, effect: .costCut(0.2)),
        Talent(id: "malsun", name: "오말순", role: "30년차 공인중개사", quote: "좋은 매물은 소문 나기 전에 잡아야 혀.",
               effectText: "매물 하루 3개 추가, 매매 수수료 5% → 2%", symbol: "key.fill", unlockRank: 2,
               cost: 150_000_000, effect: .broker),
        Talent(id: "yujin", name: "유진", role: "맛집 인플루언서 '골목탐방'", quote: "구독자 80만, 제가 가면 줄 섭니다.",
               effectText: "전 점포 매출 ×1.1, 평판 매일 +1", symbol: "camera.fill", unlockRank: 3,
               cost: 1_500_000_000, effect: .influencer),
        Talent(id: "cheol", name: "강철", role: "보디빌딩 챔피언", quote: "회원은 근육처럼 키우는 겁니다.",
               effectText: "헬스장 매출 ×1.8", symbol: "figure.strengthtraining.traditional", unlockRank: 3,
               cost: 1_800_000_000, effect: .kinds([.gym], 1.8)),
        Talent(id: "marco", name: "마르코", role: "이탈리아 출신 셰프", quote: "Il segreto? 좋은 재료, 그리고 사랑.",
               effectText: "고깃집·치킨집·분식집 매출 ×1.4", symbol: "fork.knife", unlockRank: 3,
               cost: 2_500_000_000, effect: .kinds([.bbq, .chicken, .snackBar], 1.4)),
        Talent(id: "taepung", name: "강태풍", role: "물류 전문가", quote: "재고는 돈이 잠든 겁니다.",
               effectText: "편의점·대형마트·물류센터 매출 ×1.7", symbol: "shippingbox", unlockRank: 4,
               cost: 30_000_000_000, effect: .kinds([.convenience, .supermarket, .logistics], 1.7)),
        Talent(id: "jihye", name: "서지혜", role: "경영 컨설턴트", quote: "숫자를 보면 길이 보입니다.",
               effectText: "전 점포 매출 ×1.25", symbol: "chart.line.uptrend.xyaxis", unlockRank: 4,
               cost: 50_000_000_000, effect: .allIncome(1.25)),
        Talent(id: "leo", name: "레오", role: "5성급 호텔리어", quote: "손님은 기억을 사러 옵니다.",
               effectText: "호텔·테마파크·항공사 매출 ×1.7", symbol: "bell.fill", unlockRank: 5,
               cost: 600_000_000_000, effect: .kinds([.hotel, .themePark, .airline], 1.7)),
        Talent(id: "seungho", name: "백승호", role: "전문경영인", quote: "회장님이 안 계셔도 회사는 돕니다.",
               effectText: "자리 비운 동안 수익 50% → 90%", symbol: "briefcase.fill", unlockRank: 5,
               cost: 800_000_000_000, effect: .offline(0.9)),
        Talent(id: "banker", name: "조만석", role: "전직 은행장 고문", quote: "은행 문턱, 제가 낮춰드리죠.",
               effectText: "대출 이자 절반, 대출 한도 순자산의 70%", symbol: "building.columns.fill", unlockRank: 6,
               cost: 15_000_000_000_000, effect: .banker),
        Talent(id: "sera", name: "윤세라", role: "투자은행 출신 CFO", quote: "건물은 잠들지 않는 직원이에요.",
               effectText: "건물 월세 ×2", symbol: "building.2.fill", unlockRank: 6,
               cost: 20_000_000_000_000, effect: .buildingRent(2)),
        Talent(id: "jeongwoo", name: "문정우", role: "그룹 비서실장", quote: "회장님, 오늘 일정은 세상을 바꾸는 겁니다.",
               effectText: "전 점포 매출 ×1.5", symbol: "person.badge.key.fill", unlockRank: 7,
               cost: 500_000_000_000_000, effect: .allIncome(1.5))
    ]

    static func find(_ id: String) -> Talent? { all.first { $0.id == id } }
}

// MARK: - 재계 순위 (가상 회사들)

struct Rival: Identifiable, Hashable {
    let id: String
    let name: String
    let owner: String
    let base: Double
    let growth: Double

    func worth(day: Int) -> Double { base * pow(1 + growth, Double(max(0, day - 1))) }

    static let all: [Rival] = [
        Rival(id: "daebak", name: "대박유통", owner: "황대박", base: 2e8, growth: 0.012),
        Rival(id: "haengun", name: "행운상사", owner: "오행운", base: 1.5e9, growth: 0.011),
        Rival(id: "mirae", name: "미래물산", owner: "진미래", base: 8e9, growth: 0.010),
        Rival(id: "dongbang", name: "동방F&B", owner: "동방석", base: 4e10, growth: 0.009),
        Rival(id: "nuri", name: "누리유통", owner: "한누리", base: 2e11, growth: 0.008),
        Rival(id: "eunha", name: "은하산업", owner: "별은하", base: 9e11, growth: 0.007),
        Rival(id: "hangyeol", name: "한결홀딩스", owner: "한결", base: 5e12, growth: 0.006),
        Rival(id: "saesol", name: "새솔그룹", owner: "솔새솔", base: 2e13, growth: 0.005),
        Rival(id: "narae", name: "나래그룹", owner: "나래온", base: 8e13, growth: 0.004),
        Rival(id: "garam", name: "가람그룹", owner: "강가람", base: 3e14, growth: 0.0035),
        Rival(id: "baekdu", name: "백두그룹", owner: "백두산", base: 1.2e15, growth: 0.003),
        Rival(id: "cheongun", name: "청운그룹", owner: "청운학", base: 4e15, growth: 0.0025)
    ]
}
