import SwiftUI

/// 자산 탭 — 총 자산과 구성, 거래소 지갑, 내 코인, 선물 포지션
struct AssetsView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var chargeTarget: ChargeTarget?
    @State private var transferTarget: ExchangeID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    walletSection
                    coinsSection
                    positionsSection
                    tilesSection
                    historyRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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

    // MARK: - 총 자산

    private var header: some View {
        let t = wallet.totalValuation { store.prices(for: $0) }
        let pnl = t.total - wallet.baseValue
        let rate = wallet.baseValue > 0 ? pnl / wallet.baseValue : 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("총 자산").font(.subheadline).foregroundStyle(.secondary)
            Text(Fmt.krw(t.total))
                .font(.system(size: 36, weight: .bold))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: t.total))
                .animation(.snappy, value: t.total)
            HStack(spacing: 6) {
                Image(systemName: pnl >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
                Text("\(Fmt.signedKRW(pnl))원 (\(Fmt.rate(rate)))")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.color(for: pnl))
            .monospacedDigit()

            AllocationBar(segments: [
                .init(label: "코인", value: t.coinValue, color: .orange),
                .init(label: "선물", value: t.futuresKRW + t.positionValue, color: .purple),
                .init(label: "원화", value: t.krw, color: .teal),
                .init(label: "TRADEX", value: t.tradexValue, color: .primary),
            ])
            .padding(.top, 10)
        }
    }

    // MARK: - 거래소 지갑

    private var walletSection: some View {
        let ex = store.exchange
        let a = wallet.account(ex)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("거래소 지갑")
            ExchangeSegment(selection: ex) { new in Task { await store.select(new) } }
            VStack(spacing: 0) {
                walletRow(icon: "bitcoinsign.circle.fill", tint: .orange, title: "현물", amount: a.krw) {
                    chargeTarget = ChargeTarget(exchange: ex, futures: false)
                }
                Divider().padding(.leading, 52)
                walletRow(icon: "chart.line.uptrend.xyaxis.circle.fill", tint: .purple, title: "선물", amount: a.futuresKRW) {
                    chargeTarget = ChargeTarget(exchange: ex, futures: true)
                }
                Divider().padding(.leading, 52)
                Button {
                    transferTarget = ex
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("현물 ↔ 선물 이동")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private func walletRow(icon: String, tint: Color, title: String, amount: Double, charge: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title) 주문가능").font(.caption).foregroundStyle(.secondary)
                Text(Fmt.krw(amount)).font(.headline).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            Button("충전", action: charge)
                .buttonStyle(PillButtonStyle())
                .disabled(wallet.state.tradex == 0)
                .opacity(wallet.state.tradex == 0 ? 0.35 : 1)
        }
        .padding(.vertical, 14)
    }

    // MARK: - 내 코인

    private var coinsSection: some View {
        let a = wallet.account(store.exchange)
        let prices = store.tickers
        let rows = a.holdings.sorted { x, y in
            (prices[x.key]?.tradePrice ?? x.value.averagePrice) * x.value.quantity >
                (prices[y.key]?.tradePrice ?? y.value.averagePrice) * y.value.quantity
        }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("내 코인") {
                Text("\(rows.count)개").font(.subheadline).foregroundStyle(.secondary)
            }
            if rows.isEmpty {
                emptyState("bitcoinsign.circle", a.krw > 0 ? "거래소 탭에서 첫 코인을 사 보세요" : "현물 지갑을 충전하면 거래할 수 있어요")
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
        let value = price * h.quantity
        let pnl = (price - h.averagePrice) * h.quantity
        let rate = h.averagePrice > 0 ? price / h.averagePrice - 1 : 0
        return HStack(spacing: 12) {
            CoinIcon(symbol: m.symbol, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(m.koreanName).font(.body.weight(.semibold)).lineLimit(1)
                Text("\(Fmt.qty(h.quantity)) \(m.symbol)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.krw(value)).font(.body.weight(.semibold)).monospacedDigit()
                Text("\(Fmt.signedKRW(pnl)) (\(Fmt.rate(rate)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.color(for: pnl))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - 선물 포지션

    private var positionsSection: some View {
        let positions = wallet.account(store.exchange).positions
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("선물 포지션") {
                Text("\(positions.count)개").font(.subheadline).foregroundStyle(.secondary)
            }
            if positions.isEmpty {
                emptyState("chart.line.uptrend.xyaxis", "코인 화면의 ‘선물’에서 롱·숏을 연습해 보세요")
            } else {
                VStack(spacing: 0) {
                    ForEach(positions) { p in
                        if let m = store.market(p.market) {
                            NavigationLink(value: m) { positionRow(p) }.buttonStyle(.plain)
                        } else {
                            positionRow(p)
                        }
                        if p.id != positions.last?.id { Divider().padding(.leading, 56) }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
    }

    private func positionRow(_ p: FuturesPosition) -> some View {
        let price = store.tickers[p.market]?.tradePrice ?? p.entryPrice
        let pnl = p.pnl(at: price)
        let color: Color = pnl > 0 ? .green : (pnl < 0 ? Theme.rise : .secondary)
        return HStack(spacing: 12) {
            CoinIcon(symbol: p.symbol, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(p.koreanName).font(.body.weight(.semibold)).lineLimit(1)
                HStack(spacing: 4) {
                    Text(p.side.title).foregroundStyle(p.side == .long ? .green : Theme.rise)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(p.leverage)×")
                    Text("·").foregroundStyle(.tertiary)
                    Text("청산 \(Fmt.price(p.liquidationPrice))").foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Fmt.signedKRW(pnl))원").font(.body.weight(.semibold))
                Text(Fmt.rate(p.roe(at: price))).font(.caption.weight(.semibold))
            }
            .foregroundStyle(color)
            .monospacedDigit()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - TRADEX · AI 타일

    private var tilesSection: some View {
        HStack(spacing: 12) {
            tile {
                Image("Logo").resizable().scaledToFit().frame(height: 22)
            } title: {
                "\(wallet.state.tradex) TRADEX"
            } subtitle: {
                "1개 = \(Fmt.man(TradexRules.krwPerTradex)) 원"
            }

            NavigationLink {
                PortfolioAnalysisView()
            } label: {
                tile {
                    Image(systemName: "sparkles").font(.title2)
                } title: {
                    "AI 투자 분석"
                } subtitle: {
                    "Apple Intelligence"
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func tile<Icon: View>(@ViewBuilder icon: () -> Icon, title: () -> String, subtitle: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            icon().frame(height: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title()).font(.headline).monospacedDigit()
                Text(subtitle()).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    // MARK: - 거래 내역

    private var historyRow: some View {
        let a = wallet.account(store.exchange)
        return NavigationLink {
            TradeHistoryView()
        } label: {
            HStack(spacing: 12) {
                IconTile(systemName: "list.bullet.rectangle", tint: .gray, size: 30)
                Text("\(store.exchange.name) 거래 내역").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(a.trades.count + a.futuresHistory.count)건").font(.subheadline).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(.tertiary)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
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
