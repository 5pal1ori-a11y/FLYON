import SwiftUI
import LocalAuthentication

@main
struct SubscriptionOnApp: App {
    @StateObject private var store = Store()
    @State private var splash = true
    @State private var locked = false
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !splash { RootView().environmentObject(store).transition(.opacity) }
                if locked { LockView { unlock() }.transition(.opacity) }
                if splash {
                    SplashView { withAnimation(.easeInOut(duration: 0.4)) { splash = false }; if store.faceLock { locked = true; unlock() } }
                        .transition(.opacity).zIndex(1)
                }
            }
            .preferredColorScheme(.light)
            .onChange(of: phase) { _, p in if p == .background, store.faceLock { locked = true } else if p == .active, locked, !splash { unlock() } }
            .onAppear { store.requestNotify() }
        }
    }

    func unlock() {
        let ctx = LAContext(); var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "구독온 잠금 해제") { ok, _ in
            DispatchQueue.main.async { if ok { withAnimation { locked = false } } }
        }
    }
}

struct LockView: View {
    var retry: () -> Void
    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill").font(.system(size: 36)).foregroundStyle(T.blue)
                Text("잠겨 있어요").font(.system(size: 20, weight: .bold))
                Button("열기", action: retry).font(.system(size: 17, weight: .bold)).foregroundStyle(T.blue)
            }
        }
    }
}

/// 구독(꺼짐: 검정) → 온(켜짐: 초록)
struct SplashView: View {
    var done: () -> Void
    @State private var on = false
    @State private var showText = false
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule().fill(on ? T.green : Color.black).frame(width: 132, height: 76)
                    Capsule().fill(.white).frame(width: 84, height: 60).padding(.horizontal, 8)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.78), value: on)
                HStack(spacing: 0) {
                    Text("구독").foregroundStyle(on ? T.text : T.faint)
                    Text("온").foregroundStyle(on ? T.green : T.faint)
                }
                .font(.system(size: 34, weight: .heavy)).opacity(showText ? 1 : 0)
            }
        }
        .task {
            withAnimation(.easeIn(duration: 0.3)) { showText = true }
            try? await Task.sleep(nanoseconds: 700_000_000)
            on = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            try? await Task.sleep(nanoseconds: 900_000_000)
            done()
        }
    }
}
