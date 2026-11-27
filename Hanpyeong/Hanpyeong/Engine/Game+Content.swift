import Foundation

// 인재 · 시설 투자 · 결정 이벤트 · 할 일 · 업적 · 재계 순위

extension Game {

    // MARK: - 인재 효과

    var hiredTalents: [Talent] { talents.compactMap { Talent.find($0) } }

    func hasTalent(_ id: String) -> Bool { talents.contains(id) }

    func talentIncomeFactor(_ kind: BusinessKind) -> Double {
        var m = 1.0
        for t in hiredTalents {
            switch t.effect {
            case .kinds(let ks, let x): if ks.contains(kind) { m *= x }
            case .allIncome(let x): m *= x
            case .influencer: m *= 1.1
            default: break
            }
        }
        return m
    }

    var tapFactor: Double {
        var m = 1.0
        for t in hiredTalents { if case .tap(let x) = t.effect { m *= x } }
        return m
    }

    var costCut: Double {
        var c = 0.0
        for t in hiredTalents { if case .costCut(let x) = t.effect { c += x } }
        return min(c, 0.8)
    }

    var tradeFee: Double { hasTalent("malsun") ? 0.02 : Economy.tradeFee }
    var listingsPerDay: Int { Economy.listingsPerDay + (hasTalent("malsun") ? 3 : 0) }
    var loanRate: Double { hasTalent("banker") ? Economy.loanDailyRate / 2 : Economy.loanDailyRate }
    var loanLimitRatio: Double { hasTalent("banker") ? 0.7 : Economy.loanLimitRatio }

    var offlineRate: Double {
        var r = Economy.offlineRate
        for t in hiredTalents { if case .offline(let x) = t.effect { r = max(r, x) } }
        return r
    }

    var buildingRentFactor: Double {
        var m = 1.0
        for t in hiredTalents { if case .buildingRent(let x) = t.effect { m *= x } }
        return m
    }

    var dailySalaries: Double { hiredTalents.reduce(0) { $0 + $1.salary } }

    func talentBlocker(_ t: Talent) -> String? {
        if hasTalent(t.id) { return "영입함" }
        if t.unlockRank > highestRank { return "\(Rank.all[t.unlockRank].title) 이후" }
        if cash < t.cost { return "잔고 부족" }
        return nil
    }

    func recruit(_ t: Talent) {
        guard talentBlocker(t) == nil else { return }
        cash -= t.cost
        talents.append(t.id)
        record(.hire, "\(t.role) \(t.name) 영입", -t.cost)
        toast = "\(t.name) 님이 합류했어요"
    }

    func noteKind(_ k: BusinessKind) {
        if !stats.kindsOwned.contains(k.rawValue) { stats.kindsOwned.append(k.rawValue) }
    }

    // MARK: - 시설 투자

    func improvementBlocker(_ imp: Improvement, for s: Store) -> String? {
        if s.has(imp.id) { return "완료" }
        if !imp.applies(to: s.kind) { return "해당 없음" }
        if s.level < imp.minLevel { return "Lv.\(imp.minLevel) 필요" }
        if cash < imp.cost(for: s.kind) { return "잔고 부족" }
        return nil
    }

    func buyImprovement(_ imp: Improvement, for id: UUID) {
        guard let i = stores.firstIndex(where: { $0.id == id }),
              improvementBlocker(imp, for: stores[i]) == nil else { return }
        let cost = imp.cost(for: stores[i].kind)
        cash -= cost
        stores[i].improvements.append(imp.id)
        stores[i].invested += cost
        adjustReputation(imp.reputation)
        stats.improvementsBought += 1
        progress.improvements += 1
        toast = "\(stores[i].displayName) · \(imp.title) 완료"
    }

    // MARK: - 평판

    func adjustReputation(_ delta: Double) {
        reputation = min(100, max(0, reputation + delta))
    }

    // MARK: - 하루 시작 (마감 직후)

    func startNewDay() {
        weather = Weather.roll(for: season)

        // 평판은 천천히 50으로 돌아간다. 인플루언서가 있으면 매일 +1
        if reputation > 50 { adjustReputation(-0.4) } else if reputation < 50 { adjustReputation(0.4) }
        if hasTalent("yujin") { adjustReputation(1) }

        // 못 받은 할 일 보상은 마감 때 자동 정산
        for i in missions.indices where !missions[i].claimed && missionDone(missions[i]) {
            cash += missions[i].reward
            missions[i].claimed = true
            stats.missionsDone += 1
        }
        progress = DailyProgress()
        generateMissions()

        if pendingDecision == nil && Double.random(in: 0..<1) < 0.35 {
            spawnDecision()
        }
    }

    // MARK: - 결정 이벤트

    var currentDecision: Decision? { pendingDecision.flatMap { Decision.find($0.id) } }

    func spawnDecision() {
        let pool = Decision.all.filter { highestRank >= $0.minRank && highestRank <= $0.maxRank }
        guard let d = pool.randomElement() else { return }
        pendingDecision = PendingDecision(id: d.id, scale: dailyScale, day: day)
    }

    func cashAmount(_ multiple: Double) -> Double {
        (pendingDecision?.scale ?? dailyScale) * multiple
    }

