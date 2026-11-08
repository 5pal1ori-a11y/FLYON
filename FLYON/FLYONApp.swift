import SwiftUI

@main
struct FLYONApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var auth = AuthManager()
    @State private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if auth.isSignedIn {
                        RootTabView()
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        LoginView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: auth.isSignedIn)

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .font(.app(16))
            .environment(auth)
            .environment(appState)
            .environment(PushManager.shared)
            .task { await auth.checkCredentialState() }
        }
    }
}
