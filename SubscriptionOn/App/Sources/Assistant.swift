import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 앱이 직접 계산한 숫자들 (AI는 이걸 말로 풀어 쓰기만 해요)
struct Facts {
    var monthTotal: Int
    var yearTotal: Int
    var count: Int
    var top: [(String, Int)]
    var byCategory: [(String, Int)]
    var upcoming: [(String, Int, Int)]   // 이름, 금액, D-day
    var unused: [String]
    var trials: [(String, Int)]
    var prevTotal: Int?
    var saving: Int

    @MainActor init(_ s: Store) {
        monthTotal = Int(s.monthlyTotal.rounded()); yearTotal = Int(s.yearlyTotal.rounded()); count = s.active.count
        top = s.active.sorted { $0.monthly > $1.monthly }.prefix(5).map { ($0.name, Int($0.monthly.rounded())) }
        byCategory = s.byCategory().map { ($0.0.rawValue, Int($0.1.rounded())) }
        upcoming = s.upcoming.prefix(6).map { ($0.name, $0.price, $0.dDay) }
        unused = s.active.filter { $0.usage != nil && $0.usesThisMonth == 0 }.map(\.name)
        trials = s.active.compactMap { sub in sub.trialDaysLeft.map { (sub.name, $0) } }
        prevTotal = s.prevMonthTotal
        saving = s.potentialSave
    }

    /// AI에게 줄 근거 데이터
    var text: String {
        var l = ["이번 달 구독료 합계: \(monthTotal.won)", "1년 환산: \(yearTotal.won)", "이용 중인 구독 수: \(count)개"]
        if let p = prevTotal { l.append("지난달 합계: \(p.won)") }
        l.append("비싼 순: " + top.map { "\($0.0) \($0.1.won)" }.joined(separator: ", "))
        l.append("종류별(월): " + byCategory.map { "\($0.0) \($0.1.won)" }.joined(separator: ", "))
        l.append("곧 결제: " + upcoming.map { "\($0.0) \($0.1.won) (\($0.2 <= 0 ? "오늘" : "\($0.2)일 뒤"))" }.joined(separator: ", "))
        if !unused.isEmpty { l.append("이번 달 한 번도 안 쓴 구독: " + unused.joined(separator: ", ")) }
        if !trials.isEmpty { l.append("무료 체험 중: " + trials.map { "\($0.0) \($0.1)일 남음" }.joined(separator: ", ")) }
        if saving > 0 { l.append("아낄 수 있는 금액(추정): 월 \(saving.won)") }
        return l.joined(separator: "\n")
    }
}

@MainActor
enum Assistant {
    static let suggestions = ["제일 비싼 구독이 뭐야?", "이번 주에 결제되는 거 알려줘", "안 쓰는 구독 있어?", "한 달에 총 얼마나 써?", "어떻게 하면 아낄 수 있어?"]

    static func answer(_ q: String, store: Store) async -> String {
        let f = Facts(store)
        if f.count == 0 { return "아직 등록된 구독이 없어요. + 버튼으로 먼저 추가해볼까요?" }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SmartParse.aiAvailable {
            let s = LanguageModelSession(instructions: "너는 구독 관리 앱 '구독온'의 도우미야. 아래 [데이터]에 있는 내용만 근거로, 친근하고 짧게(3문장 이내) 한국어로 답해. 금액은 데이터의 숫자를 그대로 써. 데이터에 없으면 모른다고 말해. 해지나 결제를 대신 해줄 수 있다고 하지 마.")
            if let r = try? await s.respond(to: "[데이터]\n\(f.text)\n\n[질문]\n\(q)") { return r.content }
        }
        #endif
        return rule(q, f)
    }

