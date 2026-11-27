import SwiftUI

// 게임 밸런스 숫자는 전부 이 파일에 모아둔다. 튜닝할 때 여기만 고치면 된다.

enum Economy {
    static let startingCash: Double = 30_000
    /// 실제 몇 초가 게임 하루인가
    static let dayLength: Double = 40
    static let levelGrowth: Double = 1.12
    static let maxLevel = 100
    /// 이 레벨에 도달할 때마다 매출 2배
    static let milestones = [10, 25, 50, 75, 100]
    static let staffBoost: Double = 0.35
    static let hireCostDays: Double = 2

    static let tapBase: Double = 300
    static let tapGrowth: Double = 1.45
    static let tapIncomeShare: Double = 0.08
    static let tapUpgradeBase: Double = 4_000
    static let tapUpgradeGrowth: Double = 2.4

    static let tradeFee: Double = 0.05
    static let buildingDailyYield: Double = 0.0035
    static let loanDailyRate: Double = 0.0025
    static let loanLimitRatio: Double = 0.5

    static let offlineRate: Double = 0.5
    static let offlineCap: Double = 8 * 3600

    static let listingsPerDay = 5
}

// MARK: - 업종

enum BusinessKind: String, Codable, CaseIterable, Identifiable {
    case cornerShop, snackBar, cafe, convenience, supermarket, franchiseHQ, logistics, departmentStore, holdings

    var id: String { rawValue }

    struct Info {
        let title: String
        let symbol: String
        let tier: Int
        let unlockRank: Int
        let openCost: Double
        let baseIncome: Double      // 레벨 1당 초당 매출
        let baseUpgrade: Double
        let rent: Double            // 일 임대료(지역 배율 적용 전)
        let wage: Double            // 직원 1명 일당
        let maxStaff: Int
        let color: UInt32
        let blurb: String
    }

    var info: Info {
        switch self {
        case .cornerShop:
            return Info(title: "구멍가게", symbol: "basket.fill", tier: 0, unlockRank: 0,
                        openCost: 1_000_000, baseIncome: 30, baseUpgrade: 3_000,
                        rent: 1_000, wage: 3_000, maxStaff: 2, color: 0xC23B2C,
                        blurb: "라면, 담배, 막걸리. 동네 사람들의 사랑방.")
        case .snackBar:
            return Info(title: "분식집", symbol: "takeoutbag.and.cup.and.straw.fill", tier: 1, unlockRank: 1,
                        openCost: 25_000_000, baseIncome: 260, baseUpgrade: 30_000,
                        rent: 12_000, wage: 25_000, maxStaff: 3, color: 0xD9702A,
                        blurb: "떡볶이 국물 냄새로 손님을 끈다.")
        case .cafe:
            return Info(title: "동네 카페", symbol: "cup.and.saucer.fill", tier: 2, unlockRank: 2,
                        openCost: 180_000_000, baseIncome: 1_900, baseUpgrade: 250_000,
                        rent: 80_000, wage: 180_000, maxStaff: 4, color: 0x3E6A4F,
                        blurb: "원두 하나로 단골을 만든다.")
        case .convenience:
            return Info(title: "편의점", symbol: "storefront.fill", tier: 3, unlockRank: 3,
                        openCost: 1_300_000_000, baseIncome: 14_000, baseUpgrade: 1_800_000,
                        rent: 500_000, wage: 1_200_000, maxStaff: 5, color: 0x2E5AAC,
                        blurb: "24시간 꺼지지 않는 불빛.")
        case .supermarket:
            return Info(title: "대형마트", symbol: "cart.fill", tier: 4, unlockRank: 4,
                        openCost: 10_000_000_000, baseIncome: 80_000, baseUpgrade: 14_000_000,
                        rent: 4_000_000, wage: 9_000_000, maxStaff: 8, color: 0xC8961C,
                        blurb: "주말마다 주차장이 꽉 찬다.")
        case .franchiseHQ:
            return Info(title: "프랜차이즈 본사", symbol: "building.2.fill", tier: 5, unlockRank: 5,
                        openCost: 80_000_000_000, baseIncome: 460_000, baseUpgrade: 110_000_000,
                        rent: 30_000_000, wage: 70_000_000, maxStaff: 10, color: 0x8C2B3E,
                        blurb: "내 가게 간판을 전국에 단다.")
        case .logistics:
            return Info(title: "물류센터", symbol: "shippingbox.fill", tier: 6, unlockRank: 6,
                        openCost: 650_000_000_000, baseIncome: 2_800_000, baseUpgrade: 900_000_000,
                        rent: 250_000_000, wage: 550_000_000, maxStaff: 10, color: 0x47566A,
                        blurb: "새벽 배송의 심장.")
        case .departmentStore:
            return Info(title: "백화점", symbol: "bag.fill", tier: 7, unlockRank: 7,
                        openCost: 5_500_000_000_000, baseIncome: 18_000_000, baseUpgrade: 7_500_000_000,
                        rent: 2_000_000_000, wage: 4_500_000_000, maxStaff: 12, color: 0x2A2C31,
                        blurb: "1층 명품관에 줄이 선다.")
        case .holdings:
            return Info(title: "지주회사", symbol: "crown.fill", tier: 8, unlockRank: 7,
                        openCost: 50_000_000_000_000, baseIncome: 130_000_000, baseUpgrade: 65_000_000_000,
                        rent: 18_000_000_000, wage: 40_000_000_000, maxStaff: 12, color: 0x1E2A47,
                        blurb: "모든 계열사 위에 서는 회사.")
        }
    }

