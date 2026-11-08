import SwiftUI

enum Tab { case home, calendar, stats, my }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Tab = .home
    @State private var adding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            T.bg.ignoresSafeArea()
            Group {
                switch tab {
                case .home: HomeView(onAdd: { adding = true })
                case .calendar: CalendarView()
                case .stats: StatsView()
                case .my: SettingsView()
                }
            }
            tabBar
        }
        .sheet(isPresented: $adding) { AddView().environmentObject(store) }
    }

    var tabBar: some View {
        HStack {
            item(.home, "house.fill", "홈")
            item(.calendar, "calendar", "일정")
            Button { adding = true } label: {
                Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56).background(T.blue, in: Circle())
                    .shadow(color: T.blue.opacity(0.35), radius: 10, y: 4)
            }.buttonStyle(Press()).offset(y: -10)
            item(.stats, "chart.bar.fill", "통계")
            item(.my, "person.fill", "마이")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white, in: Capsule()).shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        .padding(.horizontal, 16).padding(.bottom, 6)
    }
    func item(_ t: Tab, _ icon: String, _ label: String) -> some View {
        Button { tab = t } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 11, weight: .medium))
            }.foregroundStyle(tab == t ? T.blue : T.faint).frame(maxWidth: .infinity)
        }
    }
}

// MARK: 홈
struct HomeView: View {
    @EnvironmentObject var store: Store
    var onAdd: () -> Void
    @State private var q = ""
    @State private var selected: Subscription?
    @State private var showAllList = false

    var headline: String {
        guard let n = store.upcoming.first else { return store.userName.isEmpty ? "안녕하세요" : "\(store.userName)님, 안녕하세요" }
        return n.dDay <= 0 ? "\(n.name),\n오늘 결제돼요 👈" : "\(n.name),\n\(n.whenText) 갱신돼요 👈"
    }
    var paid: Double { max(0, store.monthlyTotal - Double(store.remainingThisMonth)) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.subs.isEmpty { empty } else {
                        Text(headline).font(.system(size: 28, weight: .heavy)).foregroundStyle(T.text).padding(.top, 12).padding(.bottom, 4)

                        // 이번 달 요약 (링 + 결제 완료 / 지출 총액)
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().stroke(T.bg, lineWidth: 5)
                                Circle().trim(from: 0, to: store.monthlyTotal > 0 ? paid / store.monthlyTotal : 0)
                                    .stroke(T.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                                Text("\(Calendar.current.component(.month, from: Date()))월").font(.system(size: 14, weight: .semibold))
                            }.frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("결제 완료").font(.system(size: 12)).foregroundStyle(T.blue)
                                Text(paid.won).font(.system(size: 18, weight: .bold)).foregroundStyle(T.blue)
                            }
                            Text("/").foregroundStyle(T.faint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("지출 총액").font(.system(size: 12)).foregroundStyle(T.sub)
                                Text(store.monthlyTotal.won).font(.system(size: 18, weight: .bold)).foregroundStyle(T.text)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        if store.budget > 0 {
                            let used = min(1, store.monthlyTotal / Double(store.budget))
                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(store.overBudget ? "예산을 넘었어요" : "예산까지 \((Double(store.budget) - store.monthlyTotal).won) 남았어요").font(.system(size: 14, weight: .semibold))
                                        Spacer(); Text("\(Int(used * 100))%").font(.system(size: 14)).foregroundStyle(T.sub)
                                    }
                                    ProgressView(value: used).tint(store.overBudget ? T.red : T.green)
                                }
                            }
                        }

                        // 다음 결제일 카드 2개
                        let nexts = nextDays()
                        if !nexts.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(nexts, id: \.0) { d, subs in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(d.formatted(.dateTime.month().day())).font(.system(size: 13)).foregroundStyle(T.sub)
                                        Text(subs.reduce(0) { $0 + $1.price }.won).font(.system(size: 20, weight: .bold))
                                        HStack(spacing: -8) {
                                            ForEach(subs.prefix(4)) { s in LogoView(name: s.name, category: s.category, size: 26) }
                                        }.padding(.top, 4)
                                    }
                                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                }
                            }
                        }

                        // 구독 서비스
                        HStack {
                            Text("구독 서비스").font(.system(size: 15)).foregroundStyle(T.sub)
                            Spacer()
                            Text("총 \(store.monthlyTotal.won)").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.text)
                        }.padding(.top, 8)
                        TextField("서비스 검색", text: $q)
                            .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        let list = q.isEmpty ? store.upcoming : store.search(q)
                        ForEach(showAllList || !q.isEmpty ? list : Array(list.prefix(6))) { s in
                            HStack(spacing: 14) {
                                LogoView(name: s.name, category: s.category, size: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(T.text)
                                    Text("\(s.price.won) / \(s.cycle == .monthly ? "1개월" : s.cycle == .yearly ? "1년" : "1주")").font(.system(size: 14)).foregroundStyle(T.sub)
                                }
                                Spacer()
                                if s.isActive { badge(s) } else { Text(s.status.rawValue).font(.system(size: 13)).foregroundStyle(T.faint) }
                            }
                            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .onTapGesture { selected = s }
                        }
                        if q.isEmpty && list.count > 6 {
                            Button { withAnimation { showAllList.toggle() } } label: {
                                Text(showAllList ? "접기" : "\(list.count - 6)개 더 보기").font(.system(size: 15)).foregroundStyle(T.sub).frame(maxWidth: .infinity)
                            }
                        }

                        if q.isEmpty {
                            NoticeCard()
                            UpcomingList { selected = $0 }
                            if !store.insights.isEmpty {
                                Card {
                                    VStack(alignment: .leading, spacing: 14) {
                                        SectionTitle(t: store.potentialSave > 0 ? "\(store.potentialSave.won) 아낄 수 있어요" : "확인해보세요")
                                        ForEach(store.insights) { i in
                                            HStack(spacing: 12) {
                                                Image(systemName: i.icon).foregroundStyle(T.blue).frame(width: 32, height: 32).background(T.blueSoft, in: Circle())
                                                Text(i.text).font(.system(size: 15)).foregroundStyle(T.text)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 160)
                }.padding(.horizontal, 20)
            }
            if !store.subs.isEmpty {
                Button(action: onAdd) {
                    Label("등록하기", systemImage: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 20).frame(height: 52).background(T.blue, in: Capsule())
                        .shadow(color: T.blue.opacity(0.35), radius: 10, y: 4)
                }.buttonStyle(Press()).padding(.trailing, 20).padding(.bottom, 104)
            }
        }
        .sheet(item: $selected) { s in DetailView(sub: s).environmentObject(store) }
    }

    func badge(_ s: Subscription) -> some View {
        let d = s.dDay
        let (txt, fg, bg): (String, Color, Color) = d <= 1 ? (s.whenText, T.red, Color(hex: 0xFFE9EB)) : ("\(d)일 뒤", T.blue, T.blueSoft)
        return Text(txt).font(.system(size: 13, weight: .bold)).foregroundStyle(fg).padding(.horizontal, 12).padding(.vertical, 6).background(bg, in: Capsule())
    }

    func nextDays() -> [(Date, [Subscription])] {
        let cal = Calendar.current
        let g = Dictionary(grouping: store.upcoming) { cal.startOfDay(for: $0.nextDate) }
        return Array(g.keys.sorted().prefix(2).map { ($0, g[$0]!) })
    }

    var empty: some View {
        VStack(spacing: 14) {
            Image("AppLogo").resizable().scaledToFit().frame(width: 120).luminanceToAlpha()
            Text("어떤 구독을 쓰고 있나요?").font(.system(size: 20, weight: .bold))
            Text("+ 버튼으로 추가해보세요").font(.system(size: 15)).foregroundStyle(T.sub)
            BigButton(title: "구독 추가하기", action: onAdd).padding(.horizontal, 40).padding(.top, 10)
        }.frame(maxWidth: .infinity).padding(.top, 120)
    }
}

