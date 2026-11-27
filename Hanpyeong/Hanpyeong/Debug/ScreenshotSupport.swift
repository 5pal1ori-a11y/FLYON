#if DEBUG
import SwiftUI

// 시뮬레이터 스크린샷용. 디버그 빌드에서만 컴파일된다.
// 실행 인자: -demoState YES -screenshotTab shop|market|goals|ledger|company -screenshotSheet decision|open|detail|talents

enum ScreenshotArgs {
    static var demo: Bool { UserDefaults.standard.bool(forKey: "demoState") }
    static var tab: String { UserDefaults.standard.string(forKey: "screenshotTab") ?? "" }
    static var sheet: String { UserDefaults.standard.string(forKey: "screenshotSheet") ?? "" }
}

struct DebugSheet: Identifiable {
    let id: String
}

struct DebugSheetView: View {
    @Environment(Game.self) private var game
    let kind: String

    var body: some View {
        switch kind {
        case "decision":
            DecisionSheet()
        case "open":
            OpenStoreSheet()
        case "talents":
            NavigationStack { TalentsView() }
        case "daily":
            EmptyView()
        default:
            NavigationStack {
                if let s = game.stores.max(by: { $0.kind.info.tier < $1.kind.info.tier }) {
                    StoreDetailView(storeID: s.id)
                }
            }
        }
    }
}

extension Game {
    func applyDemoState() {
        companyName = "한평상회"
        started = true
        day = 95
        dayClock = Economy.dayLength * 0.55
        highestRank = 3
        cash = 1_284_500_000
        debt = 200_000_000
        reputation = 72
        weather = .rain
        tapLevel = 5
        stats.taps = 4_812
        stats.kindsOwned = ["cornerShop", "bungeoppang", "snackBar", "cafe", "chicken", "convenience"]
        stats.decisionsMade = 11
        stats.improvementsBought = 6
        stats.missionsDone = 17
        talents = ["grandma", "minji", "deoksu", "malsun"]

        stores = [
            Store(kind: .convenience, district: .newtown, name: "한평24", level: 18, staff: 3,
                  invested: 1_900_000_000, openedDay: 70, improvements: ["sign", "delivery", "interior"],
                  leaseStart: 70, deposit: 650_000_000, wear: 12),
            Store(kind: .chicken, district: .campus, name: "바삭통닭", level: 34, staff: 3,
                  invested: 420_000_000, openedDay: 52, improvements: ["delivery", "sns"],
                  leaseStart: 52, deposit: 60_000_000, wear: 38),
            Store(kind: .cafe, district: .campus, name: "온기커피", level: 27, staff: 2,
                  invested: 300_000_000, openedDay: 40, improvements: ["sign"],
                  leaseStart: 40, deposit: 80_000_000, wear: 66),
            Store(kind: .snackBar, district: .market, name: "맛나분식", level: 52, staff: 3,
                  invested: 120_000_000, openedDay: 20, improvements: ["sign", "delivery", "sns", "interior"],
                  leaseStart: 20, deposit: 9_600_000, wear: 20),
            Store(kind: .cornerShop, district: .alley, name: "한평상회", level: 61, staff: 2,
                  invested: 25_000_000, openedDay: 1, improvements: ["sign"], wear: 44)
        ]
        buildings = [OwnedBuilding(id: "alley-1", district: .alley, purchasePrice: 70_000_000, boughtDay: 60)]

        for i in markets.indices {
            var v = 1.0
            var h: [Double] = []
            for _ in 0..<30 {
                v = min(1.6, max(0.7, v * exp(0.03 * Game.gaussian() + 0.003)))
                h.append(v)
            }
            markets[i].history = h
            markets[i].index = v
        }

        history = (66...94).map { d in
            var r = DayReport(day: d)
            r.revenue = Double.random(in: 1.6e7...2.6e7) * (1 + Double(d - 66) * 0.02)
            r.gross = r.revenue * 2.1
            r.rent = 2.2e6
            r.wages = 5.1e6
            r.interest = 1e5
            r.buildingIncome = 2.4e5
            return r
        }
        today = DayReport(day: day)
        today.revenue = 1.31e7
        today.gross = 2.75e7
        vatBase = 2.1e8
        incomeTaxBase = 1.42e9

        events = [MarketEvent(effect: .traffic(.campus, 1.4), daysLeft: 2, headline: "2일간 대학가 손님 +40%")]
        news = [
            NewsItem(day: 95, headline: "대학가 야시장 개장", detail: "2일간 대학가 손님 +40%", tone: .good),
            NewsItem(day: 94, headline: "한은, 기준금리 2.50% 동결", detail: "대출 금리 변동 없음", tone: .neutral),
            NewsItem(day: 92, headline: "'치킨집' 먹방 영상 조회수 1,000만", detail: "3일간 치킨집 매출 +50%", tone: .good)
        ]
        ledger = [
            LedgerEntry(day: 94, kind: .settle, title: "94일차 마감 · 임대료·인건비·이자", amount: -7_160_000),
            LedgerEntry(day: 93, kind: .buy, title: "한평24 신도시점 인수 (권리금)", amount: -1_240_000_000),
            LedgerEntry(day: 90, kind: .settle, title: "업적 · 단골이 생겼다", amount: 18_000_000),
            LedgerEntry(day: 88, kind: .sell, title: "행복상회 시장점 매각 · 옆 가게 사장님", amount: 41_000_000)
        ]
        listings = []
        refreshListings()
        progress = DailyProgress(taps: 64, levels: 3, hires: 0, trades: 1, opens: 0, improvements: 0)
        missions = [
            Mission(kind: .taps, target: 120, reward: 9_000_000),
            Mission(kind: .levels, target: 10, reward: 11_000_000),
            Mission(kind: .trade, target: 1, reward: 8_000_000)
        ]
        claimedAchievements = ["tap1", "tap1k", "stores3", "lv25", "lv50", "building1", "worth1e8"]
        pendingDecision = PendingDecision(id: "tvShow", scale: dailyScale, day: day)
        pendingRankUp = nil
        offlineReport = nil
        suppressOffline = true
        generation = 2
        legacy = 3
        streak = 4
        let p = VIPVisit.pool[1]
        vip = VIPVisit(title: p.title, symbol: p.symbol, line: p.line, reward: p.reward,
                       expires: Date().addingTimeInterval(120), x: 0.12)
        rushUntil = Date().addingTimeInterval(90)
        if ScreenshotArgs.sheet == "daily" {
            dailyReward = DailyRewardOffer(streak: 4, dayIndex: 3, amount: 2.7e8)
        }
    }
}
#endif
