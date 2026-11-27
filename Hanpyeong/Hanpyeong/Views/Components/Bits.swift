import SwiftUI
import Charts

/// 화면 위에 늘 붙어 있는 잔고 머리띠
struct CashHeader: View {
    @Environment(Game.self) private var game

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.rank.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.gold)
                        .tracking(0.8)
                    Text(Won.full(game.cash))
                        .font(.myeongjo(25))
                        .foregroundStyle(game.cash < 0 ? Palette.down : Palette.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(game.day)일차 · \(game.dayPhase)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                    Text("\(Won.signed(game.incomePerSec))/초")
                        .font(.num(15, .bold))
                        .foregroundStyle(Palette.up)
                }
            }
            DayBar(fraction: game.dayFraction)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Palette.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

/// 하루 진행 막대 — 해가 넘어가는 느낌으로 점점 진해진다
struct DayBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule()
                    .fill(Palette.sign.opacity(0.35 + 0.65 * fraction))
                    .frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 3)
        .animation(.linear(duration: 0.2), value: fraction)
    }
}

/// 작은 꼬리표
struct Tag: View {
    let text: String
    var color: Color = Palette.inkSoft
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(filled ? .white : color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(filled ? color : color.opacity(0.12))
            )
    }
}

/// 라벨 + 값 한 칸
struct StatCell: View {
    let label: String
    let value: String
    var tint: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
            Text(value)
                .font(.num(15, .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 영수증 아래 톱니 모양
struct ZigzagEdge: Shape {
    var tooth: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - tooth))
        var x = rect.width
        var down = true
        while x > 0 {
            x -= tooth
            p.addLine(to: CGPoint(x: max(0, x), y: down ? rect.height : rect.height - tooth))
            down.toggle()
        }
        p.addLine(to: CGPoint(x: 0, y: rect.height - tooth))
        p.closeSubpath()
        return p
    }
}

struct DashedLine: View {
    var body: some View {
        Line()
            .stroke(Palette.inkFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            return p
        }
    }
}

/// 빨간 인주 도장
struct Stamp: View {
    let text: String
    var size: CGFloat = 92
    var color: Color = Palette.sign

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: size * 0.06)
            Circle().strokeBorder(color, lineWidth: 1.5).padding(size * 0.1)
            Text(text)
                .font(.myeongjo(size * 0.26))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-12))
        .opacity(0.92)
    }
}

/// 시세 미니 그래프
struct Sparkline: View {
    let values: [Double]
    var color: Color

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { item in
                LineMark(x: .value("일", item.offset), y: .value("지수", item.element))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartLegend(.hidden)
    }

    private var yDomain: ClosedRange<Double> {
        let lo = values.min() ?? 0.9
        let hi = values.max() ?? 1.1
        let pad = max(0.02, (hi - lo) * 0.15)
        return (lo - pad)...(hi + pad)
    }
}

/// 상승/하락 색 (한국식)
func trendColor(_ v: Double) -> Color {
    if v > 0.0005 { return Palette.up }
    if v < -0.0005 { return Palette.down }
    return Palette.inkSoft
}

/// 탭할 때 떠오르는 금액
struct FloatingAmount: View {
    let text: String
    @State private var rise = false

    var body: some View {
        Text(text)
            .font(.myeongjo(20))
            .foregroundStyle(Palette.sign)
            .shadow(color: Palette.paper, radius: 0, x: 1, y: 1)
            .offset(y: rise ? -80 : 0)
            .opacity(rise ? 0 : 1)
            .scaleEffect(rise ? 1.1 : 0.9)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { rise = true }
            }
            .allowsHitTesting(false)
    }
}

/// 비어 있을 때 안내
struct EmptyNote: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.myeongjo(17)).foregroundStyle(Palette.ink)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
