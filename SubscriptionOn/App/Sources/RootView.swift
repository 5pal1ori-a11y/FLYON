import SwiftUI

enum Tab { case home, calendar, stats, my }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Tab = .home
    @State private var adding = false
    @State private var plusSpin: Double = 0
    @Namespace private var pill
    @ObservedObject private var router = ShortcutRouter.shared
    @State private var qaAsk = false
    @State private var qaReport = false

    var body: some View {
        ZStack(alignment: .bottom) {
            T.bg.ignoresSafeArea()
            Group {
                switch tab {
                case .home: HomeView(onAdd: { adding = true })
                case .calendar: CalendarView()
                case .stats: AnalysisView()
                case .my: SettingsView()
                }
            }
            .id(tab).transition(.opacity.combined(with: .scale(scale: 0.985)))
            tabBar
        }
        .sheet(isPresented: $adding) { AddView().environmentObject(store) }
        .sheet(isPresented: $qaAsk) { AssistantView().environmentObject(store) }
        .sheet(isPresented: $qaReport) { ReportView().environmentObject(store) }
        .onChange(of: router.action) { _, act in
            guard let act else { return }
            switch act { case "add": adding = true; case "ask": qaAsk = true; case "report": qaReport = true; default: break }
            router.action = nil
        }
        .onAppear {
            if let act = router.action {
                switch act { case "add": adding = true; case "ask": qaAsk = true; case "report": qaReport = true; default: break }
                router.action = nil
            }
        }
    }

    var tabBar: some View {
        HStack {
            item(.home, "house.fill", "홈")
            item(.calendar, "calendar", "일정")
            Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { plusSpin += 90 }; adding = true } label: {
                Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(.white).rotationEffect(.degrees(plusSpin))
                    .frame(width: 56, height: 56).background(T.blue, in: Circle())
                    .shadow(color: T.blue.opacity(0.35), radius: 10, y: 4)
            }.buttonStyle(Press()).offset(y: -10)
            item(.stats, "chart.bar.fill", "분석")
            item(.my, "person.fill", "마이")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1)).shadow(color: Color(hex: 0x1B2A4A).opacity(0.12), radius: 20, y: 8)
        .padding(.horizontal, 16).padding(.bottom, 6)
    }
    func item(_ t: Tab, _ icon: String, _ label: String) -> some View {
        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tab = t } } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20)).symbolEffect(.bounce, value: tab == t).scaleEffect(tab == t ? 1.12 : 1)
                Text(label).font(.system(size: 11, weight: .medium))
            }.foregroundStyle(tab == t ? T.blue : T.faint).frame(maxWidth: .infinity).padding(.vertical, 6)
            .background { if tab == t { Capsule().fill(T.blueSoft).matchedGeometryEffect(id: "pill", in: pill) } }
        }
    }
}

// MARK: 홈
struct HomeView: View {
    @EnvironmentObject var store: Store
    var onAdd: () -> Void
    @State private var selected: Subscription?
    @State private var showAll = false
    @State private var showAI = false
    @State private var showReport = false
    @State private var showUsage = false
    @State private var showTrials = false
    @State private var greetShift = 0

