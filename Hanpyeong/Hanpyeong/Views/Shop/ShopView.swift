import SwiftUI

struct ShopView: View {
    @Environment(Game.self) private var game
    @State private var showOpen = false
    @State private var showNews = false
    @State private var showDecision = false

    var body: some View {
        @Bindable var game = game

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DecisionBanner { showDecision = true }
                    TodayChips { showNews = true }
                    CounterCard()
                    MissionPeek()

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("내 점포").font(.system(size: 22, weight: .heavy)).foregroundStyle(Palette.ink)
                            Text("\(game.stores.count)곳 · 초당 \(Won.short(game.incomePerSec))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Picker("구매 단위", selection: $game.bulk) {
                            ForEach(BulkMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                    .padding(.top, 10)

                    if game.stores.isEmpty {
                        EmptyNote(title: "가게가 하나도 없어요",
                                  detail: "계산대로 돈을 모아 새로 열거나,\n매물 탭에서 싸게 나온 가게를 사 보세요.")
                            .paperCard()
                    }

                    ForEach(game.stores) { store in
                        StoreRow(store: store)
                            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                                    removal: .opacity))
                    }

                    Button {
                        showOpen = true
                    } label: {
                        Label("새 점포 열기", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(SignButtonStyle())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.stores.map(\.id))
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper)
            .safeAreaInset(edge: .top, spacing: 0) { CashHeader() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                StoreDetailView(storeID: id)
            }
            .sheet(isPresented: $showOpen) { OpenStoreSheet() }
            .sheet(isPresented: $showNews) { NewsSheet() }
            .sheet(isPresented: $showDecision) { DecisionSheet() }
            .animation(.snappy, value: game.pendingDecision?.id)
        }
    }
}

// MARK: - 오늘의 상황 칩

struct TodayChips: View {
    @Environment(Game.self) private var game
    let onNews: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let h = game.holidays.first {
                    chip(symbol: "party.popper.fill", title: h.name, sub: h.note, highlight: true)
                }
                chip(symbol: game.weather.symbol, title: "\(game.weather.title) · \(game.season.title)",
                     sub: GameCalendar.text(game.day))
                chip(symbol: "heart.fill", title: "평판 \(Int(game.reputation))",
                     sub: "\(game.reputationTitle) · 손님 \(Won.percent(game.reputationFactor - 1))")
                if let n = game.news.first {
                    Button(action: onNews) {
                        chip(symbol: "newspaper.fill", title: n.headline, sub: n.detail,
                             tint: n.tone == .bad ? Palette.down : n.tone == .good ? Palette.up : Palette.inkSoft)
                    }
                    .buttonStyle(PressStyle())
                }
                if !game.events.isEmpty {
                    Button(action: onNews) {
                        chip(symbol: "bolt.fill", title: "진행 중 \(game.events.count)건", sub: "뉴스 효과 보기")
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -18)
    }

    private func chip(symbol: String, title: String, sub: String,
                      highlight: Bool = false, tint: Color = Palette.inkSoft) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(highlight ? .monochrome : .multicolor)
                .foregroundStyle(highlight ? .white : Palette.sign)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(highlight ? .white : Palette.ink)
                    .lineLimit(1)
                Text(sub)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(highlight ? .white.opacity(0.9) : tint)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlight ? Palette.sign : Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(highlight ? .clear : Palette.line.opacity(0.7))
        )
    }
}

// MARK: - 계산대

struct CounterCard: View {
    @Environment(Game.self) private var game
    @State private var floats: [FloatItem] = []
    @State private var coins: [CoinItem] = []
    @State private var taps = 0
    @State private var pressed = false

    private struct FloatItem: Identifiable {
        let id = UUID()
        let text: String
        let x: CGFloat
    }

    private struct CoinItem: Identifiable {
        let id = UUID()
        let angle: Double
    }

