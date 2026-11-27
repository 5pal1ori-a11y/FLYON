import SwiftUI

@main
struct HanpyeongApp: App {
    @State private var game: Game

    init() {
        FontRegistry.registerBundledFonts()
        Appearance.apply()
        let g = Game()
        #if DEBUG
        if ScreenshotArgs.demo { g.applyDemoState() }
        #endif
        _game = State(initialValue: g)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .tint(Palette.sign)
        }
    }
}
