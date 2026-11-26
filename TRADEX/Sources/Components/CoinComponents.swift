import SwiftUI

/// 코인 아이콘
/// - 오픈소스 아이콘 세트(web3icons: MIT, cryptocurrency-icons: CC0)에서 이름까지 대조해 넣은 아이콘이 있으면 사용
/// - 없으면 심볼 글자로 그린다. 거래소(업비트) 이미지는 쓰지 않는다.
struct CoinIcon: View {
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        if let image = UIImage(named: "coin-\(symbol)") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .accessibilityHidden(true)
        } else {
            LetterCoinIcon(symbol: symbol, size: size)
        }
    }
}

/// 아이콘이 없는 코인용: 심볼 글자 아이콘
struct LetterCoinIcon: View {
    let symbol: String
    var size: CGFloat = 40

    private var tint: Color {
        let palette: [Color] = [.orange, .indigo, .teal, .pink, .mint, .purple, .cyan, .brown, .blue, .green]
        let seed = symbol.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[seed % palette.count]
    }

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.15))
            Text(String(symbol.prefix(symbol.count > 4 ? 2 : 3)))
                .font(.system(size: size * (symbol.count > 3 ? 0.28 : 0.32), weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "+46,000 (+0.09%)" 형식
struct ChangeLabel: View {
    let change: Double
    let rate: Double
    var font: Font = .subheadline

    var body: some View {
        Text("\(Fmt.signedPrice(change)) (\(Fmt.rate(rate)))")
            .font(font.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.color(for: rate))
    }
}

/// 등락률 배지
struct RateBadge: View {
    let rate: Double
    var body: some View {
        Text(Fmt.rate(rate))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.color(for: rate))
    }
}

/// 가격이 바뀌면 잠깐 빨강/파랑으로 깜빡이는 가격 텍스트
struct FlashingPrice: View {
    let price: Double
    var font: Font = .body
    var color: Color = .primary

    @State private var flash: Color = .clear

    var body: some View {
        Text(Fmt.price(price))
            .font(font.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: price))
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 4).strokeBorder(flash, lineWidth: 1))
            .onChange(of: price) { old, new in
                guard old != new else { return }
                flash = new > old ? Theme.rise : Theme.fall
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(.easeOut(duration: 0.6)) { flash = .clear }
                }
            }
    }
}

/// 거래소·관심 목록의 한 줄
struct CoinRow: View {
    let market: Market
    let ticker: Ticker?

    var body: some View {
        HStack(spacing: 12) {
            CoinIcon(symbol: market.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(market.koreanName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(market.symbol)/KRW")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let t = ticker {
                VStack(alignment: .trailing, spacing: 2) {
                    FlashingPrice(price: t.tradePrice, color: Theme.color(for: t.signedChangeRate))
                    HStack(spacing: 6) {
                        Text(Fmt.compactKRW(t.accTradePrice24h))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        RateBadge(rate: t.signedChangeRate)
                            .font(.caption)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// 실시간 연결 표시
struct LiveIndicator: View {
    let isLive: Bool
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
                .opacity(isLive && pulse ? 0.3 : 1)
                .animation(isLive ? .easeInOut(duration: 0.9).repeatForever() : .default, value: pulse)
            Text(isLive ? "실시간" : "연결 중")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .onAppear { pulse = true }
    }
}
