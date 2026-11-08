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
    /// 날짜 띠: 선택일 앞뒤 5일
    @State private var rangeDays: [CalendarDay] = []
    @State private var tab: Tab = .flights
    @State private var month: Date
    @State private var selectedDate: Date?
    @State private var flights: [Flight] = []
    @State private var dayHistory: [PricePoint] = []
    @State private var flightsLoading = false
    @State private var flightsFailed = false
    @State private var directOnly = false
    @State private var excludeLowCost = false
    @State private var showCalendar = false
    @State private var showAlertSheet = false
    @State private var chartReveal: CGFloat = 0
    @State private var detailFlight: Flight?
    @State private var liveMode = false
    @State private var liveFlights: [Flight] = []
    @State private var liveLoading = false
    @State private var liveMessage: String?
    @State private var liveURL: URL?
    /// 그날 운항하는 모든 직항편 (스케줄, 가격 없음)
    @State private var scheduled: [Flight] = []

    init(search: RouteSearch) {
        self.search = search
        _month = State(initialValue: search.month)
    }

    private var cal: Calendar { Calendar.current }
    private var route: FavoriteRoute {
        FavoriteRoute(originCode: search.origin.code, destinationCode: search.destination.code)
    }
    private var sortedCalendar: [CalendarDay] { calendar.sorted { $0.date < $1.date } }
    /// 날짜 띠에 보여 줄 날짜들 (앞뒤 5일, 없으면 그 달)
    private var stripDays: [CalendarDay] { rangeDays.isEmpty ? sortedCalendar : rangeDays.sorted { $0.date < $1.date } }
    private var cheapestDay: CalendarDay? { calendar.min { $0.price < $1.price } }
    private var selectedDay: CalendarDay? {
        selectedDate.flatMap { d in (rangeDays + calendar).first { cal.isDate($0.date, inSameDayAs: d) } }
    }

    /// 가격 데이터 + 스케줄을 합친 목록. 가격이 없는 편은 price == 0
    private var mergedFlights: [Flight] {
        let priced = liveMode ? liveFlights : flights
        let pricedKeys = Set(priced.map(\.matchKey))
        let extra = scheduled.filter { !pricedKeys.contains($0.matchKey) }
        return priced + extra
    }

    private var visibleFlights: [Flight] {
        mergedFlights
            .filter { (!directOnly || $0.transfers == 0) && (!excludeLowCost || !$0.airline.isLowCost) }
            .sorted { a, b in
                // 가격 있는 편을 싼 순으로 먼저, 가격 없는 편은 출발 시각 순으로 뒤에
                if a.hasPrice != b.hasPrice { return a.hasPrice }
                if a.hasPrice { return a.price < b.price }
                return (a.departureTime ?? "") < (b.departureTime ?? "")
            }
    }

    private var recentHistory: [PricePoint] {
        let cutoff = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: .now)) ?? .distantPast
        return history.filter { $0.date >= cutoff }
    }

    private var analysis: PriceAnalysis? { PriceAnalysis(history: recentHistory) }

    /// 선택한 날짜의 최저가 (알림 기준가)
    private var currentLowest: Int? {
        selectedDay?.price ?? visibleFlights.first?.price ?? dayHistory.last?.price
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
        .sheet(item: $liveURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .sheet(item: $detailFlight) { flight in
            if let date = selectedDate {
                FlightDetailView(search: search, date: date, flight: flight)
            }
        }
        .task { await load() }
    }

    private var subtitle: some View {
        HStack(spacing: 6) {
            Text("최근 48시간 기준")
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
                liveChip
                FilterChip(title: "직항만", isOn: $directOnly)
                FilterChip(title: "저비용 제외", isOn: $excludeLowCost)
                Spacer(minLength: 0)
            }

            if let liveMessage {
                Text(liveMessage)
                    .font(.app(12))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            flightList
        }
    }

    @ViewBuilder
    private var dateStrip: some View {
        if stripDays.isEmpty {
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
                            ForEach(stripDays) { day in dateChip(day).id(day.date) }
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

    /// 실시간 가격: 가격 비교 사이트의 해당 날짜 검색 결과를 앱 안에서 연다
    private var liveChip: some View {
        Button {
            if let date = selectedDate {
                liveURL = LivePriceLink.url(origin: search.origin, destination: search.destination, date: date)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").font(.system(size: 11, weight: .bold))
                Text("실시간 가격").font(.app(14, .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(.white)
            .background(Theme.mid, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(selectedDate == nil)
    }

    private func loadLive() async {
        guard let date = selectedDate else { return }
        liveLoading = true
        defer { liveLoading = false }
        do {
            let result = try await appState.provider.liveFlights(
                origin: search.origin, destination: search.destination, date: date, cabin: search.cabin)
            withAnimation(.easeOut(duration: 0.25)) {
                liveFlights = result
                liveMessage = result.isEmpty ? "이 날짜는 실시간으로 조회되는 항공편이 없어요" : "항공사 실시간 가격이에요 (최대 30분 전 기준)"
            }
        } catch PriceError.http(503) {
            withAnimation { liveMode = false; liveMessage = "실시간 가격은 아직 준비 중이에요" }
        } catch PriceError.http(429) {
            withAnimation { liveMode = false; liveMessage = "오늘 실시간 조회 한도를 다 썼어요. 내일 다시 시도해 주세요" }
        } catch {
            withAnimation { liveMode = false; liveMessage = "실시간 가격을 불러오지 못했어요" }
        }
    }

    @ViewBuilder
    private var flightList: some View {
        if flightsLoading || (liveMode && liveLoading) {
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
        } else if visibleFlights.isEmpty, let day = selectedDay {
            HStack(spacing: 14) {
                Image(systemName: "airplane")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(day.date.dayTitle) 최저가").font(.app(16, .bold))
                    Text("항공편 세부 정보는 수집 중이에요").font(.app(12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(day.price.won).font(.app(17, .bold)).foregroundStyle(Theme.accent)
            }
            .card(padding: 16)
        } else if visibleFlights.isEmpty {
            Text(flights.isEmpty ? "이 날짜의 항공편 정보가 없어요" : "조건에 맞는 항공편이 없어요")
                .font(.app(14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .card()
        } else {
            let lowest = visibleFlights.filter(\.hasPrice).first?.price
            let direct = visibleFlights.filter { $0.transfers == 0 }
            let connecting = visibleFlights.filter { $0.transfers > 0 }
            VStack(alignment: .leading, spacing: 10) {
                if !direct.isEmpty {
                    sectionLabel("직항", count: direct.count)
                    ForEach(Array(direct.enumerated()), id: \.element.id) { index, flight in
                        flightButton(flight, isCheapest: flight.price == lowest, index: index)
                    }
                }
                if !connecting.isEmpty {
                    sectionLabel("경유", count: connecting.count)
                        .padding(.top, direct.isEmpty ? 0 : 12)
                    ForEach(Array(connecting.enumerated()), id: \.element.id) { index, flight in
                        flightButton(flight, isCheapest: flight.price == lowest, index: direct.count + index)
                    }
                }
            }
        }
    }

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.app(15, .bold))
            Text("\(count)").font(.app(13, .semibold)).foregroundStyle(.secondary)
        }
    }

    private func flightButton(_ flight: Flight, isCheapest: Bool, index: Int) -> some View {
        Button {
            if flight.hasPrice {
                detailFlight = flight
            } else if let date = selectedDate {
                liveURL = LivePriceLink.url(origin: search.origin, destination: search.destination, date: date)
            }
        } label: {
            FlightCard(flight: flight, isCheapest: isCheapest)
        }
        .buttonStyle(PressableStyle())
        .appear(delay: Double(index) * 0.04)
    }

    // MARK: 가격 흐름

    private var trendTab: some View {
        let dayAnalysis = PriceAnalysis(history: dayHistory)
        return VStack(alignment: .leading, spacing: 16) {
            // 선택한 날짜 하루의 가격
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedDate.map { "\($0.dayTitle) 출발" } ?? "날짜를 골라 주세요")
                    .font(.app(13, .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(currentLowest.map { $0.won } ?? "––")
                    .font(.app(38, .heavy))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: currentLowest)
                if let a = dayAnalysis, a.verdict != .collecting {
                    Pill(text: a.verdict.title, systemImage: a.verdict.symbol,
                         color: a.verdict.color == Theme.mid ? .yellow : a.verdict.color)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.headerGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

            // 이 날짜 가격이 날마다 어떻게 변했는지
            VStack(alignment: .leading, spacing: 14) {
                Text("이 날짜 가격 변화").font(.app(16, .bold))
                if dayHistory.count >= 2, let a = dayAnalysis {
                    priceChart(dayHistory.map { ($0.date, $0.price) }, highlight: nil)
                    HStack {
                        stat("최저", a.lowest.won, Theme.cheap)
                        stat("최고", a.highest.won, Theme.expensive)
                        stat("기록", "\(a.sampleCount)일", .primary)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .foregroundStyle(Theme.accent)
                            .symbolEffect(.pulse)
                        Text("이 날짜의 가격 기록을 모으는 중이에요")
                            .font(.app(13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .card()

            // 같은 달 다른 날짜와 비교
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("날짜별 가격").font(.app(16, .bold))
                    Spacer()
                    Text(month.monthShort).font(.app(13, .medium)).foregroundStyle(.secondary)
                }
                if sortedCalendar.count >= 2 {
                    priceChart(sortedCalendar.map { ($0.date, $0.price) }, highlight: selectedDate)
                } else {
                    Text("이 달의 가격 정보가 부족해요")
                        .font(.app(14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .card()
        }
    }

    private func priceChart(_ points: [(Date, Int)], highlight: Date?) -> some View {
        Chart {
            ForEach(points, id: \.0) { p in
                AreaMark(x: .value("날짜", p.0), y: .value("가격", p.1))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.25), Theme.accent.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("날짜", p.0), y: .value("가격", p.1))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(Theme.accent)
            }
            if let low = points.min(by: { $0.1 < $1.1 }) {
                PointMark(x: .value("날짜", low.0), y: .value("가격", low.1))
                    .foregroundStyle(Theme.cheap)
                    .symbolSize(80)
            }
            if let highlight, let sel = points.first(where: { cal.isDate($0.0, inSameDayAs: highlight) }) {
                RuleMark(x: .value("선택", sel.0))
                    .foregroundStyle(Theme.accent.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
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
        .frame(height: 190)
        .mask(alignment: .leading) {
            GeometryReader { g in Rectangle().frame(width: g.size.width * chartReveal) }
        }
        .onAppear {
            chartReveal = 0
            withAnimation(.easeOut(duration: 1.0)) { chartReveal = 1 }
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
                    Task { await loadRange(center: date) }
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
        Task {
            await loadFlights()
            if liveMode { await loadLive() }
        }
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
        if let center = selectedDate { await loadRange(center: center) }
        withAnimation(.easeOut(duration: 0.3)) {
            phase = (calendarFailed && history.isEmpty && rangeDays.isEmpty) ? .failed : .loaded
        }
        await loadFlights()
    }

    /// 선택일 앞뒤 5일 가격을 불러온다 (서버가 그 날짜들의 항공편도 함께 채운다)
    private func loadRange(center: Date) async {
        if let days = try? await appState.provider.range(
            origin: search.origin, destination: search.destination, date: center, days: 5,
            airlines: search.airlines, cabin: search.cabin) {
            withAnimation(.easeOut(duration: 0.25)) { rangeDays = days }
        }
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
        async let schedulePoints = try? appState.provider.schedule(
            origin: search.origin, destination: search.destination, date: date)
        async let dayPoints = try? appState.provider.dayHistory(
            origin: search.origin, destination: search.destination, date: date, airlines: search.airlines, cabin: search.cabin)
        do {
            let result = try await appState.provider.flights(
                origin: search.origin, destination: search.destination, date: date, airlines: search.airlines, cabin: search.cabin)
            withAnimation(.easeOut(duration: 0.25)) { flights = result }
        } catch {
            flights = []
            // 항공편 상세가 없어도 그날 최저가가 있으면 실패로 보이지 않게 한다
            flightsFailed = selectedDay == nil
        }
        let schedule = await schedulePoints ?? []
        withAnimation(.easeOut(duration: 0.25)) { scheduled = schedule }
        if !schedule.isEmpty { flightsFailed = false }
        let points = await dayPoints ?? []
        withAnimation(.easeOut(duration: 0.25)) { dayHistory = points }
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
                if flight.hasPrice {
                    Text(flight.priceText)
                        .font(.app(17, .bold))
                        .foregroundStyle(isCheapest ? Theme.accent : .primary)
                } else {
                    Label("가격 확인", systemImage: "bolt.fill")
                        .font(.app(13, .semibold))
                        .foregroundStyle(Theme.mid)
                }
                if isCheapest && flight.hasPrice { Pill(text: "최저가", color: Theme.cheap) }
                else if flight.isLive { Pill(text: "실시간", systemImage: "bolt.fill", color: Theme.mid) }
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
