import SwiftUI
import Charts

/// 봉(캔들) 차트 + 이동평균선(5·20) + 거래량 막대
/// 상승봉 빨강, 하락봉 파랑 (국내 거래소 관례)
struct CandleChart: View {
    let candles: [OHLCCandle]
    @Binding var selected: ChartPoint?

    @State private var selectedIndex: Int?

    private func movingAverage(_ n: Int) -> [(Int, Double)] {
        guard candles.count >= n else { return [] }
        var out: [(Int, Double)] = []
        var sum = candles.prefix(n).reduce(0) { $0 + $1.close }
        out.append((n - 1, sum / Double(n)))
        for i in n..<candles.count {
            sum += candles[i].close - candles[i - n].close
            out.append((i, sum / Double(n)))
        }
        return out
    }

    private var yDomain: ClosedRange<Double> {
        let lo = candles.map(\.low).min() ?? 0
        let hi = candles.map(\.high).max() ?? 1
        let pad = max((hi - lo) * 0.08, hi * 0.0005)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        let ma5 = movingAverage(5)
        let ma20 = movingAverage(20)
        let span = yDomain.upperBound - yDomain.lowerBound
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                legend("MA5", .orange)
                legend("MA20", .purple)
                Spacer()
                if let i = selectedIndex, candles.indices.contains(i) {
                    let c = candles[i]
                    Text("시 \(Fmt.price(c.open))  고 \(Fmt.price(c.high))  저 \(Fmt.price(c.low))  종 \(Fmt.price(c.close))")
                        .font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            Chart {
                ForEach(Array(candles.enumerated()), id: \.offset) { i, c in
                    let color = c.isUp ? Theme.rise : Theme.fall
                    RuleMark(x: .value("시간", i), yStart: .value("저가", c.low), yEnd: .value("고가", c.high))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(color)
                    // 시가=종가(도지)여도 보이도록 최소 높이
                    let top = max(c.open, c.close), bottom = min(c.open, c.close)
                    RectangleMark(x: .value("시간", i),
                                  yStart: .value("시가", bottom),
                                  yEnd: .value("종가", max(top, bottom + span * 0.003)),
                                  width: .ratio(0.7))
                        .foregroundStyle(color)
                }
                ForEach(ma5, id: \.0) { i, v in
                    LineMark(x: .value("시간", i), y: .value("MA5", v), series: .value("선", "MA5"))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                }
                ForEach(ma20, id: \.0) { i, v in
                    LineMark(x: .value("시간", i), y: .value("MA20", v), series: .value("선", "MA20"))
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                }
                if let i = selectedIndex {
                    RuleMark(x: .value("선택", i))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartYScale(domain: yDomain)
            .chartXScale(domain: -1...max(candles.count, 1))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text(Fmt.price(d)).font(.system(size: 9)).foregroundStyle(.secondary) }
                    }
                }
            }
            .chartXSelection(value: $selectedIndex)

            // 거래량
            Chart {
                ForEach(Array(candles.enumerated()), id: \.offset) { i, c in
                    BarMark(x: .value("시간", i), y: .value("거래량", c.volume), width: .ratio(0.7))
                        .foregroundStyle((c.isUp ? Theme.rise : Theme.fall).opacity(0.45))
                }
            }
            .chartXScale(domain: -1...max(candles.count, 1))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
        }
        .onChange(of: selectedIndex) { _, i in
            guard let i, candles.indices.contains(i) else { selected = nil; return }
            selected = ChartPoint(date: candles[i].date, price: candles[i].close)
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func legend(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(c).frame(width: 10, height: 2)
            Text(t).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
        }
    }
}
