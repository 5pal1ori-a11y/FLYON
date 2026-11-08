import SwiftUI

/// 이번 주 / 남은 이번 달 / 다음 달 순으로 나눈 결제 목록
struct UpcomingList: View {
    @EnvironmentObject var store: Store
    var onSelect: (Subscription) -> Void
    @State private var showAll = false
    let cal = Calendar.current

    struct Group: Identifiable { let id: String; let title: String; let items: [Subscription] }

    var groups: [Group] {
        let list = store.upcoming
        func section(_ s: Subscription) -> Int {
            if s.dDay <= 6, cal.isDate(s.nextDate, equalTo: Date(), toGranularity: .weekOfYear) || s.dDay <= 3 { return 0 }
            if cal.isDate(s.nextDate, equalTo: Date(), toGranularity: .month) { return 1 }
            let next = cal.date(byAdding: .month, value: 1, to: Date())!
            if cal.isDate(s.nextDate, equalTo: next, toGranularity: .month) { return 2 }
            return 3
        }
        let titles = ["이번 주", "남은 이번 달", "다음 달", "그 이후"]
        return (0..<4).compactMap { i in
            let items = list.filter { section($0) == i }
            return items.isEmpty ? nil : Group(id: titles[i], title: titles[i], items: items)
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("다가오는 결제는 \(store.upcoming.count)건이에요.").font(.system(size: 20, weight: .bold))
                    Spacer()
                    Text("남은 결제 \(store.remainingThisMonth.won)").font(.system(size: 13)).foregroundStyle(T.sub)
                }
                ForEach(showAll ? groups : Array(groups.prefix(2))) { g in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(g.title).font(.system(size: 14)).foregroundStyle(T.text)
                            Spacer()
                            Text(g.items.reduce(0) { $0 + $1.price }.won).font(.system(size: 14)).foregroundStyle(T.faint)
                        }
                        ForEach(g.items) { s in
                            HStack(spacing: 14) {
                                LogoView(name: s.name, category: s.category, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(T.text)
                                    Text(s.cycleText).font(.system(size: 13)).foregroundStyle(T.faint)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(s.price.won).font(.system(size: 16, weight: .semibold)).foregroundStyle(T.text)
                                    Text(s.whenText).font(.system(size: 13, weight: .semibold)).foregroundStyle(s.dDay <= 3 ? T.green : T.faint)
                                }
                            }.contentShape(Rectangle()).onTapGesture { onSelect(s) }
                        }
                    }
                }
                if groups.count > 2 {
                    Button { withAnimation { showAll.toggle() } } label: {
                        Text(showAll ? "접기" : "더보기").font(.system(size: 15)).foregroundStyle(T.sub).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

/// 알아둘 점: 무료 체험 종료, 연간 갱신, 가격 인상
struct NoticeCard: View {
    @EnvironmentObject var store: Store
    struct Item: Identifiable { let id = UUID(); let title: String; let name: String; let sub: String; let day: String }
    var items: [Item] {
        var r: [Item] = []
        let wd: (Date) -> String = { $0.formatted(.dateTime.weekday(.wide)) }
        for s in store.active {
            if let t = s.trialEnd, t >= Date(), t.timeIntervalSinceNow < 14 * 86400 {
                r.append(Item(title: "무료 체험 종료", name: s.name, sub: "\(s.name) · 이후 \(s.price.won)", day: wd(t)))
            }
            if s.cycle == .yearly, s.dDay <= 30 { r.append(Item(title: "연간 갱신", name: s.name, sub: "\(s.name) · \(s.price.won)", day: wd(s.nextDate))) }
            if let h = s.priceHike { r.append(Item(title: "가격 인상", name: s.name, sub: "\(s.name) · \(h.from.won) → \(h.to.won)", day: "")) }
        }
        return Array(r.prefix(3))
    }
    var body: some View {
        if !items.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Text("알아둘 점").font(.system(size: 20, weight: .bold))
                    ForEach(items) { i in
                        HStack(spacing: 14) {
                            LogoView(name: i.name, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(i.title).font(.system(size: 16, weight: .semibold))
                                Text(i.sub).font(.system(size: 13)).foregroundStyle(T.sub)
                            }
                            Spacer()
                            Text(i.day).font(.system(size: 14)).foregroundStyle(T.sub)
                        }
                    }
                }
            }
        }
    }
}
