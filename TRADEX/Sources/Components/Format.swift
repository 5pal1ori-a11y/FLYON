import Foundation

enum Fmt {
    private static let grouped0: NumberFormatter = make(0, 0)
    private static let grouped2: NumberFormatter = make(0, 2)
    private static let grouped4: NumberFormatter = make(0, 4)
    private static let qtyFmt: NumberFormatter = make(0, 8)

    private static func make(_ minF: Int, _ maxF: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = minF
        f.maximumFractionDigits = maxF
        f.locale = Locale(identifier: "ko_KR")
        return f
    }

    /// 코인 가격: 가격대에 따라 소수점 자릿수 조정 (업비트 원화마켓 표기와 비슷하게)
    static func price(_ v: Double) -> String {
        let f = v >= 100 ? grouped0 : (v >= 1 ? grouped2 : grouped4)
        return f.string(from: NSNumber(value: v)) ?? "-"
    }

    /// 원화 금액 (정수)
    static func krw(_ v: Double) -> String {
        (grouped0.string(from: NSNumber(value: v.rounded(.down))) ?? "0") + "원"
    }

    static func number(_ v: Double) -> String { grouped0.string(from: NSNumber(value: v)) ?? "0" }

    static func signedKRW(_ v: Double) -> String {
        (v > 0 ? "+" : "") + (grouped0.string(from: NSNumber(value: v.rounded())) ?? "0")
    }

    static func signedPrice(_ v: Double) -> String {
        (v > 0 ? "+" : "") + price(v)
    }

    /// 0.0123 -> "+1.23%"
    static func rate(_ r: Double) -> String {
        String(format: "%@%.2f%%", r > 0 ? "+" : "", r * 100)
    }

    static func qty(_ v: Double) -> String { qtyFmt.string(from: NSNumber(value: v)) ?? "0" }

    /// 거래소 목록식 거래대금 (백만 원 단위)
    static func millions(_ v: Double) -> String {
        v >= 1_000_000 ? "\(number((v / 1_000_000).rounded(.down)))백만" : number(v)
    }

    /// 거래대금: 1조/억/백만 단위
    static func compactKRW(_ v: Double) -> String {
        if v >= 1_000_000_000_000 { return String(format: "%.1f조", v / 1_000_000_000_000) }
        if v >= 100_000_000 { return "\(number(v / 100_000_000))억" }
        if v >= 1_000_000 { return "\(number(v / 1_000_000))백만" }
        return number(v)
    }
}
