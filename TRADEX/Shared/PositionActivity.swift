import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// 잠금화면·다이내믹 아일랜드에 띄우는 선물 포지션 (앱과 위젯 확장이 같이 쓴다)
struct PositionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var price: Double
        var pnl: Double
        var roe: Double
    }
    var positionID: String
    var market: String
    var symbol: String
    var koreanName: String
    var isLong: Bool
    var leverage: Int
    var entryPrice: Double
    var liquidationPrice: Double
}
#endif

/// 위젯·잠금화면용 간단한 숫자 표기 (앱의 Fmt와 같은 규칙)
enum SharedFmt {
    static func price(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = v >= 100 ? 0 : (v >= 1 ? 2 : 4)
        return f.string(from: NSNumber(value: v)) ?? "-"
    }
    static func rate(_ r: Double) -> String { String(format: "%@%.2f%%", r > 0 ? "+" : "", r * 100) }
    static func signedKRW(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return (v > 0 ? "+" : "") + (f.string(from: NSNumber(value: v.rounded())) ?? "0") + "원"
    }
}
