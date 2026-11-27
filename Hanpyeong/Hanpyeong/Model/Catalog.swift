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

/// 업종마다 다른 성격. 같은 돈이라도 어디에 쓰느냐가 달라진다.
enum Trait: String, Codable {
    case normal, street, unmanned, night, steady, tourist, hit

    var title: String {
        switch self {
        case .normal:   return "일반"
        case .street:   return "노점"
        case .unmanned: return "무인"
        case .night:    return "야간형"
        case .steady:   return "불황에 강함"
        case .tourist:  return "관광형"
        case .hit:      return "흥행형"
        }
    }

    var detail: String {
        switch self {
        case .normal:   return "특별한 성격이 없는 평범한 가게."
        case .street:   return "임대료가 없다. 겨울에 잘 팔리고 여름엔 파리 날린다."
        case .unmanned: return "직원이 필요 없다. 비 오는 날 손님이 몰린다."
        case .night:    return "저녁부터 매출이 폭발한다. 아침엔 한산하다."
        case .steady:   return "불황·악천후·악재 뉴스에 매출이 줄지 않는다."
        case .tourist:  return "여름과 맑은 날에 강하다. 겨울과 비에 약하다."
        case .hit:      return "날마다 흥행이 갈린다. 대박과 쪽박 사이."
        }
    }
}

