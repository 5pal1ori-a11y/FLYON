import SwiftUI

/// 자산 탭 — 실제 거래소 앱처럼: 내 보유자산 요약 → TRADEX → 거래소 지갑 → 보유 코인 → 보유 포지션
struct AssetsView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var chargeTarget: ChargeTarget?
    @State private var transferTarget: ExchangeID?
    @State private var showChargeMenu = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    summaryCard.appear(0)
                    tradexSection.appear(0.05)
                    walletsSection.appear(0.1)
                    coinsSection.appear(0.15)
                    positionsSection.appear(0.2)
                    moreSection.appear(0.25)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Theme.background)
            .navigationTitle("자산")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ExchangePicker(selection: Binding(get: { store.exchange }, set: { new in Task { await store.select(new) } }))
                }
            }
            .navigationDestination(for: Market.self) { CoinDetailView(market: $0) }
            .sheet(item: $chargeTarget) { t in
                ChargeSheet(target: t).presentationDetents([.medium])
            }
            .sheet(item: $transferTarget) { e in
                TransferSheet(exchange: e).presentationDetents([.medium])
            }
            .confirmationDialog("어디에 충전할까요?", isPresented: $showChargeMenu, titleVisibility: .visible) {
                Button("\(store.exchange.name) 현물") { chargeTarget = ChargeTarget(exchange: store.exchange, futures: false) }
                Button("\(store.exchange.name) 선물") { chargeTarget = ChargeTarget(exchange: store.exchange, futures: true) }
            }
            .task {
                // 선택하지 않은 거래소의 보유 코인·포지션 시세도 받아 와서 평가에 반영
                for e in ExchangeID.allCases where e != store.exchange {
                    let a = wallet.account(e)
                    let codes = Array(Set(a.holdings.keys).union(a.positions.map(\.market)))
                    await store.refreshSnapshot(for: e, markets: codes)
                }
            }
        }
    }

    // MARK: - 내 보유자산 (선택한 거래소)

    private var summaryCard: some View {
        let ex = store.exchange
        let v = wallet.valuation(ex, prices: store.tickers)
        let holdingsTotal = v.coinValue + v.krw + v.futuresKRW + v.positionValue
        let pnl = v.coinPnL + v.futuresPnL
        let invested = v.coinCost + v.positionMargin
        let rate = invested > 0 ? pnl / invested : 0
        let all = wallet.totalValuation { store.prices(for: $0) }
        let allPnL = all.total - wallet.baseValue
        let allRate = wallet.baseValue > 0 ? allPnL / wallet.baseValue : 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("내 보유자산").font(.headline)
                Spacer()
                Text("단위 KRW").font(.caption2).foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 0) {
                bigValue("주문가능 KRW", v.krw)
                Divider().frame(height: 44).padding(.horizontal, 14)
                bigValue("총 보유자산", holdingsTotal)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    gridLabel("코인 평가"); gridValue(Fmt.number(v.coinValue))
                    gridLabel("평가손익"); gridValue(Fmt.signedKRW(pnl), Theme.color(for: pnl))
                }
                GridRow {
                    gridLabel("선물 평가"); gridValue(Fmt.number(v.futuresKRW + v.positionValue))
                    gridLabel("수익률"); gridValue(Fmt.rate(rate), Theme.color(for: pnl))
                }
            }

            HStack {
                Text("모의투자 자산을 충전해 보세요").font(.subheadline)
                Spacer()
                Button {
                    showChargeMenu = true
                } label: {
                    Label("충전하기", systemImage: "plus").font(.subheadline.weight(.bold))
                }
                .buttonStyle(BWButtonStyle(selected: true, cornerRadius: 10, verticalPadding: 10))
                .disabled(wallet.state.tradex == 0)
                .opacity(wallet.state.tradex == 0 ? 0.4 : 1)
            }
            .padding(12)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 6) {
                Text("전체 자산(모든 거래소 + TRADEX)").foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.krw(all.total)).fontWeight(.semibold)
                Text("(\(Fmt.rate(allRate)))").foregroundStyle(Theme.color(for: allPnL))
            }
            .font(.caption)
            .monospacedDigit()
        }
        .card()
    }

    private func bigValue(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Fmt.number(value))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: value))
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gridLabel(_ t: String) -> some View {
        Text(t).font(.caption).foregroundStyle(.secondary)
    }

    private func gridValue(_ t: String, _ color: Color = .primary) -> some View {
        Text(t).font(.subheadline.weight(.semibold)).foregroundStyle(color).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentTransition(.numericText())
            .animation(.snappy, value: t)
    }

    // MARK: - TRADEX

    private var tradexSection: some View {
        section("TRADEX") {
            Button {
                showChargeMenu = true
            } label: {
                HStack(spacing: 14) {
                    Image("Logo").resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(9)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(wallet.state.tradex) TRADEX").font(.headline).monospacedDigit()
                        Text("\(wallet.state.tradex) TRADEX → \(Fmt.krw(Double(wallet.state.tradex) * TradexRules.krwPerTradex)) 충전 가능")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
                .card()
            }
            .buttonStyle(.plain)
            .disabled(wallet.state.tradex == 0)
        }
    }

    // MARK: - 거래소 지갑 (사용 가능 잔액)

    private var walletsSection: some View {
        section("거래소 지갑") {
            VStack(spacing: 12) {
                ForEach(ExchangeID.allCases) { exchangeCard($0) }
            }
        }
    }

    private func exchangeCard(_ e: ExchangeID) -> some View {
        let a = wallet.account(e)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ExchangeBadge(exchange: e)
                Text(e.name).font(.headline)
                Text("(사용 가능 잔액)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    transferTarget = e
                } label: {
                    Image(systemName: "arrow.left.arrow.right").font(.caption.weight(.semibold))
                }
                .buttonStyle(BWButtonStyle(verticalPadding: 6))
                .accessibilityLabel("\(e.name) 현물·선물 이동")
            }
            .padding(.bottom, 12)
            Divider()
            walletRow("현물", a.krw, inUse: store.exchange == e && !a.holdings.isEmpty) {
                chargeTarget = ChargeTarget(exchange: e, futures: false)
            }
            Divider()
            walletRow("선물", a.futuresKRW, inUse: store.exchange == e && !a.positions.isEmpty) {
                chargeTarget = ChargeTarget(exchange: e, futures: true)
            }
        }
        .card()
    }

    private func walletRow(_ title: String, _ amount: Double, inUse: Bool, charge: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    if inUse {
                        Text("현재 사용").font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.4), lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text("\(Fmt.number(amount)) 원")
                    .font(.title3.weight(.bold)).monospacedDigit()
                    .contentTransition(.numericText(value: amount))
                    .animation(.snappy, value: amount)
            }
            Spacer()
            Button("충전하기", action: charge)
                .buttonStyle(BWButtonStyle(selected: true, cornerRadius: 10, verticalPadding: 9))
                .disabled(wallet.state.tradex == 0)
                .opacity(wallet.state.tradex == 0 ? 0.4 : 1)
        }
        .padding(.vertical, 12)
        .animation(.snappy, value: inUse)
    }

    // MARK: - 보유 코인

    private var coinsSection: some View {
        let a = wallet.account(store.exchange)
        let prices = store.tickers
        let rows = a.holdings.sorted { x, y in
            (prices[x.key]?.tradePrice ?? x.value.averagePrice) * x.value.quantity >
                (prices[y.key]?.tradePrice ?? y.value.averagePrice) * y.value.quantity
        }
        return section("보유 코인") {
            if rows.isEmpty {
                Text(a.krw > 0 ? "거래소 탭에서 첫 코인을 사 보세요." : "\(store.exchange.name) 현물 지갑을 충전한 뒤 거래할 수 있어요.")
                    .font(.subheadline).foregroundStyle(.secondary).card()
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.key) { code, h in
                        if let m = store.market(code) {
                            NavigationLink(value: m) { holdingRow(m, h) }.buttonStyle(.plain)
                            if code != rows.last?.key { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
    }

    private func holdingRow(_ m: Market, _ h: Holding) -> some View {
        let price = store.tickers[m.market]?.tradePrice ?? h.averagePrice
        let pnl = (price - h.averagePrice) * h.quantity
        let rate = h.averagePrice > 0 ? price / h.averagePrice - 1 : 0
        return HStack(spacing: 12) {
            CoinIcon(symbol: m.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.qty(h.quantity)) \(m.symbol)").font(.body.weight(.semibold)).monospacedDigit()
                Text("≈ \(Fmt.krw(price * h.quantity))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.signedKRW(pnl)).font(.subheadline.weight(.semibold))
                Text("(\(Fmt.rate(rate)))").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.color(for: pnl))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy, value: pnl)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - 보유 포지션

    private var positionsSection: some View {
        let positions = wallet.account(store.exchange).positions
        return section("보유 포지션 \(positions.count)") {
            if positions.isEmpty {
                Text("열린 포지션이 없어요. 코인 화면의 ‘선물’에서 롱·숏을 연습해 보세요.")
                    .font(.subheadline).foregroundStyle(.secondary).card()
            } else {
                VStack(spacing: 10) {
                    ForEach(positions) { p in
                        PositionRow(position: p, price: store.tickers[p.market]?.tradePrice, exchange: store.exchange)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: positions.map(\.id))
            }
        }
    }

    // MARK: - 투자 관리

    private var moreSection: some View {
        let a = wallet.account(store.exchange)
        return section("투자 관리") {
            VStack(spacing: 0) {
                NavigationLink {
                    PortfolioAnalysisView()
                } label: {
                    listRow("sparkles", "AI 투자 분석", "Apple Intelligence")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 44)
                NavigationLink {
                    TradeHistoryView()
                } label: {
                    listRow("list.bullet.rectangle", "\(store.exchange.name) 거래 내역", "\(a.trades.count + a.futuresHistory.count)건")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private func listRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.body).frame(width: 28)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            content()
        }
    }
}

struct ChargeTarget: Identifiable, Hashable {
    let exchange: ExchangeID
    let futures: Bool
    var id: String { "\(exchange.rawValue)-\(futures)" }
}

/// TRADEX → 거래소 현물/선물 지갑 충전
struct ChargeSheet: View {
    let target: ChargeTarget
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var count = 1
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ExchangeBadge(exchange: target.exchange)
                Text("\(target.exchange.name) \(target.futures ? "선물" : "현물") 충전").font(.title3.bold())
            }
            .padding(.top, 8)
            Text("보유 \(wallet.state.tradex) TRADEX · 1 TRADEX = \(Fmt.krw(TradexRules.krwPerTradex))")
                .font(.footnote).foregroundStyle(.secondary)

            if wallet.state.tradex == 0 {
                Text("충전할 TRADEX가 없어요.").foregroundStyle(.secondary).padding(.vertical, 30)
            } else {
                HStack(spacing: 24) {
                    stepButton("minus") { count = max(1, count - 1) }
                    VStack(spacing: 4) {
                        Text("\(count) TRADEX").font(.system(size: 30, weight: .bold)).monospacedDigit()
                        Text("→ \(Fmt.krw(Double(count) * TradexRules.krwPerTradex))").font(.headline).foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 170)
                    stepButton("plus") { count = min(wallet.state.tradex, count + 1) }
                }
                Button("전부 선택") { count = wallet.state.tradex }.font(.subheadline)
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.rise) }
                Button("충전하기") {
                    do {
                        try wallet.charge(tradex: count, to: target.exchange, futures: target.futures)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("충전한 모의투자금은 TRADEX로 되돌릴 수 없어요. 같은 거래소의 현물·선물 사이에서는 옮길 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3.weight(.bold)).frame(width: 48, height: 48)
                .foregroundStyle(.primary)
                .overlay(Circle().strokeBorder(Color.primary, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce, value: count)
    }
}

/// 같은 거래소 안에서 현물 ↔ 선물 원화 이동
struct TransferSheet: View {
    let exchange: ExchangeID
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var toFutures = true
    @State private var amountText = ""
    @State private var error: String?

    private var available: Double {
        let a = wallet.account(exchange)
        return toFutures ? a.krw : a.futuresKRW
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ExchangeBadge(exchange: exchange)
                Text("\(exchange.name) 지갑 이동").font(.title3.bold())
            }
            .padding(.top, 8)
            BWSegmented(options: [(true, "현물 → 선물"), (false, "선물 → 현물")], selection: $toFutures)
            TextField("옮길 금액 (원)", text: $amountText)
                .keyboardType(.numberPad)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Text("이동 가능 \(Fmt.krw(available))").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("전액") { amountText = String(Int(floor(available))) }
                    .buttonStyle(BWButtonStyle(verticalPadding: 5))
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.rise) }
            Button("옮기기") {
                do {
                    try wallet.transfer(Double(amountText) ?? 0, in: exchange, toFutures: toFutures)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}

struct TradeHistoryView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    var body: some View {
        let account = wallet.account(store.exchange)
        List {
            Section("현물") {
                if account.trades.isEmpty {
                    Text("아직 거래 내역이 없어요.").foregroundStyle(.secondary)
                }
                ForEach(account.trades) { t in
                    HStack {
                        badge(t.side == .buy ? "매수" : "매도", t.side == .buy ? Theme.rise : Theme.fall)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.koreanName).font(.subheadline.weight(.semibold))
                            Text(t.date, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.krw(t.price * t.quantity)).font(.subheadline).monospacedDigit()
                            if let pnl = t.realizedPnL {
                                Text("실현 \(Fmt.signedKRW(pnl))원").font(.caption).foregroundStyle(Theme.color(for: pnl))
                            } else {
                                Text("@ \(Fmt.price(t.price))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .monospacedDigit()
                    }
                }
            }
            Section("선물") {
                if account.futuresHistory.isEmpty {
                    Text("종료한 포지션이 없어요.").foregroundStyle(.secondary)
                }
                ForEach(account.futuresHistory) { r in
                    HStack {
                        badge(r.side.title, r.side == .long ? .green : Theme.rise)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(r.koreanName) \(r.leverage)×").font(.subheadline.weight(.semibold))
                            Text(r.closedAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Fmt.signedKRW(r.pnl))원").font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.color(for: r.pnl))
                            Text(r.liquidated ? "청산됨" : "@ \(Fmt.price(r.exitPrice))")
                                .font(.caption).foregroundStyle(r.liquidated ? Theme.rise : .secondary)
                        }
                        .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("\(store.exchange.name) 거래 내역")
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}
