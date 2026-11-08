import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct Draft { var name = ""; var price = 0; var cycle: Cycle = .monthly; var day: Int? = nil; var usedAI = false }

enum SmartParse {
    /// Apple Intelligence(기기 내 모델)를 쓸 수 있는지
    static var aiAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// "유튜브 프리미엄 매달 15일 14,900원" → 이름·금액·주기·결제일
    static func parse(_ text: String) async -> Draft {
        var d = local(text)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), aiAvailable, let a = await ai(text) {
            if !a.name.isEmpty { d.name = a.name }
            if a.price > 0 { d.price = a.price }
            if let day = a.day { d.day = day }
            d.cycle = a.cycle; d.usedAI = true
        }
        #endif
        if let s = Catalog.find(d.name) ?? Catalog.find(text) { d.name = s.name }
        return d
    }

    static func local(_ t: String) -> Draft {
        var d = Draft()
        d.price = Scanner.parse(t).price
        if t.contains("매주") || t.contains("주마다") || t.contains("주간") { d.cycle = .weekly }
        else if t.contains("매년") || t.contains("연간") || t.contains("연 결제") || t.contains("1년") { d.cycle = .yearly }
        if let re = try? NSRegularExpression(pattern: #"(\d{1,2})\s*일"#),
           let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)), let r = Range(m.range(at: 1), in: t),
           let v = Int(t[r]), (1...31).contains(v) { d.day = v }
        if let s = Catalog.find(t) { d.name = s.name } else {
            var n = t.replacingOccurrences(of: #"[0-9,]+\s*(원|일)?"#, with: " ", options: .regularExpression)
            for w in ["매달", "매월", "매주", "매년", "마다", "결제", "구독", "정기", "연간", "월간", "에"] { n = n.replacingOccurrences(of: w, with: " ") }
            d.name = n.split(separator: " ").joined(separator: " ")
        }
        return d
    }

    static func nextDate(day: Int?, cycle: Cycle) -> Date {
        guard let day, cycle != .weekly else { return Calendar.current.date(byAdding: .day, value: 1, to: Date())! }
        let c = Calendar.current
        var comps = c.dateComponents([.year, .month], from: Date()); comps.day = day
        var d = c.date(from: comps) ?? Date()
        if d < c.startOfDay(for: Date()) { d = c.date(byAdding: .month, value: 1, to: d)! }
        return d
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct AISub {
        @Guide(description: "구독 서비스 이름. 예: 넷플릭스, 유튜브 프리미엄, ChatGPT")
        var name: String
        @Guide(description: "결제 금액(원, 숫자만). 말하지 않았으면 0")
        var price: Int
        @Guide(description: "결제 주기. 매주, 매월, 매년 중 하나. 말하지 않았으면 매월")
        var cycle: String
        @Guide(description: "결제되는 날짜(일). 1~31. 말하지 않았으면 0")
        var day: Int
    }

    @available(iOS 26.0, *)
    static func ai(_ text: String) async -> Draft? {
        let session = LanguageModelSession(instructions: "사용자가 말한 구독 정보를 구조화해. 말하지 않은 내용은 추측하지 마.")
        guard let r = try? await session.respond(to: text, generating: AISub.self) else { return nil }
        let a = r.content
        var d = Draft()
        d.name = a.name.trimmingCharacters(in: .whitespaces)
        d.price = max(0, a.price)
        d.cycle = a.cycle.contains("주") ? .weekly : a.cycle.contains("년") ? .yearly : .monthly
        d.day = (1...31).contains(a.day) ? a.day : nil
        return d
    }
    #endif
}
