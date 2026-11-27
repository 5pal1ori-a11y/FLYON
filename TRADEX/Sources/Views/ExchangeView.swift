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
    @State private var path: [Market] = []

    /// 정렬 순서는 5초마다만 갱신 (매 틱마다 줄이 바뀌면 누르기 어렵다)
    private let reorderTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var visible: [Market] {
        var base = order.compactMap { store.market($0) }
        if base.isEmpty { base = store.markets }
        switch tab {
        case .krw: break
        case .holdings:
            let a = wallet.account(store.exchange)
            base = base.filter { m in a.holdings[m.market] != nil || a.positions.contains { $0.market == m.market } }
        case .favorites: base = base.filter { store.favorites.contains($0.market) }
        }
        guard !query.isEmpty else { return base }
        let q = query.lowercased()
        return base.filter {
            $0.koreanName.lowercased().contains(q) || $0.symbol.lowercased().contains(q) || $0.englishName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                    content
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("거래소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TradexLogo(height: 18, showsWordmark: true)
                }
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
        .onChange(of: store.pendingCoin) { _, code in openPending(code) }
        .onChange(of: store.markets) { openPending(store.pendingCoin) }
        #if DEBUG
        // 화면 캡처용: 실행 인자 -screenshotCoin KRW-BTC 이면 그 코인 상세 화면을 연다
        .onChange(of: store.markets) {
            if path.isEmpty, let code = UserDefaults.standard.string(forKey: "screenshotCoin"), let m = store.market(code) {
                path = [m]
            }
        }
        #endif
    }

    // MARK: - 본문 (요약 · 급상승 · 탭 · 정렬 · 목록)

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if query.isEmpty {
                    summaryLine
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    moversStrip
                        .padding(.top, 18)
                        .padding(.bottom, 8)
                }
                Section {
                    if visible.isEmpty {
                        Text(tab == .holdings ? "보유한 코인이 없어요." : tab == .favorites ? "관심 코인이 없어요. 코인 화면의 ☆를 눌러 추가해요." : "검색 결과가 없어요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                    ForEach(visible) { m in
                        NavigationLink(value: m) {
                            MarketTableRow(market: m, ticker: store.tickers[m.market])
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    listHeader
                }
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// 내 평가손익 한 줄
    private var summaryLine: some View {
        let v = wallet.valuation(store.exchange, prices: store.tickers)
        let pnl = v.coinPnL + v.futuresPnL
        let invested = v.coinCost + v.positionMargin
        let rate = invested > 0 ? pnl / invested : 0
        let total = v.coinValue + v.krw + v.futuresKRW + v.positionValue
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("내 \(store.exchange.name) 자산").font(.caption).foregroundStyle(.secondary)
                Text(Fmt.krw(total)).font(.title2.weight(.bold)).monospacedDigit()
                    .contentTransition(.numericText(value: total))
                    .animation(.snappy, value: total)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("평가손익").font(.caption).foregroundStyle(.secondary)
                Text("\(Fmt.signedKRW(pnl))원 (\(Fmt.rate(rate)))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.color(for: pnl))
                    .monospacedDigit()
            }
        }
    }

    /// 실시간 급상승 TOP 5 (가로 스크롤 카드)
    private var moversStrip: some View {
        let movers = store.markets
            .compactMap { m in store.tickers[m.market].map { (m, $0) } }
            .filter { $0.1.accTradePrice24h > 1_000_000_000 }   // 거래대금 10억 이상만
            .sorted { $0.1.signedChangeRate > $1.1.signedChangeRate }
            .prefix(5)
        return VStack(alignment: .leading, spacing: 10) {
            Text("지금 많이 오른 코인").font(.headline).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(movers), id: \.0.id) { m, t in
                        NavigationLink(value: m) {
                            VStack(alignment: .leading, spacing: 10) {
                                CoinIcon(symbol: m.symbol, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.koreanName).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text("₩\(Fmt.price(t.tradePrice))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                }
                                Text(Fmt.rate(t.signedChangeRate))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Theme.color(for: t.signedChangeRate))
                                    .monospacedDigit()
                            }
                            .frame(width: 128, alignment: .leading)
                            .padding(14)
                            .background(Theme.tossBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// 목록 위 고정 머리: 마켓 탭 + 정렬
    private var listHeader: some View {
        VStack(spacing: 10) {
            BWSegmented(options: ListTab.allCases.map { ($0, $0.rawValue) }, selection: $tab, compact: true, outlined: false)
            HStack(spacing: 6) {
                sortChip("거래대금", .volume)
                sortChip("등락률", .rate)
                sortChip("현재가", .price)
                sortChip("이름", .name)
                Spacer()
                Text("\(visible.count)개").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private func sortChip(_ title: String, _ c: Column) -> some View {
        Button {
            withAnimation(.snappy) {
                if column == c { ascending.toggle() } else { column = c; ascending = c == .name }
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if column == c {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .bold))
                }
            }
            .font(.caption.weight(column == c ? .bold : .medium))
            .foregroundStyle(column == c ? .primary : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(column == c ? Theme.tossBackground : .clear))
        }
        .buttonStyle(.plain)
    }

    private func openPending(_ code: String?) {
        guard let code, let m = store.market(code) else { return }
        path = [m]
        store.pendingCoin = nil
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

/// 시세 목록 한 줄 (토스식): 아이콘 · 이름/심볼·거래대금 · 현재가/등락률
struct MarketTableRow: View {
    let market: Market
    let ticker: Ticker?

    var body: some View {
        HStack(spacing: 12) {
            CoinIcon(symbol: market.symbol, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(market.koreanName).font(.body.weight(.semibold)).lineLimit(1)
                Text(ticker.map { "\(market.symbol) · \(Fmt.compactKRW($0.accTradePrice24h))" } ?? market.symbol)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if let t = ticker {
                VStack(alignment: .trailing, spacing: 3) {
                    FlashingPrice(price: t.tradePrice, font: .body, color: .primary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(Fmt.rate(t.signedChangeRate))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.color(for: t.signedChangeRate))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: t.signedChangeRate))
                        .animation(.snappy, value: t.signedChangeRate)
                }
            } else {
                Text("-").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// (이전 버전 호환) 관심 목록 — 지금은 거래소 탭의 '관심'으로 통합
struct WatchlistView: View {
    var body: some View { ExchangeView() }
}
