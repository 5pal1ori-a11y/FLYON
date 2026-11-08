import SwiftUI

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

enum Theme {
    static let navy = Color(hex: 0x05203C)
    static let navyLight = Color(hex: 0x0B3D7A)
    static let accent = Color(hex: 0x0062E3)
    static let accentSoft = Color(hex: 0x0062E3, opacity: 0.12)

    static let cheap = Color(hex: 0x0E8A5F)
    static let mid = Color(hex: 0xE08A00)
    static let expensive = Color(hex: 0xE5484D)
    static let normal = Color(hex: 0x6B7280)

    static let splashBackground = Color(hex: 0x0B0B0D)
    static let screenBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    static let cardRadius: CGFloat = 20

    static let headerGradient = LinearGradient(
        colors: [navy, navyLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 노선 타일용 그라디언트
    static let tilePalette: [[Color]] = [
        [Color(hex: 0x0062E3), Color(hex: 0x4DA3FF)],
        [Color(hex: 0x6D3AE8), Color(hex: 0xA98BFF)],
        [Color(hex: 0x0E8A5F), Color(hex: 0x3DD9A0)],
        [Color(hex: 0xE5484D), Color(hex: 0xFF9A5C)],
        [Color(hex: 0x0A8FB0), Color(hex: 0x6FE0F5)],
        [Color(hex: 0xD6336C), Color(hex: 0xFFA8C5)],
    ]

    static func tileGradient(_ index: Int) -> LinearGradient {
        let colors = tilePalette[index % tilePalette.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 공용 컴포넌트

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }
}

struct IATABadge: View {
    let code: String
    var onDark = false
    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(onDark ? Color.white.opacity(0.18) : Theme.accentSoft,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(onDark ? Color.white : Theme.accent)
    }
}

/// 항공사 로고 대신 코드로 만든 원형 배지 (항공사 상표를 쓰지 않는다)
struct AirlineBadge: View {
    let code: String
    var size: CGFloat = 38

    private static let palette: [Color] = [
        Color(hex: 0x0062E3), Color(hex: 0x6D3AE8), Color(hex: 0x0E8A5F), Color(hex: 0xE5484D),
        Color(hex: 0x0A8FB0), Color(hex: 0xD6336C), Color(hex: 0xE08A00), Color(hex: 0x4B5563),
    ]

    private var color: Color {
        let sum = code.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.palette[sum % Self.palette.count]
    }

    var body: some View {
        Text(code)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: Circle())
    }
}

struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var color: Color = Theme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            if let subtitle {
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// 인기 노선 타일
struct RouteTile: View {
    let origin: Airport
    let destination: Airport
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(origin.code)
                Image(systemName: "airplane").font(.caption2)
                Text(destination.code)
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 12)

            Text(destination.city)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(origin.city)에서")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Theme.tileGradient(index), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "airplane")
                .font(.system(size: 54, weight: .bold))
                .rotationEffect(.degrees(-20))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 8, y: -4)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - 포맷

private let wonFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "ko_KR")
    return f
}()

private let monthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "yyyy년 M월"
    return f
}()

private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "M월 d일 (E)"
    return f
}()

extension Int {
    /// 58000 -> "₩58,000"
    var won: String { "₩" + (wonFormatter.string(from: NSNumber(value: self)) ?? "\(self)") }
    /// 58000 -> "5.8만" (차트 축·달력용)
    var shortWon: String {
        self >= 10_000 ? String(format: "%.1f만", Double(self) / 10_000) : "\(self)"
    }
}

extension Date {
    var monthTitle: String { monthFormatter.string(from: self) }
    var dayTitle: String { dayFormatter.string(from: self) }
}
