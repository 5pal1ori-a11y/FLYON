import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var deals: [Deal] = []
    @State private var loading = true
    @State private var showOriginPicker = false
    @State private var planeMoving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 32) {
                        carousel
                        if deals.count > 1 { dealList }
                        if !appState.favorites.isEmpty { favorites }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -88)
                    .padding(.bottom, 40)
                }
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await loadDeals() }
            .task(id: appState.homeOriginCode) { await loadDeals() }
            .sheet(isPresented: $showOriginPicker) {
                AirportPickerView(title: "출발지", excluded: nil) { appState.setHomeOrigin($0) }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("FLYON")
                .font(.app(30, .heavy))
                .tracking(2)
                .foregroundStyle(.white)

            Button { showOriginPicker = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("\(appState.homeOrigin.city) 출발")
                        .font(.app(17, .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())

            Text("지금 가장 싼 항공권")
                .font(.app(22, .bold))
                .foregroundStyle(.white)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 112)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topLeading) {
                Theme.headerGradient
                Image(systemName: "airplane")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .offset(x: planeMoving ? 460 : -40, y: 26)
                    .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: planeMoving)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32))
            .ignoresSafeArea(edges: .top)
            .onAppear { planeMoving = true }
        }
    }

    // MARK: 가로 카드

    @ViewBuilder
    private var carousel: some View {
        if loading {
            HStack(spacing: 14) {
                SkeletonBlock(height: 280).frame(width: 250)
                SkeletonBlock(height: 280).frame(width: 250)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        } else if deals.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
                Text("\(appState.homeOrigin.city) 출발 가격을 모으고 있어요")
                    .font(.app(15, .semibold))
                Button("다른 출발지 선택") { showOriginPicker = true }
                    .font(.app(14, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .card()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(deals.prefix(6).enumerated()), id: \.element.id) { index, deal in
                        Button { open(deal) } label: {
                            DealCard(deal: deal, index: index)
                                .frame(width: 250)
                        }
                        .buttonStyle(PressableStyle())
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.75)
                        }
                        .appear(delay: Double(index) * 0.06)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -20)
        }
    }

    // MARK: 목록

    private var dealList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "노선별 최저가")
            VStack(spacing: 0) {
                ForEach(Array(deals.enumerated()), id: \.element.id) { index, deal in
                    Button { open(deal) } label: {
                        DealRow(deal: deal, index: index)
                    }
                    .buttonStyle(PressableStyle())
                    .appear(delay: 0.1 + Double(index) * 0.04)
                    if index < deals.count - 1 { Divider().padding(.leading, 64) }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "관심 노선")
            ForEach(appState.favorites) { route in
                FavoriteRow(route: route)
            }
        }
    }

    private func open(_ deal: Deal) {
        appState.pendingDate = deal.lowestDate
        appState.pendingRoute = FavoriteRoute(originCode: appState.homeOrigin.code, destinationCode: deal.destination.code)
        appState.selectedTab = .fly
    }

    private func loadDeals() async {
        if deals.isEmpty { loading = true }
        let result = (try? await appState.provider.deals(origin: appState.homeOrigin, cabin: .economy)) ?? []
        withAnimation(.easeOut(duration: 0.3)) {
            deals = result
            loading = false
        }
    }
}

// MARK: - 카드

private struct DealCard: View {
    let deal: Deal
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Theme.tileGradient(index)
                Image(systemName: "airplane")
                    .font(.system(size: 110, weight: .bold))
                    .rotationEffect(.degrees(-18))
                    .foregroundStyle(.white.opacity(0.13))
                    .offset(x: 120, y: -30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(deal.destination.city)
                        .font(.app(26, .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(deal.destination.country)
                        .font(.app(13, .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(18)
            }
            .frame(height: 160)
            .clipped()

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("최저가")
                        .font(.app(12, .semibold))
                        .foregroundStyle(Theme.cheap)
                    Text(deal.lowestDate.dayTitle)
                        .font(.app(13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(deal.lowest.won)
                    .font(.app(20, .bold))
                    .foregroundStyle(.primary)
            }
            .padding(18)
            .background(Theme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

private struct DealRow: View {
    let deal: Deal
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            Text(deal.destination.code)
                .font(.app(13, .heavy))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Theme.tileGradient(index), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(deal.destination.city)
                    .font(.app(16, .semibold))
                    .foregroundStyle(.primary)
                Text(deal.lowestDate.dayTitle)
                    .font(.app(13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(deal.lowest.won)
                .font(.app(16, .bold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct FavoriteRow: View {
    let route: FavoriteRoute
    @Environment(AppState.self) private var appState
    @State private var price: Int?
    @State private var loaded = false

    var body: some View {
        Button {
            appState.pendingRoute = route
            appState.selectedTab = .fly
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Theme.expensive)
                Text("\(route.origin?.city ?? route.originCode) → \(route.destination?.city ?? route.destinationCode)")
                    .font(.app(16, .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if let price {
                    Text(price.won)
                        .font(.app(16, .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                } else if !loaded {
                    ProgressView().controlSize(.small)
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .task(id: route) {
            guard let o = route.origin, let d = route.destination else { return }
            let history = (try? await appState.provider.history(origin: o, destination: d, days: 7, airlines: [], cabin: .economy)) ?? []
            withAnimation { price = history.max { $0.date < $1.date }?.price }
            loaded = true
        }
    }
}
