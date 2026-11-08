import SwiftUI

struct ReportView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var which = 0   // 0 지난달, 1 이번 달
    @State private var text = ""
    @State private var loading = true

    var cal: Calendar { Calendar.current }
    var date: Date { which == 0 ? cal.date(byAdding: .month, value: -1, to: Date())! : Date() }
    var month: Int { cal.component(.month, from: date) }
    var total: Int? { which == 1 ? Int(store.monthlyTotal.rounded()) : store.prevMonthTotal }
    var prevOfThat: Int? { store.history[key(cal.date(byAdding: .month, value: -1, to: date)!)] }
    var delta: Int? { if let t = total, let p = prevOfThat { return t - p }; return nil }
    var names: [String]? { which == 1 ? store.active.map(\.name).sorted() : store.names(of: date) }
    var prevNames: [String]? { store.names(of: cal.date(byAdding: .month, value: -1, to: date)!) }
    var added: [String] { guard let n = names, let p = prevNames else { return [] }; return n.filter { !p.contains($0) } }
    var removed: [String] { guard let n = names, let p = prevNames else { return [] }; return p.filter { !n.contains($0) } }
    func key(_ d: Date) -> String { let c = cal.dateComponents([.year, .month], from: d); return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BigTitle("\(month)월\n구독 리포트").stagger(0)
                    Picker("", selection: $which) { Text("지난달").tag(0); Text("이번 달").tag(1) }.pickerStyle(.segmented)
                    if total == nil {
                        VStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundStyle(T.faint)
                            Text("아직 \(month)월 기록이 없어요").font(.system(size: 16, weight: .semibold))
                            Text("앱을 쓴 달부터 자동으로 기록돼요").font(.system(size: 13)).foregroundStyle(T.sub)
                        }.frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        // 숫자
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(month)월 구독료").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                            CountingWon(target: Double(total ?? 0)).font(.system(size: 38, weight: .heavy)).foregroundStyle(.white)
                            if let d = delta {
                                Text(d == 0 ? "지난달과 같아요" : d > 0 ? "지난달보다 +\(d.won)" : "지난달보다 -\((-d).won)")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.2), in: Capsule())
                            }
                        }
                        .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(T.hero)
                        .overlay(alignment: .topTrailing) { Circle().fill(.white.opacity(0.1)).frame(width: 140).offset(x: 40, y: -50) }
                        .overlay(alignment: .bottomTrailing) { Circle().fill(T.accent3.opacity(0.45)).frame(width: 110).blur(radius: 6).offset(x: 20, y: 40) }
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).shadow(color: T.blue.opacity(0.3), radius: 18, y: 10).stagger(1)

                        // AI 요약
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) { Image(systemName: "sparkles").foregroundStyle(T.blue); Text("요약").font(.system(size: 15, weight: .bold)) }
                            if loading { TypingDots() } else { Text(text).font(.system(size: 15)).foregroundStyle(T.text).lineSpacing(4).transition(.opacity) }
                        }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(T.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous)).stagger(2)

                        if which == 1 {
                            Card {
                                VStack(alignment: .leading, spacing: 14) {
                                    SectionTitle(t: "제일 비싼 구독")
                                    ForEach(store.top3) { s in
                                        HStack(spacing: 12) {
                                            LogoView(name: s.name, category: s.category, size: 40)
                                            Text(s.name).font(.system(size: 15, weight: .semibold))
                                            Spacer()
                                            Text(s.monthly.won).font(.system(size: 15)).foregroundStyle(T.sub)
                                        }
                                    }
                                }
                            }.stagger(3)
                        }
                        if !added.isEmpty || !removed.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(t: "달라진 점")
                                    ForEach(added, id: \.self) { n in change("plus.circle.fill", T.red, "\(n) 새로 생겼어요", n) }
                                    ForEach(removed, id: \.self) { n in change("minus.circle.fill", T.green, "\(n) 정리했어요", n) }
                                }
                            }.stagger(4)
                        }
                        ShareLink(item: "구독온 \(month)월 리포트\n구독료 \((total ?? 0).won)\n\(text)") {
                            Label("공유하기", systemImage: "square.and.arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(T.blue)
                                .frame(maxWidth: .infinity).frame(height: 50).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    Spacer(minLength: 40)
                }.padding(20)
            }
            .background(T.bg)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .task(id: which) { await load() }
        }
    }

    func change(_ icon: String, _ c: Color, _ t: String, _ name: String) -> some View {
        HStack(spacing: 12) { LogoView(name: name, size: 32); Text(t).font(.system(size: 15)); Spacer(); Image(systemName: icon).foregroundStyle(c) }
    }

    func load() async {
        loading = true
        let cacheKey = "report-\(key(date))-\(which == 1 ? Int(store.monthlyTotal) : 0)"
        if which == 0, let c = UserDefaults.standard.string(forKey: cacheKey) { text = c; withAnimation { loading = false }; return }
        var f = Facts(store)
        if which == 0 { f.monthTotal = total ?? 0; f.prevTotal = prevOfThat }
        else { f.prevTotal = store.prevMonthTotal }
        let t = await Assistant.reportText(facts: f, month: month, added: added, removed: removed)
        if which == 0 { UserDefaults.standard.set(t, forKey: cacheKey) }
        text = t
        withAnimation(.easeOut(duration: 0.4)) { loading = false }
    }
}
