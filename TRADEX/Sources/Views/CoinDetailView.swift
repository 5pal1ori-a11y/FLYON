import SwiftUI

struct CoinDetailView: View {
    let market: Market
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    @State private var range: ChartRange = .day
    @State private var points: [ChartPoint] = []
    @State private var candles: [OHLCCandle] = []
    @AppStorage("chartStyle") private var chartStyle = "candle"
    @State private var selected: ChartPoint?
    @State private var chartError = false
    @State private var orderSide: TradeSide?
    @State private var section = "차트"

    private var ticker: Ticker? { store.tickers[market.market] }
    private var holding: Holding? { wallet.account(store.exchange).holdings[market.market] }
    @State private var showFutures = false
    @State private var showPlan = false

    /// 마지막 봉을 실시간 가격으로 갱신
    private var liveCandles: [OHLCCandle] {
        guard let t = ticker, var last = candles.last, range == .hour || range == .day else { return candles }
        last.close = t.tradePrice
        last.high = max(last.high, t.tradePrice)
        last.low = min(last.low, t.tradePrice)
        return Array(candles.dropLast()) + [last]
    }

    /// 차트 마지막 점을 실시간 가격으로 이어 붙인다.
    private var livePoints: [ChartPoint] {
        guard let t = ticker, let last = points.last, range == .hour || range == .day else { return points }
        let now = Date()
        return now > last.date ? points + [ChartPoint(date: now, price: t.tradePrice)] : points
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                BWSegmented(options: [("차트", "차트"), ("호가", "호가")], selection: $section, compact: true, outlined: false)
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
                if let holding {
                    Divider()
                    holdingCard(holding)
                }
                let myOrders = wallet.account(store.exchange).orders.filter { $0.market == market.market }
                if !myOrders.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("미체결 주문").font(.headline).padding(.bottom, 4)
                        ForEach(myOrders) { o in
                            PendingOrderRow(order: o, price: ticker?.tradePrice, exchange: store.exchange)
                        }
                    }
                }
                let myPositions = wallet.account(store.exchange).positions.filter { $0.market == market.market }
                if !myPositions.isEmpty {
                    Divider()
                    Text("선물 포지션").font(.headline)
                    ForEach(myPositions) { p in
                        PositionRow(position: p, price: ticker?.tradePrice, exchange: store.exchange, boxed: false)
                        if p.id != myPositions.last?.id { Divider() }
                    }
                }
                Divider()
                statsCard
                Text("시세 제공: \(store.exchange.name) Open API · 모의투자 전용, 실제 거래가 아니에요.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle(market.koreanName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(market.koreanName).font(.headline)
                    Text("\(market.symbol)/KRW · \(store.exchange.name)").font(.caption2).foregroundStyle(.secondary)
                }
            }
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
        HStack(alignment: .center, spacing: 14) {
            CoinIcon(symbol: market.symbol, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                if let t = ticker {
                    Text(selected.map { $0.date.formatted(.dateTime.month().day().hour().minute()) } ?? "현재 거래 가능 가격")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("₩ \(Fmt.price(selected?.price ?? t.tradePrice))")
                        .font(.system(size: 32, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: selected?.price ?? t.tradePrice))
                        .animation(.snappy, value: t.tradePrice)
                    HStack(spacing: 4) {
                        Image(systemName: t.signedChangeRate >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2.weight(.bold))
                        Text(Fmt.signedPrice(t.signedChangePrice))
                        Text("(\(Fmt.rate(t.signedChangeRate)))")
                        Text("전일 대비").foregroundStyle(Color.secondary).fontWeight(.regular)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.color(for: t.signedChangeRate))
                    .monospacedDigit()
                } else {
                    ProgressView()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var chartSection: some View {
        VStack(spacing: 14) {
            ZStack {
                if chartError {
                    Text("차트를 불러오지 못했어요").font(.footnote).foregroundStyle(.secondary)
                } else if points.isEmpty {
                    ProgressView()
                } else if chartStyle == "candle" {
                    CandleChart(candles: liveCandles, selected: $selected)
                        .transition(.opacity)
                } else {
                    PriceChart(points: livePoints, selected: $selected)
                        .transition(.opacity)
                }
            }
            .frame(height: chartStyle == "candle" ? 280 : 220)
            .animation(.easeInOut(duration: 0.25), value: chartStyle)

            HStack {
                Spacer()
                BWSegmented(options: [("candle", "캔들"), ("line", "라인")], selection: $chartStyle, compact: true, outlined: false)
                    .frame(width: 140)
            }

            BWSegmented(options: ChartRange.allCases.map { ($0, $0.rawValue) }, selection: $range, compact: true, outlined: false)
        }
    }

    private func holdingCard(_ h: Holding) -> some View {
        let price = ticker?.tradePrice ?? h.averagePrice
        let value = price * h.quantity
        let pnl = (price - h.averagePrice) * h.quantity
        let rate = h.averagePrice > 0 ? price / h.averagePrice - 1 : 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("내 보유").font(.headline)
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
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("시세 정보").font(.headline)
            if let t = ticker {
                dayRange(t)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("고가", "₩ \(Fmt.price(t.highPrice))", Theme.rise)
                    tile("저가", "₩ \(Fmt.price(t.lowPrice))", Theme.fall)
                    tile("전일 종가", "₩ \(Fmt.price(t.prevClosingPrice))", .primary)
                    tile("거래대금 (24H)", "\(Fmt.compactKRW(t.accTradePrice24h))원", .primary)
                }
            }
        }
    }

    /// 오늘 저가~고가 사이에서 현재가 위치
    private func dayRange(_ t: Ticker) -> some View {
        let span = max(t.highPrice - t.lowPrice, 0.0000001)
        let pos = min(max((t.tradePrice - t.lowPrice) / span, 0), 1)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.fall.opacity(0.35), Theme.rise.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                        .offset(x: (geo.size.width - 14) * pos)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pos)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
            HStack {
                Text("저가 \(Fmt.price(t.lowPrice))").foregroundStyle(Theme.fall)
                Spacer()
                Text("오늘 가격 범위").foregroundStyle(.secondary)
                Spacer()
                Text("고가 \(Fmt.price(t.highPrice))").foregroundStyle(Theme.rise)
            }
            .font(.caption2.weight(.medium))
            .monospacedDigit()
        }
    }

    private func tile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)

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
        HStack(spacing: 8) {
            tradeButton("매도", color: Theme.fall, enabled: holding != nil) { orderSide = .sell }
            tradeButton("매수", color: Theme.rise, enabled: true) { orderSide = .buy }
            Button { showFutures = true } label: {
                VStack(spacing: 1) {
                    Text("선물").font(.headline)
                    Text("롱·숏").font(.caption2.weight(.medium)).opacity(0.8)
                }
                .frame(width: 74, height: 54)
                .bwBackground(selected: true, cornerRadius: 14)
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        // 반투명(.bar) 위에서는 검정(primary)이 흐린 회색으로 보이므로 불투명 배경 사용
        .background(Color(.systemBackground))
        .disabled(ticker == nil)
    }

    /// 매수·매도 버튼: 쓸 수 없을 때는 같은 색 테두리만 흐리게
    private func tradeButton(_ title: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(enabled ? Color.white : color.opacity(0.45))
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(enabled ? color : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(color.opacity(enabled ? 0 : 0.35), lineWidth: 1.2))
                }
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
    }

    private func loadChart() async {
        chartError = false
        selected = nil
        do {
            let result = try await UpbitAPI.ohlc(market: market.market, range: range, on: store.exchange)
            withAnimation {
                candles = result
                points = result.map { ChartPoint(date: $0.date, price: $0.close) }
            }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code != .cancelled { chartError = true }
        }
    }
}

extension TradeSide: Identifiable {
    var id: String { rawValue }
}
