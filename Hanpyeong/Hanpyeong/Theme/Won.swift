import Foundation

/// 한국식 금액 표기 — "1억 2,340만원", "3.4만", "-8,200원"
enum Won {
    private static let units: [(value: Double, name: String)] = [
        (1e16, "경"), (1e12, "조"), (1e8, "억"), (1e4, "만")
    ]

    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    private static func group(_ v: Double) -> String {
        grouping.string(from: NSNumber(value: v.rounded(.down))) ?? String(format: "%.0f", v)
    }

    /// 큰 단위 두 개까지 — 장부·가격 표기용
    static func full(_ amount: Double, suffix: Bool = true) -> String {
        let sign = amount < 0 ? "-" : ""
        let a = abs(amount)
        let tail = suffix ? "원" : ""
        guard a >= 1e4 else { return sign + group(a) + tail }

        for (i, unit) in units.enumerated() where a >= unit.value {
            let major = (a / unit.value).rounded(.down)
            var text = sign + group(major) + unit.name
            if i + 1 < units.count {
                let next = units[i + 1]
                let rest = ((a - major * unit.value) / next.value).rounded(.down)
                if rest > 0 { text += " " + group(rest) + next.name }
            }
            return text + tail
        }
        return sign + group(a) + tail
    }

    /// 짧게 — "3.4만", "12억", "1.2조"
    static func short(_ amount: Double) -> String {
        let sign = amount < 0 ? "-" : ""
        let a = abs(amount)
        guard a >= 1e4 else { return sign + group(a) }
        for unit in units where a >= unit.value {
            let v = a / unit.value
            let text: String
            if v >= 1000 {
                text = group(v)
            } else if v >= 100 {
                text = String(format: "%.0f", v.rounded(.down))
            } else {
                let d = (v * 10).rounded(.down) / 10
                text = d == d.rounded(.down) ? String(format: "%.0f", d) : String(format: "%.1f", d)
            }
            return sign + text + unit.name
        }
        return sign + group(a)
    }

    /// 부호 포함 — "+3.4만", "-1,200"
    static func signed(_ amount: Double) -> String {
        (amount >= 0 ? "+" : "") + short(amount)
    }

    static func percent(_ ratio: Double, signed: Bool = true) -> String {
        let p = ratio * 100
        let s = String(format: "%.1f%%", abs(p))
        guard signed else { return s }
        if p > 0.05 { return "+" + s }
        if p < -0.05 { return "-" + s }
        return s
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds)
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)시간 \(m)분" : "\(h)시간" }
        if m > 0 { return "\(m)분" }
        return "\(s)초"
    }
}
