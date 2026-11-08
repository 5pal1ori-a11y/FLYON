import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(PushManager.self) private var push

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            HomeView()
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(AppTab.home)

            FlyView()
                .tabItem {
                    Label { Text("FLY") } icon: { Image("LogoTab").renderingMode(.template) }
                }
                .tag(AppTab.fly)

            AlertsView()
                .tabItem { Label("알림", systemImage: "bell.fill") }
                .tag(AppTab.alerts)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        .sensoryFeedback(.selection, trigger: appState.selectedTab)
        .onChange(of: push.openedRoute) { _, route in
            guard let route else { return }
            appState.pendingDate = push.openedDate
            appState.pendingRoute = route
            appState.selectedTab = .fly
            push.openedRoute = nil
        }
    }
}
