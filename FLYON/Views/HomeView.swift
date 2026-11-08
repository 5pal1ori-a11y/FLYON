import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var deals: [Deal] = []
    @State private var loading = true
    @State private var showOriginPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 28) {
                        carousel
                        if deals.count > 1 { dealList }
                        if !appState.favorites.isEmpty { favorites }
                        Text("표시되는 가격은 참고용이며, 평균은 앞으로의 출발일 가격의 평균이에요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: appState.homeOriginCode) { await loadDeals() }
            .sheet(isPresented: $showOriginPicker) {
                AirportPickerView(title: "출발지", excluded: nil) { appState.setHomeOrigin($0) }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image("LogoMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white)
                Text("FLYON")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
            }

            Button {
                showOriginPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("이 지역에서 출발하는 특가 보기")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appState.homeOrigin.city)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 64)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("추천 특가")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("출발일 평균 가격보다 저렴한 노선이에요")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 84)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.headerGradient
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: 추천 특가 (가로 카드)

    @ViewBuilder
    private var carousel: some View {
        Group {
            if loading {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.cardBackground)
                    .frame(height: 290)
                    .overlay(ProgressView())
            } else if deals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("아직 특가를 모으는 중이에요", systemImage: "hourglass")
                        .font(.headline)
                    Text("\(appState.homeOrigin.city) 출발은 가격 데이터가 더 쌓여야 특가를 보여 드릴 수 있어요. 다른 출발지를 고르거나 책정 탭에서 노선을 직접 검색해 보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(deals.prefix(6).enumerated()), id: \.element.id) { index, deal in
                            Button { open(deal) } label: {
                                DealCard(origin: appState.homeOrigin, deal: deal, index: index)
                                    .frame(width: 280)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
        }
        .padding(.top, -64)
    }

    // MARK: 노선별 최저가 (목록)

    private var dealList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "노선별 최저가", subtitle: "\(appState.homeOrigin.city) 출발")
            VStack(spacing: 0) {
                ForEach(Array(deals.enumerated()), id: \.element.id) { index, deal in
                    Button { open(deal) } label: {
                        DealRow(deal: deal, index: index)
                    }
                    .buttonStyle(.plain)
                    if index < deals.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
    }

    // MARK: 관심 노선

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "관심 노선")
            ForEach(appState.favorites) { route in
                FavoriteRow(route: route)
            }
        }
    }

    // MARK: Actions

    private func open(_ deal: Deal) {
        appState.pendingRoute = FavoriteRoute(originCode: appState.homeOrigin.code, destinationCode: deal.destination.code)
        appState.pendingDate = deal.lowestDate
        appState.selectedTab = .pricing
    }

    private func loadDeals() async {
        loading = true
        deals = (try? await appState.provider.deals(origin: appState.homeOrigin)) ?? []
        loading = false
    }
}

// MARK: - 특가 카드

private struct DealCard: View {
    let origin: Airport
    let deal: Deal
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Theme.tileGradient(index)
                Image(systemName: "airplane")
                    .font(.system(size: 120, weight: .bold))
                    .rotationEffect(.degrees(-18))
                    .foregroundStyle(.white.opacity(0.14))
                    .offset(x: 130, y: 40)
                Text(deal.destination.code)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(16)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.right")
                    Text("평균보다 \(deal.savings.won) 저렴")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(12)
            }
            .frame(height: 150)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(deal.destination.city)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(deal.destination.country)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom) {
                    Text("\(deal.lowestDate.dayTitle) 출발")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("평균 \(deal.average.won)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(deal.lowest.won)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct DealRow: View {
    let deal: Deal
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            Text(deal.destination.code)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Theme.tileGradient(index), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(deal.destination.city)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(deal.destination.country) · \(deal.lowestDate.dayTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(deal.lowest.won)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Pill(text: "\(deal.savingsPercent)% 저렴", systemImage: "arrow.down.right", color: Theme.cheap)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
