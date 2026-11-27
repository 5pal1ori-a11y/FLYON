import SwiftUI

struct StoreDetailView: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss
    let storeID: UUID

    @State private var offers: [SaleOffer] = []
    @State private var showSell = false

    var body: some View {
        Group {
            if let s = game.store(storeID) {
                content(s)
            } else {
                EmptyNote(title: "매각된 점포", detail: "이 가게는 이제 다른 사장님의 것이에요.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper)
        .navigationTitle(game.store(storeID)?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSell) {
            if let s = game.store(storeID) {
                SellSheet(store: s, offers: offers) {
                    showSell = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dismiss() }
                }
            }
        }
    }

    private func content(_ s: Store) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                StoreScene(kind: s.kind, name: s.name, dayFraction: game.dayFraction,
                           weather: game.weather, walkers: 3 + min(3, s.staff), height: 230)
                    .padding(.top, 4)

                heroStats(s)
                factorPills(s)
                levelCard(s)
                improvementsCard(s)
                operationsCard(s)
                numbersCard(s)

                Button {
                    offers = game.offers(for: s)
                    showSell = true
                } label: {
                    Label("매수 희망자 받기 · 시세 \(Won.short(game.valuation(s)))", systemImage: "hand.raised.fill")
                }
                .buttonStyle(LineButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 핵심 숫자

    private func heroStats(_ s: Store) -> some View {
        let net = game.dailyNet(s)
        return HStack(spacing: 0) {
            heroCell("초당", Won.signed(game.income(s)), Palette.up)
            Divider().frame(height: 36).overlay(Palette.line)
            heroCell("하루 순이익", Won.signed(net), trendColor(net))
            Divider().frame(height: 36).overlay(Palette.line)
            heroCell("레벨", "\(s.level)", s.kind.color)
        }
        .padding(.vertical, 14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line.opacity(0.7)))
    }

    private func heroCell(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.num(21, .heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 오늘 영향 (아이콘 칩)

    private func factorPills(_ s: Store) -> some View {
        let k = s.kind
        let items: [(String, Double)] = [
            (game.season.symbol, k.seasonFactor(game.season) * s.district.seasonFactor(game.season)),
            (game.weather.symbol, k.weatherFactor(game.weather)),
            ("heart.fill", game.reputationFactor),
            ("person.2.fill", game.talentIncomeFactor(k)),
            ("party.popper.fill", game.holidayFactor(k, s.district)),
            ("dice.fill", k.hitFactor(day: game.day)),
            ("moon.stars.fill", game.phaseFactor(k)),
            ("wrench.and.screwdriver.fill", game.wearFactor(s))
        ].filter { abs($0.1 - 1) >= 0.005 }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(icon: k.sector.symbol, text: "\(k.sector.title) · \(k.info.trait.title)", tint: k.color, filled: true)
                ForEach(Array(items.enumerated()), id: \.offset) { item in
                    pill(icon: item.element.0, text: Won.percent(item.element.1 - 1),
                         tint: trendColor(item.element.1 - 1), filled: false)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.horizontal, -18)
    }

    private func pill(icon: String, text: String, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
            Text(text).font(.num(14, .bold))
        }
        .foregroundStyle(filled ? .white : tint)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(filled ? tint : Palette.card))
        .overlay(Capsule().strokeBorder(filled ? .clear : Palette.line.opacity(0.7)))
    }

    // MARK: 시설 투자 (타일)

    private func improvementsCard(_ s: Store) -> some View {
        let list = Improvement.all.filter { $0.applies(to: s.kind) }
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("시설 투자").sectionLabel()
                Spacer()
                Text("매출 \(Won.percent(game.improvementFactor(s) - 1))")
                    .font(.num(15, .bold))
                    .foregroundStyle(Palette.up)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(list) { imp in
                    improvementTile(imp, s)
                }
            }
        }
        .paperCard()
    }

    private func improvementTile(_ imp: Improvement, _ s: Store) -> some View {
        let done = s.has(imp.id)
        let blocker = game.improvementBlocker(imp, for: s)
        let effect = imp.incomeBoost > 0 ? "매출 +\(Int(imp.incomeBoost * 100))%" : "인건비 -\(Int(imp.wageCut * 100))%"
        return Button {
            game.buyImprovement(imp, for: s.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: imp.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(done ? .white : s.kind.color)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(done ? s.kind.color : s.kind.color.opacity(0.12)))
                    Spacer()
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(s.kind.color)
                    }
                }
                Text(imp.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(done ? effect : (blocker == nil ? Won.short(imp.cost(for: s.kind)) : blocker!))
                    .font(.num(13, .semibold))
                    .foregroundStyle(done ? Palette.up : blocker == nil ? Palette.sign : Palette.inkFaint)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.cardDeep.opacity(done ? 0.4 : 0.7)))
        }
        .buttonStyle(PressStyle())
        .disabled(done || blocker != nil)
    }

    // MARK: 운영 (상태 · 직원 · 임대차)

    private func operationsCard(_ s: Store) -> some View {
        let health = 100 - s.wear
        let repair = game.repairCost(s)
        let info = s.kind.info
        let hire = game.hireCost(s)
        let canHire = s.staff < info.maxStaff && game.cash >= hire

        return VStack(alignment: .leading, spacing: 16) {
            Text("운영").sectionLabel()

            // 시설 상태
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("시설 상태").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(Int(health))%").font(.num(15, .bold))
                            .foregroundStyle(health > 60 ? Palette.ink : Palette.sign)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.line)
                            Capsule().fill(health > 60 ? Color(hex: 0x3E8E5B) : health > 30 ? Palette.gold : Palette.sign)
                                .frame(width: max(4, geo.size.width * health / 100))
                        }
                    }
                    .frame(height: 6)
                }
                smallButton(s.wear < 1 ? "양호" : Won.short(repair), enabled: s.wear >= 1 && game.cash >= repair) {
                    game.repair(s.id)
                }
            }

            // 직원
            if info.maxStaff > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("직원 \(s.staff)/\(info.maxStaff) · 명당 +\(Int(Economy.staffBoost * 100))%")
                            .font(.system(size: 15, weight: .semibold))
                        HStack(spacing: 4) {
                            ForEach(0..<info.maxStaff, id: \.self) { i in
                                Image(systemName: i < s.staff ? "person.fill" : "person")
                                    .font(.system(size: 15))
                                    .foregroundStyle(i < s.staff ? s.kind.color : Palette.inkFaint)
                            }
                        }
                        .animation(.snappy, value: s.staff)
                    }
                    Spacer()
                    Button {
                        game.fire(s.id)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Palette.cardDeep))
                            .foregroundStyle(s.staff > 0 ? Palette.ink : Palette.inkFaint)
                    }
                    .disabled(s.staff == 0)
                    smallButton(s.staff >= info.maxStaff ? "꽉 참" : "+ " + Won.short(hire), enabled: canHire) {
                        game.hire(s.id)
                    }
                }
            }

            // 임대차
            if !game.ownsBuilding(in: s.district) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("보증금 \(Won.short(s.deposit)) · 월세 \(Won.short(game.monthlyRent(s)))")
                            .font(.system(size: 15, weight: .semibold))
                        Text("갱신 D-\(game.leaseDaysLeft(s)) · \(game.renewalRightLeft(s) > 0 ? "인상 상한 5%" : "갱신요구권 만료")")
                            .font(.system(size: 13))
                            .foregroundStyle(game.renewalRightLeft(s) > 0 ? Palette.inkSoft : Palette.sign)
                    }
                    Spacer()
                }
            }
        }
        .paperCard()
    }

    private func smallButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.num(14, .bold))
                .foregroundStyle(enabled ? .white : Palette.inkFaint)
                .padding(.horizontal, 14)
                .frame(minWidth: 72, minHeight: 44)
                .background(Capsule().fill(enabled ? Palette.sign : Palette.cardDeep))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }

    // MARK: 숫자 자세히 (접어두기)

    private func numbersCard(_ s: Store) -> some View {
        DisclosureGroup {
            VStack(spacing: 14) {
                HStack {
                    StatCell(label: "총매출/초", value: Won.short(game.grossIncome(s)))
                    StatCell(label: "원가율", value: "\(Int(s.kind.cogsRatio * 100))%")
                }
                HStack {
                    StatCell(label: "인건비/일", value: Won.short(game.wages(s)))
                    StatCell(label: "들인 돈", value: Won.short(s.invested))
                }
            }
            .padding(.top, 12)
        } label: {
            Text("숫자 자세히").sectionLabel()
        }
        .tint(Palette.inkSoft)
        .paperCard()
    }

    // MARK: 레벨

    private func levelCard(_ s: Store) -> some View {
        @Bindable var game = game
        let plan = game.upgradePlan(s)
        let affordable = plan.count > 0 && game.cash >= plan.cost
        let gain = plan.count > 0
            ? (game.baseIncome(kind: s.kind, level: s.level + plan.count, staff: s.staff, district: s.district)
              - game.baseIncome(kind: s.kind, level: s.level, staff: s.staff, district: s.district))
              * game.improvementFactor(s)
              * game.modifier(kind: s.kind, district: s.district, delivery: s.has("delivery"))
            : 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("가게 키우기").sectionLabel()
                Spacer()
                Picker("구매 단위", selection: $game.bulk) {
                    ForEach(BulkMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            MilestoneBar(level: s.level)
            Button {
                game.upgrade(s.id)
            } label: {
                HStack {
                    Text(plan.count > 0 ? "Lv +\(plan.count)  ·  초당 \(Won.signed(gain))" : "최고 레벨")
                    Spacer()
                    Text(plan.count > 0 ? Won.short(plan.cost) : "")
                        .font(.num(17, .heavy))
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(SignButtonStyle(enabled: affordable))
            .disabled(!affordable)
        }
        .paperCard()
    }
}

// MARK: - 매각 시트

struct SellSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss
    let store: Store
    let offers: [SaleOffer]
    let onSold: () -> Void

    @State private var picked: SaleOffer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(store.displayName), 사겠다는 사람이 \(offers.count)명 왔어요.")
                        .font(.myeongjo(18))
                        .foregroundStyle(Palette.ink)
                        .padding(.bottom, 4)

                    ForEach(offers) { o in
                        offerRow(o)
                    }

                    Text("수수료 \(Int(game.tradeFee * 100))% 차감 · 보증금 \(Won.short(store.deposit)) 별도 반환")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Palette.paper)
            .navigationTitle("매수 제안")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("안 팔래요") { dismiss() } }
            }
            .confirmationDialog("정말 파시겠어요?", isPresented: Binding(
                get: { picked != nil }, set: { if !$0 { picked = nil } }
            ), titleVisibility: .visible) {
                if let o = picked {
                    Button("\(o.buyer)에게 \(Won.short(o.price))에 매각", role: .destructive) {
                        if game.sell(store.id, offer: o) { onSold() }
                    }
                }
                Button("취소", role: .cancel) { picked = nil }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func offerRow(_ o: SaleOffer) -> some View {
        let proceeds = o.price * (1 - game.tradeFee)
        let profit = proceeds - store.invested
        return Button {
            picked = o
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.inkFaint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(o.buyer).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("“\(o.note)”").font(.myeongjo(12, bold: false)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Won.short(o.price)).font(.myeongjo(18)).foregroundStyle(Palette.ink)
                    Text("손익 \(Won.signed(profit))").font(.num(13, .bold)).foregroundStyle(trendColor(profit))
                }
            }
            .paperCard(padding: 14)
        }
        .buttonStyle(PressStyle())
    }
}