    /// 상황에 맞는 인사말 (눌러서 바꿔볼 수 있어요)
    var bigGreeting: String {
        let cal = Calendar.current
        let name = store.userName.isEmpty ? "" : "\(store.userName)님, "
        if store.upcoming.contains(where: { $0.dDay <= 0 }) { return name + "오늘 결제될 내역,\n꼭 확인하세요!" }
        var pool = ["오늘 기분은 어떠신가요?", "즐거운 하루 되세요 :)"]
        let wd = cal.component(.weekday, from: Date())      // 1 일 ... 7 토
        let hour = cal.component(.hour, from: Date())
        if wd == 1 || wd == 7 || (wd == 6 && hour >= 15) { pool.insert("이번주도 수고하셨어요", at: 0) }
        let seed = (cal.ordinality(of: .day, in: .year, for: Date()) ?? 0) + hour / 6 + greetShift
        return name + pool[seed % pool.count]
    }
    /// 지난달 기록이 있으면 그 차이, 없으면 이번 달에 새로 생긴 구독료
    var delta: Int {
        if let d = store.monthDelta { return d }
        let c = Calendar.current
        return Int(store.active.filter { c.isDate($0.startDate, equalTo: Date(), toGranularity: .month) }.reduce(0) { $0 + $1.monthly })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(bigGreeting).font(.system(size: 30, weight: .heavy)).foregroundStyle(T.text).fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity).id(bigGreeting).transition(.opacity)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { greetShift += 1 } }
                    Spacer()
                    Image(systemName: "bell").font(.system(size: 20)).foregroundStyle(T.text).padding(.top, 6)
                        .symbolEffect(.bounce, value: store.upcoming.first?.dDay ?? 9)
                }.padding(.top, 8).stagger(0)

                if store.subs.isEmpty { empty } else {
                    TrialCountdownBanner()
                    // 이번달 구독료 (히어로)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("이번달 구독료").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                        CountingWon(target: store.monthlyTotal).font(.system(size: 38, weight: .heavy)).foregroundStyle(.white)
                        Group {
                            if delta > 0 { Text("저번달보다 \(delta.won) 늘었어요") } else if delta < 0 { Text("저번달보다 \((-delta).won) 줄었어요") } else { Text("저번달과 같아요") }
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.2), in: Capsule())
                        if store.budget > 0 {
                            let used = min(1, store.monthlyTotal / Double(store.budget))
                            AnimBar(value: used, tint: .white, track: .white.opacity(0.25)).padding(.top, 8)
                            Text(store.overBudget ? "예산을 넘었어요" : "예산까지 \((Double(store.budget) - store.monthlyTotal).won) 남았어요").font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(T.hero)
                    .overlay(alignment: .topTrailing) { Circle().fill(.white.opacity(0.09)).frame(width: 150).offset(x: 50, y: -60) }
                    .overlay(alignment: .bottomTrailing) { Circle().fill(T.accent3.opacity(0.45)).frame(width: 120).blur(radius: 6).offset(x: 20, y: 44) }
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: T.blue.opacity(0.35), radius: 22, y: 12)
                    .stagger(1)

                    // 결제일이 가까운 서비스
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("결제일이 가까운 서비스에요").font(.system(size: 17, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(T.faint)
                        }.padding(.bottom, 8)
                        let list = store.upcoming
                        ForEach(Array((showAll ? list : Array(list.prefix(5))).enumerated()), id: \.element.id) { idx, s in
                            HStack(spacing: 14) {
                                LogoView(name: s.name, category: s.category, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.system(size: 16)).foregroundStyle(T.text)
                                    HStack(spacing: 6) {
                                        Text(s.price.won).font(.system(size: 17, weight: .semibold)).foregroundStyle(T.text)
                                        if let d = s.trialDaysLeft {
                                            Text("체험 \(d)일").font(.system(size: 11, weight: .bold)).foregroundStyle(.orange)
                                                .padding(.horizontal, 7).padding(.vertical, 3).background(Color.orange.opacity(0.15), in: Capsule())
                                        }
                                    }
                                }
                                Spacer()
                                DBadge(d: s.dDay)
                            }.padding(.vertical, 8).contentShape(Rectangle()).onTapGesture { selected = s }
                            .stagger(idx + 1).transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if list.count > 5 {
                            Divider().padding(.top, 6)
                            Button { withAnimation { showAll.toggle() } } label: {
                                HStack(spacing: 4) { Text(showAll ? "접기" : "더보기"); Image(systemName: showAll ? "chevron.up" : "chevron.down") }
                                    .font(.system(size: 14)).foregroundStyle(T.sub).frame(maxWidth: .infinity).padding(.top, 10)
                            }
                        }
                    }
                    .padding(20).background(T.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 14, y: 6)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showAll)

                    // AI · 리포트
                    HStack(spacing: 12) {
                        entryCard("sparkles", "AI에게 물어보세요", "무엇이든 물어봐요", T.blue) { showAI = true }
                        entryCard("chart.bar.doc.horizontal.fill", "\(Calendar.current.component(.month, from: Calendar.current.date(byAdding: .month, value: -1, to: Date())!))월 리포트", "지난달을 한눈에", T.accent2) { showReport = true }
                    }.stagger(2)

                    // 오늘 쓴 구독 체크 (한 줄)
                    Button { showUsage = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill").foregroundStyle(T.blue)
                            Text("오늘 쓴 구독 체크하기").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.text)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(T.faint)
                        }
                        .padding(16).background(T.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }.buttonStyle(PressCard()).stagger(3)
                    Button { showTrials = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gift.fill").foregroundStyle(.orange)
                            Text("이런 무료 체험 어때요?").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.text)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(T.faint)
                        }
                        .padding(16).background(T.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }.buttonStyle(PressCard()).stagger(4)
                }
                Spacer(minLength: 130)
            }.padding(.horizontal, 20)
        }
        .sheet(item: $selected) { s in DetailView(sub: s).environmentObject(store) }
        .sheet(isPresented: $showAI) { AssistantView().environmentObject(store) }
        .sheet(isPresented: $showReport) { ReportView().environmentObject(store) }
        .sheet(isPresented: $showTrials) { TrialPickView().environmentObject(store) }
        .sheet(isPresented: $showUsage) { UsageSheet().environmentObject(store).presentationDetents([.medium, .large]) }
    }

    func entryCard(_ icon: String, _ title: String, _ sub: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(T.text)
                    Text(sub).font(.system(size: 12)).foregroundStyle(T.sub)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 12, y: 5)
        }.buttonStyle(PressCard())
    }

    var empty: some View {
        VStack(spacing: 14) {
            AppLogoMark().frame(width: 120).floating()
            Text("어떤 구독을 쓰고 있나요?").font(.system(size: 20, weight: .bold))
            Text("+ 버튼으로 추가해보세요").font(.system(size: 15)).foregroundStyle(T.sub)
            BigButton(title: "구독 추가하기", action: onAdd).padding(.horizontal, 40).padding(.top, 10)
        }.frame(maxWidth: .infinity).padding(.top, 100)
    }
}

