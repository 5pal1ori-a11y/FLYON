import SwiftUI

@main
struct FLYONApp: App {
    @State private var auth = AuthManager()
    @State private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if auth.isSignedIn {
                    RootTabView()
                } else {
                    LoginView()
                }

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .environment(auth)
            .environment(appState)
            .task { await auth.checkCredentialState() }
        }
    }
}
