import SwiftUI

@main
struct TRADEXApp: App {
    @State private var session = Session()
    @State private var market = MarketStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(market)
        }
    }
}

struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(MarketStore.self) private var market
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let wallet = session.wallet {
                MainTabView()
                    .environment(wallet)
            } else {
                LoginView()
            }
        }
        .task { await market.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            // 백그라운드에서는 실시간 연결을 끊어 배터리·데이터를 아낀다.
            if phase == .active { market.startLive() } else if phase == .background { market.stopLive() }
        }
    }
}

struct MainTabView: View {
    @Environment(Session.self) private var session

    var body: some View {
        @Bindable var session = session
        TabView {
            WatchlistView()
                .tabItem { Label("관심", systemImage: "star.fill") }
            ExchangeView()
                .tabItem { Label("거래소", systemImage: "chart.bar.fill") }
            AssetsView()
                .tabItem { Label("자산", systemImage: "wallet.pass.fill") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $session.showWelcome) {
            WelcomeBonusView()
                .presentationDetents([.medium])
        }
    }
}
