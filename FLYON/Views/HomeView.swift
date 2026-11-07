import Charts
import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    searchShortcut
                    favoritesSection
                    recentsSection
                    noticeCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("안녕하세요, \(auth.displayName ?? "여행자")님")
                .font(.title2.bold())
            Text("오늘의 항공권 흐름을 확인해 보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var searchShortcut: some View {
        Button {
            appState.selectedTab = .pricing
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("어디로 갈까요?").font(.headline)
                    Text("출발지와 도착지를 골라 가격 흐름을 봐요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .card()
        }
        .buttonStyle(.plain)
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("관심 노선", systemImage: "star.fill")

            if appState.favorites.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("책정 화면에서 별 아이콘을 누르면 관심 노선으로 저장돼요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } else {
                ForEach(appState.favorites) { route in
                    FavoriteCard(route: route)
                }
            }
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        if !appState.recents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("최근 검색", systemImage: "clock.arrow.circlepath")
                VStack(spacing: 0) {
                    ForEach(appState.recents) { item in
                        if let o = Catalog.airport(item.originCode), let d = Catalog.airport(item.destinationCode) {
                            Button {
                                open(FavoriteRoute(originCode: o.code, destinationCode: d.code))
                            } label: {
                                HStack {
                                    Image(systemName: "airplane")
                                        .foregroundStyle(.secondary)
                                    Text("\(o.city) → \(d.city)")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                                .foregroundStyle(.primary)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            if item.id != appState.recents.last?.id { Divider() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            }
        }
    }

    private var noticeCard: some View {
        Label {
            Text("표시되는 가격은 최근 검색 데이터를 바탕으로 한 참고 가격이며 실제 예약 가격과 다를 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func open(_ route: FavoriteRoute) {
        appState.pendingRoute = route
        appState.selectedTab = .pricing
    }
}

// MARK: - Components

struct SectionTitle: View {
    let title: String
    let systemImage: String
    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

private struct FavoriteCard: View {
    let route: FavoriteRoute
    @Environment(AppState.self) private var appState
    @State private var history: [PricePoint] = []
    @State private var failed = false

    var body: some View {
        Button {
            appState.pendingRoute = route
            appState.selectedTab = .pricing
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(route.origin?.city ?? route.originCode) → \(route.destination?.city ?? route.destinationCode)")
                        .font(.headline)
                    if let analysis = PriceAnalysis(history: history) {
                        Text(analysis.current.won).font(.title3.bold())
                        Label(analysis.verdict.title, systemImage: analysis.verdict.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(analysis.verdict.color)
                    } else if failed {
                        Label("불러오지 못했어요", systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                Spacer()
                if !history.isEmpty {
                    Chart(history) {
                        LineMark(x: .value("날짜", $0.date), y: .value("가격", $0.price))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.accent)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(width: 96, height: 44)
                }
            }
            .foregroundStyle(.primary)
            .card()
        }
        .buttonStyle(.plain)
        .task(id: route) { await load() }
    }

    private func load() async {
        guard let o = route.origin, let d = route.destination else { return }
        do {
            history = try await appState.provider.history(origin: o, destination: d, days: 30)
            failed = false
        } catch {
            failed = true
        }
    }
}
