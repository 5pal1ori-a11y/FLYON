import Charts
import SwiftUI

struct ResultView: View {
    let search: RouteSearch

    @Environment(AppState.self) private var appState

    private struct Loaded {
        var history: [PricePoint]
        var calendar: [CalendarDay]
        var quotes: [PriceQuote]
    }

    private enum Phase { case loading, loaded, failed }
    private enum RangeOption: Int, CaseIterable, Identifiable {
        case week = 7, month = 30, quarter = 90
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .week: return "7일"
            case .month: return "30일"
            case .quarter: return "90일"
            }
        }
    }

    @State private var phase: Phase = .loading
    @State private var data = Loaded(history: [], calendar: [], quotes: [])
    @State private var range: RangeOption = .month
    @State private var month: Date
    @State private var monthLoading = false
    @State private var showAllQuotes = false
    @State private var errorDetail: String?
    @State private var calendarError: String?
    @State private var quotesError: String?

    init(search: RouteSearch) {
        self.search = search
        _month = State(initialValue: search.month)
    }

    private var route: FavoriteRoute {
        FavoriteRoute(originCode: search.origin.code, destinationCode: search.destination.code)
    }

    private var rangeHistory: [PricePoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -(range.rawValue - 1), to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        return data.history.filter { $0.date >= cutoff }
    }

    private var analysis: PriceAnalysis? { PriceAnalysis(history: rangeHistory) }

    private var hasAnyData: Bool {
        !(data.history.isEmpty && data.calendar.isEmpty && data.quotes.isEmpty)
            || calendarError != nil || quotesError != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .loading:
                    hero(placeholder: true)
                    ProgressView("가격을 불러오는 중이에요")
                        .frame(maxWidth: .infinity, minHeight: 200)
                case .failed:
                    hero(placeholder: true)
                    ContentUnavailableView {
                        Label("가격을 불러오지 못했어요", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("네트워크 상태를 확인하고 다시 시도해 주세요." + (errorDetail.map { "\n(\($0))" } ?? ""))
                    } actions: {
                        Button("다시 시도") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                case .loaded:
                    if hasAnyData {
                        hero(placeholder: false)
                        rangePicker
                        chartCard
                        calendarCard
                        quotesCard
                    } else {
                        hero(placeholder: true)
                        emptyState
                    }
                }
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
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

    // MARK: Hero

    private func hero(placeholder: Bool) -> some View {
        let price = analysis?.current ?? data.quotes.first?.price ?? data.calendar.map(\.price).min()
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                IATABadge(code: search.origin.code, onDark: true)
                Image(systemName: "airplane").font(.caption).foregroundStyle(.white.opacity(0.8))
                IATABadge(code: search.destination.code, onDark: true)
                Spacer()
                if appState.provider.isSample {
                    Pill(text: "샘플 데이터", systemImage: "testtube.2", color: .orange)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(analysis.map { "\($0.lastDate.dayTitle) 기준 최저가" } ?? "현재 참고 최저가")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                if let price, !placeholder {
                    Text(price.won)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("––––")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            if let a = analysis, !placeholder {
                HStack(spacing: 10) {
                    Pill(text: a.verdict.title, systemImage: a.verdict.symbol, color: a.verdict.color == Theme.mid ? .yellow : a.verdict.color)
                    Text(a.deviationText)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.headerGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var rangePicker: some View {
        Picker("기간", selection: $range) {
            ForEach(RangeOption.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "가격 흐름", subtitle: "수집일별 최저가")

            if let a = analysis, rangeHistory.count >= 2 {
                Chart {
                    ForEach(rangeHistory) { p in
                        AreaMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(
                                colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(Theme.accent)
                    }
                    RuleMark(y: .value("평균", a.average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("평균 \(a.average.shortWon)").font(.caption2).foregroundStyle(.secondary)
                        }
                    if let low = rangeHistory.min(by: { $0.price < $1.price }) {
                        PointMark(x: .value("날짜", low.date), y: .value("가격", low.price))
                            .foregroundStyle(Theme.cheap)
                            .symbolSize(70)
                    }
                    if let last = rangeHistory.max(by: { $0.date < $1.date }) {
                        PointMark(x: .value("날짜", last.date), y: .value("가격", last.price))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(90)
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
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 200)

                HStack {
                    stat("최저", a.lowest.won, Theme.cheap)
                    Divider().frame(height: 30)
                    stat("평균", a.average.won, .primary)
                    Divider().frame(height: 30)
                    stat("최고", a.highest.won, Theme.expensive)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                    Text("이 노선의 가격 이력을 모으기 시작했어요. 며칠 지나면 가격 흐름 그래프가 나타나요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .card()
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Calendar

    private var canGoBack: Bool { month > (PricingView.months.first ?? month) }
    private var canGoForward: Bool { month < (PricingView.months.last ?? month) }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "출발일별 최저가", subtitle: "싼 날을 한눈에 확인해요")
                Spacer()
                HStack(spacing: 4) {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .disabled(!canGoBack || monthLoading)
                    Text(month.monthTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 84)
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(!canGoForward || monthLoading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }

            if data.calendar.isEmpty {
                Text(monthLoading ? "불러오는 중..." : (calendarError.map { "불러오지 못했어요 (\($0))" } ?? "이 달의 출발일별 가격 데이터가 아직 없어요."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                if let cheapest = data.calendar.min(by: { $0.price < $1.price }) {
                    HStack(spacing: 8) {
                        Pill(text: "가장 싼 날", systemImage: "arrow.down.right", color: Theme.cheap)
                        Text("\(cheapest.date.dayTitle)  \(cheapest.price.won)")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                CalendarGrid(month: month, days: data.calendar)
                HStack(spacing: 14) {
                    legendDot(Theme.cheap, "저렴")
                    legendDot(Theme.mid, "보통")
                    legendDot(Theme.expensive, "비쌈")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .card()
        .opacity(monthLoading ? 0.6 : 1)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.4)).frame(width: 12, height: 12)
            Text(text)
        }
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        month = next
        Task { await loadMonth() }
    }

    // MARK: Quotes

    private var quotesCard: some View {
        let quotes = data.quotes
        let shown = showAllQuotes ? quotes : Array(quotes.prefix(6))
        return VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "항공사별 최저가", subtitle: "\(month.monthTitle) 출발 기준")
                .padding(.bottom, 8)

            if quotes.isEmpty {
                Text(monthLoading ? "불러오는 중..." : (quotesError.map { "불러오지 못했어요 (\($0))" } ?? "선택한 조건에 맞는 항공사 가격이 없어요."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, q in
                    HStack(spacing: 12) {
                        AirlineBadge(code: q.airline.code)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(q.airline.name).font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(q.departureDate.dayTitle)
                                Text(q.transfers == 0 ? "직항" : "경유 \(q.transfers)회")
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(q.price.won)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(index == 0 ? Theme.accent : .primary)
                            if index == 0 { Pill(text: "최저", color: Theme.cheap) }
                        }
                    }
                    .padding(.vertical, 8)
                    if index < shown.count - 1 { Divider() }
                }
                if quotes.count > 6 {
                    Button(showAllQuotes ? "접기" : "항공사 \(quotes.count)곳 모두 보기") {
                        withAnimation { showAllQuotes.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
            }
        }
        .card()
    }

    // MARK: Empty / disclaimer

    private var emptyState: some View {
        ContentUnavailableView {
            Label("이 노선의 가격 데이터가 아직 없어요", systemImage: "tray")
        } description: {
            Text("제공처에 검색 기록이 거의 없는 노선일 수 있어요. 인기 노선이나 다른 달을 선택해 보세요.")
        } actions: {
            Button("다시 시도") { Task { await load() } }
        }
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
        errorDetail = nil
        do {
            // 처음 조회하는 노선은 서버가 이 호출에서 수집을 시작하므로 이력을 먼저 기다린다
            let history = try await appState.provider.history(
                origin: search.origin, destination: search.destination, days: 90, airlines: search.airlines)
            data = Loaded(history: history, calendar: [], quotes: [])
        } catch {
            errorDetail = error.localizedDescription
            phase = .failed
            return
        }
        await fetchMonthData()
        phase = .loaded
    }

    private func loadMonth() async {
        monthLoading = true
        defer { monthLoading = false }
        await fetchMonthData()
    }

    /// 달력과 항공사 목록은 서로 독립적으로 가져온다. 한쪽이 실패해도 나머지는 보여 준다.
    private func fetchMonthData() async {
        async let calendarResult = capture {
            try await appState.provider.calendar(
                origin: search.origin, destination: search.destination, month: month, airlines: search.airlines)
        }
        async let quotesResult = capture {
            try await appState.provider.quotes(
                origin: search.origin, destination: search.destination, month: month, airlines: search.airlines)
        }
        let (c, q) = await (calendarResult, quotesResult)

        switch c {
        case .success(let days): data.calendar = days; calendarError = nil
        case .failure(let error): data.calendar = []; calendarError = error.localizedDescription
        }
        switch q {
        case .success(let quotes): data.quotes = quotes; quotesError = nil
        case .failure(let error): data.quotes = []; quotesError = error.localizedDescription
        }
    }

    private func capture<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}

// MARK: - 달력 히트맵

private struct CalendarGrid: View {
    let month: Date
    let days: [CalendarDay]

    private let cal = Calendar(identifier: .gregorian)
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    private var pricesByDay: [Int: Int] {
        Dictionary(days.map { (cal.component(.day, from: $0.date), $0.price) }, uniquingKeysWith: { Swift.min($0, $1) })
    }

    private var thresholds: (low: Int, high: Int) {
        let sorted = days.map(\.price).sorted()
        guard sorted.count >= 3 else { return (sorted.first ?? 0, sorted.last ?? 0) }
        return (sorted[sorted.count / 4], sorted[(sorted.count * 3) / 4])
    }

    var body: some View {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let dayCount = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let leading = cal.component(.weekday, from: start) - 1
        let prices = pricesByDay
        let t = thresholds
        let cheapest = days.map(\.price).min()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(w == "일" ? Theme.expensive : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 46) }
                ForEach(1...dayCount, id: \.self) { day in
                    cell(day: day, price: prices[day], low: t.low, high: t.high, cheapest: cheapest)
                }
            }
        }
    }

    private func cell(day: Int, price: Int?, low: Int, high: Int, cheapest: Int?) -> some View {
        let tone: Color = {
            guard let price else { return .clear }
            if price <= low { return Theme.cheap }
            if price >= high { return Theme.expensive }
            return Theme.mid
        }()
        return VStack(spacing: 1) {
            Text("\(day)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(price.map { $0.shortWon } ?? "–")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(price == nil ? Color.secondary.opacity(0.5) : tone)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(tone.opacity(price == nil ? 0 : 0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if let price, price == cheapest {
                RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cheap, lineWidth: 1.5)
            }
        }
    }
}
