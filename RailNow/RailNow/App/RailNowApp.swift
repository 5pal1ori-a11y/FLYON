import SwiftUI

@main
struct RailNowApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: TrainStore
    @StateObject private var guide: RideGuide

    @MainActor
    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: TrainStore(settings: settings))
        _guide = StateObject(wrappedValue: RideGuide())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(guide)
                .tint(Palette.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var guide: RideGuide

    var body: some View {
        TabView(selection: $store.tab) {
            HomeView()
                .guidanceBar()
                .tabItem { Label("홈", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.home)
            NetworkMapView()
                .guidanceBar()
                .tabItem { Label("노선도", systemImage: "map.fill") }
                .tag(AppTab.map)
            SubwayView()
                .guidanceBar()
                .tabItem { Label("실시간", systemImage: "tram.fill") }
                .tag(AppTab.subway)
            RailView()
                .guidanceBar()
                .tabItem { Label("기차", systemImage: "train.side.front.car") }
                .tag(AppTab.rail)
            SettingsView()
                .guidanceBar()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .sheet(isPresented: $store.showGuide) {
            GuidanceView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #if DEBUG
        .onAppear {
            // 시뮬레이터 스크린샷용: -screenshotSheet guide | guidebar
            let mode = UserDefaults.standard.string(forKey: "screenshotSheet")
            if mode == "guide" || mode == "guidebar", let plan = RouteFinder.shared.plan(from: "서울", to: "판교") {
                guide.start(plan, quiet: true)
                guide.boarded()
                guide.setCurrent(5)
                store.showGuide = mode == "guide"
            }
        }
        #endif
    }
}
