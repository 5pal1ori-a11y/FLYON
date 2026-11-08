import Charts
import SwiftUI

struct ResultView: View {
    let search: RouteSearch

    @Environment(AppState.self) private var appState

    private struct Loaded {
        var history: [PricePoint]
        var calendar: [CalendarDay]
    }

    private enum Phase { case loading, loaded, failed }
    private enum Tab: String, CaseIterable, Identifiable {
        case flights = "항공편"
        case trend = "가격 추이"
        var id: String { rawValue }
    }

    @State private var phase: Phase = .loading
    @State private var data = Loaded(history: [], calendar: [])
    @State private var tab: Tab = .flights
    @State private var month: Date
    @State private var selectedDate: Date?
    @State private var flights: [Flight] = []
    @State private var flightsLoading = false
    @State private var flightsError: String?
    @State private var directOnly = false
    @State private var excludeLowCost = false
    @State private var showCalendar = false
    @State private var monthLoading = false
    @State private var errorDetail: String?
    @State private var calendarError: String?

    init(search: RouteSearch) {
        self.search = search
        _month = State(initialValue: search.month)
    }

    private var route: FavoriteRoute {
        FavoriteRoute(originCode: search.origin.code, destinationCode: search.destination.code)
    }

    private var cal: Calendar { Calendar.current }

    private var sortedCalendar: [CalendarDay] { data.calendar.sorted { $0.date < $1.date } }
    private var cheapestDay: CalendarDay? { data.calendar.min { $0.price < $1.price } }

    private var visibleFlights: [Flight] {
        flights
            .filter { (!directOnly || $0.transfers == 0) && (!excludeLowCost || !$0.airline.isLowCost) }
            .sorted { $0.price < $1.price }
    }

