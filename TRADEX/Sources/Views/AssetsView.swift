import SwiftUI

/// 자산 탭 — 전체 자산, 거래소별 현물·선물 지갑, 보유 코인, 선물 포지션
struct AssetsView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var chargeTarget: ChargeTarget?
    @State private var transferTarget: ExchangeID?

    var body: some View {
        let total = wallet.totalValuation { store.prices(for: $0) }
        let pnl = total.total - wallet.baseValue
        let rate = wallet.baseValue > 0 ? pnl / wallet.baseValue : 0
        let ex = store.exchange
        let account = wallet.account(ex)
        let prices = store.tickers

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 총 자산 (모든 거래소 + TRADEX)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("총 자산").font(.subheadline).foregroundStyle(.secondary)
                        Text(Fmt.krw(total.total))
                            .font(.system(size: 32, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: total.total))
                            .animation(.snappy, value: total.total)
                        Text("\(Fmt.signedKRW(pnl))원 (\(Fmt.rate(rate)))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.color(for: pnl))
                            .monospacedDigit()
                        Divider().padding(.vertical, 8)
                        HStack(alignment: .top) {
                            summary("코인 평가", "≈ \(Fmt.krw(total.coinValue))")
                            summary("선물 평가", "≈ \(Fmt.krw(total.futuresKRW + total.positionValue))")
                            summary("TRADEX", "\(wallet.state.tradex)개")
                        }
                    }
                    .card()

                    // 거래소별 지갑 (사용 가능 잔액)
                    ForEach(ExchangeID.allCases) { e in
                        exchangeCard(e)
                    }

                    // TRADEX
                    section("TRADEX") {
                        HStack(spacing: 14) {
                            Image("Logo")
                                .resizable().scaledToFit()
                                .frame(width: 26, height: 26)
                                .padding(8)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(wallet.state.tradex) TRADEX").font(.headline).monospacedDigit()
                                Text("1 TRADEX = \(Fmt.krw(TradexRules.krwPerTradex)) · 거래소 지갑에 충전해 사용해요")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .card()
                    }

                    // AI 분석
                    NavigationLink {
                        PortfolioAnalysisView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI 투자 분석").font(.headline)
                                Text("Apple Intelligence가 내 투자 습관을 분석해요").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)

                    // 선택한 거래소의 보유 코인 · 포지션
                    HStack {
                        Text("\(ex.name) 보유 현황").font(.headline)
                        Spacer()
                        ExchangePicker(selection: Binding(get: { store.exchange }, set: { new in Task { await store.select(new) } }))
                    }

                    section("보유 코인") {
                        if account.holdings.isEmpty {
                            Text(account.krw > 0 ? "거래소 탭에서 첫 코인을 사 보세요." : "\(ex.name) 현물 지갑을 충전한 뒤 거래할 수 있어요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .card()
                        } else {
                            VStack(spacing: 0) {
                                let rows = account.holdings.sorted { a, b in
                                    (prices[a.key]?.tradePrice ?? 0) * a.value.quantity > (prices[b.key]?.tradePrice ?? 0) * b.value.quantity
                                }
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

                    section("선물 포지션 \(account.positions.count)") {
                        if account.positions.isEmpty {
                            Text("열린 포지션이 없어요. 코인 화면의 ‘선물’에서 롱·숏을 연습해 보세요.")
                                .font(.subheadline).foregroundStyle(.secondary).card()
                        } else {
                            VStack(spacing: 10) {
                                ForEach(account.positions) { p in
                                    PositionRow(position: p, price: prices[p.market]?.tradePrice, exchange: ex)
                                }
                            }
                        }
                    }

                    NavigationLink {
                        TradeHistoryView()
                    } label: {
                        HStack {
                            Text("\(ex.name) 거래 내역").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(account.trades.count + account.futuresHistory.count)건").font(.subheadline).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("자산")
            .navigationDestination(for: Market.self) { CoinDetailView(market: $0) }
            .sheet(item: $chargeTarget) { t in
                ChargeSheet(target: t).presentationDetents([.medium])
            }
            .sheet(item: $transferTarget) { e in
                TransferSheet(exchange: e).presentationDetents([.medium])
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

    // MARK: - 거래소 카드 (현물 / 선물 + 충전하기)

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
                    Label("이동", systemImage: "arrow.left.arrow.right").font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.bottom, 10)
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    if inUse {
                        Text("현재 사용").font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.4), lineWidth: 1))
                            .foregroundStyle(.primary)
                    }
                }
                Text(Fmt.krw(amount)).font(.title3.weight(.bold)).monospacedDigit()
            }
            Spacer()
            Button("충전하기", action: charge)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .disabled(wallet.state.tradex == 0)
        }
        .padding(.vertical, 12)
    }

    private func summary(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            content()
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
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
                .background(Theme.card, in: Circle())
        }
        .buttonStyle(.plain)
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
            Picker("방향", selection: $toFutures) {
                Text("현물 → 선물").tag(true)
                Text("선물 → 현물").tag(false)
            }
            .pickerStyle(.segmented)
            TextField("옮길 금액 (원)", text: $amountText)
                .keyboardType(.numberPad)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Text("이동 가능 \(Fmt.krw(available))").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("전액") { amountText = String(Int(floor(available))) }.font(.footnote.weight(.semibold))
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