extension View {
    // 흰색 로고를 밝은 배경에서도 보이게
    func colorInvertIfNeeded() -> some View { self.luminanceToAlpha() }
}

// MARK: 일정
struct CalendarView: View {
    @EnvironmentObject var store: Store
    @State private var month = Date()
    @State private var day = Date()
    @State private var selected: Subscription?
    let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(month.formatted(.dateTime.year().month())).font(.system(size: 18, weight: .bold))
                    Spacer()
                    Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                }.foregroundStyle(T.text).padding(.top, 8)
                Card { grid }
                let todays = payments(on: day)
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(todays.isEmpty ? "결제 없는 날이에요" : "\(day.formatted(.dateTime.month().day())) 결제 \(todays.reduce(0) { $0 + $1.price }.won)")
                            .font(.system(size: 17, weight: .bold))
                        ForEach(todays) { s in SubRow(s: s).onTapGesture { selected = s } }
                    }
                }
                Spacer(minLength: 100)
            }.padding(.horizontal, 20)
        }.sheet(item: $selected) { DetailView(sub: $0).environmentObject(store) }
    }

    func payments(on d: Date) -> [Subscription] {
        store.active.filter { s in
            var x = s.nextDate
            // 앞뒤 달 표시를 위해 주기를 따라 계산
            if s.cycle == .weekly {
                let diff = cal.dateComponents([.day], from: cal.startOfDay(for: x), to: cal.startOfDay(for: d)).day ?? 0
                return diff >= 0 && diff % 7 == 0
            }
            if s.cycle == .monthly { return cal.component(.day, from: x) == cal.component(.day, from: d) && cal.startOfDay(for: d) >= cal.startOfDay(for: x) }
            x = s.nextDate
            return cal.isDate(x, inSameDayAs: d) || (cal.component(.month, from: x) == cal.component(.month, from: d) && cal.component(.day, from: x) == cal.component(.day, from: d) && d >= x)
        }
    }

    var grid: some View {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let offset = cal.component(.weekday, from: first) - 1
        let days = cal.range(of: .day, in: .month, for: first)!.count
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 10) {
            HStack(spacing: 0) { ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { Text($0).font(.system(size: 13)).foregroundStyle(T.faint).frame(maxWidth: .infinity) } }
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(0..<(offset + days), id: \.self) { i in
                    if i < offset { Color.clear.frame(height: 48) } else {
                        let d = cal.date(byAdding: .day, value: i - offset, to: first)!
                        let n = payments(on: d).count
                        let sel = cal.isDate(d, inSameDayAs: day)
                        VStack(spacing: 2) {
                            Text("\(i - offset + 1)").font(.system(size: 15, weight: sel ? .bold : .regular))
                                .foregroundStyle(sel ? .white : T.text)
                                .frame(width: 32, height: 32).background(sel ? T.blue : .clear, in: Circle())
                            Text(n > 0 ? "\(n)건" : " ").font(.system(size: 10)).foregroundStyle(T.blue)
                        }.frame(height: 48).contentShape(Rectangle()).onTapGesture { day = d }
                    }
                }
            }
        }
    }
}
