import SwiftUI

struct PricingView: View {
    @Environment(AppState.self) private var appState

    @State private var origin: Airport? = Catalog.airport("ICN")
    @State private var destination: Airport? = Catalog.airport("CJU")
    @State private var month: Date = Self.months[0]
    @State private var airlines: Set<Airline> = []

    @State private var pickerTarget: PickerTarget?
    @State private var showAirlinePicker = false
    @State private var result: RouteSearch?

    private enum PickerTarget: Identifiable {
        case origin, destination
        var id: Int { self == .origin ? 0 : 1 }
    }

    /// 서버가 수집하는 기간(이번 달부터 3개월)에 맞춘다
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
                    header
                    VStack(alignment: .leading, spacing: 24) {
                        searchCard
                        searchButton
                        popularRoutes
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, -34)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $result) { search in
                ResultView(search: search)
            }
        }
        .sheet(item: $pickerTarget) { target in
            AirportPickerView(
                title: target == .origin ? "출발지" : "도착지",
                excluded: target == .origin ? destination : origin
            ) { airport in
                if target == .origin { origin = airport } else { destination = airport }
            }
        }
        .sheet(isPresented: $showAirlinePicker) {
            AirlinePickerView(selection: $airlines)
        }
        .onChange(of: appState.pendingRoute) { _, route in consume(route) }
        .onAppear { consume(appState.pendingRoute) }
    }

    // MARK: Header

    private var header: some View {
        Text("어디로 갈까요?")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.headerGradient
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                    .ignoresSafeArea(edges: .top)
            )
    }

    // MARK: Search card

    private var searchCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    AirportRow(label: "출발", icon: "airplane.departure", airport: origin, placeholder: "출발지 선택") {
                        pickerTarget = .origin
                    }
                    Divider().padding(.leading, 16)
                    AirportRow(label: "도착", icon: "airplane.arrival", airport: destination, placeholder: "도착지 선택") {
                        pickerTarget = .destination
                    }
                }
                Button {
                    swap(&origin, &destination)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemBackground), in: Circle())
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                }
                .accessibilityLabel("출발지와 도착지 바꾸기")
                .padding(.trailing, 14)
            }

            Divider()

            HStack(spacing: 0) {
                Menu {
                    ForEach(Self.months, id: \.self) { m in
                        Button(m.monthTitle) { month = m }
                    }
                } label: {
                    OptionCell(label: "출발 월", icon: "calendar", value: month.monthTitle)
                }
                Divider().frame(height: 52)
                Button {
                    showAirlinePicker = true
                } label: {
                    OptionCell(label: "항공사", icon: "airplane.circle", value: airlineSummary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
    }

    private var airlineSummary: String {
        guard !airlines.isEmpty else { return "전체" }
        let names = airlines.map(\.name).sorted()
        return names.count == 1 ? names[0] : "\(names[0]) 외 \(names.count - 1)곳"
    }

    private var searchButton: some View {
        Button {
            guard let origin, let destination else { return }
            appState.addRecent(origin: origin, destination: destination)
            result = RouteSearch(origin: origin, destination: destination, month: month, airlines: airlines)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                Text("가격 분석하기")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canSearch ? Theme.accent : Color.gray.opacity(0.4), in: Capsule())
        }
        .disabled(!canSearch)
    }

    // MARK: Popular

    private var popularRoutes: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "인기 노선")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Catalog.popularRoutes.enumerated()), id: \.offset) { _, pair in
                        if let o = Catalog.airport(pair.0), let d = Catalog.airport(pair.1) {
                            Button {
                                origin = o
                                destination = d
                            } label: {
                                Text("\(o.city) → \(d.city)")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Theme.cardBackground, in: Capsule())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }

    private func consume(_ route: FavoriteRoute?) {
        guard let route, let o = route.origin, let d = route.destination else { return }
        origin = o
        destination = d
        result = RouteSearch(origin: o, destination: d, month: month, airlines: airlines)
        appState.pendingRoute = nil
    }
}

// MARK: - Rows

private struct AirportRow: View {
    let label: String
    let icon: String
    let airport: Airport?
    let placeholder: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    if let airport {
                        HStack(spacing: 8) {
                            Text(airport.city)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            IATABadge(code: airport.code)
                        }
                    } else {
                        Text(placeholder)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 56)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OptionCell: View {
    let label: String
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Airport picker

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
                    Section("국내 공항") { rows(Catalog.domesticAirports.filter { $0 != excluded }) }
                    Section {
                        Text("그 밖의 \(Catalog.airports.count.formatted())개 공항은 도시명, 공항명, 코드로 검색하세요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    let results = Catalog.searchAirports(trimmed, excluding: excluded)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: trimmed)
                    } else {
                        Section("검색 결과 \(results.count)") { rows(results) }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "도시, 공항, 코드 (예: 도쿄, NRT)")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
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
                        Text(airport.city).foregroundStyle(.primary)
                        Text("\(airport.name) · \(airport.country)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    IATABadge(code: airport.code)
                }
            }
        }
    }
}

// MARK: - Airline picker

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
                    Section {
                        Button { selection = [] } label: {
                            row(code: nil, title: "전체 항공사", subtitle: "\(Catalog.airlines.count)개", checked: selection.isEmpty)
                        }
                    }
                }
                let korean = filtered.filter(\.isKorean)
                let foreign = filtered.filter { !$0.isKorean }.sorted { $0.name < $1.name }
                if !korean.isEmpty { Section("국내 항공사") { airlineRows(korean) } }
                if !foreign.isEmpty { Section("해외 항공사") { airlineRows(foreign) } }
                if filtered.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "항공사 이름 또는 코드")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("항공사 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("초기화") { selection = [] }
                        .disabled(selection.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func airlineRows(_ airlines: [Airline]) -> some View {
        ForEach(airlines) { airline in
            Button {
                if selection.contains(airline) { selection.remove(airline) } else { selection.insert(airline) }
            } label: {
                row(code: airline.code, title: airline.name, subtitle: airline.englishName, checked: selection.contains(airline))
            }
        }
    }

    private func row(code: String?, title: String, subtitle: String, checked: Bool) -> some View {
        HStack(spacing: 12) {
            if let code {
                AirlineBadge(code: code, size: 34)
            } else {
                Image(systemName: "airplane")
                    .frame(width: 34, height: 34)
                    .background(Theme.accentSoft, in: Circle())
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if checked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
