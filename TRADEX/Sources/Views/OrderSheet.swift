import SwiftUI

/// 시장가 주문 화면 — 숫자 키패드로 금액(매수) 또는 수량(매도)을 입력
struct OrderSheet: View {
    let market: Market
    let side: TradeSide

    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var errorText: String?
    @State private var done = false

    private var price: Double { store.tickers[market.market]?.tradePrice ?? 0 }
    private var holdingQty: Double { wallet.state.holdings[market.market]?.quantity ?? 0 }
    private var value: Double { Double(input) ?? 0 }
    private var isBuy: Bool { side == .buy }
    private var accent: Color { isBuy ? Theme.rise : Theme.fall }

    /// 매수: 입력=원화, 환산=수량 / 매도: 입력=수량, 환산=원화
    private var converted: String {
        guard price > 0 else { return "-" }
        return isBuy ? "≈ \(Fmt.qty(floor(value / price * 1e8) / 1e8)) \(market.symbol)"
                     : "≈ \(Fmt.krw(value * price))"
    }

    private var available: String {
        isBuy ? "주문 가능 \(Fmt.krw(wallet.state.krw))" : "보유 \(Fmt.qty(holdingQty)) \(market.symbol)"
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
                        Text(isBuy ? "원" : market.symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(converted).font(.headline).foregroundStyle(accent).monospacedDigit()
                    Text(available).font(.footnote).foregroundStyle(.secondary)
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

                NumberPad(allowsDecimal: !isBuy) { key in tap(key) }
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
            .overlay {
                if done { DoneOverlay(text: isBuy ? "매수 완료" : "매도 완료", color: accent) }
            }
        }
    }

    private var formattedInput: String {
        if isBuy { return Fmt.number(value) }
        // 매도: 소수점 입력 중인 모양 유지
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        let intPart = Fmt.number(Double(parts.first ?? "0") ?? 0)
        return parts.count > 1 ? "\(intPart).\(parts[1])" : intPart
    }

    private func tap(_ key: NumberPad.Key) {
        errorText = nil
        switch key {
        case .digit(let d):
            if input == "0" { input = "" }
            if !isBuy, let dot = input.firstIndex(of: "."), input[input.index(after: dot)...].count >= 8 { return }
            if input.count < 15 { input.append(String(d)) }
        case .dot:
            if !input.contains(".") { input = input.isEmpty ? "0." : input + "." }
        case .delete:
            if !input.isEmpty { input.removeLast() }
        }
    }

    private func fill(_ ratio: Double) {
        errorText = nil
        if isBuy {
            input = String(Int(floor(wallet.maxBuyKRW * ratio)))
        } else {
            let q = ratio == 1 ? holdingQty : floor(holdingQty * ratio * 1e8) / 1e8
            input = Fmt.qty(q).replacingOccurrences(of: ",", with: "")
        }
    }

    private func submit() {
        do {
            if isBuy {
                try wallet.buy(market: market, krwAmount: value, price: price)
            } else {
                try wallet.sell(market: market, quantity: min(value, holdingQty), price: price)
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
