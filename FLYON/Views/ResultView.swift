import Charts
import SwiftUI

struct ResultView: View {
    let search: RouteSearch

    @Environment(AppState.self) private var appState

    private enum Phase {
        case loading
        case loaded(analysis: PriceAnalysis, history: [PricePoint], quotes: [PriceQuote])
        case failed
    }

    @State private var phase: Phase = .loading

    private var route: FavoriteRoute {
        FavoriteRoute(originCode: search.origin.code, destinationCode: search.destination.code)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                switch phase {
                case .loading:
                    ProgressView("가격을 불러오는 중")
                        .frame(maxWidth: .infinity, minHeight: 240)
                case .failed:
                    ContentUnavailableView {
                        Label("가격을 불러오지 못했어요", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("네트워크 상태를 확인하고 다시 시도해 주세요.")
                    } actions: {
                        Button("다시 시도") { Task { await load() } }
                    }
                case let .loaded(analysis, history, quotes):
                    summaryCard(analysis)
                    chartCard(analysis, history)
                    if quotes.isEmpty {
                        Text("선택한 조건에 맞는 항공사 가격이 없어요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        quotesCard(quotes)
                    }
                }

                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.screenBackground)
        .navigationTitle("\(search.origin.city) → \(search.destination.city)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.toggleFavorite(route)
                } label: {
                    Image(systemName: appState.isFavorite(route) ? "star.fill" : "star")
                        .foregroundStyle(appState.isFavorite(route) ? .yellow : Theme.accent)
                }
                .accessibilityLabel(appState.isFavorite(route) ? "관심 노선 해제" : "관심 노선 추가")
            }
        }
        .task { await load() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Label(search.month.monthTitle, systemImage: "calendar")
            if !search.airlines.isEmpty {
                Label("\(search.airlines.count)개 항공사", systemImage: "airplane.circle")
            }
            Spacer()
            if appState.provider.isSample {
                Label("샘플 데이터", systemImage: "testtube.2")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func summaryCard(_ a: PriceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("현재 참고 가격").font(.footnote).foregroundStyle(.secondary)
            Text(a.current.won).font(.system(size: 38, weight: .bold, design: .rounded))
            HStack(spacing: 10) {
                Label(a.verdict.title, systemImage: a.verdict.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(a.verdict.color)
                Text(a.deviationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func chartCard(_ a: PriceAnalysis, _ history: [PricePoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("최근 30일 가격 흐름", systemImage: "chart.xyaxis.line")

            Chart {
                ForEach(history) { p in
                    AreaMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(
                            colors: [Theme.accent.opacity(0.25), Theme.accent.opacity(0)],
                            startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Theme.accent)
                }
                RuleMark(y: .value("평균", a.average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("평균").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) { Text(v.shortWon) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .frame(height: 200)

            HStack {
                stat("최저", a.lowest.won, Theme.cheap)
                Divider().frame(height: 28)
                stat("평균", a.average.won, .primary)
                Divider().frame(height: 28)
                stat("최고", a.highest.won, Theme.expensive)
            }
        }
        .card()
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func quotesCard(_ quotes: [PriceQuote]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("항공사별 최저가", systemImage: "airplane")
                .padding(.bottom, 8)
            ForEach(Array(quotes.enumerated()), id: \.element.id) { index, q in
                HStack(spacing: 12) {
                    Image(systemName: "airplane")
                        .font(.footnote)
                        .foregroundStyle(index == 0 ? Theme.accent : .secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(q.airline.name).font(.subheadline.weight(.medium))
                        Text("\(q.departureDate.dayTitle) · \(q.transfers == 0 ? "직항" : "경유 \(q.transfers)회")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(q.price.won)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(index == 0 ? Theme.accent : .primary)
                }
                .padding(.vertical, 8)
                if index < quotes.count - 1 { Divider() }
            }
        }
        .card()
    }

    private var disclaimer: some View {
        Label {
            Text("참고용 가격이며 실제 예약 가격과 다를 수 있어요. FLYON은 항공권을 판매하거나 예약을 중개하지 않아요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Loading

    private func load() async {
        phase = .loading
        do {
            async let history = appState.provider.history(origin: search.origin, destination: search.destination, days: 30)
            async let quotes = appState.provider.quotes(origin: search.origin, destination: search.destination,
                                                       month: search.month, airlines: search.airlines)
            let (h, q) = try await (history, quotes)
            guard let analysis = PriceAnalysis(history: h) else {
                phase = .failed
                return
            }
            phase = .loaded(analysis: analysis, history: h, quotes: q)
        } catch {
            phase = .failed
        }
    }
}
