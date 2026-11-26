import SwiftUI

/// 거래소 탭 — 실제 거래소 앱처럼 요약 바 + 마켓 탭 + 정렬 가능한 시세 표
struct ExchangeView: View {
    enum ListTab: String, CaseIterable, Identifiable {
        case krw = "원화마켓", holdings = "보유코인", favorites = "관심"
        var id: String { rawValue }
    }
    enum Column { case name, price, rate, volume }

    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var query = ""
    @State private var tab: ListTab = .krw
    @State private var column: Column = .volume
    @State private var ascending = false
    @State private var order: [String] = []

    /// 정렬 순서는 5초마다만 갱신 (매 틱마다 줄이 바뀌면 누르기 어렵다)
    private let reorderTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var visible: [Market] {
        var base = order.compactMap { store.market($0) }
        if base.isEmpty { base = store.markets }
        switch tab {
        case .krw: break
        case .holdings: base = base.filter { wallet.state.holdings[$0.market] != nil }
        case .favorites: base = base.filter { store.favorites.contains($0.market) }
        }
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
                    VStack(spacing: 0) {
                        summaryBar
                        tabBar
                        columnHeader
                        Divider()
                        table
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("거래소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { TradexLogo(height: 18, showsWordmark: true) }
                ToolbarItem(placement: .topBarTrailing) { LiveIndicator(isLive: store.isConnected) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "코인명/심볼 검색")
            .navigationDestination(for: Market.self) { CoinDetailView(market: $0) }
        }
        .onChange(of: column) { reorder() }
        .onChange(of: ascending) { reorder() }
        .onChange(of: store.markets) { reorder() }
        .onReceive(reorderTimer) { _ in reorder() }
        .onAppear { reorder() }
    }

    // MARK: - 요약 바 (총 평가 · 평가손익 · 수익률)

    private var summaryBar: some View {
        let v = wallet.valuation(prices: store.tickers)
        let pnl = v.total - wallet.baseValue
        let rate = wallet.baseValue > 0 ? pnl / wallet.baseValue : 0
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                summaryRow("주문가능", Fmt.krw(v.krw))
                summaryRow("총 평가", Fmt.krw(v.total))
            }
            .frame(maxWidth: .infinity)
            Divider().frame(height: 34)
            VStack(alignment: .leading, spacing: 4) {
                summaryRow("평가손익", "\(Fmt.signedKRW(pnl))원", Theme.color(for: pnl))
                summaryRow("수익률", Fmt.rate(rate), Theme.color(for: pnl))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private func summaryRow(_ title: String, _ value: String, _ color: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value).fontWeight(.semibold).foregroundStyle(color).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.caption)
        .padding(.horizontal, 8)
    }

    // MARK: - 탭 · 표 머리

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ListTab.allCases) { t in
                Button {
                    withAnimation(.snappy) { tab = t }
                } label: {
                    VStack(spacing: 8) {
                        Text(t.rawValue)
                            .font(.subheadline.weight(tab == t ? .bold : .medium))
                            .foregroundStyle(tab == t ? .primary : .secondary)
                        Rectangle().fill(tab == t ? Color.primary : .clear).frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 4) {
            headerButton("코인명", .name).frame(maxWidth: .infinity, alignment: .leading)
            headerButton("현재가", .price).frame(width: 92, alignment: .trailing)
            headerButton("전일대비", .rate).frame(width: 70, alignment: .trailing)
            headerButton("거래대금", .volume).frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    private func headerButton(_ title: String, _ c: Column) -> some View {
        Button {
            if column == c { ascending.toggle() } else { column = c; ascending = c == .name }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                Image(systemName: column == c ? (ascending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill") : "arrow.up.arrow.down")
                    .font(.system(size: 7))
            }
            .font(.caption2.weight(column == c ? .bold : .regular))
            .foregroundStyle(column == c ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 시세 표

    private var table: some View {
        ScrollView {
            if visible.isEmpty {
                Text(tab == .holdings ? "보유한 코인이 없어요." : tab == .favorites ? "관심 코인이 없어요. 코인 화면에서 ☆를 눌러 추가해요." : "검색 결과가 없어요.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.top, 60)
            }
            LazyVStack(spacing: 0) {
                ForEach(visible) { m in
                    NavigationLink(value: m) {
                        MarketTableRow(market: m, ticker: store.tickers[m.market])
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    private func reorder() {
        let t = store.tickers
        func key(_ m: Market) -> Double {
            switch column {
            case .price: return t[m.market]?.tradePrice ?? 0
            case .rate: return t[m.market]?.signedChangeRate ?? 0
            case .volume, .name: return t[m.market]?.accTradePrice24h ?? 0
            }
        }
        let sorted: [Market]
        if column == .name {
            sorted = store.markets.sorted {
                let r = $0.koreanName.localizedCompare($1.koreanName)
                return ascending ? r == .orderedAscending : r == .orderedDescending
            }
        } else {
            sorted = store.markets.sorted { ascending ? key($0) < key($1) : key($0) > key($1) }
        }
        order = sorted.map(\.market)
    }
}

/// 시세 표 한 줄: 코인명 | 현재가 | 전일대비 | 거래대금
struct MarketTableRow: View {
    let market: Market
    let ticker: Ticker?

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 8) {
                CoinIcon(symbol: market.symbol, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(market.koreanName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(market.symbol)/KRW").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let t = ticker {
                let color = Theme.color(for: t.signedChangeRate)
                FlashingPrice(price: t.tradePrice, font: .subheadline, color: color)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 92, alignment: .trailing)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Fmt.rate(t.signedChangeRate)).font(.footnote.weight(.semibold))
                    Text(Fmt.signedPrice(t.signedChangePrice)).font(.caption2)
                }
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: 70, alignment: .trailing)
                Text(Fmt.millions(t.accTradePrice24h))
                    .font(.footnote).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 78, alignment: .trailing)
            } else {
                Text("-").foregroundStyle(.secondary).frame(width: 240, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// (이전 버전 호환) 관심 목록 — 지금은 거래소 탭의 '관심'으로 통합
struct WatchlistView: View {
    var body: some View { ExchangeView() }
}