    var color: Color { Color(hex: info.color) }

    var namePool: [String] {
        switch self {
        case .cornerShop:      return ["행복상회", "제일상회", "우리슈퍼", "만물상회", "골목상회", "정다운가게"]
        case .snackBar:        return ["맛나분식", "엄마손분식", "골목떡볶이", "바삭김밥", "학교앞분식"]
        case .cafe:            return ["온기커피", "느린오후", "모퉁이커피", "브루잉룸", "볕드는카페"]
        case .convenience:     return ["한평24", "나이트마트", "편한24", "별빛편의점"]
        case .supermarket:     return ["장보는날", "푸드마켓", "한평 메가마트", "알뜰마트"]
        case .franchiseHQ:     return ["골목브랜즈", "한평F&B", "단골푸드", "스트릿키친"]
        case .logistics:       return ["한평로지스", "새벽물류", "빠른길물류", "허브라인"]
        case .departmentStore: return ["한평 플라자", "스카이라인 백화점", "더 메리디안"]
        case .holdings:        return ["홀딩스"]
        }
    }
}

// MARK: - 지역

enum DistrictID: String, Codable, CaseIterable, Identifiable {
    case alley, market, campus, newtown, station, office, cbd

    var id: String { rawValue }

    struct Info {
        let name: String
        let short: String
        let traffic: Double
        let rentMult: Double
        let slots: Int
        let unlockRank: Int
        let buildingBase: Double
        let mood: String
    }

    var info: Info {
        switch self {
        case .alley:   return Info(name: "달동네 골목", short: "골목", traffic: 1.0, rentMult: 0.6, slots: 3, unlockRank: 0,
                                   buildingBase: 80_000_000, mood: "오래된 동네, 정 많은 단골")
        case .market:  return Info(name: "전통시장 거리", short: "시장", traffic: 1.25, rentMult: 0.8, slots: 3, unlockRank: 1,
                                   buildingBase: 300_000_000, mood: "주말마다 북적이는 장터")
        case .campus:  return Info(name: "대학가", short: "대학가", traffic: 1.6, rentMult: 1.0, slots: 4, unlockRank: 2,
                                   buildingBase: 1_500_000_000, mood: "개강하면 살아나는 상권")
        case .newtown: return Info(name: "신도시 상가", short: "신도시", traffic: 2.1, rentMult: 1.3, slots: 4, unlockRank: 3,
                                   buildingBase: 8_000_000_000, mood: "젊은 가족, 넓은 도로")
        case .station: return Info(name: "역세권", short: "역세권", traffic: 2.8, rentMult: 1.8, slots: 5, unlockRank: 4,
                                   buildingBase: 60_000_000_000, mood: "하루 유동인구 십만")
        case .office:  return Info(name: "오피스 타운", short: "오피스", traffic: 3.8, rentMult: 2.5, slots: 5, unlockRank: 5,
                                   buildingBase: 500_000_000_000, mood: "점심시간이 전쟁")
        case .cbd:     return Info(name: "중심 업무지구", short: "중심지", traffic: 5.2, rentMult: 3.5, slots: 6, unlockRank: 6,
                                   buildingBase: 4_000_000_000_000, mood: "이 나라 돈이 모이는 곳")
        }
    }

