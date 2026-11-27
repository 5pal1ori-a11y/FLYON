import SwiftUI

@main
struct HanpyeongApp: App {
    @State private var game = Game()

    init() {
        FontRegistry.registerBundledFonts()
        Appearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .tint(Palette.sign)
        }
    }
}
