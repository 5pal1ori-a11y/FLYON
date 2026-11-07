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
    static let accent = Color(hex: 0x0770E3)
    static let splashBackground = Color(hex: 0x0B0B0D)
    static let cheap = Color(hex: 0x1F9D55)
    static let expensive = Color(hex: 0xD64545)
    static let normal = Color(hex: 0x6B7280)

    static let screenBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    static let cardRadius: CGFloat = 20
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

// MARK: - Formatting

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
    /// 58000 -> "5.8만" (차트 축 라벨용)
    var shortWon: String {
        self >= 10_000 ? String(format: "%.1f만", Double(self) / 10_000) : "\(self)"
    }
}

extension Date {
    var monthTitle: String { monthFormatter.string(from: self) }
    var dayTitle: String { dayFormatter.string(from: self) }
}
