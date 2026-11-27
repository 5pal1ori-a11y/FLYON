import Foundation
import Observation

enum BulkMode: String, CaseIterable, Identifiable {
    case one = "×1", ten = "×10", max = "MAX"
    var id: String { rawValue }
}

@Observable
final class Game {

    // MARK: - 저장되는 상태

    var companyName = "한평상회"
    var started = false
    var cash: Double = Economy.startingCash
    var debt: Double = 0
    var day = 1
    var dayClock: Double = 0
    var tapLevel = 1
    var stores: [Store] = []
    var buildings: [OwnedBuilding] = []
    var markets: [DistrictMarket] = DistrictID.allCases.map { DistrictMarket(id: $0) }
    var listings: [Listing] = []
    var events: [MarketEvent] = []
    var news: [NewsItem] = []
    var history: [DayReport] = []
    var today = DayReport(day: 1)
    var ledger: [LedgerEntry] = []
    var stats = Stats()
    var highestRank = 0
    var hapticsOn = true
    var reputation: Double = 50
    var weather: Weather = .sunny
    var talents: [String] = []
    var pendingDecision: PendingDecision?
    var missions: [Mission] = []
    var progress = DailyProgress()
    var claimedAchievements: [String] = []

    // MARK: - 화면용 임시 상태

    var pendingRankUp: Rank?
    var offlineReport: OfflineReport?
    var toast: String?
    var bulk: BulkMode = .one
    var decisionResult: DecisionResult?

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastActive = Date()
    @ObservationIgnored private var sinceSave: Double = 0

    init() {
        load()
    }

    // MARK: - 조회

    var rank: Rank { Rank.all[min(highestRank, Rank.all.count - 1)] }

    func market(_ d: DistrictID) -> DistrictMarket {
        markets.first { $0.id == d } ?? DistrictMarket(id: d)
    }

    func index(_ d: DistrictID) -> Double { market(d).index }

    func isUnlocked(_ k: BusinessKind) -> Bool { k.info.unlockRank <= highestRank }
    func isUnlocked(_ d: DistrictID) -> Bool { d.info.unlockRank <= highestRank }

    func stores(in d: DistrictID) -> [Store] { stores.filter { $0.district == d } }
    func freeSlots(in d: DistrictID) -> Int { d.info.slots - stores(in: d).count }
    func ownsBuilding(in d: DistrictID) -> Bool { buildings.contains { $0.district == d } }

    func store(_ id: UUID) -> Store? { stores.first { $0.id == id } }

    var dayFraction: Double { dayClock / Economy.dayLength }

    var season: Season { GameCalendar.season(day) }
    var dateText: String { GameCalendar.shortText(day) }

    /// 평판 0 → ×0.8, 50 → ×1.0, 100 → ×1.2
    var reputationFactor: Double { 0.8 + reputation / 250 }

    var reputationTitle: String {
        switch reputation {
        case ..<20: return "악명"
        case ..<40: return "별로"
        case ..<60: return "보통"
        case ..<80: return "좋음"
        case ..<95: return "자랑"
        default: return "전설"
        }
    }

    var dayPhase: String {
        switch dayFraction {
        case ..<0.2: return "아침"
        case ..<0.4: return "점심"
        case ..<0.65: return "오후"
        case ..<0.85: return "저녁"
        default: return "마감 직전"
        }
    }

    // MARK: - 매출 공식

    static func milestoneMultiplier(level: Int) -> Double {
        pow(2, Double(Economy.milestones.filter { level >= $0 }.count))
    }

    static func nextMilestone(after level: Int) -> Int? {
        Economy.milestones.first { $0 > level }
    }

    /// 이벤트 영향을 뺀 점포의 기본 체력
    func baseIncome(kind: BusinessKind, level: Int, staff: Int, district: DistrictID) -> Double {
        kind.info.baseIncome
            * Double(level)
            * Game.milestoneMultiplier(level: level)
            * (1 + Economy.staffBoost * Double(staff))
            * district.info.traffic
    }

