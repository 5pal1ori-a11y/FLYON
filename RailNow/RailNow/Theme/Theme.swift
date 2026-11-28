import SwiftUI
import UIKit

// 색과 글꼴. 채도 높은 색은 노선색과 열차 종류색에만 쓰고, 나머지는 잉크·종이 톤으로 둔다.

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }

    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// 배경색 위에 올릴 글자색. 밝은 노선색(9호선, 우이신설선 등)에서는 어두운 글자를 쓴다.
    static func onColor(hex: String) -> Color {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.62 ? Color(hex: "#14161A") : .white
    }
}

enum Palette {
    static let background = Color(light: "#F4F3EF", dark: "#0D0F12")
    static let surface = Color(light: "#FFFFFF", dark: "#16191E")
    static let raised = Color(light: "#ECEAE4", dark: "#1F232A")
    static let hairline = Color(light: "#E2E0D9", dark: "#272B33")
    static let ink = Color(light: "#14161A", dark: "#F1F0EC")
    static let sub = Color(light: "#6A6E75", dark: "#8E939C")
    static let faint = Color(light: "#A3A6AB", dark: "#5B606A")
    static let accent = Color(light: "#E8522A", dark: "#FF6B42")
    static let live = Color(light: "#17914F", dark: "#35C27A")
}

enum PreWeight: String {
    case regular = "Pretendard-Regular"
    case medium = "Pretendard-Medium"
    case semibold = "Pretendard-SemiBold"
    case bold = "Pretendard-Bold"
}

extension Font {
    static func pre(_ size: CGFloat, _ weight: PreWeight = .regular) -> Font {
        .custom(weight.rawValue, size: size)
    }
}

/// 한국 시간 기준 날짜 계산.
enum KST {
    static let zone = TimeZone(identifier: "Asia/Seoul") ?? .current

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }()

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func secondsOfDay(_ date: Date) -> Double {
        date.timeIntervalSince(startOfDay(date))
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = zone
        f.dateFormat = format
        return f
    }

    private static let hmFormatter = formatter("HH:mm")
    private static let hmsFormatter = formatter("HH:mm:ss")
    private static let ymdFormatter = formatter("yyyyMMdd")
    private static let dayFormatter = formatter("M월 d일 EEEE")
    private static let stampFormatter = formatter("yyyyMMddHHmmss")
    private static let dashedFormatter = formatter("yyyy-MM-dd HH:mm:ss")

    static func hm(_ date: Date) -> String { hmFormatter.string(from: date) }
    static func hms(_ date: Date) -> String { hmsFormatter.string(from: date) }
    static func ymd(_ date: Date) -> String { ymdFormatter.string(from: date) }
    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func parseStamp(_ text: String) -> Date? { stampFormatter.date(from: text) }
    static func parseDashed(_ text: String) -> Date? { dashedFormatter.date(from: text) }
}

/// 남은 시간을 "3분", "1시간 12분"처럼 쓴다.
func minutesText(_ interval: TimeInterval) -> String {
    let m = max(0, Int((interval / 60).rounded()))
    if m < 1 { return "곧" }
    if m < 60 { return "\(m)분" }
    return m % 60 == 0 ? "\(m / 60)시간" : "\(m / 60)시간 \(m % 60)분"
}