    /// Apple Intelligence가 없는 기기용 (키워드로 답해요)
    static func rule(_ q: String, _ f: Facts) -> String {
        func has(_ w: String...) -> Bool { w.contains { q.contains($0) } }
        if has("비싼", "제일", "가장", "TOP", "top") {
            return "가장 비싼 건 \(f.top.first?.0 ?? "-")이에요. 한 달 \((f.top.first?.1 ?? 0).won)이고, 다음은 " + f.top.dropFirst().prefix(2).map { "\($0.0) \($0.1.won)" }.joined(separator: ", ") + "이에요."
        }
        if has("안 쓰", "안쓰", "미사용", "해지", "필요 없") {
            return f.unused.isEmpty ? "이번 달 안 쓴 구독이 없어요. 쓴 날 홈에서 로고를 눌러 기록하면 더 정확해져요." : "이번 달 한 번도 안 쓴 구독은 \(f.unused.joined(separator: ", "))이에요. 해지를 고민해볼 만해요."
        }
        if has("이번 주", "곧", "언제", "다음", "결제") {
            let u = f.upcoming.prefix(4).map { "\($0.0) \($0.1.won) (\($0.2 <= 0 ? "오늘" : "\($0.2)일 뒤"))" }
            return u.isEmpty ? "곧 결제될 구독이 없어요." : "곧 결제되는 건 " + u.joined(separator: ", ") + "이에요."
        }
        if has("종류", "카테고리", "어디에") {
            return "종류별로는 " + f.byCategory.prefix(3).map { "\($0.0) \($0.1.won)" }.joined(separator: ", ") + " 순으로 많이 써요."
        }
        if has("아낄", "절약", "줄이") {
            return f.saving > 0 ? "중복이나 안 쓰는 구독을 정리하면 한 달 \(f.saving.won) 정도 아낄 수 있어요." : "지금은 크게 줄일 곳이 안 보여요. 잘 관리하고 계세요!"
        }
        if has("1년", "연간", "일 년") { return "1년으로 환산하면 \(f.yearTotal.won)이에요." }
        if has("얼마", "총", "합계", "한 달") {
            var s = "이번 달 구독료는 총 \(f.monthTotal.won)이에요."
            if let p = f.prevTotal { let d = f.monthTotal - p; s += d == 0 ? " 지난달과 같아요." : d > 0 ? " 지난달보다 \(d.won) 늘었어요." : " 지난달보다 \((-d).won) 줄었어요." }
            return s
        }
        return "구독은 \(f.count)개, 한 달 \(f.monthTotal.won)이에요. \"제일 비싼 구독이 뭐야?\" 처럼 물어봐 주세요."
    }

    // MARK: 월간 리포트 글
    static func reportText(facts f: Facts, month: Int, added: [String], removed: [String]) async -> String {
        var change = ""
        if !added.isEmpty { change += "새로 생긴 구독: \(added.joined(separator: ", "))\n" }
        if !removed.isEmpty { change += "사라진 구독: \(removed.joined(separator: ", "))\n" }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SmartParse.aiAvailable {
            let s = LanguageModelSession(instructions: "너는 구독 관리 앱의 월간 리포트 작성자야. [데이터]만 근거로 4문장 이내로 친근하게 한국어로 요약해. 숫자는 그대로 쓰고, 마지막엔 한 가지 실천 팁을 줘. 없는 사실은 만들지 마.")
            if let r = try? await s.respond(to: "[데이터]\n\(month)월\n\(f.text)\n\(change)") { return r.content }
        }
        #endif
        var t = "\(month)월 구독료는 총 \(f.monthTotal.won)이에요."
        if let p = f.prevTotal { let d = f.monthTotal - p; t += d == 0 ? " 지난달과 같아요." : d > 0 ? " 지난달보다 \(d.won) 늘었어요." : " 지난달보다 \((-d).won) 줄었어요." }
        if let top = f.top.first { t += " 가장 큰 지출은 \(top.0)(\(top.1.won))이에요." }
        if !added.isEmpty { t += " \(added.joined(separator: ", ")) 구독이 새로 생겼어요." }
        if !removed.isEmpty { t += " \(removed.joined(separator: ", ")) 구독은 정리했어요." }
        t += f.unused.isEmpty ? " 이번 달도 알뜰하게 쓰고 계세요." : " \(f.unused.joined(separator: ", "))은 안 쓰고 있어서 해지를 고민해볼 만해요."
        return t
    }
}
