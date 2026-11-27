import SwiftUI

struct MarketView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case listings = "점포 매물", buildings = "건물", prices = "시세"
        var id: String { rawValue }
    }

    @Environment(Game.self) private var game
    @State private var section: Pane = .listings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("구분", selection: $section) {
                        ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .listings: ListingsList()
                    case .buildings: BuildingsList()
                    case .prices: PriceBoard()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .animation(.easeInOut(duration: 0.25), value: section)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper)
            .safeAreaInset(edge: .top, spacing: 0) { CashHeader() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - 점포 매물

struct ListingsList: View {
    @Environment(Game.self) private var game
    @State private var confirm: Listing?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘의 매물").sectionLabel()
                Spacer()
            }
            if game.listings.isEmpty {
                EmptyNote(title: "매물이 다 팔렸어요", detail: "내일 아침이면 새 매물이 올라옵니다.").paperCard()
            }
            ForEach(game.listings) { l in
                ListingCard(listing: l) { confirm = l }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .scale(scale: 0.85).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.listings.map(\.id))
        .confirmationDialog("이 가게를 인수할까요?", isPresented: Binding(
            get: { confirm != nil }, set: { if !$0 { confirm = nil } }
        ), titleVisibility: .visible) {
            if let l = confirm {
                Button("권리금 \(Won.short(l.price)) + 보증금 \(Won.short(game.newDeposit(l.kind, l.district)))에 인수") { game.buy(l) }
            }
            Button("취소", role: .cancel) { confirm = nil }
        } message: {
            if let l = confirm {
                Text("\(l.name) \(l.district.info.short)점 · \(l.kind.info.title) Lv.\(l.level) · 직원 \(l.staff)명")
            }
        }
    }
}

struct ListingCard: View {
    @Environment(Game.self) private var game
    let listing: Listing
    let onBuy: () -> Void

