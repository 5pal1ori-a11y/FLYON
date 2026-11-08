import SwiftUI

/// FLY 탭: 노선 검색
struct FlyView: View {
    @Environment(AppState.self) private var appState

    @State private var origin: Airport? = Catalog.airport("ICN")
    @State private var destination: Airport? = Catalog.airport("CJU")
    @State private var month: Date = Self.months[0]
    @State private var cabin: Cabin = .economy
    @State private var airlines: Set<Airline> = []

    @State private var pickerTarget: PickerTarget?
    @State private var showAirlinePicker = false
    @State private var result: RouteSearch?
    @State private var swapTurns = 0.0

    private enum PickerTarget: Identifiable {
        case origin, destination
        var id: Int { self == .origin ? 0 : 1 }
    }

    /// 서버가 수집하는 기간(이번 달부터 3개월)
    static let months: [Date] = {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return (0..<3).compactMap { cal.date(byAdding: .month, value: $0, to: start) }
    }()

    private var canSearch: Bool {
        guard let origin, let destination else { return false }
        return origin != destination
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("어디로 갈까요?")
                        .font(.app(28, .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Theme.headerGradient
                                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32))
                                .ignoresSafeArea(edges: .top)
                        )

                    VStack(alignment: .leading, spacing: 22) {
                        searchCard.appear()
                        searchButton.appear(delay: 0.06)
                        popular.appear(delay: 0.12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -48)
                    .padding(.bottom, 40)
                }
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $result) { ResultView(search: $0) }
        }
        .sheet(item: $pickerTarget) { target in
            AirportPickerView(title: target == .origin ? "출발지" : "도착지",
                              excluded: target == .origin ? destination : origin) { airport in
                withAnimation(.snappy) {
                    if target == .origin { origin = airport } else { destination = airport }
                }
            }
        }
        .sheet(isPresented: $showAirlinePicker) { AirlinePickerView(selection: $airlines) }
        .onChange(of: appState.pendingRoute) { _, route in consume(route) }
        .onAppear { consume(appState.pendingRoute) }
    }

    // MARK: 검색 카드

    private var searchCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    AirportRow(label: "출발", airport: origin) { pickerTarget = .origin }
                    Divider().padding(.leading, 20)
                    AirportRow(label: "도착", airport: destination) { pickerTarget = .destination }
                }
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        swap(&origin, &destination)
                        swapTurns += 1
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Theme.accent, in: Circle())
                        .rotationEffect(.degrees(swapTurns * 180))
                        .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(PressableStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: swapTurns)
                .accessibilityLabel("출발지와 도착지 바꾸기")
                .padding(.trailing, 18)
            }

            Divider()

            HStack(spacing: 0) {
                Menu {
                    ForEach(Self.months, id: \.self) { m in Button(m.monthTitle) { month = m } }
                } label: {
                    OptionCell(label: "출발", value: month.monthShort)
                }
                Divider().frame(height: 44)
                Menu {
                    ForEach(Cabin.allCases) { c in Button(c.title) { cabin = c } }
                } label: {
                    OptionCell(label: "좌석", value: cabin.title)
                }
                Divider().frame(height: 44)
                Button { showAirlinePicker = true } label: {
                    OptionCell(label: "항공사", value: airlineSummary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var airlineSummary: String {
        guard let first = airlines.map(\.name).sorted().first else { return "전체" }
        return airlines.count == 1 ? first : "\(first) 외 \(airlines.count - 1)"
    }

    private var searchButton: some View {
        Button {
            guard let origin, let destination else { return }
            appState.addRecent(origin: origin, destination: destination)
            result = RouteSearch(origin: origin, destination: destination, month: month, airlines: airlines, cabin: cabin)
        } label: {
            Text("항공권 찾기")
                .font(.app(17, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSearch ? Theme.accent : Color.gray.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.accent.opacity(canSearch ? 0.3 : 0), radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .disabled(!canSearch)
    }

    private var popular: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "인기 노선")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Catalog.popularRoutes.enumerated()), id: \.offset) { _, pair in
                        if let o = Catalog.airport(pair.0), let d = Catalog.airport(pair.1) {
                            Button {
                                withAnimation(.snappy) { origin = o; destination = d }
                            } label: {
                                Text("\(o.city) → \(d.city)")
                                    .font(.app(14, .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Theme.cardBackground, in: Capsule())
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private func consume(_ route: FavoriteRoute?) {
        guard let route, let o = route.origin, let d = route.destination else { return }
        origin = o
        destination = d
        var searchMonth = month
        if let date = appState.pendingDate {
            let cal = Calendar.current
            searchMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? month
            month = searchMonth
        }
        result = RouteSearch(origin: o, destination: d, month: searchMonth, airlines: airlines, date: appState.pendingDate, cabin: cabin)
        appState.pendingRoute = nil
        appState.pendingDate = nil
    }
}

private struct AirportRow: View {
    let label: String
    let airport: Airport?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.app(12, .medium))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(airport?.city ?? "선택")
                            .font(.app(22, .bold))
                            .foregroundStyle(airport == nil ? Color.secondary : Color.primary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                        if let airport {
                            Text(airport.code)
                                .font(.app(14, .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 70)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OptionCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.app(12, .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.app(15, .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - 공항 선택

struct AirportPickerView: View {
    let title: String
    let excluded: Airport?
    let onSelect: (Airport) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            List {
                if trimmed.isEmpty {
                    Section("인기 도시") { rows(Catalog.popularAirports.filter { $0 != excluded }) }
                    Section("국내") { rows(Catalog.domesticAirports.filter { $0 != excluded }) }
                } else {
                    let results = Catalog.searchAirports(trimmed, excluding: excluded)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: trimmed)
                    } else {
                        rows(results)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "도시, 공항, 코드")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    private func rows(_ airports: [Airport]) -> some View {
        ForEach(airports) { airport in
            Button {
                onSelect(airport)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(airport.city).font(.app(16, .semibold)).foregroundStyle(.primary)
                        Text(airport.country).font(.app(12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(airport.code).font(.app(14, .bold)).foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

// MARK: - 항공사 선택

struct AirlinePickerView: View {
    @Binding var selection: Set<Airline>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private var filtered: [Airline] {
        guard !trimmed.isEmpty else { return Catalog.airlines }
        return Catalog.airlines.filter { $0.searchKey.contains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmed.isEmpty {
                    Button { withAnimation { selection = [] } } label: {
                        row(code: nil, title: "전체 항공사", checked: selection.isEmpty)
                    }
                }
                let korean = filtered.filter(\.isKorean)
                let foreign = filtered.filter { !$0.isKorean }.sorted { $0.name < $1.name }
                if !korean.isEmpty { Section("국내") { airlineRows(korean) } }
                if !foreign.isEmpty { Section("해외") { airlineRows(foreign) } }
                if filtered.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "항공사 이름 또는 코드")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("항공사")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: selection)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func airlineRows(_ airlines: [Airline]) -> some View {
        ForEach(airlines) { airline in
            Button {
                withAnimation(.snappy) {
                    if selection.contains(airline) { selection.remove(airline) } else { selection.insert(airline) }
                }
            } label: {
                row(code: airline.code, title: airline.name, checked: selection.contains(airline))
            }
        }
    }

    private func row(code: String?, title: String, checked: Bool) -> some View {
        HStack(spacing: 12) {
            if let code {
                AirlineLogo(code: code, size: 32)
            } else {
                Image(systemName: "airplane")
                    .frame(width: 32, height: 32)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .foregroundStyle(Theme.accent)
            }
            Text(title).font(.app(16)).foregroundStyle(.primary)
            Spacer()
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(checked ? Theme.accent : Color(.tertiaryLabel))
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