    func describe(_ effects: [DecisionEffect], scale: Double) -> [String] {
        effects.map { e in
            switch e {
            case .cash(let x): return "현금 \(Won.signed(x * scale))"
            case .reputation(let x): return "평판 \(x >= 0 ? "+" : "")\(Int(x))"
            case .boost(let x, let days, _): return "\(days)일간 매출 \(Won.percent(x - 1))"
            }
        }
    }

    func resolve(_ option: DecisionOption) {
        guard let pending = pendingDecision, let decision = Decision.find(pending.id) else { return }
        let success = Double.random(in: 0..<1) < option.chance
        let effects = success ? option.success : option.failure
        for e in effects {
            switch e {
            case .cash(let x):
                cash += x * pending.scale
            case .reputation(let x):
                adjustReputation(x)
            case .boost(let x, let days, let label):
                events.append(MarketEvent(effect: .economy(x), daysLeft: days, headline: label))
            }
        }
        stats.decisionsMade += 1
        pendingDecision = nil
        decisionResult = DecisionResult(
            title: decision.title,
            text: success ? option.successText : option.failureText,
            good: success && (option.chance < 1 || !Game.isNegative(effects)),
            lines: describe(effects, scale: pending.scale)
        )
    }

    static func isNegative(_ effects: [DecisionEffect]) -> Bool {
        for e in effects {
            switch e {
            case .cash(let x): if x < 0 { return true }
            case .reputation(let x): if x < 0 { return true }
            case .boost(let x, _, _): if x < 1 { return true }
            }
        }
        return false
    }

    // MARK: - 오늘의 할 일

    func generateMissions() {
        let scale = dailyScale
        var kinds: [MissionKind] = [.taps, .revenue, .levels]
        var optional: [MissionKind] = [.trade, .improve]
        if stores.contains(where: { $0.staff < $0.kind.info.maxStaff }) { optional.append(.hire) }
        if DistrictID.allCases.contains(where: { isUnlocked($0) && freeSlots(in: $0) > 0 }) { optional.append(.open) }
        kinds.shuffle()
        var picked = Array(kinds.prefix(2))
        if let extra = optional.randomElement() { picked.append(extra) }

        missions = picked.map { k in
            let target: Double
            switch k {
            case .taps:    target = Double([60, 100, 150, 200].randomElement()! + highestRank * 20)
            case .revenue: target = (scale * Double.random(in: 0.7...1.0) / 1000).rounded() * 1000
            case .levels:  target = Double(Int.random(in: 4...8) + highestRank * 2)
            case .hire:    target = Double(Int.random(in: 1...2))
            case .trade:   target = 1
            case .open:    target = 1
            case .improve: target = 1
            }
            return Mission(kind: k, target: max(1, target), reward: (scale * Double.random(in: 0.3...0.6) / 100).rounded() * 100)
        }
    }

    func missionValue(_ m: Mission) -> Double {
        switch m.kind {
        case .taps:    return Double(progress.taps)
        case .revenue: return today.revenue
        case .levels:  return Double(progress.levels)
        case .hire:    return Double(progress.hires)
        case .trade:   return Double(progress.trades)
        case .open:    return Double(progress.opens)
        case .improve: return Double(progress.improvements)
        }
    }

    func missionDone(_ m: Mission) -> Bool { missionValue(m) >= m.target }

    func claim(_ m: Mission) {
        guard let i = missions.firstIndex(where: { $0.id == m.id }),
              !missions[i].claimed, missionDone(missions[i]) else { return }
        missions[i].claimed = true
        cash += missions[i].reward
        stats.missionsDone += 1
        toast = "할 일 완료 · \(Won.signed(missions[i].reward))"
    }

    // MARK: - 업적

    func achievementReward(_ a: Achievement) -> Double { max(a.floor, dailyScale * a.days) }

    func isAchieved(_ a: Achievement) -> Bool { a.current(self) >= a.target }

    func isClaimed(_ a: Achievement) -> Bool { claimedAchievements.contains(a.id) }

    var claimableCount: Int {
        let ach = Achievement.all.filter { !isClaimed($0) && isAchieved($0) }.count
        let mis = missions.filter { !$0.claimed && missionDone($0) }.count
        return ach + mis
    }

    func claim(_ a: Achievement) {
        guard !isClaimed(a), isAchieved(a) else { return }
        let reward = achievementReward(a)
        claimedAchievements.append(a.id)
        cash += reward
        record(.settle, "업적 · \(a.title)", reward)
        toast = "업적 달성 · \(a.title)"
    }

    // MARK: - 재계 순위

    struct BoardRow: Identifiable {
        let id: String
        let name: String
        let owner: String
        let worth: Double
        let isPlayer: Bool
    }

    var leaderboard: [BoardRow] {
        var rows = Rival.all.map {
            BoardRow(id: $0.id, name: $0.name, owner: $0.owner, worth: $0.worth(day: day), isPlayer: false)
        }
        rows.append(BoardRow(id: "me", name: highestRank >= 4 ? companyName + "그룹" : companyName,
                             owner: "나", worth: netWorth, isPlayer: true))
        return rows.sorted { $0.worth > $1.worth }
    }

    var leaderboardPosition: Int {
        (leaderboard.firstIndex { $0.isPlayer } ?? 0) + 1
    }
}
