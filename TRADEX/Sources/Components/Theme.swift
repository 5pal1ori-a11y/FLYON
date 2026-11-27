import SwiftUI

enum Theme {
    /// 한국 시장 관례: 상승 빨강, 하락 파랑
    static let rise = Color(red: 0.898, green: 0.196, blue: 0.176)
    static let fall = Color(red: 0.122, green: 0.384, blue: 0.839)
    static let even = Color.secondary
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 16

    // 토스 스타일 카드: 연한 회색 바탕 위 흰 카드 (테두리·그림자 없음)
    static let tossBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.063, green: 0.063, blue: 0.075, alpha: 1)
                                      : UIColor(red: 0.949, green: 0.957, blue: 0.965, alpha: 1)   // #F2F4F6
    })
    static let tossCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.118, green: 0.118, blue: 0.133, alpha: 1)
                                      : .white
    })

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

    /// 토스 스타일 카드: 큰 둥근 모서리, 넉넉한 여백, 테두리 없음
    func tossCard(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.tossCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
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