    /// 뉴스·계절·날씨·평판·인재·시간대를 모두 합친 배율
    func modifier(kind: BusinessKind, district: DistrictID, delivery: Bool = false) -> Double {
        let steady = kind.info.trait == .steady
        func adj(_ x: Double) -> Double { steady ? max(1, x) : x }

        var m = 1.0
        for e in events {
            switch e.effect {
            case .traffic(let d, let x): if d == district { m *= adj(x) }
            case .business(let k, let x): if k == kind { m *= adj(x) }
            case .economy(let x): m *= adj(x)
            }
        }
        m *= adj(kind.seasonFactor(season) * district.seasonFactor(season))
        var w = kind.weatherFactor(weather)
        if delivery && w < 1 && (weather == .rain || weather == .snow) { w = 1 }
        m *= adj(w)
        m *= reputationFactor
        m *= talentIncomeFactor(kind)
        m *= phaseFactor(kind)
        return m
    }

    /// 야간형은 저녁에 강하고 아침에 약하다
    func phaseFactor(_ kind: BusinessKind) -> Double {
        guard kind.info.trait == .night else { return 1 }
        switch dayFraction {
        case ..<0.4: return 0.6
        case ..<0.65: return 1.0
        default: return 1.7
        }
    }

    func improvementFactor(_ s: Store) -> Double {
        1 + s.improvements.compactMap { Improvement.find($0)?.incomeBoost }.reduce(0, +)
    }

    func income(_ s: Store) -> Double {
        baseIncome(kind: s.kind, level: s.level, staff: s.staff, district: s.district)
            * improvementFactor(s)
            * modifier(kind: s.kind, district: s.district, delivery: s.has("delivery"))
    }

    var incomePerSec: Double { stores.reduce(0) { $0 + income($1) } }

    // MARK: - 고정비

    func rent(_ s: Store) -> Double {
        ownsBuilding(in: s.district) ? 0 : s.kind.info.rent * s.district.info.rentMult * (1 - costCut)
    }

    func wages(_ s: Store) -> Double {
        let kiosk = s.has("kiosk") ? 1 - (Improvement.find("kiosk")?.wageCut ?? 0) : 1
        return Double(s.staff) * s.kind.info.wage * kiosk * (1 - costCut)
    }

    func dailyNet(_ s: Store) -> Double {
        income(s) * Economy.dayLength - rent(s) - wages(s)
    }

    var dailyInterest: Double { debt * loanRate }

    var dailyStoreCosts: Double { stores.reduce(0) { $0 + rent($1) + wages($1) } }

    var dailyBuildingIncome: Double { buildings.reduce(0) { $0 + buildingRent($1) } }

    var projectedDailyNet: Double {
        incomePerSec * Economy.dayLength + dailyBuildingIncome - dailyStoreCosts - dailyInterest - dailySalaries
    }

    /// 보상·결정 이벤트 금액의 기준이 되는 하루 매출 규모
    var dailyScale: Double { max(30_000, incomePerSec * Economy.dayLength) }

    // MARK: - 가치 평가

    static func upgradeCost(kind: BusinessKind, from level: Int, count n: Int) -> Double {
        guard n > 0 else { return 0 }
        let r = Economy.levelGrowth
        let first = kind.info.baseUpgrade * pow(r, Double(level - 1))
        return first * (pow(r, Double(n)) - 1) / (r - 1)
    }

    static func cumulativeUpgrade(kind: BusinessKind, to level: Int) -> Double {
        upgradeCost(kind: kind, from: 1, count: level - 1)
    }

    /// 시세 반영 적정가 — 매물 가격과 매각 제안의 기준
    func fairValue(kind: BusinessKind, level: Int, staff: Int, district: DistrictID) -> Double {
        let fundamentals = kind.info.openCost * 0.6
            + Game.cumulativeUpgrade(kind: kind, to: level) * 0.45
            + Double(staff) * kind.info.wage * Economy.hireCostDays * 0.5
            + baseIncome(kind: kind, level: level, staff: staff, district: district) * 600
        return fundamentals * index(district)
    }

    func valuation(_ s: Store) -> Double {
        let improvements = s.improvements.compactMap { Improvement.find($0)?.cost(for: s.kind) }.reduce(0, +)
        return fairValue(kind: s.kind, level: s.level, staff: s.staff, district: s.district)
            * improvementFactor(s)
            + improvements * 0.5 * index(s.district)
    }