enum BusinessKind: String, Codable, CaseIterable, Identifiable {
    case bungeoppang, cornerShop, flowerShop,
         snackBar, laundromat, hairSalon,
         cafe, chicken, pcBang, academy, carRepair,
         convenience, gym, bbq, webtoon, appStudio,
         supermarket, foodFactory, entertainment,
         franchiseHQ, hotel, gameCompany,
         logistics, themePark, pharma,
         departmentStore, airline, securities, chipFab,
         holdings

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
        let trait: Trait
        let blurb: String
    }

    var info: Info {
        switch self {
        case .bungeoppang:
            return Info(title: "붕어빵 노점", symbol: "flame.fill", tier: 0, unlockRank: 0,
                        openCost: 300_000, baseIncome: 14, baseUpgrade: 1_500,
                        rent: 0, wage: 2_000, maxStaff: 1, color: 0x9A5B2E, trait: .street,
                        blurb: "팥이냐 슈크림이냐. 겨울 저녁엔 줄이 선다.")
        case .cornerShop:
            return Info(title: "구멍가게", symbol: "basket.fill", tier: 0, unlockRank: 0,
                        openCost: 1_000_000, baseIncome: 30, baseUpgrade: 3_000,
                        rent: 1_000, wage: 3_000, maxStaff: 2, color: 0xC23B2C, trait: .normal,
                        blurb: "라면, 담배, 막걸리. 동네 사람들의 사랑방.")
        case .snackBar:
            return Info(title: "분식집", symbol: "takeoutbag.and.cup.and.straw.fill", tier: 1, unlockRank: 1,
                        openCost: 25_000_000, baseIncome: 260, baseUpgrade: 30_000,
                        rent: 12_000, wage: 25_000, maxStaff: 3, color: 0xD9702A, trait: .normal,
                        blurb: "떡볶이 국물 냄새로 손님을 끈다.")
        case .laundromat:
            return Info(title: "코인빨래방", symbol: "tshirt.fill", tier: 1, unlockRank: 1,
                        openCost: 18_000_000, baseIncome: 260, baseUpgrade: 26_000,
                        rent: 9_000, wage: 0, maxStaff: 0, color: 0x4F86B8, trait: .unmanned,
                        blurb: "사장이 없어도 세탁기는 돈다. 장마철이 대목.")
        case .cafe:
            return Info(title: "동네 카페", symbol: "cup.and.saucer.fill", tier: 2, unlockRank: 2,
                        openCost: 180_000_000, baseIncome: 1_900, baseUpgrade: 250_000,
                        rent: 80_000, wage: 180_000, maxStaff: 4, color: 0x3E6A4F, trait: .normal,
                        blurb: "원두 하나로 단골을 만든다. 여름엔 아이스가 불티난다.")
        case .chicken:
            return Info(title: "치킨집", symbol: "fork.knife", tier: 2, unlockRank: 2,
                        openCost: 150_000_000, baseIncome: 1_650, baseUpgrade: 220_000,
                        rent: 60_000, wage: 150_000, maxStaff: 4, color: 0xB5481F, trait: .night,
                        blurb: "밤 열 시, 배달 앱 알림이 쉬지 않는다.")
        case .pcBang:
            return Info(title: "PC방", symbol: "desktopcomputer", tier: 2, unlockRank: 2,
                        openCost: 260_000_000, baseIncome: 2_600, baseUpgrade: 340_000,
                        rent: 100_000, wage: 160_000, maxStaff: 3, color: 0x5B3E8C, trait: .night,
                        blurb: "방학과 새벽이 대목. 라면이 게임비보다 더 팔린다.")
        case .convenience:
            return Info(title: "편의점", symbol: "storefront.fill", tier: 3, unlockRank: 3,
                        openCost: 1_300_000_000, baseIncome: 14_000, baseUpgrade: 1_800_000,
                        rent: 500_000, wage: 1_200_000, maxStaff: 5, color: 0x2E5AAC, trait: .normal,
                        blurb: "24시간 꺼지지 않는 불빛.")
        case .gym:
            return Info(title: "헬스장", symbol: "figure.run", tier: 3, unlockRank: 3,
                        openCost: 1_100_000_000, baseIncome: 11_500, baseUpgrade: 1_500_000,
                        rent: 450_000, wage: 800_000, maxStaff: 4, color: 0x2F7D6B, trait: .steady,
                        blurb: "연간 회원권은 불황을 타지 않는다. 봄마다 등록 러시.")
        case .bbq:
            return Info(title: "고깃집", symbol: "fork.knife.circle.fill", tier: 3, unlockRank: 3,
                        openCost: 1_600_000_000, baseIncome: 17_000, baseUpgrade: 2_200_000,
                        rent: 600_000, wage: 1_500_000, maxStaff: 6, color: 0x8B3A2B, trait: .night,
                        blurb: "회식 자리 1순위. 불판 위에서 돈이 익는다.")
        case .supermarket:
            return Info(title: "대형마트", symbol: "cart.fill", tier: 4, unlockRank: 4,
                        openCost: 10_000_000_000, baseIncome: 80_000, baseUpgrade: 14_000_000,
                        rent: 4_000_000, wage: 9_000_000, maxStaff: 8, color: 0xC8961C, trait: .normal,
                        blurb: "주말마다 주차장이 꽉 찬다. 명절 대목.")
        case .franchiseHQ:
            return Info(title: "프랜차이즈 본사", symbol: "building.2.fill", tier: 5, unlockRank: 5,
                        openCost: 80_000_000_000, baseIncome: 460_000, baseUpgrade: 110_000_000,
                        rent: 30_000_000, wage: 70_000_000, maxStaff: 10, color: 0x8C2B3E, trait: .steady,
                        blurb: "내 가게 간판을 전국에 단다. 가맹비는 불황에도 들어온다.")
        case .hotel:
            return Info(title: "호텔", symbol: "bed.double.fill", tier: 5, unlockRank: 5,
                        openCost: 120_000_000_000, baseIncome: 600_000, baseUpgrade: 160_000_000,
                        rent: 45_000_000, wage: 100_000_000, maxStaff: 10, color: 0x6B5B3E, trait: .tourist,
                        blurb: "성수기엔 방이 없고, 비수기엔 직원이 더 많다.")
        case .logistics:
            return Info(title: "물류센터", symbol: "shippingbox.fill", tier: 6, unlockRank: 6,
                        openCost: 650_000_000_000, baseIncome: 2_800_000, baseUpgrade: 900_000_000,
                        rent: 250_000_000, wage: 550_000_000, maxStaff: 10, color: 0x47566A, trait: .night,
                        blurb: "새벽 배송의 심장. 밤에 가장 바쁘다.")
        case .themePark:
            return Info(title: "테마파크", symbol: "sparkles", tier: 6, unlockRank: 6,
                        openCost: 900_000_000_000, baseIncome: 3_600_000, baseUpgrade: 1_250_000_000,
                        rent: 300_000_000, wage: 800_000_000, maxStaff: 12, color: 0xC0456E, trait: .tourist,
                        blurb: "롤러코스터 대기 90분. 여름 방학이 일 년 장사.")
        case .departmentStore:
            return Info(title: "백화점", symbol: "bag.fill", tier: 7, unlockRank: 7,
                        openCost: 5_500_000_000_000, baseIncome: 18_000_000, baseUpgrade: 7_500_000_000,
                        rent: 2_000_000_000, wage: 4_500_000_000, maxStaff: 12, color: 0x2A2C31, trait: .normal,
                        blurb: "1층 명품관에 줄이 선다. 연말 세일이 승부처.")
        case .airline:
            return Info(title: "항공사", symbol: "airplane", tier: 7, unlockRank: 7,
                        openCost: 8_000_000_000_000, baseIncome: 24_000_000, baseUpgrade: 10_500_000_000,
                        rent: 3_000_000_000, wage: 6_500_000_000, maxStaff: 12, color: 0x2B5C8A, trait: .tourist,
                        blurb: "하늘길을 연다. 휴가철 좌석은 매진.")
        case .flowerShop:
            return Info(title: "꽃집", symbol: "camera.macro", tier: 0, unlockRank: 0,
                        openCost: 600_000, baseIncome: 20, baseUpgrade: 2_000,
                        rent: 800, wage: 2_500, maxStaff: 1, color: 0xD0567A, trait: .normal,
                        blurb: "졸업식과 어버이날이 대목.")
        case .hairSalon:
            return Info(title: "미용실", symbol: "scissors", tier: 1, unlockRank: 1,
                        openCost: 22_000_000, baseIncome: 240, baseUpgrade: 28_000,
                        rent: 11_000, wage: 30_000, maxStaff: 3, color: 0x8A5FB0, trait: .normal,
                        blurb: "단골 손님은 10년을 간다.")
        case .academy:
            return Info(title: "보습학원", symbol: "graduationcap.fill", tier: 2, unlockRank: 2,
                        openCost: 160_000_000, baseIncome: 1_750, baseUpgrade: 230_000,
                        rent: 70_000, wage: 200_000, maxStaff: 4, color: 0x2E7FA8, trait: .steady,
                        blurb: "방학 특강이 승부처.")
        case .carRepair:
            return Info(title: "카센터", symbol: "wrench.and.screwdriver.fill", tier: 2, unlockRank: 2,
                        openCost: 200_000_000, baseIncome: 2_000, baseUpgrade: 270_000,
                        rent: 90_000, wage: 170_000, maxStaff: 3, color: 0x5D6B78, trait: .normal,
                        blurb: "눈 오는 날 타이어 교체 줄.")
        case .webtoon:
            return Info(title: "웹툰 스튜디오", symbol: "paintpalette.fill", tier: 3, unlockRank: 3,
                        openCost: 1_200_000_000, baseIncome: 13_000, baseUpgrade: 1_700_000,
                        rent: 300_000, wage: 1_300_000, maxStaff: 5, color: 0x1FA67A, trait: .hit,
                        blurb: "연재 한 편이 인생을 바꾼다.")
        case .appStudio:
            return Info(title: "앱 개발사", symbol: "iphone", tier: 3, unlockRank: 3,
                        openCost: 1_500_000_000, baseIncome: 16_000, baseUpgrade: 2_000_000,
                        rent: 400_000, wage: 1_600_000, maxStaff: 6, color: 0x3B5BDB, trait: .hit,
                        blurb: "차트 1위 아니면 0원.")
        case .foodFactory:
            return Info(title: "식품 공장", symbol: "gearshape.2.fill", tier: 4, unlockRank: 4,
                        openCost: 12_000_000_000, baseIncome: 95_000, baseUpgrade: 16_000_000,
                        rent: 3_000_000, wage: 10_000_000, maxStaff: 10, color: 0x9C6B2F, trait: .steady,
                        blurb: "라인은 멈추지 않는다.")
        case .entertainment:
            return Info(title: "연예 기획사", symbol: "music.mic", tier: 4, unlockRank: 4,
                        openCost: 9_000_000_000, baseIncome: 75_000, baseUpgrade: 13_000_000,
                        rent: 3_500_000, wage: 8_000_000, maxStaff: 8, color: 0xE0457B, trait: .hit,
                        blurb: "데뷔 앨범 하나에 운명이 걸렸다.")
        case .gameCompany:
            return Info(title: "게임 회사", symbol: "gamecontroller.fill", tier: 5, unlockRank: 5,
                        openCost: 100_000_000_000, baseIncome: 520_000, baseUpgrade: 135_000_000,
                        rent: 25_000_000, wage: 90_000_000, maxStaff: 12, color: 0x6741D9, trait: .hit,
                        blurb: "업데이트 날엔 서버가 운다.")
        case .pharma:
            return Info(title: "제약·바이오", symbol: "pills.fill", tier: 6, unlockRank: 6,
                        openCost: 800_000_000_000, baseIncome: 3_300_000, baseUpgrade: 1_100_000_000,
                        rent: 200_000_000, wage: 700_000_000, maxStaff: 12, color: 0x0CA678, trait: .hit,
                        blurb: "임상 결과 발표날, 모두가 숨죽인다.")
        case .securities:
            return Info(title: "증권사", symbol: "chart.line.uptrend.xyaxis", tier: 7, unlockRank: 7,
                        openCost: 6_500_000_000_000, baseIncome: 20_000_000, baseUpgrade: 9_000_000_000,
                        rent: 2_500_000_000, wage: 5_500_000_000, maxStaff: 12, color: 0x1C7ED6, trait: .hit,
                        blurb: "장이 열리면 돈이 돈다.")
        case .chipFab:
            return Info(title: "반도체 공장", symbol: "cpu", tier: 7, unlockRank: 7,
                        openCost: 7_000_000_000_000, baseIncome: 21_000_000, baseUpgrade: 9_500_000_000,
                        rent: 1_500_000_000, wage: 6_000_000_000, maxStaff: 12, color: 0x495057, trait: .steady,
                        blurb: "먼지 한 톨 없는 클린룸.")
        case .holdings:
            return Info(title: "지주회사", symbol: "crown.fill", tier: 8, unlockRank: 7,
                        openCost: 50_000_000_000_000, baseIncome: 130_000_000, baseUpgrade: 65_000_000_000,
                        rent: 18_000_000_000, wage: 40_000_000_000, maxStaff: 12, color: 0x1E2A47, trait: .steady,
                        blurb: "모든 계열사 위에 서는 회사.")
        }
    }

    var color: Color { Color(hex: info.color) }

    var namePool: [String] {
        switch self {
        case .bungeoppang:     return ["황금붕어", "할매붕어빵", "따끈붕어", "팥붕슈붕"]
        case .cornerShop:      return ["행복상회", "제일상회", "우리슈퍼", "만물상회", "골목상회", "정다운가게"]
        case .snackBar:        return ["맛나분식", "엄마손분식", "골목떡볶이", "바삭김밥", "학교앞분식"]
        case .laundromat:      return ["뽀송빨래방", "구름세탁", "하얀거품", "24시 코인워시"]
        case .cafe:            return ["온기커피", "느린오후", "모퉁이커피", "브루잉룸", "볕드는카페"]
        case .chicken:         return ["바삭통닭", "옛날통닭", "치킨공방", "두마리치킨", "골목치킨"]
        case .pcBang:          return ["레벨업PC", "한판PC", "로그인PC", "풀옵PC방"]
        case .convenience:     return ["한평24", "나이트마트", "편한24", "별빛편의점"]
        case .gym:             return ["강철짐", "득근헬스", "바디랩", "새벽헬스"]
        case .bbq:             return ["화로구이", "숯불명가", "고기굽는집", "한평정육식당"]
        case .supermarket:     return ["장보는날", "푸드마켓", "한평 메가마트", "알뜰마트"]
        case .franchiseHQ:     return ["골목브랜즈", "한평F&B", "단골푸드", "스트릿키친"]
        case .hotel:           return ["호텔 한평", "더 하버 호텔", "스테이 온", "그랜드 라온"]
        case .logistics:       return ["한평로지스", "새벽물류", "빠른길물류", "허브라인"]
        case .themePark:       return ["한평랜드", "드림월드", "구름나라", "판타지아 파크"]
        case .departmentStore: return ["한평 플라자", "스카이라인 백화점", "더 메리디안"]
        case .airline:         return ["한평항공", "에어 라온", "블루윙", "스카이온"]
        case .flowerShop:      return ["꽃다발", "봄날꽃집", "플라워 온", "들꽃상회"]
        case .hairSalon:       return ["가위손헤어", "살롱 드 한평", "단발머리", "헤어라운지"]
        case .academy:         return ["일등학원", "수학의 정석학원", "한평에듀", "올백학원"]
        case .carRepair:       return ["달려카센터", "믿음정비", "스피드모터스", "타이어뱅크온"]
        case .webtoon:         return ["컷앤컷", "말풍선 스튜디오", "레드펜", "한평툰"]
        case .appStudio:       return ["픽셀랩", "한평소프트", "탭탭스튜디오", "앱공방"]
        case .foodFactory:     return ["한평식품", "바른먹거리", "든든푸드", "새참식품"]
        case .entertainment:   return ["스타라이트", "한평엔터", "블루노트", "무대뒤"]
        case .gameCompany:     return ["한평게임즈", "크리티컬", "레벨나인", "픽셀포지"]
        case .pharma:          return ["한평제약", "새살바이오", "늘봄제약", "셀온"]
        case .securities:      return ["한평증권", "미래가치증권", "황소증권", "온투자증권"]
        case .chipFab:         return ["한평반도체", "나노팹", "실리콘온", "웨이퍼원"]
        case .holdings:        return ["홀딩스"]
        }
    }

    /// 계절별 매출 배율
    func seasonFactor(_ s: Season) -> Double {
        switch (self, s) {
        case (.bungeoppang, .spring): return 0.8
        case (.bungeoppang, .summer): return 0.5
        case (.bungeoppang, .autumn): return 1.1
        case (.bungeoppang, .winter): return 1.8
        case (.snackBar, .winter): return 1.15
        case (.laundromat, .summer): return 1.15
        case (.cafe, .summer): return 1.2
        case (.cafe, .winter): return 0.95
        case (.chicken, .summer), (.chicken, .autumn): return 1.1
        case (.pcBang, .summer), (.pcBang, .winter): return 1.2
        case (.convenience, .summer): return 1.15
        case (.gym, .spring): return 1.3
        case (.gym, .winter): return 0.9
        case (.bbq, .autumn): return 1.15
        case (.bbq, .winter): return 1.1
        case (.supermarket, .autumn): return 1.2
        case (.hotel, .summer), (.themePark, .summer), (.airline, .summer): return 1.4
        case (.hotel, .spring), (.themePark, .spring), (.airline, .spring): return 1.1
        case (.hotel, .winter), (.themePark, .winter), (.airline, .winter): return 0.8
        case (.departmentStore, .winter): return 1.25
        case (.flowerShop, .spring): return 1.4
        case (.flowerShop, .winter): return 0.8
        case (.academy, .summer), (.academy, .winter): return 1.3
        case (.academy, .spring), (.academy, .autumn): return 0.9
        case (.carRepair, .winter): return 1.2
        default: return 1
        }
    }

    /// 날씨별 매출 배율
    func weatherFactor(_ w: Weather) -> Double {
        switch (self, w) {
        case (_, .cloudy): return 1
        case (.bungeoppang, .rain): return 0.6
        case (.bungeoppang, .snow): return 1.3
        case (.bungeoppang, .cold): return 1.4
        case (.bungeoppang, .heat): return 0.5
        case (.laundromat, .rain): return 1.35
        case (.chicken, .rain), (.chicken, .snow): return 1.2
        case (.pcBang, .rain), (.pcBang, .snow), (.pcBang, .cold): return 1.15
        case (.cafe, .heat), (.convenience, .heat): return 1.3
        case (.snackBar, .cold): return 1.15
        case (.gym, .heat): return 0.85
        case (.carRepair, .snow), (.carRepair, .cold): return 1.3
        case (.flowerShop, .rain): return 0.7
        case (.webtoon, _), (.appStudio, _), (.gameCompany, _), (.securities, _), (.chipFab, _), (.pharma, _): return 1
        default: break
        }
        switch (info.trait, w) {
        case (.tourist, .sunny): return 1.15
        case (.tourist, .rain): return 0.7
        case (.tourist, .snow): return 0.75
        default: break
        }
        switch w {
        case .sunny: return 1.05
        case .cloudy: return 1
        case .rain: return 0.85
        case .snow: return 0.8
        case .heat: return 0.92
        case .cold: return 0.9
        }
    }
}