    private var flagship: Store? {
        game.stores.max { a, b in
            a.kind.info.tier == b.kind.info.tier ? a.level < b.level : a.kind.info.tier < b.kind.info.tier
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                StoreScene(kind: flagship?.kind ?? .cornerShop,
                           name: flagship?.name ?? game.companyName,
                           dayFraction: game.dayFraction,
                           weather: game.weather,
                           walkers: min(6, 1 + game.stores.count),
                           height: 220,
                           pressed: pressed)
                ForEach(coins) { c in
                    CoinBurst(angle: c.angle)
                }
                ForEach(floats) { f in
                    FloatingAmount(text: f.text)
                        .offset(x: f.x, y: -30)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { ring() }

            Button(action: ring) {
                HStack(spacing: 14) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("손님 계산하기")
                            .font(.system(size: 19, weight: .heavy))
                        Text("한 번에 \(Won.full(game.tapValue))")
                            .font(.num(14, .semibold))
                            .opacity(0.9)
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(minHeight: 70)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.sign)
                        .shadow(color: Color(hex: 0x7A1F15), radius: 0, x: 0, y: 4)
                )
            }
            .buttonStyle(PressStyle())

            counterUpgrade
        }
        .paperCard(padding: 16)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: taps) { _, _ in
            game.hapticsOn
        }
    }

    private var counterUpgrade: some View {
        let cost = game.counterUpgradeCost
        let maxed = game.counterMaxed
        let affordable = !maxed && game.cash >= cost
        return HStack(spacing: 12) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .font(.system(size: 22))
                .foregroundStyle(Palette.inkSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text("계산대 · \(Counter.name(level: game.tapLevel))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(maxed ? "최고 단계예요" : "다음 \(Counter.name(level: game.tapLevel + 1)) · 계산당 +45%")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Button {
                game.upgradeCounter()
            } label: {
                Text(maxed ? "완료" : Won.short(cost))
                    .font(.num(15, .bold))
                    .foregroundStyle(affordable ? .white : Palette.inkFaint)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(affordable ? Palette.ink : Palette.cardDeep))
            }
            .buttonStyle(PressStyle())
            .disabled(!affordable)
        }
    }

    private func ring() {
        let v = game.tap()
        taps += 1
        let item = FloatItem(text: "+" + Won.short(v), x: CGFloat.random(in: -90...90))
        floats.append(item)
        if floats.count > 12 { floats.removeFirst(floats.count - 12) }
        let burst = (0..<3).map { _ in CoinItem(angle: Double.random(in: -Double.pi...0)) }
        coins.append(contentsOf: burst)
        if coins.count > 18 { coins.removeFirst(coins.count - 18) }

        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { pressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { pressed = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            floats.removeAll { $0.id == item.id }
            coins.removeAll { c in burst.contains { $0.id == c.id } }
        }
    }
}

// MARK: - 점포 한 줄

struct StoreRow: View {
    @Environment(Game.self) private var game
    let store: Store
    @State private var bump = 0

    var body: some View {
        let plan = game.upgradePlan(store)
        let affordable = plan.count > 0 && game.cash >= plan.cost

        VStack(spacing: 14) {
            HStack(spacing: 14) {
                NavigationLink(value: store.id) {
                    HStack(spacing: 14) {
                        BrandLogo(name: store.name, color: store.kind.color, size: 56, badge: store.kind.info.symbol)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.displayName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            HStack(spacing: 6) {
                                Text("Lv.\(store.level)")
                                    .font(.num(14, .heavy))
                                    .foregroundStyle(store.kind.color)
                                    .contentTransition(.numericText())
                                Text("\(store.kind.info.title) · 직원 \(store.staff)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Palette.inkSoft)
                                    .lineLimit(1)
                                if store.wear >= 60 {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.sign)
                                }
                            }
                            Text("\(Won.signed(game.income(store)))/초")
                                .font(.num(16, .bold))
                                .foregroundStyle(Palette.up)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    if game.upgrade(store.id) { bump += 1 }
                } label: {
                    VStack(spacing: 3) {
                        Text(plan.count > 0 ? "Lv +\(plan.count)" : "최고")
                            .font(.system(size: 15, weight: .heavy))
                        Text(plan.count > 0 ? Won.short(plan.cost) : "—")
                            .font(.num(14, .bold))
                    }
                    .foregroundStyle(affordable ? .white : Palette.inkFaint)
                    .frame(width: 96, height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(affordable ? Palette.sign : Palette.cardDeep)
                    )
                }
                .buttonStyle(PressStyle())
                .disabled(!affordable)
                .sensoryFeedback(.impact(weight: .medium), trigger: bump) { _, _ in game.hapticsOn }
            }
            MilestoneBar(level: store.level)
        }
        .paperCard(padding: 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: store.level)
    }
}

struct MilestoneBar: View {
    let level: Int

