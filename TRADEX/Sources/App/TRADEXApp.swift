import SwiftUI

@main
struct TRADEXApp: App {
    @State private var session = Session()
    @State private var market = MarketStore()
    @State private var ranking = RankingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(market)
                .environment(ranking)
        }
    }
}

struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(MarketStore.self) private var market
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if let wallet = session.wallet {
                    MainTabView()
                        .environment(wallet)
                } else {
                    LoginView()
                }
            }
            if showSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    .zIndex(1)
            }
        }
        .task {
            // 로고를 잠깐 보여 준 뒤 앱으로 (시세는 그동안 뒤에서 불러옴)
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
        }
        .task { await market.bootstrap() }
        // 위젯·잠금화면을 누르면 tradex://coin/KRW-BTC 로 열림 → 거래소 탭에서 그 코인 화면
        .onOpenURL { url in
            guard url.scheme == "tradex", url.host == "coin" else { return }
            market.pendingCoin = url.lastPathComponent
        }
        .onChange(of: scenePhase) { _, phase in
            // 백그라운드에서는 실시간 연결을 끊어 배터리·데이터를 아낀다.
            if phase == .active { market.startLive() } else if phase == .background { market.stopLive() }
        }
    }
}

struct MainTabView: View {
    @Environment(Session.self) private var session
    @Environment(RankingStore.self) private var ranking
    @Environment(MarketStore.self) private var market
    @Environment(Wallet.self) private var wallet
    @State private var liquidated: [FuturesRecord] = []
    /// 주문 체결·적립식 실행 알림
    @State private var notices: [String] = []
    @State private var showSeasonResult = false

    private func fillText(_ f: OrderFill) -> String {
        "\(f.koreanName) \(f.kind.title) 체결 · \(Fmt.qty(f.quantity))개 @ \(Fmt.price(f.price))"
    }
    @State private var tab = MainTabView.initialTab

    /// 디버그 빌드의 화면 캡처용: 실행 인자 -screenshotTab assets 등으로 시작 탭 지정
    private static var initialTab: String {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "screenshotTab") ?? "exchange"
        #else
        return "exchange"
        #endif
    }

    var body: some View {
        @Bindable var session = session
        TabView(selection: $tab) {
            ExchangeView()
                .tabItem { Label("거래소", systemImage: "chart.bar").environment(\.symbolVariants, .none) }
                .tag("exchange")
            AssetsView()
                .tabItem { Label("자산", systemImage: "wallet.pass").environment(\.symbolVariants, .none) }
                .tag("assets")
            RewardsView()
                .tabItem { Label("혜택", systemImage: "gift").environment(\.symbolVariants, .none) }
                .tag("rewards")
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape").environment(\.symbolVariants, .none) }
                .tag("settings")
        }
        #if DEBUG
        .task { await DebugDemo.seedIfRequested(wallet: wallet, market: market) }
        #endif
        // 랭킹: 로그인한 사용자 연결, 5분마다 이번 시즌 AP 전송
        .task(id: session.user?.id) {
            ranking.bind(userID: session.user?.id)
            while !Task.isCancelled {
                if ranking.isJoined {
                    wallet.rollSeasonIfNeeded()
                    await ranking.sync(season: wallet.season, ap: wallet.seasonAP)
                }
                try? await Task.sleep(for: .seconds(300))
            }
        }
        // 선물 청산 감시: 앱을 연 동안은 1초마다 현재가로, 거래소를 바꾸거나 앱을 열 때는 꺼져 있던 동안의 고가·저가로 확인
        .onChange(of: market.pendingCoin) { _, code in if code != nil { tab = "exchange" } }
        // 예약 주문(지정가·손절·익절)과 적립식도 같이 처리
        .task(id: market.exchange) {
            let ex = market.exchange
            let offline = await wallet.reconcileLiquidations(on: ex)
            if !offline.isEmpty { liquidated = offline }
            let offlineFills = await wallet.reconcileOrders(on: ex)
            notices += offlineFills.map(fillText)
            notices += await wallet.runDuePlans(on: ex, currentPrices: market.tickers)
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                tick += 1
                let done = wallet.checkLiquidations(prices: market.tickers, on: ex)
                if !done.isEmpty { liquidated = done }
                if tick % 5 == 0 {
                    await LiveActivityManager.sync(positions: wallet.account(ex).positions, prices: market.tickers)
                }
                let fills = wallet.checkOrders(prices: market.tickers, on: ex)
                if !fills.isEmpty { notices += fills.map(fillText) }
                if tick % 60 == 0 {   // 1분마다 적립식 실행일 확인 (오전 9시가 지나면 실행)
                    notices += await wallet.runDuePlans(on: ex, currentPrices: market.tickers)
                }
            }
        }
        .alert("알림", isPresented: Binding(get: { !notices.isEmpty && liquidated.isEmpty }, set: { if !$0 { notices = [] } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(notices.joined(separator: "\n"))
        }
        .sensoryFeedback(.success, trigger: notices.count)
        .alert("포지션 청산", isPresented: Binding(get: { !liquidated.isEmpty }, set: { if !$0 { liquidated = [] } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(liquidated.map { "\($0.koreanName) \($0.side.title) \($0.leverage)× · 증거금 \(Fmt.krw($0.margin)) 소진" }.joined(separator: "\n"))
        }
        .overlay {
            if let lv = wallet.pendingLevelUp, !session.showWelcome {
                LevelUpOverlay(level: lv) {
                    withAnimation(.easeOut(duration: 0.25)) { wallet.pendingLevelUp = nil }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: wallet.pendingLevelUp)
        // 시즌이 끝났으면 결과·보상 화면
        .overlay {
            if showSeasonResult, let record = wallet.pendingSeasonRecord, wallet.pendingLevelUp == nil, !session.showWelcome {
                SeasonResultOverlay(record: record) {
                    withAnimation(.easeOut(duration: 0.25)) { showSeasonResult = false }
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .task {
            wallet.rollSeasonIfNeeded()
            try? await Task.sleep(for: .seconds(2))
            if wallet.pendingSeasonRecord != nil { withAnimation { showSeasonResult = true } }
        }
        .sheet(isPresented: $session.showWelcome) {
            WelcomeBonusView()
                .presentationDetents([.medium])
        }
    }
}
