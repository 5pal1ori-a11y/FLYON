import SwiftUI
import UserNotifications

@MainActor
final class Store: ObservableObject {
    @Published var subs: [Subscription] = [] { didSet { save(); scheduleAll(); recordMonth() } }
    @AppStorage("userName") var userName = ""
    @AppStorage("budget") var budget = 0
    @AppStorage("saveGoal") var saveGoal = 0
    @AppStorage("notifyDaysBefore") var notifyDays = 1
    @AppStorage("notifyHour") var notifyHour = 9
    @AppStorage("notifyOn") var notifyOn = true
    @AppStorage("faceLock") var faceLock = false
    @AppStorage("monthHistory") private var historyRaw = "{}"

    private var url: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("subs.json") }

    init() {
        if let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode([Subscription].self, from: d) { subs = v }
        rollForward()
        recordMonth()
        scheduleAll()
        Task { await refreshFX() }
    }

    // MARK: 월별 기록
    private static func key(_ d: Date) -> String { let c = Calendar.current.dateComponents([.year, .month], from: d); return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0) }
    var history: [String: Int] {
        guard let d = historyRaw.data(using: .utf8), let h = try? JSONDecoder().decode([String: Int].self, from: d) else { return [:] }
        return h
    }
    func recordMonth() {
        var h = history
        h[Store.key(Date())] = Int(monthlyTotal.rounded())
        if let d = try? JSONEncoder().encode(h), let s = String(data: d, encoding: .utf8), s != historyRaw { historyRaw = s }
    }
    /// 지난달 기록이 있으면 그 값
    var prevMonthTotal: Int? {
        guard let p = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return nil }
        return history[Store.key(p)]
    }
    var monthDelta: Int? { prevMonthTotal.map { Int(monthlyTotal.rounded()) - $0 } }

    // MARK: 사용 체크 / 환율
    func markUsed(_ s: Subscription) {
        guard let i = subs.firstIndex(where: { $0.id == s.id }) else { return }
        var u = subs[i].usage ?? []
        u.append(Date())
        subs[i].usage = u
    }
    func refreshFX() async {
        guard subs.contains(where: { $0.currency != nil }) else { return }
        await FX.refresh()
        for i in subs.indices { if let c = subs[i].currency, let a = subs[i].foreignAmount { subs[i].price = FX.toKRW(a, c) } }
    }
    private func save() { try? JSONEncoder().encode(subs).write(to: url, options: .atomic) }

    /// 결제일이 지난 구독은 다음 결제일로 자동 이동
    func rollForward() {
        var changed = false
        for i in subs.indices where subs[i].isActive {
            while subs[i].nextDate < Calendar.current.startOfDay(for: Date()) {
                subs[i].nextDate = subs[i].cycle.next(after: subs[i].nextDate)
                subs[i].payCount += 1; changed = true
            }
        }
        _ = changed
    }

    func add(_ s: Subscription) {
        var n = s; n.history = [PricePoint(date: Date(), price: s.price)]
        subs.append(n)
    }
    func update(_ s: Subscription) {
        guard let i = subs.firstIndex(where: { $0.id == s.id }) else { return }
        var n = s
        if subs[i].price != s.price { n.history = subs[i].history + [PricePoint(date: Date(), price: s.price)] }
        subs[i] = n
    }
    func delete(_ s: Subscription) { subs.removeAll { $0.id == s.id } }

    // MARK: 집계
    var active: [Subscription] { subs.filter(\.isActive) }
    var monthlyTotal: Double { active.reduce(0) { $0 + $1.monthly } }
    var yearlyTotal: Double { monthlyTotal * 12 }
    var weeklyTotal: Double { monthlyTotal * 12 / 52 }
    var upcoming: [Subscription] { active.sorted { $0.nextDate < $1.nextDate } }
    var remainingThisMonth: Int {
        let c = Calendar.current
        return active.filter { c.isDate($0.nextDate, equalTo: Date(), toGranularity: .month) }.reduce(0) { $0 + $1.price }
    }
    func byCategory() -> [(Category, Double)] {
        Dictionary(grouping: active, by: \.category).map { ($0.key, $0.value.reduce(0) { $0 + $1.monthly }) }.sorted { $0.1 > $1.1 }
    }
    var top3: [Subscription] { Array(active.sorted { $0.monthly > $1.monthly }.prefix(3)) }

    // MARK: 인사이트 (기기 안에서 계산해요)
    struct Insight: Identifiable { let id = UUID(); let icon: String; let text: String; let save: Int }
    var insights: [Insight] {
        var r: [Insight] = []
        for (cat, list) in Dictionary(grouping: active, by: \.category) where list.count >= 2 && (cat == .ott || cat == .ai) {
            let cheapest = list.min { $0.monthly < $1.monthly }!
            let save = Int(list.reduce(0) { $0 + $1.monthly } - cheapest.monthly)
            r.append(Insight(icon: "square.on.square", text: "\(cat.rawValue) \(list.count)개 쓰고 있어요. 하나만 남기면?", save: save))
        }
        for s in active { if let h = s.priceHike { r.append(Insight(icon: "arrow.up.right", text: "\(s.name) \(h.from.won) → \(h.to.won) 올랐어요", save: 0)) } }
        for s in active where s.cycle == .monthly {
            if let y = s.service?.yearlyPrice, s.price * 12 > y {
                r.append(Insight(icon: "calendar", text: "\(s.name) 연 결제로 바꾸면 1년에 \((s.price * 12 - y).won) 아껴요", save: s.price * 12 - y))
            }
        }
        let day = Calendar.current.component(.day, from: Date())
        for s in active where s.usage != nil && s.usesThisMonth == 0 && day >= 10 {
            r.append(Insight(icon: "moon.zzz", text: "\(s.name) 이번 달 한 번도 안 썼어요", save: Int(s.monthly)))
        }
        for s in active { if let t = s.trialEnd, t > Date(), t.timeIntervalSinceNow < 3 * 86400 { r.append(Insight(icon: "clock", text: "\(s.name) 무료 체험이 곧 끝나요", save: s.price)) } }
        return r
    }
    var potentialSave: Int { insights.reduce(0) { $0 + $1.save } }
    var health: Int { // 0~100
        guard budget > 0 else { return 80 }
        return max(0, min(100, Int(100 - max(0, (monthlyTotal / Double(budget) - 0.6)) * 150)))
    }
    var overBudget: Bool { budget > 0 && monthlyTotal > Double(budget) }

    func search(_ q: String) -> [Subscription] {
        let t = q.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return subs }
        // 자연어: "넷플릭스 얼마", "ai 구독" 등 → 키워드/카테고리 매칭
        let low = t.lowercased()
        let cats = Category.allCases.filter { low.contains($0.rawValue.lowercased()) }
        return subs.filter { s in
            low.contains(s.name.lowercased()) || s.name.lowercased().contains(low) || cats.contains(s.category) || (Catalog.find(low)?.name == s.service?.name && s.service != nil)
        }
    }

    // MARK: CSV
    func csv() -> URL {
        var out = "서비스,카테고리,금액,주기,다음결제일,상태\n"
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        for s in subs { out += "\(s.name),\(s.category.rawValue),\(s.price),\(s.cycle.rawValue),\(f.string(from: s.nextDate)),\(s.status.rawValue)\n" }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("구독온.csv")
        try? ("\u{FEFF}" + out).write(to: u, atomically: true, encoding: .utf8)
        return u
    }
    func reset() { subs = [] }

    // MARK: 알림
    func requestNotify() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in } }
    func scheduleAll() {
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()
        guard notifyOn else { return }
        let weekly = UNMutableNotificationContent()
        weekly.title = "구독온"; weekly.body = "이번 주에 쓴 구독을 체크해볼까요?"; weekly.sound = .default
        c.add(UNNotificationRequest(identifier: "weekly-use", content: weekly, trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 20, weekday: 1), repeats: true)))
        for s in active {
            func add(_ date: Date, _ body: String, _ id: String) {
                guard date > Date() else { return }
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
                comps.hour = notifyHour
                let content = UNMutableNotificationContent()
                content.title = s.name; content.body = body; content.sound = .default
                c.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
            let before = Calendar.current.date(byAdding: .day, value: -notifyDays, to: s.nextDate)!
            add(before, "\(notifyDays)일 뒤 \(s.price.won) 결제돼요", "\(s.id)-b")
            add(s.nextDate, "오늘 \(s.price.won) 결제돼요", "\(s.id)-d")
            if let t = s.trialEnd { add(Calendar.current.date(byAdding: .day, value: -1, to: t)!, "무료 체험이 내일 끝나요", "\(s.id)-t") }
        }
    }

    /// 알림이 실제로 오는지 5초 뒤 테스트
    func sendTestNotification() {
        let c = UNMutableNotificationContent(); c.title = "구독온"; c.body = "알림이 잘 와요 🎉"; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test-\(UUID())", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