    var body: some View {
        let next = Game.nextMilestone(after: level)
        let prev = Economy.milestones.last(where: { $0 <= level }) ?? 0
        let progress: Double = next.map { Double(level - prev) / Double($0 - prev) } ?? 1

        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line)
                    Capsule().fill(Palette.gold)
                        .frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 4)
            Text(next.map { "Lv.\($0) 매출 ×2" } ?? "최고 레벨")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize()
        }
        .animation(.easeOut(duration: 0.25), value: level)
    }
}

// MARK: - 뉴스

struct NewsStrip: View {
    @Environment(Game.self) private var game
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("속보")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Palette.ink))
                if let n = game.news.first {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(n.headline)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(n.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(n.tone == .bad ? Palette.down : n.tone == .good ? Palette.up : Palette.inkSoft)
                            .lineLimit(1)
                    }
                    .id(n.id)
                    .transition(.push(from: .bottom))
                } else {
                    Text("오늘은 조용한 하루").font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                if !game.events.isEmpty {
                    Tag(text: "진행 \(game.events.count)", color: Palette.sign)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
            .clipped()
            .animation(.snappy, value: game.news.first?.id)
        }
        .buttonStyle(PressStyle())
    }
}

struct NewsSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !game.events.isEmpty {
                    Section("지금 영향 중") {
                        ForEach(game.events) { e in
                            HStack {
                                Text(e.headline).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text("\(e.daysLeft)일 남음").font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                    }
                }
                Section("지난 소식") {
                    ForEach(game.news) { n in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(n.day)일차").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSoft)
                                Spacer()
                            }
                            Text(n.headline).font(.myeongjo(16))
                            Text(n.detail)
                                .font(.system(size: 15))
                                .foregroundStyle(n.tone == .bad ? Palette.down : n.tone == .good ? Palette.up : Palette.inkSoft)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .navigationTitle("한평 경제신문")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 오늘의 장사 환경

struct ConditionsStrip: View {
    @Environment(Game.self) private var game

    var body: some View {
        HStack(spacing: 0) {
            cell(symbol: game.season.symbol, title: game.season.title, sub: GameCalendar.text(game.day))
            Divider().frame(height: 28).overlay(Palette.line)
            cell(symbol: game.weather.symbol, title: game.weather.title, sub: game.weather.forecast)
            Divider().frame(height: 28).overlay(Palette.line)
            cell(symbol: "heart.fill", title: "평판 \(Int(game.reputation))",
                 sub: "\(game.reputationTitle) · 손님 \(Won.percent(game.reputationFactor - 1))")
        }
        .padding(.vertical, 10)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
    }

    private func cell(symbol: String, title: String, sub: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol).symbolRenderingMode(.multicolor)
                Text(title)
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Palette.ink)
            Text(sub)
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }
}

// MARK: - 오늘의 할 일 미리보기

struct MissionPeek: View {
    @Environment(Game.self) private var game

    var body: some View {
        let done = game.missions.filter { $0.claimed || game.missionDone($0) }.count
        let total = max(1, game.missions.count)
        let ready = game.missions.filter { !$0.claimed && game.missionDone($0) }.count

        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(done) / CGFloat(total))
                    .stroke(Palette.sign, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(done)/\(total)")
                    .font(.num(13, .heavy))
                    .foregroundStyle(Palette.ink)
            }
            .frame(width: 48, height: 48)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: done)

            VStack(alignment: .leading, spacing: 3) {
                Text("오늘의 할 일")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(game.missions.first { !$0.claimed && !game.missionDone($0) }.map { $0.kind.title($0.target) }
                     ?? "오늘 할 일을 다 했어요")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            Spacer()
            if ready > 0 {
                Text("보상 \(ready)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.sign))
            }
        }
        .paperCard(padding: 16)
    }
}

// MARK: - 명절·시즌 띠

struct HolidayStrip: View {
    @Environment(Game.self) private var game

    var body: some View {
        if let h = game.holidays.first {
            HStack(spacing: 8) {
                Image(systemName: "party.popper.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text(h.name).font(.system(size: 15, weight: .heavy))
                    Text(h.note).font(.system(size: 13)).opacity(0.9)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Palette.sign, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
