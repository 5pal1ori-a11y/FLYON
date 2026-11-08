import Charts
import SwiftUI

struct ResultView: View {
    let search: RouteSearch

    @Environment(AppState.self) private var appState

    private enum Phase { case loading, loaded, failed }
    private enum Tab: String, CaseIterable, Identifiable {
        case flights = "항공편"
        case trend = "가격 흐름"
        var id: String { rawValue }
    }

    @Namespace private var ns
    @State private var phase: Phase = .loading
    @State private var history: [PricePoint] = []
    @State private var calendar: [CalendarDay] = []
    @State private var calendarFailed = false
    @State private var tab: Tab = .flights
    @State private var month: Date
    @State private var selectedDate: Date?
    @State private var flights: [Flight] = []
    @State private var flightsLoading = false
    @State private var flightsFailed = false
    @State private var directOnly = false
    @State private var excludeLowCost = false
    @State private var showCalendar = false
    @State private var showAlertSheet = false
    @State private var chartReveal: CGFloat = 0

    init(search: RouteSearch) {
        self.search = search
        _month = State(initialValue: search.month)
    }

    private var cal: Calendar { Calendar.current }
    private var route: FavoriteRoute {
        FavoriteRoute(originCode: search.origin.code, destinationCode: search.destination.code)
    }
    private var sortedCalendar: [CalendarDay] { calendar.sorted { $0.date < $1.date } }
    private var cheapestDay: CalendarDay? { calendar.min { $0.price < $1.price } }

    private var visibleFlights: [Flight] {
        flights
            .filter { (!directOnly || $0.transfers == 0) && (!excludeLowCost || !$0.airline.isLowCost) }
            .sorted { $0.price < $1.price }
    }

