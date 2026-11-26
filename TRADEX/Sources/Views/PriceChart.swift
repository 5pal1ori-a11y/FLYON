import SwiftUI
import Charts

struct PriceChart: View {
    let points: [ChartPoint]
    @Binding var selected: ChartPoint?

    @State private var selectedDate: Date?

    private var color: Color {
        guard let first = points.first?.price, let last = points.last?.price else { return .secondary }
        return Theme.color(for: last - first)
    }

    private var yDomain: ClosedRange<Double> {
        let prices = points.map(\.price)
        guard let lo = prices.min(), let hi = prices.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.12, hi * 0.0005)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("시간", p.date), y: .value("가격", p.price))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                AreaMark(x: .value("시간", p.date), yStart: .value("최저", yDomain.lowerBound), yEnd: .value("가격", p.price))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.18), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
            if let s = selected {
                RuleMark(x: .value("선택", s.date))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text("₩ \(Fmt.price(s.price))").font(.caption.weight(.bold)).monospacedDigit()
                            Text(s.date, format: .dateTime.month().day().hour().minute()).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                PointMark(x: .value("선택", s.date), y: .value("가격", s.price))
                    .foregroundStyle(color)
            } else if let last = points.last {
                PointMark(x: .value("현재", last.date), y: .value("가격", last.price))
                    .foregroundStyle(color)
                    .symbolSize(50)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXSelection(value: $selectedDate)
        .onChange(of: selectedDate) { _, date in
            guard let date else { selected = nil; return }
            selected = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .animation(.easeInOut(duration: 0.25), value: points.count)
    }
}
