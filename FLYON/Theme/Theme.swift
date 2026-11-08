import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - 폰트 (Pretendard, SIL Open Font License)

extension Font {
    /// 앱 기본 서체. 시스템 글자 크기 설정을 따라 커지고 작아진다.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        if weight == .heavy || weight == .black {
            name = "Pretendard-ExtraBold"
        } else if weight == .bold {
            name = "Pretendard-Bold"
        } else if weight == .semibold {
            name = "Pretendard-SemiBold"
        } else if weight == .medium {
            name = "Pretendard-Medium"
        } else {
            name = "Pretendard-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

// MARK: - 색과 모양

enum Theme {
    static let navy = Color(hex: 0x061A33)
    static let navyLight = Color(hex: 0x0D3A73)
    static let accent = Color(hex: 0x1A6DFF)
    static let accentSoft = Color(hex: 0x1A6DFF, opacity: 0.12)

    static let cheap = Color(hex: 0x12A26B)
    static let mid = Color(hex: 0xE69500)
    static let expensive = Color(hex: 0xEF4A4F)
    static let normal = Color(hex: 0x8A93A3)

    static let splashBackground = Color(hex: 0x050B16)
    static let screenBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    static let cardRadius: CGFloat = 22

    static let headerGradient = LinearGradient(
        colors: [navy, navyLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tilePalette: [[Color]] = [
        [Color(hex: 0x1A6DFF), Color(hex: 0x63A4FF)],
        [Color(hex: 0x6C3CF0), Color(hex: 0xB194FF)],
        [Color(hex: 0x0E9F6E), Color(hex: 0x5BE0B0)],
        [Color(hex: 0xF0544F), Color(hex: 0xFFA26B)],
        [Color(hex: 0x0B8BB3), Color(hex: 0x74DDF4)],
        [Color(hex: 0xD63B7A), Color(hex: 0xFFA9C9)],
    ]

    static func tileGradient(_ index: Int) -> LinearGradient {
        LinearGradient(colors: tilePalette[abs(index) % tilePalette.count], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 카드

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardStyle(padding: padding)) }
}

// MARK: - 움직임

/// 누르면 살짝 작아지는 버튼
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 화면에 나타날 때 아래에서 떠오르는 효과
struct AppearModifier: ViewModifier {
    let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) { shown = true }
            }
    }
}

/// 불러오는 동안 빛이 지나가는 효과
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.6)
                        .offset(x: phase * g.size.width * 1.6)
                }
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

extension View {
    func appear(delay: Double = 0) -> some View { modifier(AppearModifier(delay: delay)) }
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

/// 자리표시용 회색 블록
struct SkeletonBlock: View {
    var height: CGFloat
    var radius: CGFloat = Theme.cardRadius
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(height: height)
            .shimmering()
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - 공용 구성요소

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.app(20, .bold, relativeTo: .title3))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IATABadge: View {
    let code: String
    var onDark = false
    var body: some View {
        Text(code)
            .font(.app(12, .bold, relativeTo: .caption))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(onDark ? Color.white.opacity(0.18) : Theme.accentSoft,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .foregroundStyle(onDark ? Color.white : Theme.accent)
    }
}

struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var color: Color = Theme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.app(12, .semibold, relativeTo: .caption))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }
}

/// 로고를 불러오지 못했을 때 쓰는 원형 코드 배지
struct AirlineBadge: View {
    let code: String
    var size: CGFloat = 38

    private static let palette: [Color] = [
        Color(hex: 0x1A6DFF), Color(hex: 0x6C3CF0), Color(hex: 0x0E9F6E), Color(hex: 0xF0544F),
        Color(hex: 0x0B8BB3), Color(hex: 0xD63B7A), Color(hex: 0xE69500), Color(hex: 0x4B5563),
    ]

    private var color: Color {
        let sum = code.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.palette[sum % Self.palette.count]
    }

    var body: some View {
        Group {
            if code.isEmpty {
                Image(systemName: "airplane").font(.system(size: size * 0.38, weight: .semibold))
            } else {
                Text(code).font(.app(size * 0.34, .bold))
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// 항공사 로고 (가격 데이터 제공처의 로고 이미지, 실패하면 코드 배지)
struct AirlineLogo: View {
    let code: String
    var size: CGFloat = 38

    private var url: URL? {
        guard !code.isEmpty else { return nil }
        let px = Int(size * 3)
        return URL(string: "https://pics.avs.io/\(px)/\(px)/\(code).png")
    }

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
                    .frame(width: size, height: size)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(Color.black.opacity(0.06)))
                    .transition(.opacity)
            } else {
                AirlineBadge(code: code, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 포맷

private func formatter(_ format: String) -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = format
    return f
}

private let wonFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "ko_KR")
    return f
}()
private let monthFormatter = formatter("yyyy년 M월")
private let monthShortFormatter = formatter("M월")
private let dayFormatter = formatter("M월 d일 (E)")
private let shortDayFormatter = formatter("M/d")
private let weekdayFormatter = formatter("E")

extension Int {
    /// 58000 -> "₩58,000"
    var won: String { "₩" + (wonFormatter.string(from: NSNumber(value: self)) ?? "\(self)") }
    /// 58000 -> "5.8만"
    var shortWon: String {
        self >= 10_000 ? String(format: "%.1f만", Double(self) / 10_000) : "\(self)"
    }
}

extension Date {
    var monthTitle: String { monthFormatter.string(from: self) }
    var monthShort: String { monthShortFormatter.string(from: self) }
    var dayTitle: String { dayFormatter.string(from: self) }
    var shortDay: String { shortDayFormatter.string(from: self) }
    var weekdayShort: String { weekdayFormatter.string(from: self) }
}
