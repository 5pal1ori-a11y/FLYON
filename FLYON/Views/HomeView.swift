import Charts
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
                        favoritesSection
                        popularSection
                        recentsSection
                        legend
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("안녕하세요")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("\(auth.displayName ?? "여행자")님")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image("LogoMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Button {
                appState.selectedTab = .pricing
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text("어디로 갈까요?")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(.systemBackground), in: Capsule())
            }
            .buttonStyle(.plain)

            Text("전 세계 \(Catalog.airports.count.formatted())개 공항의 항공권 가격 흐름을 확인해 보세요")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.headerGradient
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Sections

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "관심 노선")

            if appState.favorites.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "star")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("아직 관심 노선이 없어요").font(.subheadline.weight(.semibold))
                        Text("가격 화면의 별 아이콘을 누르면 여기에 모아 볼 수 있어요")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .card()
            } else {
                ForEach(appState.favorites) { route in
                    FavoriteCard(route: route)
                }
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "인기 노선", subtitle: "탭하면 가격 흐름을 바로 볼 수 있어요")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(Catalog.popularRoutes.enumerated()), id: \.offset) { index, pair in
                    if let o = Catalog.airport(pair.0), let d = Catalog.airport(pair.1) {
                        Button {
                            open(FavoriteRoute(originCode: o.code, destinationCode: d.code))
                        } label: {
                            RouteTile(origin: o, destination: d, index: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        if !appState.recents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "최근 검색")
                VStack(spacing: 0) {
                    ForEach(appState.recents) { item in
                        if let o = Catalog.airport(item.originCode), let d = Catalog.airport(item.destinationCode) {
                            Button {
                                open(FavoriteRoute(originCode: o.code, destinationCode: d.code))
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text("\(o.city) → \(d.city)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    IATABadge(code: "\(o.code)–\(d.code)")
                                }
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
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

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "가격 읽는 법")
            HStack(spacing: 8) {
                Pill(text: "저렴", systemImage: "arrow.down.right", color: Theme.cheap)
                Pill(text: "보통", systemImage: "equal", color: Theme.mid)
                Pill(text: "비쌈", systemImage: "arrow.up.right", color: Theme.expensive)
            }
            Text("최근 가격 흐름을 평균과 비교한 참고 표시예요. 표시된 가격은 실제 예약 가격과 다를 수 있고, FLYON은 항공권을 판매하거나 예약을 중개하지 않아요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func open(_ route: FavoriteRoute) {
        appState.pendingRoute = route
        appState.selectedTab = .pricing
    }
}

private struct FavoriteCard: View {
    let route: FavoriteRoute
    @Environment(AppState.self) private var appState
    @State private var history: [PricePoint] = []
    @State private var loaded = false

    var body: some View {
        Button {
            appState.pendingRoute = route
            appState.selectedTab = .pricing
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        IATABadge(code: route.originCode)
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                        IATABadge(code: route.destinationCode)
                    }
                    Text("\(route.origin?.city ?? route.originCode) → \(route.destination?.city ?? route.destinationCode)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let a = PriceAnalysis(history: history) {
                        HStack(spacing: 8) {
                            Text(a.current.won)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                            Pill(text: a.verdict.title, systemImage: a.verdict.symbol, color: a.verdict.color)
                        }
                    } else if loaded {
                        Text("아직 가격 데이터가 없어요")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                Spacer(minLength: 0)
                if history.count > 1 {
                    Chart(history) {
                        LineMark(x: .value("날짜", $0.date), y: .value("가격", $0.price))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.accent)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(width: 84, height: 44)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .task(id: route) { await load() }
    }

    private func load() async {
        guard let o = route.origin, let d = route.destination else { return }
        history = (try? await appState.provider.history(origin: o, destination: d, days: 30, airlines: [])) ?? []
        loaded = true
    }
}
