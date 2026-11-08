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
                case .home: HomeView()
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
    @State private var showAll = false
    @State private var q = ""
    @State private var selected: Subscription?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(store.userName.isEmpty ? "안녕하세요 👋" : "\(store.userName)님, 안녕하세요").font(.system(size: 22, weight: .bold))
                    Spacer()
                }.padding(.top, 8)

                if store.subs.isEmpty { empty } else {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("이번 달 구독료").font(.system(size: 15)).foregroundStyle(T.sub)
                            Text(store.monthlyTotal.won).font(.system(size: 32, weight: .heavy))
                            HStack(spacing: 8) {
                                Text("1년이면 \(store.yearlyTotal.won)").font(.system(size: 14)).foregroundStyle(T.sub)
                            }
                            if store.overBudget { Text("예산을 \((store.monthlyTotal - Double(store.budget)).won) 넘었어요").font(.system(size: 14, weight: .semibold)).foregroundStyle(T.red).padding(.top, 2) }
                        }
                    }

                    TextField("넷플릭스, AI, 3만원 이하…", text: $q)
                        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    if !q.isEmpty {
                        Card { VStack(spacing: 16) { ForEach(store.search(q)) { s in SubRow(s: s).onTapGesture { selected = s } } } }
                    } else {
                        Card {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionTitle(t: "곧 결제돼요")
                                let list = store.upcoming
                                ForEach(showAll ? list : Array(list.prefix(4))) { s in SubRow(s: s).onTapGesture { selected = s } }
                                if list.count > 4 {
                                    Button { withAnimation { showAll.toggle() } } label: {
                                        Text(showAll ? "접기" : "더보기").font(.system(size: 15)).foregroundStyle(T.sub).frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
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
                        if !store.top3.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 16) {
                                    SectionTitle(t: "제일 비싼 구독")
                                    ForEach(Array(store.top3.enumerated()), id: \.element.id) { i, s in
                                        HStack { Text("\(i + 1)").font(.system(size: 16, weight: .bold)).foregroundStyle(T.blue).frame(width: 20); SubRow(s: s) }
                                            .onTapGesture { selected = s }
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 100)
            }.padding(.horizontal, 20)
        }
        .sheet(item: $selected) { s in DetailView(sub: s).environmentObject(store) }
    }

    var empty: some View {
        VStack(spacing: 14) {
            Image("AppLogo").resizable().scaledToFit().frame(width: 120).colorInvertIfNeeded()
            Text("어떤 구독을 쓰고 있나요?").font(.system(size: 20, weight: .bold))
            Text("+ 버튼으로 추가해보세요").font(.system(size: 15)).foregroundStyle(T.sub)
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
