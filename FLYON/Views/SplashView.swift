import SwiftUI

/// 오프닝: 로고가 잔상을 남기며 미끄러져 들어오고(드래그), 글자가 차례로 따라 들어온 뒤 불이 켜진다.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoX: CGFloat = -320
    @State private var trail: CGFloat = 1
    @State private var lettersIn = false
    @State private var glow = 0.0
    @State private var sweep: CGFloat = -1

    private let letters = Array("FLY ON")

    var body: some View {
        ZStack {
            Theme.splashBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    // 잔상 (끌려오는 느낌)
                    ForEach(1..<6, id: \.self) { i in
                        logo
                            .opacity(0.22 * trail * (1 - Double(i) / 6))
                            .offset(x: logoX - CGFloat(i) * 26 * trail)
                            .blur(radius: CGFloat(i) * 1.6 * trail)
                    }
                    logo
                        .offset(x: logoX)
                        .shadow(color: Theme.accent.opacity(0.9 * glow), radius: 26 * glow)
                }
                .frame(height: 96)

                HStack(spacing: 2) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { index, ch in
                        Text(String(ch))
                            .font(.app(46, .heavy))
                            .foregroundStyle(.white)
                            .offset(x: lettersIn ? 0 : -60)
                            .opacity(lettersIn ? 1 : 0)
                            .blur(radius: lettersIn ? 0 : 8)
                            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double(index) * 0.055), value: lettersIn)
                    }
                }
                .tracking(4)
                .shadow(color: Theme.accent.opacity(0.85 * glow), radius: 20 * glow)
                .overlay {
                    // 글자 위를 빛이 쓸고 지나간다
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.35)
                            .offset(x: sweep * g.size.width)
                            .blendMode(.plusLighter)
                    }
                    .mask {
                        HStack(spacing: 2) {
                            ForEach(Array(letters.enumerated()), id: \.offset) { _, ch in
                                Text(String(ch)).font(.app(46, .heavy))
                            }
                        }
                        .tracking(4)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .task { await play() }
        .accessibilityHidden(true)
    }

    private var logo: some View {
        Image("LogoMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 92, height: 92)
            .foregroundStyle(.white)
    }

    private func play() async {
        if reduceMotion {
            logoX = 0; trail = 0; lettersIn = true; glow = 1
            try? await Task.sleep(for: .seconds(0.8))
            onFinish()
            return
        }
        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) { logoX = 0 }
        withAnimation(.easeOut(duration: 0.9)) { trail = 0 }
        try? await Task.sleep(for: .seconds(0.45))
        lettersIn = true
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.easeOut(duration: 0.5)) { glow = 1 }
        withAnimation(.easeInOut(duration: 0.8)) { sweep = 1.2 }
        try? await Task.sleep(for: .seconds(1.0))
        onFinish()
    }
}

#Preview {
    SplashView {}
}