// MARK: - 지역

enum DistrictID: String, Codable, CaseIterable, Identifiable {
    case alley, market, campus, newtown, station, beach, office, cbd, airport

    var id: String { rawValue }

    struct Info {
        let name: String
        let short: String
        let traffic: Double
        let rentMult: Double
        let slots: Int
        let unlockRank: Int
        let buildingBase: Double
        let tourist: Bool
        let mood: String
    }

    var info: Info {
        switch self {
        case .alley:   return Info(name: "달동네 골목", short: "골목", traffic: 1.0, rentMult: 0.6, slots: 3, unlockRank: 0,
                                   buildingBase: 80_000_000, tourist: false, mood: "오래된 동네, 정 많은 단골")
        case .market:  return Info(name: "전통시장 거리", short: "시장", traffic: 1.25, rentMult: 0.8, slots: 3, unlockRank: 1,
                                   buildingBase: 300_000_000, tourist: false, mood: "주말마다 북적이는 장터")
        case .campus:  return Info(name: "대학가", short: "대학가", traffic: 1.6, rentMult: 1.0, slots: 4, unlockRank: 2,
                                   buildingBase: 1_500_000_000, tourist: false, mood: "개강하면 살아나는 상권")
        case .newtown: return Info(name: "신도시 상가", short: "신도시", traffic: 2.1, rentMult: 1.3, slots: 4, unlockRank: 3,
                                   buildingBase: 8_000_000_000, tourist: false, mood: "젊은 가족, 넓은 도로")
        case .station: return Info(name: "역세권", short: "역세권", traffic: 2.8, rentMult: 1.8, slots: 5, unlockRank: 4,
                                   buildingBase: 60_000_000_000, tourist: false, mood: "하루 유동인구 십만")
        case .beach:   return Info(name: "바닷가 관광지", short: "해변", traffic: 2.4, rentMult: 1.4, slots: 4, unlockRank: 4,
                                   buildingBase: 30_000_000_000, tourist: true, mood: "여름 한철에 일 년을 번다")
        case .office:  return Info(name: "오피스 타운", short: "오피스", traffic: 3.8, rentMult: 2.5, slots: 5, unlockRank: 5,
                                   buildingBase: 500_000_000_000, tourist: false, mood: "점심시간이 전쟁")
        case .cbd:     return Info(name: "중심 업무지구", short: "중심지", traffic: 5.2, rentMult: 3.5, slots: 6, unlockRank: 6,
                                   buildingBase: 4_000_000_000_000, tourist: false, mood: "이 나라 돈이 모이는 곳")
        case .airport: return Info(name: "공항 신도시", short: "공항", traffic: 4.6, rentMult: 3.0, slots: 5, unlockRank: 6,
                                   buildingBase: 2_500_000_000_000, tourist: true, mood: "하루 수십만 명이 오가는 관문")
        }
    }

