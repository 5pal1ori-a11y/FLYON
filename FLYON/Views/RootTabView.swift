import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            HomeView()
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(AppTab.home)

            PricingView()
                .tabItem { Label("책정", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.pricing)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
    }
}
