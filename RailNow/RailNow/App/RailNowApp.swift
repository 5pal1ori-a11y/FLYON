import SwiftUI

@main
struct RailNowApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: TrainStore

    @MainActor
    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: TrainStore(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .tint(Palette.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TrainStore

    var body: some View {
        TabView(selection: $store.tab) {
            HomeView()
                .tabItem { Label("홈", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.home)
            NetworkMapView()
                .tabItem { Label("노선도", systemImage: "map.fill") }
                .tag(AppTab.map)
            SubwayView()
                .tabItem { Label("실시간", systemImage: "tram.fill") }
                .tag(AppTab.subway)
            RailView()
                .tabItem { Label("기차", systemImage: "train.side.front.car") }
                .tag(AppTab.rail)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}
