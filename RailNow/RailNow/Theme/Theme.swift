import SwiftUI
import UIKit

// 색과 글꼴. 로고의 파랑을 강조색으로 쓰고, 그 밖의 채도 높은 색은 노선색과 열차 종류색뿐이다.

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
    // 밝은 화면은 흰 바탕에 파랑, 어두운 화면은 검정 바탕. 기기 설정을 따른다.
    static let background = Color(light: "#F5F6F8", dark: "#0A0B0E")
    static let surface = Color(light: "#FFFFFF", dark: "#15171C")
    static let raised = Color(light: "#E9ECF1", dark: "#20232B")
    static let hairline = Color(light: "#E1E5EB", dark: "#272B34")
    static let ink = Color(light: "#111318", dark: "#F4F5F7")
    static let sub = Color(light: "#6B7079", dark: "#8D929C")
    static let faint = Color(light: "#A7ACB5", dark: "#555A66")
    static let accent = Color(light: "#1A6DFF", dark: "#3D8BFF")
    static let star = Color(light: "#F5A623", dark: "#FFC043")
    static let brand = [Color(hex: "#0A3BE0"), Color(hex: "#0A6CF5"), Color(hex: "#2FA8FF")]
    static let live = Color(light: "#12A150", dark: "#2EDB8A")
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