    static func spec(_ id: String) -> BuildingSpec? {
        for d in DistrictID.allCases {
            if let s = d.buildings.first(where: { $0.id == id }) { return s }
        }
        return nil
    }

    func buildingPrice(_ spec: BuildingSpec) -> Double {
        spec.district.info.buildingBase * spec.factor * index(spec.district)
    }

    func buildingValue(_ b: OwnedBuilding) -> Double {
        guard let spec = Game.spec(b.id) else { return 0 }
        return buildingPrice(spec)
    }

    func buildingRent(_ b: OwnedBuilding) -> Double {
        buildingValue(b) * Economy.buildingDailyYield * buildingRentFactor
    }

    func owns(_ spec: BuildingSpec) -> Bool { buildings.contains { $0.id == spec.id } }

    var storesValue: Double { stores.reduce(0) { $0 + valuation($1) } }
    var buildingsValue: Double { buildings.reduce(0) { $0 + buildingValue($1) } }
    var netWorth: Double { cash + storesValue + buildingsValue - debt }

    // MARK: - 계산대 (탭)

    var tapValue: Double {
        (Economy.tapBase * pow(Economy.tapGrowth, Double(tapLevel - 1))
            + incomePerSec * Economy.tapIncomeShare) * tapFactor
    }

    var counterUpgradeCost: Double {
        Economy.tapUpgradeBase * pow(Economy.tapUpgradeGrowth, Double(tapLevel - 1))
    }

    @discardableResult
    func tap() -> Double {
        let v = tapValue
        cash += v
        today.revenue += v
        stats.taps += 1
        progress.taps += 1
        stats.tapEarnings += v
        stats.totalRevenue += v
        return v
    }

    var counterMaxed: Bool { tapLevel >= Counter.names.count }

    func upgradeCounter() {
        let cost = counterUpgradeCost
        guard !counterMaxed, cash >= cost else { return }
        cash -= cost
        tapLevel += 1
        toast = "새 계산대 들였어요 · \(Counter.name(level: tapLevel))"
    }

    // MARK: - 레벨업

    func upgradePlan(_ s: Store) -> (count: Int, cost: Double) {
        let room = Economy.maxLevel - s.level
        guard room > 0 else { return (0, 0) }
        switch bulk {
        case .one:
            return (1, Game.upgradeCost(kind: s.kind, from: s.level, count: 1))
        case .ten:
            let n = min(10, room)
            return (n, Game.upgradeCost(kind: s.kind, from: s.level, count: n))
        case .max:
            let r = Economy.levelGrowth
            let first = s.kind.info.baseUpgrade * pow(r, Double(s.level - 1))
            var raw = log(max(cash, 0) * (r - 1) / first + 1) / log(r)
            if !raw.isFinite { raw = 1 }
            var n = min(max(Int(raw.rounded(.down)), 1), room)
            while n > 1 && Game.upgradeCost(kind: s.kind, from: s.level, count: n) > cash { n -= 1 }
            return (n, Game.upgradeCost(kind: s.kind, from: s.level, count: n))
        }
    }

    @discardableResult
    func upgrade(_ id: UUID) -> Bool {
        guard let i = stores.firstIndex(where: { $0.id == id }) else { return false }
        let plan = upgradePlan(stores[i])
        guard plan.count > 0, cash >= plan.cost else { return false }
        let before = stores[i].level
        cash -= plan.cost
        stores[i].level += plan.count
        stores[i].invested += plan.cost
        progress.levels += plan.count
        let after = stores[i].level
        if let m = Economy.milestones.last(where: { $0 > before && $0 <= after }) {
            toast = "\(stores[i].displayName) Lv.\(m) 달성 · 매출 2배"
        }
        return true
    }

    // MARK: - 직원

    func hireCost(_ s: Store) -> Double { s.kind.info.wage * Economy.hireCostDays }

