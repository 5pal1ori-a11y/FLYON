import SwiftUI

/// 주문 입력 단위
enum OrderUnit: Hashable {
    case krw, coin
}

/// 주문 종류
enum OrderType: Hashable {
    case market, limit, stop, take
    func title(buy: Bool) -> String {
        switch self {
        case .market: return "시장가"
        case .limit: return "지정가"
        case .stop: return "손절"
        case .take: return "익절"
        }
    }
    var priceLabel: String {
        switch self {
        case .market: return "현재가"
        case .limit: return "지정가"
        case .stop: return "손절가 (이 가격 이하가 되면 매도)"
        case .take: return "익절가 (이 가격 이상이 되면 매도)"
        }
    }
}

/// 주문 화면 — 시장가 · 지정가(매수·매도) · 손절 · 익절. 원(금액) 또는 코인 개수로 입력
struct OrderSheet: View {
    let market: Market
    let side: TradeSide

    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    @State private var unit: OrderUnit
    @State private var orderType: OrderType = .market
    @State private var input = ""
    @State private var priceText = ""
    @State private var editingPrice = false
    @State private var errorText: String?
    @State private var done = false

    init(market: Market, side: TradeSide) {
        self.market = market
        self.side = side
        // 기본값: 매수는 원, 매도는 개수
        _unit = State(initialValue: side == .buy ? .krw : .coin)
    }

    private var price: Double { store.tickers[market.market]?.tradePrice ?? 0 }
    private var ex: ExchangeID { store.exchange }
    private var holdingQty: Double { wallet.account(ex).holdings[market.market]?.quantity ?? 0 }
    private var value: Double { Double(input) ?? 0 }
    private var isBuy: Bool { side == .buy }
    private var accent: Color { isBuy ? Theme.rise : Theme.fall }
    private var types: [OrderType] { isBuy ? [.market, .limit] : [.market, .limit, .stop, .take] }
    private var triggerPrice: Double { Double(priceText) ?? 0 }
    /// 환산에 쓰는 가격: 시장가는 현재가, 예약 주문은 지정한 가격
    private var refPrice: Double { orderType == .market ? price : triggerPrice }

    /// 입력값을 코인 개수로 환산
    private var quantity: Double {
        guard refPrice > 0 else { return 0 }
        return unit == .coin ? value : floor(value / refPrice * 1e8) / 1e8
    }

    /// 입력값을 원화 금액으로 환산
    private var amountKRW: Double { unit == .krw ? value : value * refPrice }

    private var converted: String {
        guard refPrice > 0, value > 0 else { return " " }
        return unit == .krw ? "≈ \(Fmt.qty(quantity)) \(market.symbol)" : "≈ \(Fmt.krw(amountKRW))"
    }

    private var available: String {
        if isBuy {
            let maxQty = refPrice > 0 ? floor(wallet.maxBuyKRW(ex) / refPrice * 1e8) / 1e8 : 0
            return "주문 가능 \(Fmt.krw(wallet.account(ex).krw)) (최대 \(Fmt.qty(maxQty)) \(market.symbol))"
        } else {
            return "보유 \(Fmt.qty(holdingQty)) \(market.symbol) (≈ \(Fmt.krw(holdingQty * refPrice)))"
        }
    }

