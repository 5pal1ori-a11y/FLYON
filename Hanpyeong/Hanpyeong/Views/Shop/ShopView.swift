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
                VStack(spacing: 14) {
                    DecisionBanner { showDecision = true }
                    ConditionsStrip()
                    NewsStrip { showNews = true }
                    CounterCard()
                    MissionPeek()

                    HStack(alignment: .lastTextBaseline) {
                        Text("내 점포 \(game.stores.count)곳").sectionLabel()
                        Spacer()
                        Picker("구매 단위", selection: $game.bulk) {
                            ForEach(BulkMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 168)
                    }
                    .padding(.top, 6)

                    if game.stores.isEmpty {
                        EmptyNote(title: "가게가 하나도 없어요",
                                  detail: "계산대로 돈을 모아 새로 열거나,\n매물 탭에서 싸게 나온 가게를 사 보세요.")
                            .paperCard()
                    }

                    ForEach(game.stores) { store in
                        StoreRow(store: store)
                    }

                    Button {
                        showOpen = true
                    } label: {
                        Label("새 점포 열기", systemImage: "plus")
                    }
                    .buttonStyle(LineButtonStyle())
                    .padding(.top, 2)
                }
                .padding(16)
                .padding(.bottom, 20)
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

// MARK: - 계산대

struct CounterCard: View {
    @Environment(Game.self) private var game
    @State private var floats: [FloatItem] = []
    @State private var taps = 0

    private struct FloatItem: Identifiable {
        let id = UUID()
        let text: String
        let x: CGFloat
    }

    private var flagship: Store? {
        game.stores.max { a, b in
            a.kind.info.tier == b.kind.info.tier ? a.level < b.level : a.kind.info.tier < b.kind.info.tier
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Storefront(kind: flagship?.kind ?? .cornerShop,
                           name: flagship?.name ?? game.companyName,
                           height: 172)
                ForEach(floats) { f in
                    FloatingAmount(text: f.text)
                        .offset(x: f.x, y: -20)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { ring() }

            Button(action: ring) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("손님 계산하기")
                            .font(.system(size: 16, weight: .heavy))
                        Text("한 번에 \(Won.full(game.tapValue))")
                            .font(.num(12, .medium))
                            .opacity(0.85)
                    }
                    Spacer()
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 22))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    // 금전등록기 버튼처럼 아랫면이 살짝 보이게
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.sign)
                        .shadow(color: Color(hex: 0x7A1F15), radius: 0, x: 0, y: 3)
                )
            }
            .buttonStyle(PressStyle())

            counterUpgrade
        }
        .paperCard(padding: 14)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: taps) { _, _ in
            game.hapticsOn
        }
    }

    private var counterUpgrade: some View {
        let cost = game.counterUpgradeCost
        let maxed = game.counterMaxed
        let affordable = !maxed && game.cash >= cost
        return HStack(spacing: 10) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .font(.system(size: 18))
                .foregroundStyle(Palette.inkSoft)
            VStack(alignment: .leading, spacing: 1) {
                Text("계산대 · \(Counter.name(level: game.tapLevel))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(maxed ? "최고 단계 · 매출이 오를수록 계산당 금액도 커져요"
                           : "다음 · \(Counter.name(level: game.tapLevel + 1)) · 계산당 +45%")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Button {
                game.upgradeCounter()
            } label: {
                Text(maxed ? "완료" : Won.short(cost))
                    .font(.num(13, .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(affordable ? Palette.ink : Palette.inkFaint)
                    .background(Capsule().strokeBorder(affordable ? Palette.ink : Palette.line, lineWidth: 1.2))
            }
            .disabled(!affordable)
        }
    }

    private func ring() {
        let v = game.tap()
        taps += 1
        let item = FloatItem(text: "+" + Won.short(v), x: CGFloat.random(in: -90...90))
        floats.append(item)
        if floats.count > 14 { floats.removeFirst(floats.count - 14) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            floats.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - 점포 한 줄

struct StoreRow: View {
    @Environment(Game.self) private var game
    let store: Store

    var body: some View {
        let plan = game.upgradePlan(store)
        let affordable = plan.count > 0 && game.cash >= plan.cost

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                NavigationLink(value: store.id) {
                    HStack(spacing: 12) {
                        KindTile(kind: store.kind)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.displayName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text("\(store.kind.info.title) · Lv.\(store.level) · 직원 \(store.staff)명")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.inkSoft)
                                .lineLimit(1)
                            Text("\(Won.signed(game.income(store)))/초")
                                .font(.num(13, .bold))
                                .foregroundStyle(Palette.up)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    game.upgrade(store.id)
                } label: {
                    VStack(spacing: 2) {
                        Text(plan.count > 0 ? "Lv +\(plan.count)" : "최고")
                            .font(.system(size: 12, weight: .heavy))
                        Text(plan.count > 0 ? Won.short(plan.cost) : "—")
                            .font(.num(13, .bold))
                    }
                    .foregroundStyle(affordable ? .white : Palette.inkFaint)
                    .frame(width: 82, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(affordable ? Palette.sign : Palette.cardDeep)
                    )
                }
                .buttonStyle(PressStyle())
                .disabled(!affordable)
            }
            MilestoneBar(level: store.level)
        }
        .paperCard(padding: 12)
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
                .font(.system(size: 10, weight: .semibold))
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
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Palette.ink))
                if let n = game.news.first {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(n.headline)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(n.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(n.tone == .bad ? Palette.down : n.tone == .good ? Palette.up : Palette.inkSoft)
                            .lineLimit(1)
                    }
                    .id(n.id)
                    .transition(.push(from: .bottom))
                } else {
                    Text("오늘은 조용한 하루").font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                if !game.events.isEmpty {
                    Tag(text: "진행 \(game.events.count)", color: Palette.sign)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
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
                                Text(e.headline).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(e.daysLeft)일 남음").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                    }
                }
                Section("지난 소식") {
                    ForEach(game.news) { n in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(n.day)일차").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.inkSoft)
                                Spacer()
                            }
                            Text(n.headline).font(.myeongjo(16))
                            Text(n.detail)
                                .font(.system(size: 13))
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
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.ink)
            Text(sub)
                .font(.system(size: 10))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("오늘의 할 일").sectionLabel()
                Spacer()
                Text("할 일 탭에서 보상 받기")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkFaint)
            }
            ForEach(game.missions) { m in
                MissionRow(mission: m, compact: true)
            }
        }
        .paperCard(padding: 14)
    }
}