    private var recentHistory: [PricePoint] {
        let cutoff = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: .now)) ?? .distantPast
        return history.filter { $0.date >= cutoff }
    }

    private var analysis: PriceAnalysis? { PriceAnalysis(history: recentHistory) }

    /// 지금 고른 조건의 최저가 (알림 기준가)
    private var currentLowest: Int? {
        visibleFlights.first?.price ?? cheapestDay?.price ?? analysis?.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                subtitle

                switch phase {
                case .loading:
                    VStack(spacing: 12) {
                        SkeletonBlock(height: 64, radius: 14)
                        SkeletonBlock(height: 96)
                        SkeletonBlock(height: 96)
                        SkeletonBlock(height: 96)
                    }
                case .failed:
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("가격을 불러오지 못했어요")
                            .font(.app(16, .semibold))
                        Button("다시 시도") { Task { await load() } }
                            .font(.app(15, .semibold))
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                case .loaded:
                    segmented
                    Group {
                        switch tab {
                        case .flights: flightsTab.transition(.move(edge: .leading).combined(with: .opacity))
                        case .trend: trendTab.transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.86), value: tab)
                }

                Text("참고용 가격이에요")
                    .font(.app(12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.screenBackground)
        .navigationTitle("\(search.origin.city) → \(search.destination.city)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showAlertSheet = true } label: {
                    Image(systemName: "bell.badge")
                }
                .accessibilityLabel("가격 알림 만들기")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { appState.toggleFavorite(route) }
                } label: {
                    Image(systemName: appState.isFavorite(route) ? "heart.fill" : "heart")
                        .foregroundStyle(appState.isFavorite(route) ? Theme.expensive : Theme.accent)
                        .symbolEffect(.bounce, value: appState.isFavorite(route))
                }
                .sensoryFeedback(.success, trigger: appState.isFavorite(route))
                .accessibilityLabel("관심 노선")
            }
        }
        .sheet(isPresented: $showCalendar) { calendarSheet }
        .sheet(isPresented: $showAlertSheet) {
            CreateAlertView(search: search, selectedDate: selectedDate, month: month, currentPrice: currentLowest)
        }
        .task { await load() }
    }

    private var subtitle: some View {
        HStack(spacing: 6) {
            Text(search.cabin.title)
            Text("·")
            Text(search.airlines.isEmpty ? "전체 항공사" : search.airlines.map(\.name).sorted().joined(separator: ", "))
                .lineLimit(1)
            if appState.provider.isSample {
                Spacer()
                Pill(text: "샘플", color: .orange)
            }
        }
        .font(.app(13, .medium))
        .foregroundStyle(.secondary)
    }

    // MARK: 탭 전환

    private var segmented: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(.app(14, .semibold))
                        .foregroundStyle(tab == t ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if tab == t {
                                Capsule().fill(Theme.accent).matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.cardBackground, in: Capsule())
        .sensoryFeedback(.selection, trigger: tab)
    }

    // MARK: 항공편

    private var flightsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            dateStrip

            HStack(spacing: 8) {
                FilterChip(title: "직항만", isOn: $directOnly)
                FilterChip(title: "저비용 제외", isOn: $excludeLowCost)
                Spacer()
            }

            flightList
        }
    }

    @ViewBuilder
    private var dateStrip: some View {
        if sortedCalendar.isEmpty {
            HStack {
                Text(calendarFailed ? "날짜별 가격을 불러오지 못했어요" : "\(month.monthShort) 가격 정보가 없어요")
                    .font(.app(14))
                    .foregroundStyle(.secondary)
                Spacer()
                if calendarFailed {
                    Button("다시") { Task { await loadMonth() } }.font(.app(14, .semibold))
                }
                calendarButton
            }
            .card(padding: 14)
        } else {
            HStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedCalendar) { day in dateChip(day).id(day.date) }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: selectedDate) { _, value in
                        if let value { withAnimation(.snappy) { proxy.scrollTo(value, anchor: .center) } }
                    }
                    .onAppear {
                        if let selectedDate { proxy.scrollTo(selectedDate, anchor: .center) }
                    }
                }
                calendarButton
            }
            .sensoryFeedback(.selection, trigger: selectedDate)
        }
    }

    private var calendarButton: some View {
        Button { showCalendar = true } label: {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 62)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("달력")
    }

    private func dateChip(_ day: CalendarDay) -> some View {
        let selected = selectedDate.map { cal.isDate($0, inSameDayAs: day.date) } ?? false
        let cheapest = day.id == cheapestDay?.id
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { select(day.date) }
        } label: {
            VStack(spacing: 4) {
                Text("\(day.date.shortDay) \(day.date.weekdayShort)")
                    .font(.app(12, .medium))
                Text(day.price.shortWon)
                    .font(.app(14, .bold))
            }
            .foregroundStyle(selected ? Color.white : (cheapest ? Theme.cheap : Color.primary))
            .frame(width: 70, height: 62)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accent)
                        .matchedGeometryEffect(id: "date", in: ns)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.cardBackground)
                }
            }
            .overlay(alignment: .top) {
                if cheapest && !selected {
                    Circle().fill(Theme.cheap).frame(width: 6, height: 6).offset(y: 5)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private var flightList: some View {
        if flightsLoading {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 84) }
            }
        } else if flightsFailed {
            HStack {
                Text("항공편을 불러오지 못했어요").font(.app(14)).foregroundStyle(.secondary)
                Spacer()
                Button("다시") { Task { await loadFlights() } }.font(.app(14, .semibold))
            }
            .card()
        } else if visibleFlights.isEmpty {
            Text(flights.isEmpty ? "이 날짜의 항공편 정보가 없어요" : "조건에 맞는 항공편이 없어요")
                .font(.app(14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .card()
        } else {
            let lowest = visibleFlights.first?.price
            VStack(spacing: 10) {
                ForEach(Array(visibleFlights.enumerated()), id: \.element.id) { index, flight in
                    FlightCard(flight: flight, isCheapest: flight.price == lowest)
                        .appear(delay: Double(index) * 0.04)
                }
            }
        }
    }

    // MARK: 가격 흐름

    private var trendTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("현재 최저가")
                    .font(.app(13, .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text((currentLowest ?? 0) > 0 ? currentLowest!.won : "––")
                    .font(.app(38, .heavy))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                if let a = analysis, a.verdict != .collecting {
                    Pill(text: a.verdict.title, systemImage: a.verdict.symbol,
                         color: a.verdict.color == Theme.mid ? .yellow : a.verdict.color)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.headerGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                if let a = analysis, recentHistory.count >= 2 {
                    Chart {
                        ForEach(recentHistory) { p in
                            AreaMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.25), Theme.accent.opacity(0)],
                                                                startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel { if let v = value.as(Int.self) { Text(v.shortWon).font(.app(10)) } }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .frame(height: 200)
                    .mask(alignment: .leading) {
                        GeometryReader { g in Rectangle().frame(width: g.size.width * chartReveal) }
                    }
                    .onAppear {
                        chartReveal = 0
                        withAnimation(.easeOut(duration: 1.0)) { chartReveal = 1 }
                    }

                    HStack {
                        stat("최저", a.lowest.won, Theme.cheap)
                        stat("최고", a.highest.won, Theme.expensive)
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.accent)
                            .symbolEffect(.pulse)
                        Text("가격 흐름을 모으는 중이에요")
                            .font(.app(15, .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .card()
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.app(12)).foregroundStyle(.secondary)
            Text(value).font(.app(15, .bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 달력

    private var canGoBack: Bool { month > (FlyView.months.first ?? month) }
    private var canGoForward: Bool { month < (FlyView.months.last ?? month) }

    private var calendarSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .disabled(!canGoBack)
                    Spacer()
                    Text(month.monthTitle)
                        .font(.app(17, .bold))
                        .contentTransition(.numericText())
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(!canGoForward)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)

                CalendarGrid(month: month, days: calendar, selected: selectedDate) { date in
                    select(date)
                    showCalendar = false
                }
                .id(month)
                .transition(.opacity)

                Spacer()
            }
            .padding(20)
            .navigationTitle("날짜 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { showCalendar = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: 동작

    private func shiftMonth(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.snappy) { month = next }
        Task { await loadMonth() }
    }

    private func select(_ date: Date) {
        selectedDate = date
        Task { await loadFlights() }
    }

    private func load() async {
        phase = .loading
        do {
            // 처음 조회하는 노선은 서버가 이 호출에서 수집을 시작하므로 이력을 먼저 기다린다
            history = try await appState.provider.history(
                origin: search.origin, destination: search.destination, days: 90, airlines: search.airlines, cabin: search.cabin)
        } catch {
            history = []
        }
        await fetchCalendar()
        chooseInitialDate()
        withAnimation(.easeOut(duration: 0.3)) {
            phase = (calendarFailed && history.isEmpty) ? .failed : .loaded
        }
        await loadFlights()
    }

    private func loadMonth() async {
        await fetchCalendar()
        if let selectedDate, !calendar.contains(where: { cal.isDate($0.date, inSameDayAs: selectedDate) }) {
            self.selectedDate = cheapestDay?.date
        }
        await loadFlights()
    }

    private func fetchCalendar() async {
        do {
            let days = try await appState.provider.calendar(
                origin: search.origin, destination: search.destination, month: month, airlines: search.airlines, cabin: search.cabin)
            withAnimation(.easeOut(duration: 0.25)) { calendar = days }
            calendarFailed = false
        } catch {
            calendar = []
            calendarFailed = true
        }
    }

    private func chooseInitialDate() {
        if let wanted = search.date, let match = calendar.first(where: { cal.isDate($0.date, inSameDayAs: wanted) }) {
            selectedDate = match.date
        } else {
            selectedDate = cheapestDay?.date
        }
    }

    private func loadFlights() async {
        guard let date = selectedDate else {
            flights = []
            return
        }
        flightsLoading = true
        flightsFailed = false
        do {
            let result = try await appState.provider.flights(
                origin: search.origin, destination: search.destination, date: date, airlines: search.airlines, cabin: search.cabin)
            withAnimation(.easeOut(duration: 0.25)) { flights = result }
        } catch {
            flights = []
            flightsFailed = true
        }
        flightsLoading = false
    }
}

// MARK: - 구성요소

private struct FilterChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            HStack(spacing: 5) {
                if isOn { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).transition(.scale.combined(with: .opacity)) }
                Text(title).font(.app(14, .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Theme.accent : Theme.cardBackground, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

private struct FlightCard: View {
    let flight: Flight
    let isCheapest: Bool

    var body: some View {
        HStack(spacing: 14) {
            AirlineLogo(code: flight.airline.code, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                if let dep = flight.departureTime {
                    HStack(spacing: 6) {
                        Text(dep)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
                        Text(flight.arrivalTime?.text ?? "––")
                        if flight.arrivalTime?.nextDay == true {
                            Text("+1").font(.app(11, .bold)).foregroundStyle(Theme.expensive)
                        }
                    }
                    .font(.app(17, .bold))
                }
                Text(detail)
                    .font(.app(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                Text(flight.price.won)
                    .font(.app(17, .bold))
                    .foregroundStyle(isCheapest ? Theme.accent : .primary)
                if isCheapest { Pill(text: "최저가", color: Theme.cheap) }
            }
        }
        .card(padding: 16)
    }

    private var detail: String {
        var parts = [flight.airline.name]
        if let d = flight.durationText { parts.append(d) }
        parts.append(flight.transfers == 0 ? "직항" : "경유 \(flight.transfers)회")
        return parts.joined(separator: " · ")
    }
}

private struct CalendarGrid: View {
    let month: Date
    let days: [CalendarDay]
    var selected: Date? = nil
    var onSelect: ((Date) -> Void)? = nil

    private let cal = Calendar(identifier: .gregorian)
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let dayCount = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let leading = cal.component(.weekday, from: start) - 1
        let prices = Dictionary(days.map { (cal.component(.day, from: $0.date), $0.price) }, uniquingKeysWith: { Swift.min($0, $1) })
        let sorted = days.map(\.price).sorted()
        let low = sorted.isEmpty ? 0 : sorted[sorted.count / 4]
        let high = sorted.isEmpty ? 0 : sorted[(sorted.count * 3) / 4]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w)
                        .font(.app(12, .semibold))
                        .foregroundStyle(w == "일" ? Theme.expensive : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 50) }
                ForEach(1...dayCount, id: \.self) { day in
                    let date = cal.date(byAdding: .day, value: day - 1, to: start) ?? start
                    cell(day: day, date: date, price: prices[day], low: low, high: high)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(day: Int, date: Date, price: Int?, low: Int, high: Int) -> some View {
        let tone: Color = {
            guard let price else { return .clear }
            if price <= low { return Theme.cheap }
            if price >= high { return Theme.expensive }
            return Theme.mid
        }()
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let content = VStack(spacing: 2) {
            Text("\(day)").font(.app(12, .medium)).foregroundStyle(isSelected ? Color.white : .primary)
            Text(price.map { $0.shortWon } ?? " ")
                .font(.app(10, .bold))
                .foregroundStyle(isSelected ? Color.white : tone)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(isSelected ? Theme.accent : tone.opacity(price == nil ? 0 : 0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        if price != nil, let onSelect {
            Button { onSelect(date) } label: { content }.buttonStyle(PressableStyle())
        } else {
            content.opacity(0.45)
        }
    }
}
