import SwiftUI

/// 선물 포지션 한 줄 — 평가손익, 수익률(ROE), 청산가, 종료 버튼
struct PositionRow: View {
    let position: FuturesPosition
    let price: Double?
    let exchange: ExchangeID
    var boxed = true

    @Environment(Wallet.self) private var wallet
    @State private var confirmClose = false

    var body: some View {
        let p = position
        let now = price ?? p.entryPrice
        let pnl = p.pnl(at: now)
        let color: Color = pnl > 0 ? .green : (pnl < 0 ? Theme.rise : .secondary)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.symbol).font(.headline)
                    Text("\(p.symbol)/KRW").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        tag(p.side.title, p.side == .long ? .green : Theme.rise)
                        tag("\(p.leverage)×", .secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("평가손익").font(.caption).foregroundStyle(.secondary)
                    Text("\(Fmt.signedKRW(pnl))원").font(.title3.weight(.bold)).foregroundStyle(color)
                    Text("수익률(ROE) \(Fmt.rate(p.roe(at: now)))").font(.caption.weight(.semibold)).foregroundStyle(color)
                }
                .monospacedDigit()
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    label("포지션 수량"); value("\(Fmt.qty(p.quantity)) \(p.symbol)")
                    label("평균 진입가"); value(Fmt.price(p.entryPrice))
                }
                GridRow {
                    label("평가금액"); value(Fmt.krw(p.quantity * now))
                    label("증거금"); value(Fmt.krw(p.margin))
                }
                GridRow {
                    label("현재가"); value(Fmt.price(now))
                    label("청산가"); value(Fmt.price(p.liquidationPrice)).foregroundStyle(Theme.rise)
                }
            }
            Button { confirmClose = true } label: {
                Text("포지션 종료").frame(maxWidth: .infinity)
            }
            .buttonStyle(BWButtonStyle(cornerRadius: 10, verticalPadding: 10))
            .disabled(price == nil)
        }
        .padding(boxed ? 16 : 0)
        .padding(.vertical, boxed ? 0 : 8)
        .background {
            if boxed {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.card)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("현재가 \(Fmt.price(now))에 종료할까요? 예상 손익 \(Fmt.signedKRW(pnl))원",
                            isPresented: $confirmClose, titleVisibility: .visible) {
            Button("포지션 종료", role: .destructive) {
                if let price { try? wallet.closePosition(id: p.id, price: price, on: exchange) }
            }
        }
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
    private func label(_ t: String) -> some View { Text(t).font(.caption).foregroundStyle(.secondary) }
    private func value(_ t: String) -> some View {
        Text(t).font(.caption.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// 선물 주문 — 롱/숏, 레버리지, 사용할 증거금
struct FuturesOrderSheet: View {
    let market: Market

    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    @State private var side: PositionSide = .long
    @State private var leverageIndex = TradexRules.leverageSteps.count - 1
    @State private var marginText = ""
    @State private var errorText: String?
    @State private var done = false

    private var ex: ExchangeID { store.exchange }
    private var price: Double { store.tickers[market.market]?.tradePrice ?? 0 }
    private var leverage: Int { TradexRules.leverageSteps[leverageIndex] }
    private var available: Double { wallet.account(ex).futuresKRW }
    private var margin: Double { Double(marginText) ?? 0 }
    private var accent: Color { side == .long ? .green : Theme.rise }
    private var positions: [FuturesPosition] { wallet.account(ex).positions.filter { $0.market == market.market } }

    private var preview: FuturesPosition? {
        guard price > 0, margin > 0 else { return nil }
        return FuturesPosition(market: market.market, koreanName: market.koreanName, side: side, leverage: leverage,
                               margin: margin, entryPrice: price, quantity: margin * Double(leverage) / price, openedAt: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        CoinIcon(symbol: market.symbol, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(market.koreanName) (\(market.symbol)/KRW)").font(.subheadline.weight(.semibold))
                            Text("₩ \(Fmt.price(price))").font(.headline).monospacedDigit()
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            ExchangeBadge(exchange: ex, size: 18)
                            Text(ex.name).font(.caption.weight(.semibold))
                        }
                    }

                    BWSegmented(options: [(PositionSide.long, "롱 (상승)"), (PositionSide.short, "숏 (하락)")], selection: $side)

                    HStack {
                        Text("주문가능").foregroundStyle(.secondary)
                        Spacer()
                        Text(Fmt.krw(available)).fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.subheadline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("레버리지 \(leverage)× / \(TradexRules.maxLeverage)×").font(.subheadline.weight(.semibold))
                        HStack(spacing: 6) {
                            ForEach(TradexRules.leverageSteps.indices, id: \.self) { i in
                                Button {
                                    withAnimation(.snappy) { leverageIndex = i }
                                } label: {
                                    Text("\(TradexRules.leverageSteps[i])×").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(BWButtonStyle(selected: i == leverageIndex))
                                .sensoryFeedback(.selection, trigger: leverageIndex)
                            }
                        }
                    }

                    TextField("사용할 증거금 (원)", text: $marginText)
                        .keyboardType(.numberPad)
                        .font(.title3.weight(.semibold))
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))

                    HStack(spacing: 6) {
                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { r in
                            Button {
                                marginText = String(Int(floor(available * r)))
                            } label: {
                                Text("\(Int(r * 100))%").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(BWButtonStyle())
                        }
                    }

                    if let p = preview {
                        VStack(spacing: 6) {
                            info("포지션 크기", "\(Fmt.krw(p.size)) (\(Fmt.qty(p.quantity)) \(market.symbol))")
                            info("예상 청산가", "₩ \(Fmt.price(p.liquidationPrice))")
                        }
                    }
                    Text("증거금을 모두 잃으면(가격이 \(String(format: "%.1f", 100 / Double(leverage)))% 반대로 움직이면) 자동 청산돼요. 모의 선물이라 수수료·펀딩비는 없어요.")
                        .font(.caption).foregroundStyle(.secondary)

                    if let errorText { Text(errorText).font(.footnote).foregroundStyle(Theme.rise) }

                    Button("\(side.title) 진입") { submit() }
                        .buttonStyle(PrimaryButtonStyle(color: accent))
                        .disabled(margin <= 0 || price <= 0)
                        .opacity(margin <= 0 ? 0.5 : 1)

                    if !positions.isEmpty {
                        Text("보유 포지션").font(.headline).padding(.top, 8)
                        ForEach(positions) { p in
                            PositionRow(position: p, price: store.tickers[p.market]?.tradePrice, exchange: ex)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("선물 주문")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
            .sensoryFeedback(.success, trigger: done)
        }
    }

    private func info(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).foregroundStyle(.secondary)
            Spacer()
            Text(v).fontWeight(.semibold).monospacedDigit()
        }
        .font(.subheadline)
    }

    private func submit() {
        errorText = nil
        do {
            try wallet.openPosition(market: market, side: side, leverage: leverage, margin: margin, price: price, on: ex)
            marginText = ""
            done.toggle()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
