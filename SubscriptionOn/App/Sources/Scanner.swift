import SwiftUI
import Vision

struct ParsedPayment { var name: String = ""; var price: Int = 0; var date: Date? = nil }

enum Scanner {
    /// 이미지 속 글자를 읽어요 (기기 안에서 처리, 서버로 보내지 않아요)
    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { r, _ in
                let t = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
                cont.resume(returning: t)
            }
            req.recognitionLanguages = ["ko-KR", "en-US"]
            req.recognitionLevel = .accurate
            DispatchQueue.global().async {
                do { try VNImageRequestHandler(cgImage: cg).perform([req]) } catch { cont.resume(returning: "") }
            }
        }
    }

    /// 영수증/문자/메일 글에서 서비스·금액·날짜 추출
    static func parse(_ text: String) -> ParsedPayment {
        var p = ParsedPayment()
        if let s = Catalog.find(text) { p.name = s.name }
        // 금액: "17,000원", "₩17,000", "KRW 17000"
        let pats = [#"([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,7})\s*원"#, #"[₩\\]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,7})"#, #"KRW\s*([0-9,]{3,9})"#]
        var best = 0
        for pat in pats {
            guard let re = try? NSRegularExpression(pattern: pat) else { continue }
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(m.range(at: 1), in: text), let v = Int(text[r].replacingOccurrences(of: ",", with: "")), v >= 100 { best = best == 0 ? v : best }
            }
            if best > 0 { break }
        }
        p.price = best
        // 날짜: 2025.12.14 / 2025-12-14 / 12월 14일
        if let re = try? NSRegularExpression(pattern: #"(20\d{2})[.\-/년\s]+(\d{1,2})[.\-/월\s]+(\d{1,2})"#),
           let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let a = Range(m.range(at: 1), in: text), let b = Range(m.range(at: 2), in: text), let c = Range(m.range(at: 3), in: text) {
            p.date = Calendar.current.date(from: DateComponents(year: Int(text[a]), month: Int(text[b]), day: Int(text[c])))
        } else if let re = try? NSRegularExpression(pattern: #"(\d{1,2})월\s*(\d{1,2})일"#),
                  let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let b = Range(m.range(at: 1), in: text), let c = Range(m.range(at: 2), in: text) {
            let y = Calendar.current.component(.year, from: Date())
            p.date = Calendar.current.date(from: DateComponents(year: y, month: Int(text[b]), day: Int(text[c])))
        }
        return p
    }
}
