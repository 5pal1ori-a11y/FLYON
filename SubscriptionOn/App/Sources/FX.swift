import Foundation

/// 환율: 공개 환율 정보만 받아와요 (내 구독 정보는 보내지 않아요)
enum FX {
    static let currencies = ["KRW", "USD", "JPY", "EUR", "GBP", "CNY"]
    static let symbol = ["KRW": "원", "USD": "$", "JPY": "¥", "EUR": "€", "GBP": "£", "CNY": "¥"]
    private static let key = "fxRatesKRW"
    private static let fallback: [String: Double] = ["USD": 1450, "JPY": 9.5, "EUR": 1600, "GBP": 1870, "CNY": 200]

    /// 1단위 외화 = 몇 원
    static var rates: [String: Double] {
        if let d = UserDefaults.standard.data(forKey: key), let r = try? JSONDecoder().decode([String: Double].self, from: d), !r.isEmpty { return r }
        return fallback
    }

    static func refresh() async {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/KRW") else { return }
        struct R: Decodable { let rates: [String: Double] }
        guard let (data, _) = try? await URLSession.shared.data(from: url), let r = try? JSONDecoder().decode(R.self, from: data) else { return }
        var out: [String: Double] = [:]
        for c in currencies where c != "KRW" { if let v = r.rates[c], v > 0 { out[c] = 1 / v } }
        if let enc = try? JSONEncoder().encode(out), !out.isEmpty { UserDefaults.standard.set(enc, forKey: key) }
    }

    static func toKRW(_ amount: Double, _ cur: String?) -> Int {
        guard let cur, cur != "KRW" else { return Int(amount.rounded()) }
        return Int((amount * (rates[cur] ?? 0)).rounded())
    }
    static func label(_ amount: Double, _ cur: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = cur == "JPY" ? 0 : 2
        return (symbol[cur] ?? cur) + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }
}
