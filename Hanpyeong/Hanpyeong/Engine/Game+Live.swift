import Foundation
import UserNotifications

// 플레이 중 수시로 터지는 재미: VIP 손님, 러시 타임, 출석 보상, 알림

struct VIPVisit: Identifiable, Hashable {
    enum Reward: Hashable {
        case cash(Double)       // 하루 매출 규모 × 배수
        case rush
        case reputation(Double)
    }

    let id = UUID()
    let title: String
    let symbol: String
    let line: String
    let reward: Reward
    let expires: Date
    let x: Double

    static let pool: [(title: String, symbol: String, line: String, reward: Reward, weight: Double)] = [
        ("단골 할머니", "heart.fill", "손주들 줄 거 한 보따리!", .cash(0.25), 5),
        ("회식 단체 손님", "person.3.fill", "여기 스무 명이요!", .cash(0.6), 4),
        ("외국인 관광객", "globe.asia.australia.fill", "Wow, so good!", .cash(0.4), 4),
        ("먹방 유튜버", "video.fill", "구독자 여러분, 여기예요!", .rush, 3),
        ("동네 기자", "newspaper.fill", "기사 한 줄 써드릴게요", .reputation(3), 3),
        ("재벌 3세", "crown.fill", "가게 통째로 결제할게요", .cash(1.2), 1)
    ]
}

struct DailyRewardOffer: Identifiable, Hashable {
    let id = UUID()
    let streak: Int
    /// 0...6 (7일 주기)
    let dayIndex: Int
    let amount: Double

    static let multipliers: [Double] = [0.3, 0.5, 0.7, 1.0, 1.3, 1.6, 3.0]
}

extension Game {

    // MARK: - 러시 타임

    var isRushing: Bool { (rushUntil ?? .distantPast) > Date() }

    var rushRemaining: Double { max(0, (rushUntil ?? .distantPast).timeIntervalSinceNow) }

    func startRush(seconds: Double = 12) {
        rushUntil = Date().addingTimeInterval(seconds)
    }

    // MARK: - 매 틱

    func liveEvents(_ dt: Double) {
        if let v = vip, v.expires < Date() { vip = nil }
        if rushUntil != nil && !isRushing { rushUntil = nil }

        // VIP: 평균 100초에 한 번
        if vip == nil && Double.random(in: 0..<1) < dt / 100 {
            let total = VIPVisit.pool.reduce(0) { $0 + $1.weight }
            var r = Double.random(in: 0..<total)
            for p in VIPVisit.pool {
                if r < p.weight {
                    vip = VIPVisit(title: p.title, symbol: p.symbol, line: p.line, reward: p.reward,
                                   expires: Date().addingTimeInterval(9), x: Double.random(in: -0.3...0.3))
                    break
                }
                r -= p.weight
            }
        }

        // 러시: 평균 4분에 한 번
        if !isRushing && Double.random(in: 0..<1) < dt / 240 {
            startRush()
            toast = "러시 타임! 12초간 계산 ×3"
        }
    }

    // MARK: - VIP

    @discardableResult
    func serveVIP() -> String? {
        guard let v = vip else { return nil }
        vip = nil
        stats.vipServed += 1
        let text: String
        switch v.reward {
        case .cash(let m):
            let amount = dailyScale * m
            cash += amount
            today.revenue += amount
            stats.totalRevenue += amount
            text = "\(v.title) · \(Won.signed(amount))"
        case .rush:
            startRush(seconds: 15)
            text = "\(v.title) 효과 · 15초 러시!"
        case .reputation(let x):
            adjustReputation(x)
            text = "\(v.title) · 평판 +\(Int(x))"
        }
        toast = text
        return text
    }

    func noteCombo(_ n: Int) {
        if n > stats.bestCombo { stats.bestCombo = n }
    }

    // MARK: - 출석

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func checkDailyReward() {
        guard started else { return }
        let today = Game.dayKey(Date())
        guard today != lastLoginDay else { return }
        let yesterday = Game.dayKey(Date().addingTimeInterval(-86_400))
        streak = lastLoginDay == yesterday ? streak + 1 : 1
        lastLoginDay = today
        let index = (streak - 1) % 7
        let amount = max(10_000 * Double(index + 1), dailyScale * DailyRewardOffer.multipliers[index])
        dailyReward = DailyRewardOffer(streak: streak, dayIndex: index, amount: (amount / 100).rounded() * 100)
    }

    func claimDailyReward() {
        guard let r = dailyReward else { return }
        cash += r.amount
        record(.settle, "출석 보상 \(r.streak)일째", r.amount)
        dailyReward = nil
        save()
    }
}

// MARK: - 로컬 알림 (사용자가 켰을 때만)

enum Notifier {
    static func request(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func schedule(perSec: Double, company: String) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let plan: [(TimeInterval, String, String)] = [
            (2 * 3600, "\(company) 금고가 불어나는 중",
             "자리 비운 사이 \(Won.short(perSec * 2 * 3600)) 벌었어요. 정산하러 오세요."),
            (8 * 3600, "금고가 가득 찼어요",
             "더 벌려면 가게에 들러주세요. 손님들이 사장님을 찾아요.")
        ]
        for (i, item) in plan.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.1
            content.body = item.2
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.0, repeats: false)
            center.add(UNNotificationRequest(identifier: "hanpyeong-\(i)", content: content, trigger: trigger))
        }
    }

    static func clear() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
