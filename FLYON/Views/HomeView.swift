import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    VStack(alignment: .leading, spacing: 28) {
                        if !appState.favorites.isEmpty { favorites }
                        popular
                        Text("표시되는 가격은 참고용이에요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(auth.displayName ?? "여행자")님,\n어디로 갈까요?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Button {
                appState.selectedTab = .pricing
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.accent)
                    Text("노선 검색")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.body.weight(.medium))
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color(.systemBackground), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.headerGradient
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Sections

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "관심 노선")
            ForEach(appState.favorites) { route in
                FavoriteRow(route: route)
            }
        }
    }

    private var popular: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "인기 노선")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(Catalog.popularRoutes.enumerated()), id: \.offset) { index, pair in
                        if let o = Catalog.airport(pair.0), let d = Catalog.airport(pair.1) {
                            Button {
                                appState.pendingRoute = FavoriteRoute(originCode: o.code, destinationCode: d.code)
                                appState.selectedTab = .pricing
                            } label: {
                                RouteTile(origin: o, destination: d, index: index)
                                    .frame(width: 150)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
}

private struct FavoriteRow: View {
    let route: FavoriteRoute
    @Environment(AppState.self) private var appState
    @State private var history: [PricePoint] = []
    @State private var loaded = false

    var body: some View {
        Button {
            appState.pendingRoute = route
            appState.selectedTab = .pricing
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(route.origin?.city ?? route.originCode) → \(route.destination?.city ?? route.destinationCode)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let a = PriceAnalysis(history: history) {
                        Text(a.current.won)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                    } else if loaded {
                        Text("가격 데이터 없음")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                Spacer()
                if let a = PriceAnalysis(history: history), a.verdict != .collecting {
                    Pill(text: a.verdict.title, systemImage: a.verdict.symbol, color: a.verdict.color)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .task(id: route) {
            guard let o = route.origin, let d = route.destination else { return }
            history = (try? await appState.provider.history(origin: o, destination: d, days: 30, airlines: [])) ?? []
            loaded = true
        }
    }
}
