import SwiftUI

enum Theme {
    /// 한국 시장 관례: 상승 빨강, 하락 파랑
    static let rise = Color(red: 0.898, green: 0.196, blue: 0.176)
    static let fall = Color(red: 0.122, green: 0.384, blue: 0.839)
    static let even = Color.secondary
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 16

    static func color(for change: Double) -> Color {
        change > 0 ? rise : (change < 0 ? fall : even)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// 브랜드 버튼 (검정/흰색 반전)
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(color == .primary ? Color(.systemBackground) : .white)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// TRADEX 로고 (Assets의 Logo, 템플릿 이미지라 다크모드에서 자동 반전)
struct TradexLogo: View {
    var height: CGFloat = 28
    var showsWordmark = true
    var body: some View {
        HStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: height)
            if showsWordmark {
                Text("TRADEX")
                    .font(.system(size: height * 0.8, weight: .heavy))
                    .tracking(1.5)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TRADEX")
    }
}