    func hire(_ id: UUID) {
        guard let i = stores.firstIndex(where: { $0.id == id }) else { return }
        let s = stores[i]
        let cost = hireCost(s)
        guard s.staff < s.kind.info.maxStaff, cash >= cost else { return }
        cash -= cost
        stores[i].staff += 1
        stores[i].invested += cost
        progress.hires += 1
    }

    func fire(_ id: UUID) {
        guard let i = stores.firstIndex(where: { $0.id == id }), stores[i].staff > 0 else { return }
        stores[i].staff -= 1
    }

    // MARK: - 개업

    func openCost(_ k: BusinessKind, in d: DistrictID) -> Double { k.info.openCost * index(d) }

    func openBlocker(_ k: BusinessKind, in d: DistrictID) -> String? {
        if !isUnlocked(d) { return "지역 잠김" }
        if !isUnlocked(k) { return "업종 잠김" }
        if freeSlots(in: d) <= 0 { return "자리 없음" }
        if k == .holdings && stores.contains(where: { $0.kind == .holdings }) { return "이미 설립함" }
        if cash < openCost(k, in: d) { return "잔고 부족" }
        return nil
    }

    @discardableResult
    func openStore(_ k: BusinessKind, in d: DistrictID) -> Bool {
        guard openBlocker(k, in: d) == nil else { return false }
        let cost = openCost(k, in: d)
        cash -= cost
        let s = Store(kind: k, district: d, name: makeName(k), invested: cost, openedDay: day)
        stores.append(s)
        stats.storesOpened += 1
        progress.opens += 1
        noteKind(k)
        record(.open, "\(s.displayName) 개업", -cost)
        toast = "\(s.displayName) 문을 열었어요"
        return true
    }

    private func makeName(_ k: BusinessKind) -> String {
        if k == .holdings { return companyName + "홀딩스" }
        let used = Set(stores.map(\.name))
        return k.namePool.first { !used.contains($0) } ?? k.namePool.randomElement() ?? k.info.title
    }

    // MARK: - 점포 매매

    func offers(for s: Store) -> [SaleOffer] {
        let buyers: [(String, String)] = [
            ("개인 투자자", "현금 일시불, 바로 잔금"),
            ("옆 가게 사장님", "확장 이전 희망"),
            ("체인 본사 개발팀", "직영점 전환 목적"),
            ("부동산 펀드", "수익률만 봅니다"),
            ("은퇴 준비 부부", "대출 끼고 매수"),
            ("사모펀드", "볼트온 인수 검토 중"),
            ("젊은 창업자", "첫 가게로 생각 중")
        ]
        let v = valuation(s)
        return buyers.shuffled().prefix(3).map { b in
            SaleOffer(buyer: b.0, note: b.1, price: v * Double.random(in: 0.82...1.12))
        }
        .sorted { $0.price > $1.price }
    }

    @discardableResult
    func sell(_ id: UUID, offer: SaleOffer) -> Bool {
        guard let i = stores.firstIndex(where: { $0.id == id }) else { return false }
        let s = stores[i]
        let proceeds = offer.price * (1 - tradeFee)
        cash += proceeds
        stats.trades += 1
        stats.sells += 1
        progress.trades += 1
        stats.tradeProfit += proceeds - s.invested
        stores.remove(at: i)
        record(.sell, "\(s.displayName) 매각 · \(offer.buyer)", proceeds)
        toast = "\(s.displayName) 매각 완료 · \(Won.full(proceeds))"
        return true
    }

    func buyBlocker(_ l: Listing) -> String? {
        if !isUnlocked(l.district) || !isUnlocked(l.kind) { return "잠김" }
        if freeSlots(in: l.district) <= 0 { return "\(l.district.info.short) 자리 없음" }
        if cash < l.price { return "잔고 부족" }
        return nil
    }

    @discardableResult
    func buy(_ l: Listing) -> Bool {
        guard listings.contains(where: { $0.id == l.id }), buyBlocker(l) == nil else { return false }
        cash -= l.price
        let s = Store(kind: l.kind, district: l.district, name: l.name,
                      level: l.level, staff: l.staff, invested: l.price, openedDay: day)
        stores.append(s)
        listings.removeAll { $0.id == l.id }
        stats.trades += 1
        progress.trades += 1
        noteKind(l.kind)
        record(.buy, "\(s.displayName) 인수", -l.price)
        toast = "\(s.displayName) 인수 완료"
        return true
    }