    /// 관광지는 계절을 탄다
    func seasonFactor(_ s: Season) -> Double {
        guard info.tourist else { return 1 }
        switch s {
        case .summer: return 1.3
        case .winter: return 0.8
        default: return 1
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
        case .beach:   names = ["해변 앞 2층 상가", "오션뷰 펜션 건물", "리조트 상가동"]
        case .office:  names = ["업무지구 이면 빌딩", "12층 오피스", "랜드마크 타워 저층부"]
        case .cbd:     names = ["중심지 근생 빌딩", "35층 프라임 오피스", "스카이 타워"]
        case .airport: names = ["공항철도역 상가", "면세 쇼핑몰 동", "에어포트 비즈니스 타워"]
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
        "다른 사업 시작해서 손 뗍니다. 급매.",
        "부모님 가게 이어받느라 정리합니다.",
        "빚 정리해야 해서 시세보다 싸게 넘깁니다.",
        "솔직히 지쳤습니다. 쉬고 싶어요."
    ]
    static let normal = [
        "단골 많은 자리입니다. 장부 공개 가능.",
        "인테리어 2년 됐습니다. 바로 영업 가능.",
        "직원들 그대로 승계 원합니다.",
        "권리금 협의 가능합니다.",
        "은퇴하려고 내놓습니다. 잘 키워주세요.",
        "단골 명부와 레시피까지 넘겨드립니다.",
        "주변에 경쟁 가게 없습니다. 직접 와서 보세요.",
        "건물주 좋은 분입니다. 재계약 문제없어요."
    ]
    static let premium = [
        "상권 1등 자리. 가격 조정 없습니다.",
        "이 자리 노리는 분 많습니다. 먼저 오시는 분께.",
        "매출 장부 보시면 납득하실 겁니다.",
        "입지 하나는 자신 있습니다.",
        "방송 세 번 탄 집입니다.",
        "대기 줄이 매일 섭니다. 사진 보내드릴게요."
    ]
}
