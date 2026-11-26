import SwiftUI

/// 주문 입력 단위
enum OrderUnit: Hashable {
    case krw, coin
}

/// 시장가 주문 화면 — 원(금액) 또는 코인 개수로 입력해서 매수·매도
struct OrderSheet: View {
    let market: Market
    let side: TradeSide

    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    @State private var unit: OrderUnit
    @State private var input = ""
    @State private var errorText: String?
    @State private var done = false

    init(market: Market, side: TradeSide) {
        self.market = market
        self.side = side
        // 기본값: 매수는 원, 매도는 개수
        _unit = State(initialValue: side == .buy ? .krw : .coin)
    }

    private var price: Double { store.tickers[market.market]?.tradePrice ?? 0 }
    private var holdingQty: Double { wallet.state.holdings[market.market]?.quantity ?? 0 }
    private var value: Double { Double(input) ?? 0 }
    private var isBuy: Bool { side == .buy }
    private var accent: Color { isBuy ? Theme.rise : Theme.fall }

    /// 입력값을 코인 개수로 환산
    private var quantity: Double {
        guard price > 0 else { return 0 }
        return unit == .coin ? value : floor(value / price * 1e8) / 1e8
    }

    /// 입력값을 원화 금액으로 환산
    private var amountKRW: Double { unit == .krw ? value : value * price }

    private var converted: String {
        guard price > 0, value > 0 else { return " " }
        return unit == .krw ? "≈ \(Fmt.qty(quantity)) \(market.symbol)" : "≈ \(Fmt.krw(amountKRW))"
    }

    private var available: String {
        if isBuy {
            let maxQty = price > 0 ? floor(wallet.maxBuyKRW / price * 1e8) / 1e8 : 0
            return "주문 가능 \(Fmt.krw(wallet.state.krw)) (최대 \(Fmt.qty(maxQty)) \(market.symbol))"
        } else {
            return "보유 \(Fmt.qty(holdingQty)) \(market.symbol) (≈ \(Fmt.krw(holdingQty * price)))"
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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(input.isEmpty ? "0" : formattedInput)
                            .font(.system(size: 40, weight: .bold))
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
                .padding(20)

                Spacer()

                HStack {
                    ForEach([0.25, 0.5, 1.0], id: \.self) { ratio in
                        Button(ratio == 1 ? "최대" : "\(Int(ratio * 100))%") { fill(ratio) }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.card, in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                NumberPad(allowsDecimal: unit == .coin) { key in tap(key) }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                Button(isBuy ? "매수" : "매도") { submit() }
                    .buttonStyle(PrimaryButtonStyle(color: accent))
                    .disabled(value <= 0 || price <= 0)
                    .opacity(value <= 0 ? 0.5 : 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .navigationTitle("\(market.koreanName) \(isBuy ? "매수" : "매도")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
            }
            .sensoryFeedback(.success, trigger: done)
            .sensoryFeedback(.selection, trigger: unit)
            .overlay {
                if done { DoneOverlay(text: isBuy ? "매수 완료" : "매도 완료", color: accent) }
            }
        }
    }

    /// 원 / 개수 전환 버튼
    private var unitPicker: some View {
        HStack(spacing: 2) {
            unitButton("원", .krw)
            unitButton("개수", .coin)
        }
        .padding(3)
        .background(Theme.card, in: Capsule())
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
                .foregroundStyle(unit == u ? Color(.systemBackground) : .secondary)
                .background(unit == u ? Color.primary : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(unit == u ? .isSelected : [])
    }

    /// 단위를 바꾸면 입력해 둔 값을 새 단위로 환산해서 유지
    private func switchUnit(to newUnit: OrderUnit) {
        guard newUnit != unit else { return }
        errorText = nil
        if value > 0, price > 0 {
            if newUnit == .coin {
                input = plain(floor(value / price * 1e8) / 1e8)
            } else {
                input = String(Int(floor(value * price)))
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
        guard price > 0 else { return }
        if isBuy {
            let krw = floor(wallet.maxBuyKRW * ratio)
            input = unit == .krw ? String(Int(krw)) : plain(floor(krw / price * 1e8) / 1e8)
        } else {
            let qty = ratio == 1 ? holdingQty : floor(holdingQty * ratio * 1e8) / 1e8
            input = unit == .coin ? plain(qty) : String(Int(floor(qty * price)))
        }
    }

    private func submit() {
        do {
            if isBuy {
                if unit == .krw {
                    try wallet.buy(market: market, krwAmount: value, price: price)
                } else {
                    try wallet.buy(market: market, quantity: value, price: price)
                }
            } else {
                // 원으로 입력했는데 보유 평가금액 이상이면 전량 매도
                var qty = unit == .coin ? value : floor(value / price * 1e8) / 1e8
                if unit == .krw && value >= floor(holdingQty * price) { qty = holdingQty }
                try wallet.sell(market: market, quantity: min(qty, holdingQty), price: price)
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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: true)
            Text(text).font(.title3.bold())
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }
}