    // MARK: - 건물 매매

    @discardableResult
    func buyBuilding(_ spec: BuildingSpec) -> Bool {
        let price = buildingPrice(spec)
        guard !owns(spec), isUnlocked(spec.district), cash >= price else { return false }
        cash -= price
        buildings.append(OwnedBuilding(id: spec.id, district: spec.district, purchasePrice: price, boughtDay: day))
        stats.trades += 1
        progress.trades += 1
        record(.buy, "\(spec.district.info.short) \(spec.name) 매입", -price)
        toast = "\(spec.name) 등기 완료. 이 지역 내 점포는 임대료 0원"
        return true
    }

    @discardableResult
    func sellBuilding(_ spec: BuildingSpec) -> Bool {
        guard let i = buildings.firstIndex(where: { $0.id == spec.id }) else { return false }
        let proceeds = buildingPrice(spec) * (1 - tradeFee)
        stats.trades += 1
        progress.trades += 1
        stats.tradeProfit += proceeds - buildings[i].purchasePrice
        buildings.remove(at: i)
        cash += proceeds
        record(.sell, "\(spec.district.info.short) \(spec.name) 매도", proceeds)
        toast = "\(spec.name) 매도 · \(Won.full(proceeds))"
        return true
    }

    // MARK: - 대출

    var loanAvailable: Double { max(0, max(0, netWorth) * loanLimitRatio - debt) }

    func borrow(_ amount: Double) {
        let a = min(amount, loanAvailable)
        guard a >= 1 else { return }
        debt += a
        cash += a
        record(.loan, "은행 대출 실행", a)
    }

    func repay(_ amount: Double) {
        let a = min(amount, debt, max(0, cash))
        guard a >= 1 else { return }
        debt -= a
        cash -= a
        if debt < 1 { debt = 0 }
        record(.repay, "대출 상환", -a)
    }

    // MARK: - 시간

    func tick(_ dt: Double) {
        guard started else { return }
        let earned = incomePerSec * dt
        cash += earned
        today.revenue += earned
        stats.totalRevenue += earned

        dayClock += dt
        if dayClock >= Economy.dayLength {
            dayClock -= Economy.dayLength
            endDay()
        }

        checkRank()

        sinceSave += dt
        if sinceSave >= 15 {
            sinceSave = 0
            save()
        }
    }

    private func checkRank() {
        let worth = netWorth
        if worth > stats.peakNetWorth { stats.peakNetWorth = worth }
        let r = Rank.forNetWorth(worth)
        if r.id > highestRank {
            highestRank = r.id
            pendingRankUp = r
            refreshListings()
            save()
        }
    }

    private func endDay() {
        let totalRent = stores.reduce(0) { $0 + self.rent($1) }
        let totalWages = stores.reduce(0) { $0 + self.wages($1) }
        let bIncome = dailyBuildingIncome
        let interest = dailyInterest
        let salaries = dailySalaries
        let fixed = bIncome - totalRent - totalWages - interest - salaries
        cash += fixed

        today.rent = totalRent
        today.wages = totalWages + salaries
        today.interest = interest
        today.buildingIncome = bIncome
        history.append(today)
        if history.count > 30 { history.removeFirst(history.count - 30) }
        stats.bestDailyNet = max(stats.bestDailyNet, today.net)
        if abs(fixed) >= 1 {
            record(.settle, "\(day)일차 마감 · 임대료·인건비·이자", fixed)
        }

        day += 1
        today = DayReport(day: day)

        advanceMarkets()
        for i in events.indices { events[i].daysLeft -= 1 }
        events.removeAll { $0.daysLeft <= 0 }
        rollNews()
        refreshListings()
        startNewDay()

        if cash < 0 {
            toast = "잔고가 마이너스예요. 직원이나 대출을 정리해 보세요."
        }
    }

