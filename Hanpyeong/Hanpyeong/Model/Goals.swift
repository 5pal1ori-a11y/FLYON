import Foundation

// MARK: - 오늘의 할 일

enum MissionKind: String, Codable, CaseIterable {
    case taps, revenue, levels, hire, trade, open, improve

    func title(_ target: Double) -> String {
        let n = Int(target)
        switch self {
        case .taps:    return "손님 \(n)명 계산하기"
        case .revenue: return "오늘 매출 \(Won.short(target)) 달성"
        case .levels:  return "가게 레벨 \(n)번 올리기"
        case .hire:    return "직원 \(n)명 채용하기"
        case .trade:   return "점포나 건물 \(n)건 거래하기"
        case .open:    return "새 점포 \(n)곳 열기"
        case .improve: return "시설 투자 \(n)건 하기"
        }
    }

    var symbol: String {
        switch self {
        case .taps:    return "hand.tap.fill"
        case .revenue: return "wonsign.circle.fill"
        case .levels:  return "arrow.up.circle.fill"
        case .hire:    return "person.badge.plus"
        case .trade:   return "arrow.left.arrow.right.circle.fill"
        case .open:    return "storefront.fill"
        case .improve: return "hammer.fill"
        }
    }
}

struct Mission: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: MissionKind
    var target: Double
    var reward: Double
    var claimed = false
}

/// 오늘 한 일 카운터 (매일 0으로)
struct DailyProgress: Codable, Hashable {
    var taps = 0
    var levels = 0
    var hires = 0
    var trades = 0
    var opens = 0
    var improvements = 0
}

