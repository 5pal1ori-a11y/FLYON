import Foundation

// 현실 장사 규칙: 원가율, 명절·시즌, 세금, 임대차, 최저임금, 기준금리.
// 세율과 법 조항은 2025~2026년 한국 기준을 단순화한 것이다.

// MARK: - 원가율

extension BusinessKind {
    /// 총매출 중 재료비·상품 매입 비율. 게임 속 '초당 매출'은 원가를 뺀 매출총이익이다.
    var cogsRatio: Double {
        switch self {
        case .bungeoppang: return 0.35
        case .cornerShop: return 0.75
        case .snackBar: return 0.38
        case .laundromat: return 0.15
        case .cafe: return 0.30
        case .chicken: return 0.45
        case .pcBang: return 0.25
        case .convenience: return 0.72
        case .gym: return 0.10
        case .bbq: return 0.40
        case .supermarket: return 0.75
        case .franchiseHQ: return 0.55
        case .hotel: return 0.25
        case .logistics: return 0.60
        case .themePark: return 0.20
        case .departmentStore: return 0.70
        case .airline: return 0.65
        case .holdings: return 0.05
        }
    }

    var cogsLabel: String {
        switch self {
        case .cornerShop, .convenience, .supermarket, .departmentStore: return "상품 매입"
        case .laundromat, .pcBang, .gym, .themePark: return "전기·소모품"
        case .franchiseHQ, .logistics: return "물류·운송비"
        case .hotel: return "객실 운영비"
        case .airline: return "유류비·정비"
        case .holdings: return "운영비"
        default: return "재료비"
        }
    }
}

// MARK: - 명절·시즌

struct Holiday: Identifiable {
    let id: String
    let name: String
    let month: Int
    let fromDay: Int
    let toDay: Int
    let note: String
    let factor: (BusinessKind, DistrictID) -> Double

    func isActive(month m: Int, day d: Int) -> Bool { m == month && d >= fromDay && d <= toDay }

    static let all: [Holiday] = [
        Holiday(id: "semesterSpring", name: "개강 시즌", month: 3, fromDay: 1, toDay: 10,
                note: "대학가가 다시 살아난다") { k, d in
            d == .campus ? 1.35 : (k == .pcBang || k == .cafe ? 1.1 : 1)
        },
        Holiday(id: "valentine", name: "밸런타인데이", month: 2, fromDay: 13, toDay: 16,
                note: "카페·편의점에 초콜릿") { k, _ in
            k == .cafe || k == .convenience ? 1.2 : 1
        },
        Holiday(id: "seollal", name: "설 연휴", month: 2, fromDay: 1, toDay: 10,
                note: "마트·백화점·항공 대목, 골목은 귀성으로 한산") { k, d in
            switch k {
            case .supermarket: return 1.45
            case .departmentStore, .airline: return 1.35
            case .hotel: return 1.2
            case .cornerShop, .snackBar, .cafe, .bbq: return 0.8
            default: return d == .office || d == .cbd ? 0.7 : 1
            }
        },
        Holiday(id: "familyMonth", name: "가정의 달", month: 5, fromDay: 1, toDay: 10,
                note: "어린이날·어버이날, 테마파크와 고깃집 북적") { k, _ in
            switch k {
            case .themePark: return 1.5
            case .departmentStore, .bbq: return 1.2
            default: return 1
            }
        },
        Holiday(id: "vacationSummer", name: "여름 방학", month: 7, fromDay: 1, toDay: 28,
                note: "대학가는 비고, PC방·테마파크는 찬다") { k, d in
            if d == .campus { return 0.7 }
            return k == .pcBang || k == .themePark ? 1.25 : 1
        },
        Holiday(id: "peakSeason", name: "휴가철 극성수기", month: 8, fromDay: 1, toDay: 13,
                note: "바닷가와 공항이 터져나간다") { k, d in
            if d == .beach || d == .airport { return 1.4 }
            return k == .airline || k == .hotel ? 1.3 : 1
        },
        Holiday(id: "semesterFall", name: "2학기 개강", month: 9, fromDay: 1, toDay: 7,
                note: "대학가 복귀") { _, d in d == .campus ? 1.3 : 1 },
        Holiday(id: "chuseok", name: "추석 연휴", month: 9, fromDay: 16, toDay: 28,
                note: "선물세트와 귀성길, 마트·백화점 대목") { k, d in
            switch k {
            case .supermarket: return 1.45
            case .departmentStore, .airline: return 1.35
            case .hotel: return 1.2
            case .cornerShop, .snackBar, .cafe, .bbq: return 0.8
            default: return d == .office || d == .cbd ? 0.7 : 1
            }
        },
        Holiday(id: "pepero", name: "빼빼로데이", month: 11, fromDay: 10, toDay: 13,
                note: "편의점 매대가 과자로 덮인다") { k, _ in k == .convenience ? 1.35 : 1 },
        Holiday(id: "suneung", name: "수능 끝", month: 11, fromDay: 16, toDay: 22,
                note: "수험생 해방, PC방·분식·고깃집 북적") { k, _ in
            k == .pcBang ? 1.35 : (k == .snackBar || k == .bbq ? 1.15 : 1)
        },
        Holiday(id: "yearEnd", name: "크리스마스·연말", month: 12, fromDay: 19, toDay: 28,
                note: "송년회와 케이크, 치킨·고깃집·호텔 대목") { k, _ in
            switch k {
            case .chicken, .departmentStore: return 1.4
            case .cafe, .bbq, .hotel: return 1.3
            default: return 1
            }
        }
    ]