    private var submitTitle: String {
        switch orderType {
        case .market: return isBuy ? "매수" : "매도"
        case .limit: return isBuy ? "지정가 매수 주문" : "지정가 매도 주문"
        case .stop: return "손절 주문 걸기"
        case .take: return "익절 주문 걸기"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    CoinIcon(symbol: market.symbol, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("현재 거래 가능 가격").font(.caption).foregroundStyle(.secondary)
                        Text("1 \(market.symbol) = ₩ \(Fmt.price(price))")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .contentTransition(.numericText(value: price))
                            .animation(.snappy, value: price)
                    }
                    Spacer()
                    unitPicker
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                BWSegmented(options: types.map { ($0, $0.title(buy: isBuy)) }, selection: $orderType)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                if orderType != .market {
                    priceRow
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(input.isEmpty ? "0" : formattedInput)
                            .font(.system(size: orderType == .market ? 40 : 32, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(unit == .krw ? "원" : market.symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(converted).font(.headline).foregroundStyle(accent).monospacedDigit()
                    Text(available).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                    if let errorText {
                        Text(errorText).font(.footnote.weight(.medium)).foregroundStyle(Theme.rise)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: orderType != .market && !editingPrice ? 1.5 : 0))
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.snappy) { editingPrice = false } }
                .padding(.horizontal, 4)
                .padding(12)

                Spacer(minLength: 0)

                HStack {
                    ForEach([0.25, 0.5, 1.0], id: \.self) { ratio in
                        Button { fill(ratio) } label: {
                            Text(ratio == 1 ? "최대" : "\(Int(ratio * 100))%").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BWButtonStyle(verticalPadding: 10))
                    }
                }
                .padding(.horizontal, 20)

                NumberPad(allowsDecimal: editingPrice || unit == .coin) { key in tap(key) }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)

                Button(submitTitle) { submit() }
                    .buttonStyle(PrimaryButtonStyle(color: accent))
                    .disabled(value <= 0 || refPrice <= 0)
                    .opacity(value <= 0 || refPrice <= 0 ? 0.5 : 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: orderType)
            .navigationTitle("\(market.koreanName) \(isBuy ? "매수" : "매도")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
            }
            .sensoryFeedback(.success, trigger: done)
            .sensoryFeedback(.selection, trigger: unit)
            .onChange(of: orderType) { _, t in
                errorText = nil
                editingPrice = false
                let base = price
                switch t {
                case .market: priceText = ""
                case .limit: priceText = plainPrice(base)
                case .stop: priceText = plainPrice(base * 0.95)
                case .take: priceText = plainPrice(base * 1.05)
                }
            }
            .overlay {
                if done {
                    DoneOverlay(text: orderType == .market ? (isBuy ? "매수 완료" : "매도 완료") : "주문 접수",
                                color: accent)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: done)
        }
    }

    // MARK: - 가격 입력 (지정가 · 손절가 · 익절가)

    private var priceRow: some View {
        let diff = price > 0 && triggerPrice > 0 ? triggerPrice / price - 1 : 0
        let chips: [Double] = {
            switch orderType {
            case .stop: return [-0.03, -0.05, -0.10]
            case .take: return [0.03, 0.05, 0.10]
            default: return isBuy ? [0, -0.01, -0.03] : [0, 0.01, 0.03]
            }
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { editingPrice = true }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(orderType.priceLabel).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(priceText.isEmpty ? "0" : priceText).font(.title3.weight(.bold)).monospacedDigit()
                    Text("원").font(.subheadline).foregroundStyle(.secondary)
                    Text(Fmt.rate(diff)).font(.caption.weight(.semibold)).foregroundStyle(Theme.color(for: diff))
                        .monospacedDigit()
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: editingPrice ? 1.5 : 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { c in
                    Button {
                        priceText = plainPrice(price * (1 + c))
                        editingPrice = true
                    } label: {
                        Text(c == 0 ? "현재가" : String(format: "%+.0f%%", c * 100)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BWButtonStyle(verticalPadding: 6))
                }
            }
        }
    }

    /// 가격대에 맞춰 반올림한 가격 문자열
    private func plainPrice(_ v: Double) -> String {
        guard v > 0 else { return "" }
        if v >= 100 { return String(Int(v.rounded())) }
        return plain((v * (v >= 1 ? 100 : 10_000)).rounded() / (v >= 1 ? 100 : 10_000))
    }

    /// 원 / 개수 전환 버튼
    private var unitPicker: some View {
        HStack(spacing: 2) {
            unitButton("원", .krw)
            unitButton("개수", .coin)
        }
        .padding(3)
        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("입력 단위")
    }

    private func unitButton(_ title: String, _ u: OrderUnit) -> some View {
        Button {
            switchUnit(to: u)
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(unit == u ? Color(.systemBackground) : .primary)
                .background(unit == u ? Color.primary : .clear, in: Capsule())
                .animation(.snappy, value: unit)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(unit == u ? .isSelected : [])
    }

    /// 단위를 바꾸면 입력해 둔 값을 새 단위로 환산해서 유지
    private func switchUnit(to newUnit: OrderUnit) {
        guard newUnit != unit else { return }
        errorText = nil
        if value > 0, refPrice > 0 {
            if newUnit == .coin {
                input = plain(floor(value / refPrice * 1e8) / 1e8)
            } else {
                input = String(Int(floor(value * refPrice)))
            }
        }
        withAnimation(.snappy) { unit = newUnit }
    }

    private var formattedInput: String {
        if unit == .krw { return Fmt.number(value) }
        // 개수: 소수점 입력 중인 모양 유지
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        let intPart = Fmt.number(Double(parts.first ?? "0") ?? 0)
        return parts.count > 1 ? "\(intPart).\(parts[1])" : intPart
    }

    /// 쉼표 없는 숫자 문자열 (소수 8자리까지, 끝의 0 제거)
    private func plain(_ v: Double) -> String {
        var s = String(format: "%.8f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s
    }

    private func tap(_ key: NumberPad.Key) {
        errorText = nil
        if editingPrice && orderType != .market {
            // 가격 입력
            switch key {
            case .digit(let d):
                if priceText == "0" { priceText = "" }
                if let dot = priceText.firstIndex(of: "."), priceText[priceText.index(after: dot)...].count >= 4 { return }
                if priceText.count < 15 { priceText.append(String(d)) }
            case .dot:
                if !priceText.contains(".") { priceText = priceText.isEmpty ? "0." : priceText + "." }
            case .delete:
                if !priceText.isEmpty { priceText.removeLast() }
            }
            return
        }
        switch key {
        case .digit(let d):
            if input == "0" { input = "" }
            if unit == .coin, let dot = input.firstIndex(of: "."), input[input.index(after: dot)...].count >= 8 { return }
            if input.count < 15 { input.append(String(d)) }
        case .dot:
            guard unit == .coin else { return }
            if !input.contains(".") { input = input.isEmpty ? "0." : input + "." }
        case .delete:
            if !input.isEmpty { input.removeLast() }
        }
    }

    private func fill(_ ratio: Double) {
        errorText = nil
        editingPrice = false
        guard refPrice > 0 else { return }
        if isBuy {
            let krw = floor(wallet.maxBuyKRW(ex) * ratio)
            input = unit == .krw ? String(Int(krw)) : plain(floor(krw / refPrice * 1e8) / 1e8)
        } else {
            let qty = ratio == 1 ? holdingQty : floor(holdingQty * ratio * 1e8) / 1e8
            input = unit == .coin ? plain(qty) : String(Int(floor(qty * refPrice)))
        }
    }

    private func submit() {
        do {
            switch (orderType, isBuy) {
            case (.market, true):
                if unit == .krw {
                    try wallet.buy(market: market, krwAmount: value, price: price, on: ex)
                } else {
                    try wallet.buy(market: market, quantity: value, price: price, on: ex)
                }
            case (.market, false):
                // 원으로 입력했는데 보유 평가금액 이상이면 전량 매도
                var qty = unit == .coin ? value : floor(value / price * 1e8) / 1e8
                if unit == .krw && value >= floor(holdingQty * price) { qty = holdingQty }
                try wallet.sell(market: market, quantity: min(qty, holdingQty), price: price, on: ex)
            case (_, true):
                // 지정가 매수: 원으로 입력하면 그 금액, 개수로 입력하면 개수 × 지정가
                try wallet.placeLimitBuy(market: market, limitPrice: triggerPrice, krwAmount: amountKRW, on: ex)
            case (let t, false):
                var qty = unit == .coin ? value : floor(value / triggerPrice * 1e8) / 1e8
                if unit == .krw && value >= floor(holdingQty * triggerPrice) { qty = holdingQty }
                let kind: OrderKind = t == .stop ? .stopLoss : (t == .take ? .takeProfit : .limitSell)
                if kind == .stopLoss && triggerPrice >= price { errorText = "손절가는 현재가보다 낮아야 해요."; return }
                if kind == .takeProfit && triggerPrice <= price { errorText = "익절가는 현재가보다 높아야 해요."; return }
                try wallet.placeSellOrder(kind, market: market, triggerPrice: triggerPrice, quantity: min(qty, holdingQty), on: ex)
            }
            done = true
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

struct NumberPad: View {
    enum Key: Hashable { case digit(Int), dot, delete }
    var allowsDecimal: Bool
    var onTap: (Key) -> Void

    private let rows: [[Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.dot, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { key in
                        Button { onTap(key) } label: { label(key).frame(maxWidth: .infinity, minHeight: 52) }
                            .buttonStyle(.plain)
                            .disabled(key == .dot && !allowsDecimal)
                            .opacity(key == .dot && !allowsDecimal ? 0 : 1)
                    }
                }
            }
        }
        .font(.title2.weight(.medium))
    }

    @ViewBuilder private func label(_ key: Key) -> some View {
        switch key {
        case .digit(let d): Text("\(d)")
        case .dot: Text(".")
        case .delete: Image(systemName: "delete.left")
        }
    }
}

struct DoneOverlay: View {
    let text: String
    let color: Color
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.primary)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text(text).font(.title3.bold())
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }
}