// MARK: - 업적

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let target: Double
    /// 보상 = max(floor, 하루 매출 규모 × days)
    let days: Double
    let floor: Double
    let current: (Game) -> Double

    static let all: [Achievement] = [
        Achievement(id: "tap1", title: "첫 손님", detail: "손님 1명 계산", symbol: "hand.tap",
                    target: 1, days: 0.2, floor: 5_000) { Double($0.stats.taps) },
        Achievement(id: "tap1k", title: "단골이 생겼다", detail: "손님 1,000명 계산", symbol: "hand.tap.fill",
                    target: 1_000, days: 1, floor: 100_000) { Double($0.stats.taps) },
        Achievement(id: "tap10k", title: "손목이 시큰", detail: "손님 10,000명 계산", symbol: "hands.clap.fill",
                    target: 10_000, days: 3, floor: 1_000_000) { Double($0.stats.taps) },
        Achievement(id: "stores3", title: "3호점까지", detail: "점포 3곳 운영", symbol: "storefront",
                    target: 3, days: 1, floor: 200_000) { Double($0.stores.count) },
        Achievement(id: "stores10", title: "체인의 시작", detail: "점포 10곳 운영", symbol: "storefront.fill",
                    target: 10, days: 2, floor: 5_000_000) { Double($0.stores.count) },
        Achievement(id: "stores25", title: "간판이 스물다섯 개", detail: "점포 25곳 운영", symbol: "building.2",
                    target: 25, days: 4, floor: 100_000_000) { Double($0.stores.count) },
        Achievement(id: "lv25", title: "장사가 손에 익다", detail: "한 점포 Lv.25 달성", symbol: "arrow.up.circle",
                    target: 25, days: 1, floor: 100_000) { Double($0.stores.map(\.level).max() ?? 0) },
        Achievement(id: "lv50", title: "동네 명물", detail: "한 점포 Lv.50 달성", symbol: "arrow.up.circle.fill",
                    target: 50, days: 2, floor: 2_000_000) { Double($0.stores.map(\.level).max() ?? 0) },
        Achievement(id: "lv100", title: "전설의 가게", detail: "한 점포 Lv.100 달성", symbol: "crown",
                    target: 100, days: 5, floor: 100_000_000) { Double($0.stores.map(\.level).max() ?? 0) },
        Achievement(id: "staff10", title: "사장님 소리", detail: "직원 합계 10명", symbol: "person.2.fill",
                    target: 10, days: 1, floor: 1_000_000) { g in Double(g.stores.reduce(0) { $0 + $1.staff }) },
        Achievement(id: "staff50", title: "일자리 창출", detail: "직원 합계 50명", symbol: "person.3.fill",
                    target: 50, days: 3, floor: 100_000_000) { g in Double(g.stores.reduce(0) { $0 + $1.staff }) },
        Achievement(id: "sell1", title: "첫 매각", detail: "점포 1곳 매각", symbol: "hand.wave.fill",
                    target: 1, days: 0.5, floor: 100_000) { Double($0.stats.sells) },
        Achievement(id: "trade20", title: "부동산 촉", detail: "매매 20건", symbol: "arrow.left.arrow.right",
                    target: 20, days: 2, floor: 10_000_000) { Double($0.stats.trades) },
        Achievement(id: "building1", title: "건물주", detail: "건물 1채 보유", symbol: "building.fill",
                    target: 1, days: 1, floor: 5_000_000) { Double($0.buildings.count) },
        Achievement(id: "building10", title: "빌딩 수집가", detail: "건물 10채 보유", symbol: "building.2.crop.circle.fill",
                    target: 10, days: 4, floor: 1_000_000_000) { Double($0.buildings.count) },
        Achievement(id: "worth1e8", title: "억대 자산가", detail: "순자산 1억", symbol: "banknote",
                    target: 1e8, days: 1, floor: 2_000_000) { $0.netWorth },
        Achievement(id: "worth1e10", title: "백억 클럽", detail: "순자산 100억", symbol: "banknote.fill",
                    target: 1e10, days: 2, floor: 200_000_000) { $0.netWorth },
        Achievement(id: "worth1e12", title: "조 단위의 세계", detail: "순자산 1조", symbol: "chart.line.uptrend.xyaxis",
                    target: 1e12, days: 3, floor: 20_000_000_000) { $0.netWorth },
        Achievement(id: "worth1e15", title: "천조 원의 사나이", detail: "순자산 1,000조", symbol: "globe.asia.australia.fill",
                    target: 1e15, days: 5, floor: 1e13) { $0.netWorth },
        Achievement(id: "kinds6", title: "문어발 경영", detail: "서로 다른 업종 6개 운영해 보기", symbol: "square.grid.3x3.fill",
                    target: 6, days: 2, floor: 50_000_000) { Double($0.stats.kindsOwned.count) },
        Achievement(id: "kindsAll", title: "업종 도감 완성", detail: "모든 업종 운영해 보기", symbol: "books.vertical.fill",
                    target: Double(BusinessKind.allCases.count), days: 10, floor: 1e13) { Double($0.stats.kindsOwned.count) },
        Achievement(id: "rep80", title: "동네의 자랑", detail: "평판 80", symbol: "hand.thumbsup.fill",
                    target: 80, days: 1, floor: 1_000_000) { $0.reputation },
        Achievement(id: "rep100", title: "국민 가게", detail: "평판 100", symbol: "heart.circle.fill",
                    target: 100, days: 3, floor: 50_000_000) { $0.reputation },
        Achievement(id: "improve10", title: "투자의 귀재", detail: "시설 투자 10건", symbol: "hammer.fill",
                    target: 10, days: 2, floor: 20_000_000) { Double($0.stats.improvementsBought) },
        Achievement(id: "talent3", title: "사람이 재산", detail: "인재 3명 영입", symbol: "person.crop.rectangle.stack.fill",
                    target: 3, days: 1, floor: 5_000_000) { Double($0.talents.count) },
        Achievement(id: "talentAll", title: "드림팀", detail: "모든 인재 영입", symbol: "star.fill",
                    target: Double(Talent.all.count), days: 10, floor: 1e14) { Double($0.talents.count) },
        Achievement(id: "day100", title: "100일 장사", detail: "100일 영업", symbol: "calendar",
                    target: 100, days: 2, floor: 10_000_000) { Double($0.day) },
        Achievement(id: "year1", title: "1주년", detail: "1년(120일) 영업", symbol: "birthday.cake.fill",
                    target: 121, days: 4, floor: 100_000_000) { Double($0.day) },
        Achievement(id: "decide20", title: "결단의 사장님", detail: "결정 20번 내리기", symbol: "signpost.right.and.left.fill",
                    target: 20, days: 2, floor: 10_000_000) { Double($0.stats.decisionsMade) },
        Achievement(id: "missions30", title: "성실함이 무기", detail: "오늘의 할 일 30개 완료", symbol: "checklist",
                    target: 30, days: 3, floor: 50_000_000) { Double($0.stats.missionsDone) },
        Achievement(id: "bestDay", title: "대박 난 날", detail: "하루 순이익 1억", symbol: "sparkles",
                    target: 1e8, days: 1, floor: 10_000_000) { $0.stats.bestDailyNet },
        Achievement(id: "debtFree", title: "무차입 경영", detail: "빚 없이 순자산 1,000억", symbol: "checkmark.seal.fill",
                    target: 1e11, days: 3, floor: 2_000_000_000) { $0.debt > 0 ? 0 : $0.netWorth },
        Achievement(id: "winterFish", title: "겨울엔 붕어빵", detail: "겨울에 붕어빵 노점 운영", symbol: "snowflake",
                    target: 1, days: 1, floor: 500_000) { g in
                        g.season == .winter && g.stores.contains { $0.kind == .bungeoppang } ? 1 : 0
                    },
        Achievement(id: "everywhere", title: "전국구", detail: "모든 지역에 점포 운영", symbol: "map.fill",
                    target: Double(DistrictID.allCases.count), days: 5, floor: 1e12) { g in
                        Double(Set(g.stores.map(\.district)).count)
                    },
        Achievement(id: "top1", title: "재계 1위", detail: "재계 순위 1위", symbol: "trophy.fill",
                    target: 1, days: 10, floor: 1e14) { $0.leaderboardPosition == 1 ? 1 : 0 }
    ]
}