    private func advanceMarkets() {
        for i in markets.indices {
            var m = markets[i]
            let drift = 0.002 - 0.05 * log(m.index)
            m.index = min(2.4, max(0.5, m.index * exp(drift + 0.035 * Game.gaussian())))
            m.history.append(m.index)
            if m.history.count > 30 { m.history.removeFirst(m.history.count - 30) }
            markets[i] = m
        }
    }

    private func rollNews() {
        let ds = DistrictID.allCases.filter { isUnlocked($0) }
        let ks = BusinessKind.allCases.filter { isUnlocked($0) }
        switch NewsDesk.roll(day: day, districts: ds, kinds: ks) {
        case .lasting(let event, let item):
            events.append(event)
            pushNews(item)
        case .indexShock(let d, let pct, let item):
            if let i = markets.firstIndex(where: { $0.id == d }) {
                let v = min(2.4, max(0.5, markets[i].index * (1 + pct)))
                markets[i].index = v
                let last = markets[i].history.count - 1
                if last >= 0 { markets[i].history[last] = v }
            }
            pushNews(item)
        case nil:
            break
        }
    }

    private func pushNews(_ n: NewsItem) {
        news.insert(n, at: 0)
        if news.count > 20 { news.removeLast(news.count - 20) }
    }

    func refreshListings() {
        listings.removeAll { $0.expiresDay < day }
        var attempts = 0
        while listings.count < listingsPerDay && attempts < 30 {
            attempts += 1
            if let l = makeListing() { listings.append(l) }
        }
    }

    private func makeListing() -> Listing? {
        let kinds = BusinessKind.allCases.filter { isUnlocked($0) && $0 != .holdings }
        let districts = DistrictID.allCases.filter { isUnlocked($0) }
        guard !kinds.isEmpty, let d = districts.randomElement() else { return nil }

        // 높은 업종일수록 자주 나오게
        let weights = kinds.map { pow(2.5, Double($0.info.tier)) }
        var roll = Double.random(in: 0..<weights.reduce(0, +))
        var kind = kinds[kinds.count - 1]
        for (k, w) in zip(kinds, weights) {
            if roll < w { kind = k; break }
            roll -= w
        }

        let maxLevel = min(Economy.maxLevel - 1, 12 + highestRank * 6)
        let level = Int.random(in: 3...maxLevel)
        let staff = Int.random(in: 0...kind.info.maxStaff)
        let fair = fairValue(kind: kind, level: level, staff: staff, district: d)
        let mult = Double.random(in: 0.72...1.25)
        let story: String
        if mult < 0.88 { story = SellerStory.bargain.randomElement()! }
        else if mult > 1.12 { story = SellerStory.premium.randomElement()! }
        else { story = SellerStory.normal.randomElement()! }

        return Listing(kind: kind, district: d, name: kind.namePool.randomElement() ?? kind.info.title,
                       level: level, staff: staff, price: fair * mult,
                       postedDay: day, expiresDay: day + Int.random(in: 2...4), story: story)
    }

    static func gaussian() -> Double {
        let u1 = Double.random(in: Double.ulpOfOne..<1)
        let u2 = Double.random(in: 0..<1)
        return sqrt(-2 * log(u1)) * cos(2 * Double.pi * u2)
    }

    func record(_ kind: LedgerEntry.Kind, _ title: String, _ amount: Double) {
        ledger.insert(LedgerEntry(day: day, kind: kind, title: title, amount: amount), at: 0)
        if ledger.count > 80 { ledger.removeLast(ledger.count - 80) }
    }

    // MARK: - 시작 · 초기화

    func begin(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        companyName = trimmed.isEmpty ? "한평상회" : String(trimmed.prefix(10))
        started = true
        cash = Economy.startingCash
        stores = [Store(kind: .cornerShop, district: .alley, name: companyName,
                        invested: BusinessKind.cornerShop.info.openCost, openedDay: 1)]
        news = [NewsItem(day: 1, headline: "\(companyName), 다시 문을 열다",
                         detail: "할머니의 구멍가게가 새 주인을 맞았다", tone: .neutral)]
        stats.kindsOwned = [BusinessKind.cornerShop.rawValue]
        reputation = 50
        weather = .sunny
        refreshListings()
        generateMissions()
        lastActive = Date()
        save()
    }