    /// 지역마다 살 수 있는 건물 세 채
    var buildings: [BuildingSpec] {
        let names: [String]
        switch self {
        case .alley:   names = ["2층 상가주택", "모퉁이 점포 건물", "3층 근린상가"]
        case .market:  names = ["시장 입구 상가", "청과동 건물", "아케이드 4층 상가"]
        case .campus:  names = ["정문 앞 상가", "원룸 겸 상가", "먹자골목 빌딩"]
        case .newtown: names = ["단지 내 상가", "중앙광장 상가동", "신도시 메디컬 빌딩"]
        case .station: names = ["출구 앞 꼬마빌딩", "환승센터 상가", "역세권 오피스텔"]
        case .office:  names = ["업무지구 이면 빌딩", "12층 오피스", "랜드마크 타워 저층부"]
        case .cbd:     names = ["중심지 근생 빌딩", "35층 프라임 오피스", "스카이 타워"]
        }
        let factors: [Double] = [0.8, 1.0, 1.5]
        return zip(names, factors).enumerated().map { i, pair in
            BuildingSpec(id: "\(rawValue)-\(i)", district: self, name: pair.0, factor: pair.1)
        }
    }
}

struct BuildingSpec: Identifiable, Hashable {
    let id: String
    let district: DistrictID
    let name: String
    let factor: Double
}

// MARK: - 신분(직함)

struct Rank: Identifiable, Hashable {
    let id: Int
    let title: String
    let requirement: Double   // 순자산
    let line: String

    static let all: [Rank] = [
        Rank(id: 0, title: "한 평 가게 주인", requirement: 0,
             line: "잔고 3만 원, 낡은 간판 하나."),
        Rank(id: 1, title: "동네 사장님", requirement: 3_000_000,
             line: "골목에서 이름이 불리기 시작했다."),
        Rank(id: 2, title: "골목 상권 큰손", requirement: 50_000_000,
             line: "시장 상인회에서 먼저 인사를 건넨다."),
        Rank(id: 3, title: "다점포 사장님", requirement: 1_000_000_000,
             line: "명함에 '대표'라고 새겼다."),
        Rank(id: 4, title: "중소기업 대표", requirement: 20_000_000_000,
             line: "법인을 세웠다. 직원 단톡방이 시끄럽다."),
        Rank(id: 5, title: "중견기업 대표", requirement: 400_000_000_000,
             line: "경제 신문에 인터뷰가 실렸다."),
        Rank(id: 6, title: "상장사 회장", requirement: 10_000_000_000_000,
             line: "상장 종을 쳤다. 주가가 곧 성적표다."),
        Rank(id: 7, title: "재계 순위권", requirement: 300_000_000_000_000,
             line: "재계 순위 발표에 회사 이름이 올랐다."),
        Rank(id: 8, title: "그룹 회장", requirement: 10_000_000_000_000_000,
             line: "한 평 가게에서 여기까지.")
    ]

    static func forNetWorth(_ worth: Double) -> Rank {
        all.last(where: { worth >= $0.requirement }) ?? all[0]
    }

    /// 도장에 새길 두 글자
    var stamp: String {
        ["개업", "사장", "큰손", "대표", "법인", "중견", "상장", "재계", "회장"][id]
    }

    var next: Rank? { id + 1 < Rank.all.count ? Rank.all[id + 1] : nil }

    var unlockedKinds: [BusinessKind] { BusinessKind.allCases.filter { $0.info.unlockRank == id } }
    var unlockedDistricts: [DistrictID] { DistrictID.allCases.filter { $0.info.unlockRank == id } }
}

// MARK: - 계산대 단계

enum Counter {
    static let names = ["주판", "손 계산기", "금전등록기", "카드 단말기", "POS 시스템", "키오스크", "셀프 계산대", "무인 결제"]

    static func name(level: Int) -> String {
        let i = level - 1
        if i < names.count { return names[i] }
        return "\(names.last!) \(i - names.count + 2)세대"
    }
}

// MARK: - 매물 사연

enum SellerStory {
    static let bargain = [
        "사장님 건강 문제로 급하게 내놓습니다.",
        "해외 이민 준비 중이라 빨리 정리합니다.",
        "동업자랑 갈라서게 됐어요. 가격 조정 가능.",
        "자녀 학교 때문에 이사 갑니다.",
        "다른 사업 시작해서 손 뗍니다. 급매."
    ]
    static let normal = [
        "단골 많은 자리입니다. 장부 공개 가능.",
        "인테리어 2년 됐습니다. 바로 영업 가능.",
        "직원들 그대로 승계 원합니다.",
        "권리금 협의 가능합니다.",
        "은퇴하려고 내놓습니다. 잘 키워주세요."
    ]
    static let premium = [
        "상권 1등 자리. 가격 조정 없습니다.",
        "이 자리 노리는 분 많습니다. 먼저 오시는 분께.",
        "매출 장부 보시면 납득하실 겁니다.",
        "입지 하나는 자신 있습니다."
    ]
}