    private var recentHistory: [PricePoint] {
        let cutoff = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: .now)) ?? .distantPast
        return data.history.filter { $0.date >= cutoff }
    }

    private var analysis: PriceAnalysis? { PriceAnalysis(history: recentHistory) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .loading:
                    ProgressView("가격을 불러오는 중이에요")
                        .frame(maxWidth: .infinity, minHeight: 240)
                case .failed:
                    ContentUnavailableView {
                        Label("불러오지 못했어요", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("네트워크를 확인하고 다시 시도해 주세요." + (errorDetail.map { "\n(\($0))" } ?? ""))
                    } actions: {
                        Button("다시 시도") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                case .loaded:
                    Picker("보기", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .flights: flightsTab
                    case .trend: trendTab
                    }
                }

                Text("참고용 가격이며 실제 예약 가격과 다를 수 있어요. FLYON은 항공권을 판매하거나 예약을 중개하지 않아요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Image(systemName: appState.isFavorite(route) ? "heart.fill" : "heart")
                        .foregroundStyle(appState.isFavorite(route) ? Theme.expensive : Theme.accent)
                }
                .accessibilityLabel(appState.isFavorite(route) ? "관심 노선 해제" : "관심 노선 추가")
            }
        }
        .sheet(isPresented: $showCalendar) { calendarSheet }
        .task { await load() }
    }

    // MARK: 항공편 탭

    private var flightsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if appState.provider.isSample {
                Pill(text: "샘플 데이터", color: .orange)
            }

            dateStrip

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "직항만", isOn: $directOnly)
                    FilterChip(title: "저비용 항공사 제외", isOn: $excludeLowCost)
                }
            }

            if let date = selectedDate {
                Text("\(date.dayTitle) 출발 · 1인 편도 참고 가격")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            flightList
        }
    }

    /// 날짜별 최저가 띠 (오른쪽 끝의 달력 버튼으로 월 전체 보기)
    @ViewBuilder
    private var dateStrip: some View {
        if sortedCalendar.isEmpty {
            HStack {
                Text(calendarError.map { "달력을 불러오지 못했어요 (\($0))" } ?? "\(month.monthTitle) 출발 가격 데이터가 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                calendarButton
            }
            .card()
        } else {
            HStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedCalendar) { day in
                                dateChip(day).id(day.date)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: selectedDate) { _, newValue in
                        if let newValue { withAnimation { proxy.scrollTo(newValue, anchor: .center) } }
                    }
                    .onAppear {
                        if let selectedDate { proxy.scrollTo(selectedDate, anchor: .center) }
                    }
                }
                calendarButton
            }
        }
    }

    private var calendarButton: some View {
        Button { showCalendar = true } label: {
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.accent)
            .frame(width: 44, height: 60)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel("달력으로 날짜 선택")
    }

    private func dateChip(_ day: CalendarDay) -> some View {
        let selected = selectedDate.map { cal.isDate($0, inSameDayAs: day.date) } ?? false
        let cheapest = day.id == cheapestDay?.id
        return Button {
            select(day.date)
        } label: {
            VStack(spacing: 3) {
                Text("\(day.date.shortDay)(\(day.date.weekdayShort))")
                    .font(.footnote.weight(.semibold))
                Text(day.price.shortWon)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                if cheapest {
                    Text("최저").font(.system(size: 9, weight: .bold))
                } else {
                    Text(" ").font(.system(size: 9))
                }
            }
            .foregroundStyle(selected ? Color.white : (cheapest ? Theme.cheap : Color.primary))
            .frame(width: 68, height: 60)
            .background(selected ? Theme.accent : Theme.cardBackground,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var flightList: some View {
        if flightsLoading {
            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
        } else if let flightsError {
            Text("항공편을 불러오지 못했어요 (\(flightsError))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .card()
        } else if visibleFlights.isEmpty {
            Text(flights.isEmpty ? "이 날짜의 항공편 정보가 없어요." : "필터에 맞는 항공편이 없어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        } else {
            let cheapestPrice = visibleFlights.map(\.price).min()
            VStack(spacing: 0) {
                ForEach(Array(visibleFlights.enumerated()), id: \.element.id) { index, flight in
                    FlightRow(flight: flight, isCheapest: flight.price == cheapestPrice)
                    if index < visibleFlights.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
    }

    // MARK: 가격 추이 탭

    private var trendTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            trendHero

            VStack(alignment: .leading, spacing: 14) {
                if let a = analysis, recentHistory.count >= 2 {
                    Chart {
                        ForEach(recentHistory) { p in
                            AreaMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(
                                    colors: [Theme.accent.opacity(0.25), Theme.accent.opacity(0)],
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

                    Text("최근 30일  최저 \(a.lowest.won) · 평균 \(a.average.won) · 최고 \(a.highest.won)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                        Text("가격 이력을 모으는 중이에요. 며칠 지나면 그래프가 나타나요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var trendHero: some View {
        let price = analysis?.current ?? cheapestDay?.price
        return VStack(alignment: .leading, spacing: 10) {
            Text("현재 최저가")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            if let price {
                Text(price.won)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Text("––––")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            if let a = analysis {
                HStack(spacing: 10) {
                    Pill(text: a.verdict.title, systemImage: a.verdict.symbol,
                         color: a.verdict.color == Theme.mid ? .yellow : a.verdict.color)
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

    // MARK: 달력 시트

    private var canGoBack: Bool { month > (PricingView.months.first ?? month) }
    private var canGoForward: Bool { month < (PricingView.months.last ?? month) }

    private var calendarSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .disabled(!canGoBack || monthLoading)
                        Spacer()
                        Text(month.monthTitle).font(.headline)
                        Spacer()
                        Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(!canGoForward || monthLoading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)

                    if data.calendar.isEmpty {
                        Text(monthLoading ? "불러오는 중..." : "이 달의 가격 데이터가 아직 없어요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        CalendarGrid(month: month, days: data.calendar, selected: selectedDate) { date in
                            select(date)
                            showCalendar = false
                        }
                        HStack(spacing: 14) {
                            legendDot(Theme.cheap, "저렴")
                            legendDot(Theme.mid, "보통")
                            legendDot(Theme.expensive, "비쌈")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .opacity(monthLoading ? 0.6 : 1)
            }
            .navigationTitle("출발일 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { showCalendar = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.4)).frame(width: 12, height: 12)
            Text(text)
        }
    }

    // MARK: Actions

    private func shiftMonth(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: month) else { return }
        month = next
        Task { await loadMonth() }
    }

    private func select(_ date: Date) {
        selectedDate = date
        Task { await loadFlights() }
    }

    // MARK: Loading

    private func load() async {
        phase = .loading
        errorDetail = nil
        do {
            // 처음 조회하는 노선은 서버가 이 호출에서 수집을 시작하므로 이력을 먼저 기다린다
            let history = try await appState.provider.history(
                origin: search.origin, destination: search.destination, days: 90, airlines: search.airlines)
            data = Loaded(history: history, calendar: [])
        } catch {
            errorDetail = error.localizedDescription
            phase = .failed
            return
        }
        await fetchCalendar()
        chooseInitialDate()
        phase = .loaded
        await loadFlights()
    }

    private func loadMonth() async {
        monthLoading = true
        await fetchCalendar()
        monthLoading = false
    }

    private func fetchCalendar() async {
        do {
            data.calendar = try await appState.provider.calendar(
                origin: search.origin, destination: search.destination, month: month, airlines: search.airlines)
            calendarError = nil
        } catch {
            data.calendar = []
            calendarError = error.localizedDescription
        }
    }

    /// 처음 보여 줄 날짜: 검색에서 넘어온 날짜 > 가장 싼 날
    private func chooseInitialDate() {
        if let wanted = search.date, data.calendar.contains(where: { cal.isDate($0.date, inSameDayAs: wanted) }) {
            selectedDate = data.calendar.first { cal.isDate($0.date, inSameDayAs: wanted) }?.date
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
        flightsError = nil
        do {
            flights = try await appState.provider.flights(
                origin: search.origin, destination: search.destination, date: date, airlines: search.airlines)
        } catch {
            flights = []
            flightsError = error.localizedDescription
        }
        flightsLoading = false
    }
}

// MARK: - 구성요소

private struct FilterChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 6) {
                if isOn { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Theme.accent : Theme.cardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FlightRow: View {
    let flight: Flight
    let isCheapest: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AirlineBadge(code: flight.airline.code, size: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if let dep = flight.departureTime {
                        let arrival = flight.arrivalTime
                        Text(arrival.map { "\(dep) → \($0.text)" } ?? dep)
                            .font(.system(.headline, design: .rounded))
                        if arrival?.nextDay == true {
                            Text("+1").font(.caption2.weight(.bold)).foregroundStyle(Theme.expensive)
                        }
                    } else {
                        Text("시간 정보 없음").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let d = flight.durationText { Text(d) }
                    Text(flight.transfers == 0 ? "직항" : "경유 \(flight.transfers)회")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("\(flight.airline.name)\(flight.flightNumber.isEmpty ? "" : " · \(flight.flightNumber)")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if isCheapest {
                    Pill(text: "최저가", color: Theme.cheap)
                }
            }

            Spacer(minLength: 8)

            Text(flight.price.won)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - 달력 히트맵

private struct CalendarGrid: View {
    let month: Date
    let days: [CalendarDay]
    var selected: Date? = nil
    var onSelect: ((Date) -> Void)? = nil

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
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 48) }
                ForEach(1...dayCount, id: \.self) { day in
                    let date = cal.date(byAdding: .day, value: day - 1, to: start) ?? start
                    cell(day: day, date: date, price: prices[day], low: t.low, high: t.high, cheapest: cheapest)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(day: Int, date: Date, price: Int?, low: Int, high: Int, cheapest: Int?) -> some View {
        let tone: Color = {
            guard let price else { return .clear }
            if price <= low { return Theme.cheap }
            if price >= high { return Theme.expensive }
            return Theme.mid
        }()
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let content = VStack(spacing: 1) {
            Text("\(day)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(price.map { $0.shortWon } ?? "–")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(price == nil ? Color.secondary.opacity(0.5) : tone)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(tone.opacity(price == nil ? 0 : 0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.accent, lineWidth: 2)
            } else if let price, price == cheapest {
                RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cheap, lineWidth: 1.5)
            }
        }

        if price != nil, let onSelect {
            Button { onSelect(date) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}