    var body: some View {
        let l = listing
        let fair = game.fairValue(kind: l.kind, level: l.level, staff: l.staff, district: l.district)
        let gap = fair > 0 ? l.price / fair - 1 : 0
        let income = game.baseIncome(kind: l.kind, level: l.level, staff: l.staff, district: l.district)
        let blocker = game.buyBlocker(l)
        let daysLeft = l.expiresDay - game.day

        let deposit = game.newDeposit(l.kind, l.district)
        let monthly = game.baseRent(l.kind, l.district) * Lease.daysPerMonth

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                BrandLogo(name: l.name, color: l.kind.color, size: 54, badge: l.kind.info.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(l.name) \(l.district.info.short)점")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        Text("Lv.\(l.level)").font(.num(14, .heavy)).foregroundStyle(l.kind.color)
                        Text(l.kind.info.title).font(.system(size: 14)).foregroundStyle(Palette.inkSoft)
                        Text("D-\(max(0, daysLeft))")
                            .font(.num(13, .semibold))
                            .foregroundStyle(daysLeft <= 0 ? Palette.sign : Palette.inkFaint)
                    }
                }
                Spacer(minLength: 0)
                if gap < -0.12 {
                    Tag(text: "급매 \(Won.percent(gap))", color: Palette.down, filled: true)
                } else if gap > 0.12 {
                    Tag(text: "프리미엄", color: Palette.gold)
                }
            }

            HStack(spacing: 0) {
                miniStat("초당", Won.short(income), Palette.up)
                miniStat("보증금", deposit > 0 ? Won.short(deposit) : "없음", Palette.ink)
                miniStat("월세", deposit > 0 ? Won.short(monthly) : "없음", Palette.ink)
            }
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardDeep.opacity(0.6)))

            Button(action: onBuy) {
                HStack {
                    Text(blocker ?? "인수하기")
                    Spacer()
                    Text("권리금 \(Won.short(l.price))").font(.num(17, .heavy))
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(SignButtonStyle(enabled: blocker == nil))
            .disabled(blocker != nil)
        }
        .paperCard(padding: 16)
    }

    private func miniStat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.num(16, .bold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 건물

struct BuildingsList: View {
    @Environment(Game.self) private var game
    @State private var selling: BuildingSpec?
    @State private var buying: BuildingSpec?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("사면 매일 월세 수입 · 그 지역 내 가게 임대료 0원", systemImage: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkSoft)

            VStack(spacing: 12) {
            ForEach(DistrictID.allCases) { d in
                if game.isUnlocked(d) {
                    districtBlock(d)
                } else {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("\(d.info.name) · \(Rank.all[d.info.unlockRank].title) 되면 열림")
                        Spacer()
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.inkFaint)
                    .paperCard(padding: 12)
                }
            }
            }
            .confirmationDialog("건물을 매입할까요?", isPresented: Binding(
                get: { buying != nil }, set: { if !$0 { buying = nil } }
            ), titleVisibility: .visible) {
                if let b = buying {
                    Button("\(Won.full(game.buildingPrice(b)))에 매입") { game.buyBuilding(b) }
                }
                Button("취소", role: .cancel) { buying = nil }
            }
        }
        .confirmationDialog("건물을 팔까요?", isPresented: Binding(
            get: { selling != nil }, set: { if !$0 { selling = nil } }
        ), titleVisibility: .visible) {
            if let b = selling {
                Button("\(Won.full(game.buildingPrice(b) * (1 - game.tradeFee)))에 매도", role: .destructive) {
                    game.sellBuilding(b)
                }
            }
            Button("취소", role: .cancel) { selling = nil }
        } message: {
            Text("수수료·세금 \(Int(game.tradeFee * 100))%를 뗀 금액이 들어옵니다.")
        }
    }

    private func districtBlock(_ d: DistrictID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(d.info.name).font(.myeongjo(16))
                Spacer()
                let m = game.market(d)
                Text("지수 \(String(format: "%.1f", m.index * 100)) \(Won.percent(m.change))")
                    .font(.num(13, .bold))
                    .foregroundStyle(trendColor(m.change))
            }
            .padding(.bottom, 8)

            ForEach(d.buildings) { spec in
                buildingRow(spec)
                if spec.id != d.buildings.last?.id { Divider().overlay(Palette.line) }
            }
        }
        .paperCard(padding: 14)
    }

    private func buildingRow(_ spec: BuildingSpec) -> some View {
        let price = game.buildingPrice(spec)
        let owned = game.buildings.first { $0.id == spec.id }
        let rent = price * Economy.buildingDailyYield

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(spec.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    if owned != nil { Tag(text: "보유", color: Palette.gold, filled: true) }
                }
                Text("월세 \(Won.short(rent))/일")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
                if let o = owned {
                    let pnl = price * (1 - game.tradeFee) - o.purchasePrice
                    Text("매입가 \(Won.short(o.purchasePrice)) · 평가손익 \(Won.signed(pnl))")
                        .font(.num(13, .semibold))
                        .foregroundStyle(trendColor(pnl))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(Won.short(price)).font(.myeongjo(15)).foregroundStyle(Palette.ink)
                if owned != nil {
                    Button("매도") { selling = spec }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.down)
                } else {
                    Button("매입") { buying = spec }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(game.cash >= price ? Palette.sign : Palette.inkFaint)
                        .disabled(game.cash < price)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - 시세판

struct PriceBoard: View {
    @Environment(Game.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("지역 시세").sectionLabel()
            ForEach(DistrictID.allCases) { d in
                row(d)
            }
        }
    }

    private func row(_ d: DistrictID) -> some View {
        let m = game.market(d)
        let unlocked = game.isUnlocked(d)
        let trend = (m.history.last ?? 1) - (m.history.first ?? 1)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if !unlocked { Image(systemName: "lock.fill").font(.system(size: 12)) }
                    Text(d.info.name).font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(unlocked ? Palette.ink : Palette.inkFaint)
                Text("내 점포 \(game.stores(in: d).count) · 건물 \(game.buildings.filter { $0.district == d }.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(width: 112, alignment: .leading)

            Sparkline(values: m.history, color: trendColor(trend))
                .frame(height: 34)
                .opacity(unlocked ? 1 : 0.4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", m.index * 100))
                    .font(.num(18, .bold))
                    .foregroundStyle(Palette.ink)
                Text(arrow(m.change) + Won.percent(m.change, signed: false))
                    .font(.num(13, .bold))
                    .foregroundStyle(trendColor(m.change))
            }
            .frame(width: 64, alignment: .trailing)
        }
        .paperCard(padding: 12)
    }

    private func arrow(_ v: Double) -> String {
        if v > 0.0005 { return "▲ " }
        if v < -0.0005 { return "▼ " }
        return ""
    }
}