    func reset() {
        stopLoop()
        try? FileManager.default.removeItem(at: Game.saveURL)
        apply(Game.blank())
        pendingRankUp = nil
        offlineReport = nil
        decisionResult = nil
        toast = nil
        startLoop()
    }

    // MARK: - 앱 생명주기

    func becameActive() {
        applyOffline()
        startLoop()
    }

    func wentBackground() {
        stopLoop()
        save()
    }

    private func applyOffline() {
        let now = Date()
        let elapsed = min(now.timeIntervalSince(lastActive), Economy.offlineCap)
        lastActive = now
        guard started, elapsed > 60 else { return }
        let perSec = incomePerSec + (dailyBuildingIncome - dailyStoreCosts - dailyInterest - dailySalaries) / Economy.dayLength
        let earned = max(0, perSec) * elapsed * offlineRate
        guard earned >= 1 else { return }
        cash += earned
        stats.totalRevenue += earned
        offlineReport = OfflineReport(seconds: elapsed, earned: earned)
    }

    private func startLoop() {
        guard loop == nil else { return }
        loop = Task { @MainActor [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let now = Date()
                let dt = min(now.timeIntervalSince(last), 1)
                last = now
                self?.tick(dt)
            }
        }
    }

    private func stopLoop() {
        loop?.cancel()
        loop = nil
    }

    // MARK: - 저장

    private static var saveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hanpyeong-save.json")
    }

    func save() {
        guard started else { return }
        lastActive = Date()
        do {
            let data = try JSONEncoder().encode(snapshot())
            try data.write(to: Game.saveURL, options: .atomic)
        } catch {
            print("저장 실패:", error)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Game.saveURL),
              let s = try? JSONDecoder().decode(SaveData.self, from: data) else { return }
        apply(s)
    }

    private func snapshot() -> SaveData {
        SaveData(companyName: companyName, started: started, cash: cash, debt: debt, day: day,
                 dayClock: dayClock, tapLevel: tapLevel, stores: stores, buildings: buildings,
                 markets: markets, listings: listings, events: events, news: news, history: history,
                 today: today, ledger: ledger, stats: stats, highestRank: highestRank,
                 lastActive: lastActive, hapticsOn: hapticsOn,
                 reputation: reputation, weather: weather, talents: talents,
                 pendingDecision: pendingDecision, missions: missions, progress: progress,
                 claimedAchievements: claimedAchievements)
    }

    private func apply(_ s: SaveData) {
        companyName = s.companyName
        started = s.started
        cash = s.cash
        debt = s.debt
        day = s.day
        dayClock = s.dayClock
        tapLevel = s.tapLevel
        stores = s.stores
        buildings = s.buildings
        markets = DistrictID.allCases.map { id in s.markets.first { $0.id == id } ?? DistrictMarket(id: id) }
        listings = s.listings
        events = s.events
        news = s.news
        history = s.history
        today = s.today
        ledger = s.ledger
        stats = s.stats
        highestRank = s.highestRank
        lastActive = s.lastActive
        hapticsOn = s.hapticsOn
        reputation = s.reputation ?? 50
        weather = s.weather ?? .sunny
        talents = s.talents ?? []
        pendingDecision = s.pendingDecision
        missions = s.missions ?? []
        progress = s.progress ?? DailyProgress()
        claimedAchievements = s.claimedAchievements ?? []
        if stats.kindsOwned.isEmpty { stats.kindsOwned = Array(Set(stores.map(\.kind.rawValue))) }
        if started && missions.isEmpty { generateMissions() }
    }

    private static func blank() -> SaveData {
        SaveData(companyName: "한평상회", started: false, cash: Economy.startingCash, debt: 0, day: 1,
                 dayClock: 0, tapLevel: 1, stores: [], buildings: [],
                 markets: DistrictID.allCases.map { DistrictMarket(id: $0) },
                 listings: [], events: [], news: [], history: [], today: DayReport(day: 1),
                 ledger: [], stats: Stats(), highestRank: 0, lastActive: Date(), hapticsOn: true)
    }
}
