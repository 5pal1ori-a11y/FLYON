import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

// MARK: - 위젯 묶음

@main
struct TRADEXWidgets: WidgetBundle {
    var body: some Widget {
        CoinPriceWidget()
        PositionLiveActivity()
    }
}

private let rise = Color(red: 0.898, green: 0.196, blue: 0.176)
private let fall = Color(red: 0.122, green: 0.384, blue: 0.839)
private func tint(_ v: Double) -> Color { v > 0 ? rise : (v < 0 ? fall : .secondary) }

// MARK: - 코인 시세 위젯 (홈 화면 작은·중간, 잠금화면)

enum WidgetCoin: String, AppEnum {
    case btc = "KRW-BTC", eth = "KRW-ETH", xrp = "KRW-XRP", sol = "KRW-SOL", doge = "KRW-DOGE", ada = "KRW-ADA",
         trx = "KRW-TRX", link = "KRW-LINK", avax = "KRW-AVAX", sui = "KRW-SUI", xlm = "KRW-XLM", dot = "KRW-DOT"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "코인"
    static var caseDisplayRepresentations: [WidgetCoin: DisplayRepresentation] = [
        .btc: "비트코인", .eth: "이더리움", .xrp: "엑스알피(리플)", .sol: "솔라나", .doge: "도지코인", .ada: "에이다",
        .trx: "트론", .link: "체인링크", .avax: "아발란체", .sui: "수이", .xlm: "스텔라루멘", .dot: "폴카닷",
    ]
    var name: String {
        switch self {
        case .btc: return "비트코인"; case .eth: return "이더리움"; case .xrp: return "리플"; case .sol: return "솔라나"
        case .doge: return "도지코인"; case .ada: return "에이다"; case .trx: return "트론"; case .link: return "체인링크"
        case .avax: return "아발란체"; case .sui: return "수이"; case .xlm: return "스텔라루멘"; case .dot: return "폴카닷"
        }
    }
    var symbol: String { String(rawValue.dropFirst(4)) }
}

struct CoinWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "코인 선택"
    static var description = IntentDescription("위젯에 보여 줄 코인을 골라요.")
    @Parameter(title: "코인", default: .btc) var coin: WidgetCoin
}

struct CoinEntry: TimelineEntry {
    let date: Date
    let coin: WidgetCoin
    let price: Double?
    let rate: Double
    let spark: [Double]
}