    static func active(onDay day: Int) -> [Holiday] {
        let m = GameCalendar.month(day)
        let d = GameCalendar.dayOfMonth(day)
        return all.filter { $0.isActive(month: m, day: d) }
    }
}

// MARK: - 세금

enum Tax {
    /// 종합소득세 (2023년 귀속부터 적용되는 8단계 누진세율)
    static let personal: [(limit: Double, rate: Double)] = [
        (14_000_000, 0.06), (50_000_000, 0.15), (88_000_000, 0.24), (150_000_000, 0.35),
        (300_000_000, 0.38), (500_000_000, 0.40), (1_000_000_000, 0.42), (.infinity, 0.45)
    ]

    /// 법인세 (2023년 사업연도부터 4단계)
    static let corporate: [(limit: Double, rate: Double)] = [
        (200_000_000, 0.09), (20_000_000_000, 0.19), (300_000_000_000, 0.21), (.infinity, 0.24)
    ]

    static func progressive(_ income: Double, _ table: [(limit: Double, rate: Double)]) -> Double {
        guard income > 0 else { return 0 }
        var tax = 0.0
        var lower = 0.0
        for b in table {
            let upper = min(income, b.limit)
            if upper > lower { tax += (upper - lower) * b.rate }
            if income <= b.limit { break }
            lower = b.limit
        }
        return tax
    }

    /// 국세 + 지방소득세(국세의 10%)
    static func income(_ taxable: Double, corporation: Bool) -> Double {
        progressive(taxable, corporation ? corporate : personal) * 1.1
    }

    /// 부가가치세: 가격에 부가세가 포함돼 있다고 보고 (매출 - 매입) / 11
    static func vat(onMargin margin: Double) -> Double { max(0, margin / 11) }

    static let incorporationCost: Double = 3_000_000
}

struct TaxBill: Codable, Hashable {
    var title: String
    var amount: Double
    var dueDay: Int
    var taxable: Double
}

// MARK: - 임대차 (상가건물 임대차보호법 단순화)

enum Lease {
    /// 보증금 = 월세 10개월치. 게임 한 달 = 10일
    static let depositMonths: Double = 10
    static let daysPerMonth: Double = 10
    /// 계약 기간 2년 = 240일
    static let term = 240
    /// 갱신요구권 10년 = 1,200일. 이 안에서는 증액 상한 5%
    static let renewalRightDays = 1_200
    static let renewalCap = 0.05

    static func deposit(dailyRent: Double) -> Double { dailyRent * daysPerMonth * depositMonths }
}

// MARK: - 최저임금 · 기준금리

enum Labor {
    /// 2026년 최저시급
    static let startingMinimumWage: Double = 10_320
    /// 4대보험 사업주 부담 대략치
    static let insuranceRate = 0.105
    /// 주 15시간 이상 근무 시 주휴수당 (주 5일 기준 1일분 ÷ 5)
    static let weeklyHolidayPay = 0.2
}

enum Money {
    static let startingBaseRate = 2.50
    /// 사업자 대출 가산금리 (연 %)
    static let spread = 3.0
    static let bankerSpread = 1.0
    /// 게임 1년 = 120일
    static let daysPerYear: Double = 120
}
