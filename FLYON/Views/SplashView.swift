import SwiftUI

/// 꺼져 있던 네온 간판이 깜빡이다가 켜지는 오프닝.
/// FLY가 먼저 불안정하게 켜지고, 이어서 ON이 또렷하게 켜진다.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoLevel = 0.0
    @State private var flyLevel = 0.0
    @State private var onLevel = 0.0

    var body: some View {
        ZStack {
            Theme.splashBackground.ignoresSafeArea()

            VStack(spacing: 30) {
                Image("LogoMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .foregroundStyle(.white.opacity(0.10 + 0.90 * logoLevel))
                    .shadow(color: .white.opacity(0.5 * logoLevel), radius: 18 * logoLevel)

                HStack(spacing: 16) {
                    NeonText(text: "FLY", level: flyLevel, glow: .white)
                    NeonText(text: "ON", level: onLevel, glow: Theme.accent)
                }
            }
        }
        .task { await play() }
        .accessibilityHidden(true)
    }

    private func play() async {
        if reduceMotion {
            logoLevel = 1; flyLevel = 1; onLevel = 1
            try? await Task.sleep(for: .seconds(0.8))
            onFinish()
            return
        }

        try? await Task.sleep(for: .seconds(0.45))

        // (목표 밝기, 유지 시간) — 깜빡이며 켜지는 패턴
        let flyFlicker: [(Double, Double)] = [
            (0.55, 0.06), (0.08, 0.09), (0.85, 0.05), (0.15, 0.12), (0.7, 0.05), (0.3, 0.07), (1.0, 0.0),
        ]
        for (level, hold) in flyFlicker {
            withAnimation(.linear(duration: 0.05)) {
                flyLevel = level
                logoLevel = max(logoLevel, level * 0.8)
            }
            try? await Task.sleep(for: .seconds(hold + 0.05))
        }
        withAnimation(.easeOut(duration: 0.4)) { logoLevel = 1 }

        try? await Task.sleep(for: .seconds(0.25))

        let onFlicker: [(Double, Double)] = [(0.6, 0.07), (0.1, 0.1), (1.0, 0.0)]
        for (level, hold) in onFlicker {
            withAnimation(.linear(duration: 0.05)) { onLevel = level }
            try? await Task.sleep(for: .seconds(hold + 0.05))
        }

        try? await Task.sleep(for: .seconds(0.9))
        onFinish()
    }
}

private struct NeonText: View {
    let text: String
    let level: Double
    let glow: Color

    var body: some View {
        Text(text)
            .font(.system(size: 46, weight: .heavy, design: .rounded))
            .tracking(6)
            .foregroundStyle(.white.opacity(0.10 + 0.90 * level))
            .shadow(color: glow.opacity(0.9 * level), radius: 22 * level)
            .shadow(color: glow.opacity(0.6 * level), radius: 5 * level)
    }
}

#Preview {
    SplashView {}
}