struct AppLogoMark: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let img = Image("AppLogo").resizable().scaledToFit().luminanceToAlpha()
        if scheme == .dark { img.colorInvert() } else { img }
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
                HStack(alignment: .center) {
                    BigTitle("\(cal.component(.year, from: month))년 \(cal.component(.month, from: month))월").contentTransition(.numericText()).id(month)
                    Spacer()
                    HStack(spacing: 18) {
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = cal.date(byAdding: .month, value: -1, to: month)! } } label: { Image(systemName: "chevron.left") }
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = cal.date(byAdding: .month, value: 1, to: month)! } } label: { Image(systemName: "chevron.right") }
                    }.font(.system(size: 18, weight: .semibold)).foregroundStyle(T.sub).padding(.top, 8)
                }.stagger(0)
                Card { grid.id(month).transition(.opacity.combined(with: .move(edge: .trailing))) }.clipped()
                let todays = payments(on: day)
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(todays.isEmpty ? "결제 없는 날이에요" : "\(cal.isDateInToday(day) ? "오늘은" : "\(cal.component(.month, from: day))월 \(cal.component(.day, from: day))일은") \(todays.reduce(0) { $0 + $1.price }.won) 결제해요.")
                            .font(.system(size: 17, weight: .bold))
                        ForEach(todays) { s in SubRow(s: s).onTapGesture { selected = s } }
                    }
                }
                UpcomingList { selected = $0 }
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
                                .frame(width: 32, height: 32).background(sel ? T.blue : .clear, in: Circle()).scaleEffect(sel ? 1.1 : 1)
                            Text(n > 0 ? "\(n)건" : " ").font(.system(size: 10)).foregroundStyle(T.blue)
                        }.frame(height: 48).contentShape(Rectangle()).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { day = d } }
                    }
                }
            }
        }
    }
}
