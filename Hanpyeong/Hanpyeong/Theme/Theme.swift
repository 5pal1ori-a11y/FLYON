import SwiftUI
import UIKit
import CoreText

// MARK: - 색상
// 장부(종이)와 간판(빨강)을 기본 톤으로 잡았다. 그라데이션·네온은 쓰지 않는다.

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum Palette {
    static let paper    = Color(light: 0xF3F0EA, dark: 0x0F1012)
    static let card     = Color(light: 0xFFFFFF, dark: 0x1B1C20)
    static let cardDeep = Color(light: 0xF0ECE4, dark: 0x26282D)
    /// 다크 모드에서만 보이는 카드 테두리
    static let hairline = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x2A2C31) : .clear })
    static let ink      = Color(light: 0x1C222A, dark: 0xECE6DA)
    static let inkSoft  = Color(light: 0x6D685F, dark: 0x9C978D)
    static let inkFaint = Color(light: 0xA39D92, dark: 0x5E5B55)
    static let line     = Color(light: 0xDDD4C4, dark: 0x2D3036)

    /// 간판 빨강 — 앱의 유일한 강조색
    static let sign     = Color(light: 0xC23B2C, dark: 0xE0553F)
    /// 한국식 시세 표기: 상승 빨강, 하락 파랑
    static let up       = Color(light: 0xD13A2A, dark: 0xF0644F)
    static let down     = Color(light: 0x2D61C4, dark: 0x6E9BF0)
    static let gold     = Color(light: 0xA97B22, dark: 0xD7A84A)
    static let glass    = Color(light: 0xCFE0E6, dark: 0x2E3E46)
    static let receipt  = Color(light: 0xFBF8F1, dark: 0x202226)
}

// MARK: - UIKit 쪽 모양 (탭바)

enum Appearance {
    static func apply() {
        let paper = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x131416) : UIColor(hex: 0xF2EDE3) }
        let line = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x2D3036) : UIColor(hex: 0xDDD4C4) }
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = paper
        tab.shadowColor = line
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = paper
        nav.shadowColor = line
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

// MARK: - 글꼴

enum FontRegistry {
    static func registerBundledFonts() {
        let names = ["NanumMyeongjo", "NanumMyeongjoBold"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// 명조 — 간판, 제목, 숫자 강조
    static func myeongjo(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "NanumMyeongjoBold" : "NanumMyeongjo", size: size)
    }

    /// 숫자 — 자릿수 폭 고정
    static func num(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// 영수증용 고정폭
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - 카드 스타일

struct PaperCard: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x5A4632).opacity(0.07), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func paperCard(padding: CGFloat = 20) -> some View {
        modifier(PaperCard(padding: padding))
    }

    /// 작은 회색 머리글 (섹션 라벨)
    /// 카드 제목 — 굵고 크게
    func sectionLabel() -> some View {
        self.font(.system(size: 17, weight: .bold))
            .foregroundStyle(Palette.ink)
            .textCase(nil)
    }
}

/// 꾹 누르면 살짝 눌리는 버튼
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 채워진 주 버튼 (간판 빨강)
struct SignButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? Palette.sign : Palette.inkFaint)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 테두리만 있는 보조 버튼
struct LineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.cardDeep.opacity(0.7))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
