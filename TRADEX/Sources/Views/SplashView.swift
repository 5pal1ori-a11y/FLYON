import SwiftUI

/// 앱 시작 로고 화면 — iOS 시작 화면(같은 위치·크기의 로고)에서 이어져
/// 로고가 살짝 튀고 "TRADEX" 글자가 나타난 뒤 사라진다.
struct SplashView: View {
    @State private var logoPop = false
    @State private var showWordmark = false
    @State private var tracking: CGFloat = 14

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .foregroundStyle(.primary)
                .scaleEffect(logoPop ? 1.08 : 1)
                .overlay(alignment: .bottom) {
                    Text("TRADEX")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(tracking)
                        .fixedSize()
                        .opacity(showWordmark ? 1 : 0)
                        .offset(y: showWordmark ? 52 : 64)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TRADEX")
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { logoPop = true }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { logoPop = false }
            withAnimation(.easeOut(duration: 0.6)) {
                showWordmark = true
                tracking = 5
            }
        }
    }
}
