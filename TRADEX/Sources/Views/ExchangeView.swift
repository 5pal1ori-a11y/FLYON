import SwiftUI

struct ExchangeView: View {
    @Environment(MarketStore.self) private var store
    @State private var query = ""
    @State private var sortKey: SortKey = .volume
    @State private var order: [Market] = []

    /// 정렬 순서는 5초마다만 갱신 (매 틱마다 줄이 바뀌면 누르기 어렵다)
    private let reorderTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var visible: [Market] {
        let base = order.isEmpty ? store.markets : order
        guard !query.isEmpty else { return base }
        let q = query.lowercased()
        return base.filter {
            $0.koreanName.lowercased().contains(q) || $0.symbol.lowercased().contains(q) || $0.englishName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let error = store.loadError, store.markets.isEmpty {
                    ContentUnavailableView {
                        Label("시세를 불러오지 못했어요", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("다시 시도") { Task { await store.retry() } }
                    }
                } else if store.markets.isEmpty {
                    ProgressView("시세 불러오는 중…")
                } else {
                    list
                }
            }
            .background(Theme.background)
            .navigationTitle("거래소")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { LiveIndicator(isLive: store.isConnected) }
            }
            .searchable(text: $query, prompt: "코인명/심볼 검색")
            .navigationDestination(for: Market.self) { CoinDetailView(market: $0) }
        }
        .onChange(of: sortKey) { reorder() }
        .onChange(of: store.markets) { reorder() }
        .onReceive(reorderTimer) { _ in reorder() }
        .onAppear { reorder() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(visible) { m in
                        NavigationLink(value: m) {
                            CoinRow(market: m, ticker: store.tickers[m.market])
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        Divider().padding(.leading, 72)
                    }
                } header: {
                    sortBar
                }
            }
        }
    }

    private var sortBar: some View {
        HStack(spacing: 8) {
            ForEach(SortKey.allCases) { key in
                Button {
                    sortKey = key
                } label: {
                    Text(key.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(sortKey == key ? Color(.systemBackground) : .primary)
                        .background(sortKey == key ? Color.primary : Theme.card, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(visible.count)개")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private func reorder() {
        withAnimation(.snappy) { order = store.sorted(store.markets, by: sortKey) }
    }
}

struct WatchlistView: View {
    @Environment(MarketStore.self) private var store

    private var items: [Market] {
        store.sorted(store.markets.filter { store.favorites.contains($0.market) }, by: .volume)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if items.isEmpty {
                    ContentUnavailableView("관심 코인이 없어요", systemImage: "star",
                                           description: Text("코인 상세 화면에서 ☆를 눌러 추가해 보세요."))
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { m in
                            NavigationLink(value: m) {
                                CoinRow(market: m, ticker: store.tickers[m.market])
                            }
                            .buttonStyle(.plain)
                            if m.id != items.last?.id { Divider().padding(.leading, 52) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .padding(16)
                }
            }
            .background(Theme.background)
            .navigationTitle("관심")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { TradexLogo(height: 20, showsWordmark: false) }
                ToolbarItem(placement: .topBarTrailing) { LiveIndicator(isLive: store.isConnected) }
            }
            .navigationDestination(for: Market.self) { CoinDetailView(market: $0) }
        }
    }
}