struct CoinProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CoinEntry {
        CoinEntry(date: .now, coin: .btc, price: 82_000_000, rate: 0.012, spark: (0..<24).map { 80 + sin(Double($0) / 3) * 2 })
    }

    func snapshot(for configuration: CoinWidgetIntent, in context: Context) async -> CoinEntry {
        await load(configuration.coin)
    }

    func timeline(for configuration: CoinWidgetIntent, in context: Context) async -> Timeline<CoinEntry> {
        let entry = await load(configuration.coin)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    /// 업비트 공개 시세: 현재가·등락률 + 최근 24시간(1시간 봉) 흐름
    private func load(_ coin: WidgetCoin) async -> CoinEntry {
        struct T: Decodable { let trade_price: Double; let signed_change_rate: Double }
        struct C: Decodable { let trade_price: Double }
        var price: Double?, rate = 0.0, spark: [Double] = []
        if let url = URL(string: "https://api.upbit.com/v1/ticker?markets=\(coin.rawValue)"),
           let (d, _) = try? await URLSession.shared.data(from: url),
           let t = try? JSONDecoder().decode([T].self, from: d).first {
            price = t.trade_price; rate = t.signed_change_rate
        }
        if let url = URL(string: "https://api.upbit.com/v1/candles/minutes/60?market=\(coin.rawValue)&count=24"),
           let (d, _) = try? await URLSession.shared.data(from: url),
           let c = try? JSONDecoder().decode([C].self, from: d) {
            spark = c.map(\.trade_price).reversed()
        }
        return CoinEntry(date: .now, coin: coin, price: price, rate: rate, spark: spark)
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 0.000001)
            Path { p in
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

struct CoinWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CoinEntry

    var body: some View {
        let color = tint(entry.rate)
        switch family {
        case .accessoryInline:
            Text("\(entry.coin.symbol) \(entry.price.map(SharedFmt.price) ?? "-") \(SharedFmt.rate(entry.rate))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.coin.name).font(.caption2.weight(.semibold))
                Text("₩\(entry.price.map(SharedFmt.price) ?? "-")").font(.headline).minimumScaleFactor(0.6)
                Text(SharedFmt.rate(entry.rate)).font(.caption2.weight(.semibold))
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    header
                    Spacer()
                    Text("₩\(entry.price.map(SharedFmt.price) ?? "-")")
                        .font(.title2.weight(.bold)).minimumScaleFactor(0.5).lineLimit(1)
                    Text(SharedFmt.rate(entry.rate)).font(.subheadline.weight(.semibold)).foregroundStyle(color)
                }
                Sparkline(values: entry.spark, color: color).padding(.vertical, 8)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 2)
                Sparkline(values: entry.spark, color: color).frame(height: 26)
                Text("₩\(entry.price.map(SharedFmt.price) ?? "-")")
                    .font(.headline.weight(.bold)).minimumScaleFactor(0.5).lineLimit(1)
                Text(SharedFmt.rate(entry.rate)).font(.caption.weight(.semibold)).foregroundStyle(color)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(entry.coin.name).font(.caption.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 0)
            Text("TRADEX").font(.system(size: 8, weight: .heavy)).foregroundStyle(.secondary)
        }
    }
}

struct CoinPriceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CoinPriceWidget", intent: CoinWidgetIntent.self, provider: CoinProvider()) { entry in
            CoinWidgetView(entry: entry)
                .widgetURL(URL(string: "tradex://coin/\(entry.coin.rawValue)"))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("코인 시세")
        .description("업비트 실시간 시세를 홈 화면과 잠금화면에서 봐요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 선물 포지션 잠금화면 · 다이내믹 아일랜드

struct PositionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PositionActivityAttributes.self) { context in
            let a = context.attributes, s = context.state
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(a.koreanName).font(.headline)
                        Text("\(a.isLong ? "롱" : "숏") \(a.leverage)×").font(.caption.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
                    }
                    Text("현재 ₩\(SharedFmt.price(s.price)) · 진입 ₩\(SharedFmt.price(a.entryPrice))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("청산가 ₩\(SharedFmt.price(a.liquidationPrice))").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SharedFmt.rate(s.roe)).font(.title2.weight(.heavy)).foregroundStyle(tint(s.pnl))
                    Text(SharedFmt.signedKRW(s.pnl)).font(.caption.weight(.semibold)).foregroundStyle(tint(s.pnl))
                }
            }
            .padding(16)
            .widgetURL(URL(string: "tradex://coin/\(a.market)"))
        } dynamicIsland: { context in
            let a = context.attributes, s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.symbol).font(.headline)
                        Text("\(a.isLong ? "롱" : "숏") \(a.leverage)×").font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SharedFmt.rate(s.roe)).font(.headline).foregroundStyle(tint(s.pnl))
                        Text(SharedFmt.signedKRW(s.pnl)).font(.caption2).foregroundStyle(tint(s.pnl))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("현재 ₩\(SharedFmt.price(s.price)) · 청산가 ₩\(SharedFmt.price(a.liquidationPrice))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(a.symbol).font(.caption2.weight(.bold))
            } compactTrailing: {
                Text(SharedFmt.rate(s.roe)).font(.caption2.weight(.bold)).foregroundStyle(tint(s.pnl))
            } minimal: {
                Image(systemName: s.pnl >= 0 ? "arrow.up" : "arrow.down").foregroundStyle(tint(s.pnl))
            }
            .widgetURL(URL(string: "tradex://coin/\(a.market)"))
        }
    }
}
