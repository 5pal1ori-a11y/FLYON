import SwiftUI

struct AssetsView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var showExchange = false

    var body: some View {
        let v = wallet.valuation(prices: store.tickers)
        let pnl = v.total - wallet.baseValue
        let rate = wallet.baseValue > 0 ? pnl / wallet.baseValue : 0

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 총 자산
                    VStack(alignment: .leading, spacing: 6) {
                        Text("총 자산").font(.subheadline).foregroundStyle(.secondary)
                        Text(Fmt.krw(v.total))
                            .font(.system(size: 34, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: v.total))
                            .animation(.snappy, value: v.total)
                        Text("\(Fmt.signedKRW(pnl))원 (\(Fmt.rate(rate)))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.color(for: pnl))
                            .monospacedDigit()
                        Divider().padding(.vertical, 10)
                        HStack(alignment: .top) {
                            summary("코인 평가", "≈ \(Fmt.krw(v.coinValue))")
                            summary("원화", Fmt.krw(v.krw))
                        }
                    }
                    .card()

                    // AI 분석
                    NavigationLink {
                        PortfolioAnalysisView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
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

                    // TRADEX
                    section("TRADEX") {
                        Button { showExchange = true } label: {
                            HStack(spacing: 14) {
                                Image("Logo")
                                    .resizable().scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .padding(8)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(wallet.state.tradex) TRADEX").font(.headline).monospacedDigit()
                                    Text("\(wallet.state.tradex) TRADEX → \(Fmt.krw(v.tradexValue)) 교환 가능")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .card()
                        }
                        .buttonStyle(.plain)
                    }

                    // 보유 코인
                    section("보유 코인") {
                        if wallet.state.holdings.isEmpty {
                            Text(v.krw > 0 ? "거래소 탭에서 첫 코인을 사 보세요." : "TRADEX를 교환한 뒤 거래를 시작할 수 있어요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .card()
                        } else {
                            VStack(spacing: 0) {
                                let rows = wallet.state.holdings.sorted { a, b in
                                    (store.tickers[a.key]?.tradePrice ?? 0) * a.value.quantity > (store.tickers[b.key]?.tradePrice ?? 0) * b.value.quantity
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

                    NavigationLink {
                        TradeHistoryView()
                    } label: {
                        HStack {
                            Text("거래 내역").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(wallet.state.trades.count)건").font(.subheadline).foregroundStyle(.secondary)
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
            .sheet(isPresented: $showExchange) {
                TradexExchangeSheet().presentationDetents([.medium])
            }
        }
    }

    private func summary(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
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

/// TRADEX → 모의 원화 교환
struct TradexExchangeSheet: View {
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var count = 1
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("TRADEX 교환").font(.title3.bold()).padding(.top, 8)
            Text("보유 \(wallet.state.tradex) TRADEX · 1 TRADEX = \(Fmt.krw(TradexRules.krwPerTradex))")
                .font(.footnote).foregroundStyle(.secondary)

            if wallet.state.tradex == 0 {
                Text("교환할 TRADEX가 없어요.").foregroundStyle(.secondary).padding(.vertical, 30)
            } else {
                HStack(spacing: 24) {
                    stepButton("minus") { count = max(1, count - 1) }
                    VStack(spacing: 4) {
                        Text("\(count) TRADEX").font(.system(size: 30, weight: .bold)).monospacedDigit()
                        Text("→ \(Fmt.krw(Double(count) * TradexRules.krwPerTradex))").font(.headline).foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 160)
                    stepButton("plus") { count = min(wallet.state.tradex, count + 1) }
                }
                Button("전부 선택") { count = wallet.state.tradex }.font(.subheadline)
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.rise) }
                Button("교환하기") {
                    do {
                        try wallet.exchange(tradex: count)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("교환한 모의투자금은 TRADEX로 되돌릴 수 없어요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onAppear { count = max(1, wallet.state.tradex) }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3.weight(.bold)).frame(width: 48, height: 48)
                .background(Theme.card, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct TradeHistoryView: View {
    @Environment(Wallet.self) private var wallet

    var body: some View {
        List {
            if wallet.state.trades.isEmpty {
                Text("아직 거래 내역이 없어요.").foregroundStyle(.secondary)
            }
            ForEach(wallet.state.trades) { t in
                HStack {
                    Text(t.side == .buy ? "매수" : "매도")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(t.side == .buy ? Theme.rise : Theme.fall, in: Capsule())
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
        .navigationTitle("거래 내역")
    }
}
