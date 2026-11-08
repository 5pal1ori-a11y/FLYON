import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

struct Candidate: Identifiable {
    let id = UUID()
    var name: String
    var price: Int
    var date: Date?
    var count: Int
    var on = true
    var known: Bool
}

/// 영수증·카드 명세서 글에서 구독 후보 찾기 (전부 기기 안에서 처리)
enum Statement {
    static func amount(in line: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"(?<![0-9,])([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{4,7})(?![0-9,])"#) else { return nil }
        let ms = re.matches(in: line, range: NSRange(line.startIndex..., in: line))
        for m in ms.reversed() {
            if let r = Range(m.range(at: 1), in: line), let v = Int(line[r].replacingOccurrences(of: ",", with: "")), (500...2_000_000).contains(v) { return v }
        }
        return nil
    }
    static func merchant(_ line: String) -> String {
        var t = line.replacingOccurrences(of: #"[0-9][0-9,.\-/:]*"#, with: " ", options: .regularExpression)
        for w in ["일시불", "할부", "승인", "원", "₩", "KRW", "결제", "해외", "국내"] { t = t.replacingOccurrences(of: w, with: " ") }
        return t.split(separator: " ").joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    static func date(in line: String) -> Date? {
        if let re = try? NSRegularExpression(pattern: #"(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})"#),
           let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let a = Range(m.range(at: 1), in: line), let b = Range(m.range(at: 2), in: line), let c = Range(m.range(at: 3), in: line) {
            return Calendar.current.date(from: DateComponents(year: Int(line[a]), month: Int(line[b]), day: Int(line[c])))
        }
        return nil
    }

    static func extract(_ text: String) -> [Candidate] {
        var known: [String: Candidate] = [:]
        var unknown: [String: Candidate] = [:]
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.count >= 3, let amt = amount(in: line) else { continue }
            if let s = Catalog.find(line) {
                var c = known[s.name] ?? Candidate(name: s.name, price: amt, date: date(in: line), count: 0, known: true)
                c.count += 1; c.price = amt; c.date = date(in: line) ?? c.date
                known[s.name] = c
            } else {
                let m = merchant(line)
                guard m.count >= 2 else { continue }
                let k = m.lowercased() + "|\(amt)"
                var c = unknown[k] ?? Candidate(name: m, price: amt, date: date(in: line), count: 0, known: false)
                c.count += 1
                unknown[k] = c
            }
        }
        // 모르는 가맹점은 같은 금액이 2번 이상 반복될 때만 구독 후보
        let rec = unknown.values.filter { $0.count >= 2 }
        var out = Array(known.values) + rec
        if out.isEmpty {
            let p = Scanner.parse(text)
            if !p.name.isEmpty && p.price > 0 { out = [Candidate(name: p.name, price: p.price, date: p.date, count: 1, known: true)] }
        }
        return out.sorted { $0.known && !$1.known }
    }
}

struct BulkScanView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var picks: [PhotosPickerItem] = []
    @State private var cands: [Candidate] = []
    @State private var busy = false
    @State private var showPDF = false
    @State private var msg = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if cands.isEmpty {
                        Text("한 번에\n찾아드려요").font(.system(size: 30, weight: .heavy)).padding(.top, 8)
                        Text("결제 캡처 여러 장이나 카드 명세서 PDF를 올려주세요. 폰 안에서만 읽고 서버로 보내지 않아요.").font(.system(size: 14)).foregroundStyle(T.sub)
                        PhotosPicker(selection: $picks, maxSelectionCount: 10, matching: .images) { big("photo.on.rectangle", "캡처 여러 장 고르기") }
                        Button { showPDF = true } label: { big("doc.text", "카드 명세서 PDF 고르기") }
                        if busy { HStack { ProgressView(); Text("읽는 중이에요").foregroundStyle(T.sub) }.frame(maxWidth: .infinity).padding(.top, 10) }
                        if !msg.isEmpty { Text(msg).font(.system(size: 14)).foregroundStyle(T.sub) }
                    } else {
                        Text("\(cands.count)개 찾았어요").font(.system(size: 26, weight: .heavy)).padding(.top, 8)
                        Text("맞는 것만 남기고 추가하세요").font(.system(size: 14)).foregroundStyle(T.sub)
                        Card {
                            VStack(spacing: 0) {
                                ForEach($cands) { $c in
                                    HStack(spacing: 14) {
                                        LogoView(name: c.name, category: Catalog.classify(c.name), size: 44)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(c.name).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                                            Text("\(c.price.won)" + (c.count > 1 ? " · \(c.count)번 반복" : "") + (c.known ? "" : " · 확인 필요")).font(.system(size: 13)).foregroundStyle(T.sub)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $c.on).labelsHidden().tint(T.blue)
                                    }.padding(.vertical, 10)
                                }
                            }
                        }
                        let n = cands.filter(\.on).count
                        BigButton(title: "\(n)개 추가하기", action: addAll).opacity(n > 0 ? 1 : 0.4).disabled(n == 0)
                    }
                }.padding(20)
            }
            .background(T.bg)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .fileImporter(isPresented: $showPDF, allowedContentTypes: [.pdf]) { res in
                if case .success(let url) = res { Task { await readPDF(url) } }
            }
            .onChange(of: picks) { _, items in
                guard !items.isEmpty else { return }
                Task { await readPhotos(items) }
            }
        }
    }

    func big(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(T.blue)
            .frame(maxWidth: .infinity).frame(height: 60).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func readPhotos(_ items: [PhotosPickerItem]) async {
        busy = true; msg = ""
        var all: [Candidate] = []
        for it in items {
            if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                all += Statement.extract(await Scanner.recognize(img))
            }
        }
        finish(all)
    }

    func readPDF(_ url: URL) async {
        busy = true; msg = ""
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { busy = false; msg = "PDF를 못 읽었어요"; return }
        var text = doc.string ?? ""
        if text.count < 40 { // 스캔본이면 글자 인식으로
            text = ""
            for i in 0..<min(doc.pageCount, 8) {
                if let p = doc.page(at: i) { text += await Scanner.recognize(p.thumbnail(of: CGSize(width: 1400, height: 2000), for: .mediaBox)) + "\n" }
            }
        }
        finish(Statement.extract(text))
    }

    func finish(_ all: [Candidate]) {
        // 같은 서비스는 합치기
        var merged: [String: Candidate] = [:]
        for c in all {
            let k = c.name.lowercased()
            if var m = merged[k] { m.count += c.count; merged[k] = m } else { merged[k] = c }
        }
        cands = merged.values.sorted { $0.known && !$1.known }
        busy = false
        if cands.isEmpty { msg = "구독으로 보이는 결제를 못 찾았어요" }
    }

    func addAll() {
        let cal = Calendar.current
        for c in cands where c.on {
            var next = c.date ?? Date()
            while next <= Date() { next = Cycle.monthly.next(after: next) }
            if c.date == nil { next = cal.date(byAdding: .month, value: 1, to: Date())! }
            store.add(Subscription(name: c.name, price: c.price, category: Catalog.classify(c.name), cycle: .monthly, nextDate: next))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
