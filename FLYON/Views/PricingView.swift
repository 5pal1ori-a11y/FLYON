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

    static let months: [Date] = {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return (0..<12).compactMap { cal.date(byAdding: .month, value: $0, to: start) }
    }()

    private var canSearch: Bool {
        guard let origin, let destination else { return false }
        return origin != destination
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("어디로 갈까요?")
                        .font(.largeTitle.bold())
                        .padding(.top, 8)

                    searchCard
                    searchButton
                    popularRoutes
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
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

    // MARK: Search card

    private var searchCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    FieldRow(icon: "airplane.departure", label: "출발",
                             value: origin.map { "\($0.city) (\($0.code))" }, placeholder: "출발지 선택") {
                        pickerTarget = .origin
                    }
                    Divider().padding(.leading, 44)
                    FieldRow(icon: "airplane.arrival", label: "도착",
                             value: destination.map { "\($0.city) (\($0.code))" }, placeholder: "도착지 선택") {
                        pickerTarget = .destination
                    }
                }
                Button {
                    swap(&origin, &destination)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Theme.cardBackground, in: Circle())
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                }
                .accessibilityLabel("출발지와 도착지 바꾸기")
                .padding(.trailing, 4)
            }

            Divider().padding(.leading, 44)

            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .frame(width: 30)
                    .foregroundStyle(Theme.accent)
                Text("출발 월").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Picker("출발 월", selection: $month) {
                    ForEach(Self.months, id: \.self) { Text($0.monthTitle).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.vertical, 6)

            Divider().padding(.leading, 44)

            FieldRow(icon: "airplane.circle", label: "항공사",
                     value: airlineSummary, placeholder: "전체") {
                showAirlinePicker = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var airlineSummary: String? {
        guard !airlines.isEmpty else { return nil }
        let names = airlines.map(\.name).sorted()
        return names.count == 1 ? names[0] : "\(names[0]) 외 \(names.count - 1)곳"
    }

    private var searchButton: some View {
        Button {
            guard let origin, let destination else { return }
            appState.addRecent(origin: origin, destination: destination)
            result = RouteSearch(origin: origin, destination: destination, month: month, airlines: airlines)
        } label: {
            Label("가격 분석하기", systemImage: "chart.xyaxis.line")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(!canSearch)
    }

    private var popularRoutes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("인기 노선", systemImage: "flame")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Catalog.popularRoutes.enumerated()), id: \.offset) { _, pair in
                        if let o = Catalog.airport(pair.0), let d = Catalog.airport(pair.1) {
                            Button {
                                origin = o
                                destination = d
                            } label: {
                                Text("\(o.city) – \(d.city)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Theme.cardBackground, in: Capsule())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
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

private struct FieldRow: View {
    let icon: String
    let label: String
    let value: String?
    let placeholder: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 30)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(value ?? placeholder)
                        .font(.body.weight(.medium))
                        .foregroundStyle(value == nil ? .secondary : .primary)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Airport picker

struct AirportPickerView: View {
    let title: String
    let excluded: Airport?
    let onSelect: (Airport) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Airport] {
        let base = Catalog.airports.filter { $0 != excluded }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.city.localizedCaseInsensitiveContains(q) ||
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.code.localizedCaseInsensitiveContains(q) ||
            $0.country.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                let domestic = filtered.filter(\.isDomestic)
                let overseas = filtered.filter { !$0.isDomestic }

                if !domestic.isEmpty {
                    Section("국내") { rows(domestic) }
                }
                if !overseas.isEmpty {
                    Section("해외") { rows(overseas) }
                }
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "도시, 공항, 코드 검색")
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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(airport.city).foregroundStyle(.primary)
                        Text("\(airport.name) · \(airport.country)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(airport.code)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Airline picker

struct AirlinePickerView: View {
    @Binding var selection: Set<Airline>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selection = []
                    } label: {
                        row("전체 항공사", checked: selection.isEmpty)
                    }
                }
                Section {
                    ForEach(Catalog.airlines) { airline in
                        Button {
                            if selection.contains(airline) { selection.remove(airline) } else { selection.insert(airline) }
                        } label: {
                            row(airline.name, checked: selection.contains(airline))
                        }
                    }
                } footer: {
                    Text("항공사별 가격은 데이터 제공 범위에 따라 일부 항공사만 표시될 수 있어요.")
                }
            }
            .navigationTitle("항공사 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, checked: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.primary)
            Spacer()
            if checked {
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.accent)
                    .fontWeight(.semibold)
            }
        }
    }
}
