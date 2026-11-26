import SwiftUI

struct CoinDetailView: View {
    let market: Market
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    @State private var range: ChartRange = .day
    @State private var points: [ChartPoint] = []
    @State private var selected: ChartPoint?
    @State private var chartError = false
    @State private var orderSide: TradeSide?
    @State private var section = "차트"

    private var ticker: Ticker? { store.tickers[market.market] }
    private var holding: Holding? { wallet.account(store.exchange).holdings[market.market] }
    @State private var showFutures = false
    @State private var showPlan = false

    /// 차트 마지막 점을 실시간 가격으로 이어 붙인다.
    private var livePoints: [ChartPoint] {
        guard let t = ticker, let last = points.last, range == .hour || range == .day else { return points }
        let now = Date()
        return now > last.date ? points + [ChartPoint(date: now, price: t.tradePrice)] : points
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                BWSegmented(options: [("차트", "차트"), ("호가", "호가")], selection: $section)
                Group {
                    if section == "차트" {
                        chartSection
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                    removal: .opacity))
                    } else {
                        OrderbookView(market: market, prevClose: ticker?.prevClosingPrice ?? 0, exchange: store.exchange)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: section)
                if let holding { holdingCard(holding) }
                let myOrders = wallet.account(store.exchange).orders.filter { $0.market == market.market }
                if !myOrders.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("미체결 주문").font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 4)
                        ForEach(myOrders) { o in
                            PendingOrderRow(order: o, price: ticker?.tradePrice, exchange: store.exchange)
                        }
                    }
                    .card()
                }
                ForEach(wallet.account(store.exchange).positions.filter { $0.market == market.market }) { p in
                    PositionRow(position: p, price: ticker?.tradePrice, exchange: store.exchange)
                }
                statsCard
                Text("시세 제공: 업비트 Open API · 모의투자 전용, 실제 거래가 아닙니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Theme.background)
        .navigationTitle(market.englishName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showPlan = true } label: { Image(systemName: "repeat") }
                    .accessibilityLabel("적립식 자동 매수 만들기")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleFavorite(market.market)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: store.favorites.contains(market.market) ? "star.fill" : "star")
                }
                .accessibilityLabel(store.favorites.contains(market.market) ? "관심 해제" : "관심 추가")
            }
        }
        .safeAreaInset(edge: .bottom) { orderButtons }
        .task(id: range) { await loadChart() }
        .onAppear { wallet.recordEvent("chart:\(market.market)") }
        .sheet(isPresented: $showPlan) {
            NewPlanSheet(preset: market).presentationDetents([.large])
        }
        .sheet(isPresented: $showFutures) {
            FuturesOrderSheet(market: market).presentationDetents([.large])
        }
        .sheet(item: $orderSide) { side in
            OrderSheet(market: market, side: side)
                .presentationDetents([.large])
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            CoinIcon(symbol: market.symbol, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(market.koreanName) · \(market.symbol)/KRW")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let t = ticker {
                    Text("₩ \(Fmt.price(selected?.price ?? t.tradePrice))")
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: selected?.price ?? t.tradePrice))
                        .animation(.snappy, value: t.tradePrice)
                    ChangeLabel(change: t.signedChangePrice, rate: t.signedChangeRate)
                } else {
                    ProgressView()
                }
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var chartSection: some View {
        VStack(spacing: 14) {
            ZStack {
                if chartError {
                    Text("차트를 불러오지 못했어요").font(.footnote).foregroundStyle(.secondary)
                } else if points.isEmpty {
                    ProgressView()
                } else {
                    PriceChart(points: livePoints, selected: $selected)
                }
            }
            .frame(height: 240)

            BWSegmented(options: ChartRange.allCases.map { ($0, $0.rawValue) }, selection: $range)
        }
    }

    private func holdingCard(_ h: Holding) -> some View {
        let price = ticker?.tradePrice ?? h.averagePrice
        let value = price * h.quantity
        let pnl = (price - h.averagePrice) * h.quantity
        let rate = h.averagePrice > 0 ? price / h.averagePrice - 1 : 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("내 보유").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text("\(Fmt.qty(h.quantity)) \(market.symbol)").font(.title3.bold()).monospacedDigit()
                Spacer()
                Text(Fmt.krw(value)).font(.headline).monospacedDigit()
            }
            Divider()
            row("평균 매수가", "₩ \(Fmt.price(h.averagePrice))")
            HStack {
                Text("평가손익").foregroundStyle(.secondary)
                Spacer()
                Text("\(Fmt.signedKRW(pnl))원 (\(Fmt.rate(rate)))")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.color(for: pnl))
                    .monospacedDigit()
            }
            .font(.subheadline)
        }
        .card()
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            if let t = ticker {
                row("고가", "₩ \(Fmt.price(t.highPrice))", color: Theme.rise)
                row("저가", "₩ \(Fmt.price(t.lowPrice))", color: Theme.fall)
                row("전일 종가", "₩ \(Fmt.price(t.prevClosingPrice))")
                row("거래대금(24H)", "\(Fmt.compactKRW(t.accTradePrice24h))원")
            }
        }
        .card()
    }

    private func row(_ title: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(color).monospacedDigit()
        }
        .font(.subheadline)
    }

    private var orderButtons: some View {
        HStack(spacing: 10) {
            Button("매도") { orderSide = .sell }
                .buttonStyle(PrimaryButtonStyle(color: Theme.fall))
                .disabled(holding == nil)
                .opacity(holding == nil ? 0.4 : 1)
            Button("매수") { orderSide = .buy }
                .buttonStyle(PrimaryButtonStyle(color: Theme.rise))
            Button { showFutures = true } label: {
                VStack(spacing: 0) {
                    Text("선물").font(.headline)
                    Text("롱·숏").font(.caption2)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 76)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
        .disabled(ticker == nil)
    }

    private func loadChart() async {
        chartError = false
        selected = nil
        do {
            let result = try await UpbitAPI.candles(market: market.market, range: range, on: store.exchange)
            withAnimation { points = result }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code != .cancelled { chartError = true }
        }
    }
}

extension TradeSide: Identifiable {
    var id: String { rawValue }
}
