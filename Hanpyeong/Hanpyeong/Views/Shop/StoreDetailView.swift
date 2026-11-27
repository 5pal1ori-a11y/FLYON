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
            VStack(spacing: 14) {
                Storefront(kind: s.kind, name: s.name, height: 196)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                Text(s.kind.info.blurb)
                    .font(.myeongjo(14, bold: false))
                    .foregroundStyle(Palette.inkSoft)

                numbers(s)
                levelCard(s)
                staffCard(s)
                sellCard(s)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 숫자

    private func numbers(_ s: Store) -> some View {
        let rent = game.rent(s)
        let wages = game.wages(s)
        let net = game.dailyNet(s)
        let mod = game.modifier(kind: s.kind, district: s.district)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("영업 현황").sectionLabel()
                Spacer()
                if abs(mod - 1) > 0.001 {
                    Tag(text: "뉴스 영향 \(Won.percent(mod - 1))", color: trendColor(mod - 1))
                }
            }
            HStack {
                StatCell(label: "초당 매출", value: Won.signed(game.income(s)), tint: Palette.up)
                StatCell(label: "하루 순이익", value: Won.signed(net), tint: trendColor(net))
            }
            HStack {
                StatCell(label: "임대료/일",
                         value: rent == 0 ? "내 건물 · 0" : Won.short(rent))
                StatCell(label: "인건비/일", value: Won.short(wages))
            }
            HStack {
                StatCell(label: "지금 팔면 (시세)", value: Won.short(game.valuation(s)))
                StatCell(label: "들인 돈", value: Won.short(s.invested))
            }
        }
        .paperCard()
    }

    // MARK: 레벨

    private func levelCard(_ s: Store) -> some View {
        @Bindable var game = game
        let plan = game.upgradePlan(s)
        let affordable = plan.count > 0 && game.cash >= plan.cost
        let gain = plan.count > 0
            ? game.baseIncome(kind: s.kind, level: s.level + plan.count, staff: s.staff, district: s.district)
              - game.baseIncome(kind: s.kind, level: s.level, staff: s.staff, district: s.district)
            : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("가게 키우기").sectionLabel()
                Spacer()
                Text("Lv.\(s.level)")
                    .font(.myeongjo(22))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("/ \(Economy.maxLevel)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkFaint)
            }
            MilestoneBar(level: s.level)
            Picker("구매 단위", selection: $game.bulk) {
                ForEach(BulkMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Button {
                game.upgrade(s.id)
            } label: {
                HStack {
                    Text(plan.count > 0 ? "Lv +\(plan.count) · 초당 \(Won.signed(gain))" : "최고 레벨")
                    Spacer()
                    Text(plan.count > 0 ? Won.full(plan.cost) : "")
                        .font(.num(14, .bold))
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(SignButtonStyle(enabled: affordable))
            .disabled(!affordable)
        }
        .paperCard()
    }

    // MARK: 직원

    private func staffCard(_ s: Store) -> some View {
        let info = s.kind.info
        let hire = game.hireCost(s)
        let canHire = s.staff < info.maxStaff && game.cash >= hire

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("직원").sectionLabel()
                Spacer()
                Text("1명당 매출 +\(Int(Economy.staffBoost * 100))% · 일당 \(Won.short(info.wage))")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 6) {
                ForEach(0..<info.maxStaff, id: \.self) { i in
                    Image(systemName: i < s.staff ? "person.fill" : "person")
                        .font(.system(size: 20))
                        .foregroundStyle(i < s.staff ? s.kind.color : Palette.inkFaint)
                        .frame(maxWidth: 34)
                }
                Spacer(minLength: 0)
            }
            .animation(.snappy, value: s.staff)

            HStack(spacing: 10) {
                Button("내보내기") { game.fire(s.id) }
                    .buttonStyle(LineButtonStyle())
                    .disabled(s.staff == 0)
                    .opacity(s.staff == 0 ? 0.5 : 1)
                Button {
                    game.hire(s.id)
                } label: {
                    Text(s.staff >= info.maxStaff ? "자리 꽉 참" : "채용 · \(Won.short(hire))")
                }
                .buttonStyle(SignButtonStyle(enabled: canHire))
                .disabled(!canHire)
            }
            Text("직원 일당이 늘어난 매출보다 크면 손해예요. 레벨이 낮을 땐 혼자 버티는 게 낫습니다.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkFaint)
        }
        .paperCard()
    }

    // MARK: 매각

    private func sellCard(_ s: Store) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("매각").sectionLabel()
            Text("\(s.district.info.name) 시세지수 \(String(format: "%.1f", game.index(s.district) * 100)). 시세가 좋을 때 팔면 차익이 남아요.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
            Button("매수 희망자 받아보기") {
                offers = game.offers(for: s)
                showSell = true
            }
            .buttonStyle(LineButtonStyle())
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

                    Text("중개수수료와 세금 \(Int(Economy.tradeFee * 100))%를 떼고 입금됩니다. 지금 들인 돈은 \(Won.full(store.invested))입니다.")
                        .font(.system(size: 12))
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
        let proceeds = o.price * (1 - Economy.tradeFee)
        let profit = proceeds - store.invested
        return Button {
            picked = o
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.inkFaint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(o.buyer).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("“\(o.note)”").font(.myeongjo(12, bold: false)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Won.short(o.price)).font(.myeongjo(18)).foregroundStyle(Palette.ink)
                    Text("손익 \(Won.signed(profit))").font(.num(11, .bold)).foregroundStyle(trendColor(profit))
                }
            }
            .paperCard(padding: 14)
        }
        .buttonStyle(PressStyle())
    }
}
