import SwiftUI
import PhotosUI

struct AddView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    var editing: Subscription? = nil

    enum Method { case manual, photo, text }
    enum Stage { case pick, form }
    @State private var stage: Stage = .pick
    @State private var query = ""
    @State private var showAllServices = false
    @State private var aiBusy = false
    @State private var saved = false
    @State private var showBulk = false
    @State private var currency = "KRW"
    @State private var method: Method = .manual
    @State private var name = ""
    @State private var priceText = ""
    @State private var category: Category = .etc
    @State private var catTouched = false
    @State private var cycle: Cycle = .monthly
    @State private var nextDate = Date()
    @State private var pay = ""
    @State private var people = 1
    @State private var memo = ""
    @State private var trial = false
    @State private var trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var pasted = ""
    @State private var picked: PhotosPickerItem?
    @State private var scanning = false
    @State private var scanMsg = ""

    static let popular = ["넷플릭스", "유튜브 프리미엄", "티빙", "쿠팡 와우", "디즈니 플러스", "스포티파이", "멜론", "ChatGPT", "Claude", "웨이브", "Gemini", "네이버 플러스 멤버십"]
    var popularServices: [Service] { Self.popular.compactMap { n in Catalog.all.first { $0.name == n } } }
    var q: String { query.trimmingCharacters(in: .whitespaces) }
    var looksLikeSentence: Bool { q.rangeOfCharacter(from: .decimalDigits) != nil || q.contains("매달") || q.contains("매주") || q.contains("매년") }

    var body: some View {
        NavigationStack {
            ScrollView {
                if stage == .pick && editing == nil {
                    pickView.transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    formView.transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stage)
            .background(T.bg)
            .navigationTitle(editing == nil ? "" : "수정").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if stage == .form && editing == nil { Button("뒤로") { stage = .pick } } else { Button("닫기") { dismiss() } }
                }
            }
            .onAppear { load() }
            .sheet(isPresented: $showBulk) { BulkScanView().environmentObject(store) }
            .overlay {
                if saved {
                    ZStack {
                        T.bg.opacity(0.92).ignoresSafeArea()
                        VStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 84)).foregroundStyle(T.green).symbolEffect(.bounce, value: saved)
                            Text(editing == nil ? "추가했어요" : "저장했어요").font(.system(size: 20, weight: .bold))
                        }.transition(.scale(scale: 0.5).combined(with: .opacity))
                    }.transition(.opacity)
                }
            }
        }
    }

    // MARK: 1단계 — 검색 하나만
    var results: [Service] { q.isEmpty ? [] : Catalog.search(q) }

    var pickView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("무엇을\n구독하세요?").font(.system(size: 30, weight: .heavy)).padding(.top, 8)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(T.faint)
                TextField("서비스 이름", text: $query).submitLabel(.done).onSubmit(submitQuery)
                if aiBusy { ProgressView() } else if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.faint) }
                }
            }
            .padding(16).background(T.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if q.isEmpty {
                Text("많이 쓰는 서비스").font(.system(size: 14, weight: .semibold)).foregroundStyle(T.sub)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 18) {
                    ForEach(Array(popularServices.enumerated()), id: \.element.name) { i, s in
                        Button { choose(s) } label: {
                            VStack(spacing: 8) {
                                LogoView(name: s.name, category: s.category, size: 58)
                                Text(s.name.replacingOccurrences(of: " 프리미엄", with: "").replacingOccurrences(of: " 플러스 멤버십", with: ""))
                                    .font(.system(size: 12)).foregroundStyle(T.text).lineLimit(1)
                            }
                        }.buttonStyle(PressCard()).stagger(i)
                    }
                }
                HStack(spacing: 10) {
                    quick("photo", "캡처로") { method = .photo; stage = .form }
                    quick("text.bubble", "문자·메일로") { method = .text; stage = .form }
                }
                quick("doc.text.magnifyingglass", "여러 장·카드 명세서로 한 번에") { showBulk = true }
                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showAllServices.toggle() } } label: {
                    HStack(spacing: 4) { Text(showAllServices ? "접기" : "전체 서비스 보기"); Image(systemName: showAllServices ? "chevron.up" : "chevron.down") }
                        .font(.system(size: 15)).foregroundStyle(T.sub).frame(maxWidth: .infinity)
                }
                if showAllServices {
                    ForEach(Category.allCases) { cat in
                        let items = Catalog.all.filter { $0.category == cat }
                        if !items.isEmpty {
                            Text(cat.rawValue).font(.system(size: 14, weight: .semibold)).foregroundStyle(T.sub)
                            Card { VStack(spacing: 0) { ForEach(items, id: \.name) { serviceRow($0) } } }
                        }
                    }
                }
            } else {
                Card {
                    VStack(spacing: 0) {
                        if looksLikeSentence {
                            Button(action: runAI) {
                                HStack(spacing: 14) {
                                    Image(systemName: "sparkles").foregroundStyle(T.blue).frame(width: 40, height: 40).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 12))
                                    Text("‘\(q)’ 이대로 읽기").font(.system(size: 16, weight: .semibold)).foregroundStyle(T.text).lineLimit(1)
                                    Spacer()
                                }.padding(.vertical, 10).contentShape(Rectangle())
                            }
                        }
                        ForEach(results.prefix(6), id: \.name) { serviceRow($0) }
                        Button { name = q; catTouched = false; autofill(q, force: true); stage = .form } label: {
                            HStack(spacing: 14) {
                                LogoView(name: q, category: Catalog.classify(q), size: 40)
                                Text("‘\(q)’ 그대로 추가").font(.system(size: 16)).foregroundStyle(T.text).lineLimit(1)
                                Spacer(); Image(systemName: "plus").foregroundStyle(T.blue)
                            }.padding(.vertical, 10).contentShape(Rectangle())
                        }
                    }
                }
            }
        }.padding(20)
    }

    func submitQuery() {
        if looksLikeSentence { runAI() }
        else if let s = results.first { choose(s) }
        else if !q.isEmpty { name = q; catTouched = false; autofill(q, force: true); stage = .form }
    }

    func serviceRow(_ s: Service) -> some View {
        Button { choose(s) } label: {
            HStack(spacing: 14) {
                LogoView(name: s.name, category: s.category, size: 40)
                Text(s.name).font(.system(size: 16)).foregroundStyle(T.text)
                Spacer()
                Image(systemName: "plus").foregroundStyle(T.blue)
            }.padding(.vertical, 10).contentShape(Rectangle())
        }
    }

    func quick(_ icon: String, _ title: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(T.blue)
                .frame(maxWidth: .infinity).frame(height: 46).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    func choose(_ s: Service) {
        name = s.name; catTouched = false; autofill(s.name, force: true); stage = .form
    }

    func runAI() {
        let t = q
        guard !t.isEmpty, !aiBusy else { return }
        aiBusy = true
        Task {
            let d = await SmartParse.parse(t)
            aiBusy = false
            name = d.name; catTouched = false; autofill(d.name, force: true)
            if d.price > 0 { priceText = String(d.price) }
            cycle = d.cycle; nextDate = SmartParse.nextDate(day: d.day, cycle: d.cycle)
            stage = .form
        }
    }

    // MARK: 2단계 — 꼭 필요한 것만
    var catChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(Category.allCases) { c in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { category = c; catTouched = true } } label: {
                    Text(c.rawValue).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(category == c ? .white : T.sub).frame(maxWidth: .infinity).frame(height: 40)
                        .background(category == c ? c.color : T.bg, in: Capsule()).scaleEffect(category == c ? 1.05 : 1)
                }
            }
        }
    }

    var formView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if editing == nil {
                if method == .photo { photoBox }
                if method == .text { textBox }
            }
            let svc = Catalog.find(name)
            Card {
                HStack(spacing: 16) {
                    LogoView(name: name, category: category, size: 64).id(svc?.name ?? "none").transition(.scale(scale: 0.6).combined(with: .opacity))
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("서비스 이름", text: $name).font(.system(size: 22, weight: .bold)).onChange(of: name) { _, v in autofill(v) }
                        Text(category.rawValue).font(.system(size: 13, weight: .semibold)).foregroundStyle(category.color)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(category.color.opacity(0.12), in: Capsule())
                    }
                }.animation(.spring(response: 0.4, dampingFraction: 0.7), value: svc?.name)
            }
            if editing == nil, let svc, let u = svc.joinURL {
                Button { openURL(u) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                        Text("아직 가입 전이면 \(svc.name) 가입하러 가기")
                        Spacer()
                    }.font(.system(size: 14, weight: .semibold)).foregroundStyle(T.blue)
                    .padding(14).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("한 번에 얼마예요?").font(.system(size: 14)).foregroundStyle(T.sub)
                        Spacer()
                        Menu {
                            ForEach(FX.currencies, id: \.self) { c in Button(c) { currency = c } }
                        } label: {
                            HStack(spacing: 4) { Text(currency); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)) }
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(T.blue)
                                .padding(.horizontal, 10).padding(.vertical, 5).background(T.blueSoft, in: Capsule())
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("0", text: $priceText).keyboardType(currency == "KRW" ? .numberPad : .decimalPad).font(.system(size: 34, weight: .heavy))
                        Text(currency == "KRW" ? "원" : currency).font(.system(size: 20, weight: .bold)).foregroundStyle(T.sub)
                    }
                    if currency != "KRW", let d = Double(priceText), d > 0 {
                        Text("≈ \(FX.toKRW(d, currency).won) (오늘 환율)").font(.system(size: 13)).foregroundStyle(T.sub)
                    }
                }
            }
            // 무료 체험
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $trial.animation(.spring(response: 0.4, dampingFraction: 0.8))) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("무료 체험 중이에요").font(.system(size: 16, weight: .semibold))
                            Text("끝나기 하루 전에 알려드려요").font(.system(size: 12)).foregroundStyle(T.sub)
                        }
                    }.tint(T.blue)
                    if trial {
                        DatePicker("체험 종료일", selection: $trialEnd, in: Date()..., displayedComponents: .date).environment(\.locale, Locale(identifier: "ko_KR"))
                            .onChange(of: trialEnd) { _, d in nextDate = d }
                        Text("이후 \(priceLabel) 결제돼요").font(.system(size: 13)).foregroundStyle(T.sub)
                    }
                }
            }
            .onChange(of: trial) { _, on in if on { nextDate = trialEnd } }
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $cycle) { ForEach(Cycle.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    DatePicker("다음 결제일", selection: $nextDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ko_KR"))
                }
            }
            if svc == nil {
                Card { VStack(alignment: .leading, spacing: 10) { Text("종류를 골라주세요").font(.system(size: 14)).foregroundStyle(T.sub); catChips } }
            }
            Card {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        if svc != nil { catChips.padding(.top, 8) }
                        TextField("결제수단 (예: 토스 체크카드)", text: $pay)
                        Divider()
                        Stepper("인원 \(people)명", value: $people, in: 1...10)
                        Divider()
                        TextField("메모", text: $memo)
                    }.padding(.top, 6)
                } label: { Text("더 적기").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.sub) }
                .tint(T.sub)
            }
            BigButton(title: editing == nil ? "추가하기" : "저장", action: save)
                .opacity(canSave ? 1 : 0.4).disabled(!canSave).padding(.top, 6)
        }.padding(20)
    }

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(priceText) ?? 0) > 0 }
    var priceLabel: String { currency == "KRW" ? (Int(priceText) ?? 0).won : FX.label(Double(priceText) ?? 0, currency) }

    func field<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(T.sub)
            Card { VStack(alignment: .leading, spacing: 12) { c() } }
        }
    }

    var photoBox: some View {
        Card {
            VStack(spacing: 10) {
                PhotosPicker(selection: $picked, matching: .images) {
                    Label("결제 캡처 고르기", systemImage: "photo").font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).frame(height: 48)
                        .background(T.blueSoft, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(T.blue)
                }
                if scanning { ProgressView() }
                if !scanMsg.isEmpty { Text(scanMsg).font(.system(size: 14)).foregroundStyle(T.sub) }
                Text("사진은 폰 안에서만 읽어요").font(.system(size: 12)).foregroundStyle(T.faint)
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            scanning = true; scanMsg = ""
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    let t = await Scanner.recognize(img); apply(Scanner.parse(t))
                } else { scanMsg = "사진을 못 읽었어요" }
                scanning = false
            }
        }
    }
    var textBox: some View {
        Card {
            VStack(spacing: 10) {
                TextEditor(text: $pasted).frame(height: 110).scrollContentBackground(.hidden).background(T.bg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) { if pasted.isEmpty { Text("결제 문자나 메일을 붙여넣어 주세요").foregroundStyle(T.faint).padding(8).allowsHitTesting(false) } }
                HStack {
                    Button("붙여넣기") { pasted = UIPasteboard.general.string ?? "" }.foregroundStyle(T.sub)
                    Spacer()
                    Button { readPasted() } label: {
                        HStack(spacing: 4) { if scanning { ProgressView() } else { Image(systemName: "sparkles") }; Text("읽기") }
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(T.blue)
                    }
                }
                if !scanMsg.isEmpty { Text(scanMsg).font(.system(size: 14)).foregroundStyle(T.sub) }
            }
        }
    }

    /// 문자·메일: Apple Intelligence가 있으면 AI로, 없으면 규칙으로 읽어요
    func readPasted() {
        let t = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !scanning else { return }
        scanning = true
        Task {
            let d = await SmartParse.parse(t)
            scanning = false
            var p = ParsedPayment(); p.name = d.name; p.price = d.price; p.date = d.date
            if d.trialDays > 0 {
                trial = true
                trialEnd = Calendar.current.date(byAdding: .day, value: d.trialDays, to: Date())!
                nextDate = trialEnd
            }
            if d.cycle != .monthly { cycle = d.cycle }
            apply(p)
            if d.trialDays > 0 { scanMsg = "무료 체험 \(d.trialDays)일을 찾았어요. 끝나기 하루 전에 알려드릴게요" }
            else if d.usedAI { scanMsg = "AI가 읽었어요! 확인해주세요" }
        }
    }

    func apply(_ p: ParsedPayment) {
        if !p.name.isEmpty { name = p.name; autofill(p.name, force: true) }
        if p.price > 0 { priceText = String(p.price) }
        if let d = p.date, !trial { nextDate = d < Date() ? Cycle.monthly.next(after: d) : d }
        scanMsg = (p.name.isEmpty && p.price == 0) ? "찾지 못했어요. 직접 적어주세요" : "찾았어요! 확인해주세요"
        if p.name.isEmpty && p.price > 0 { scanMsg = "금액만 찾았어요. 이름을 적어주세요" }
        method = .manual
    }

    func autofill(_ v: String, force: Bool = false) {
        if editing != nil && !force { return }
        if !catTouched || force { category = Catalog.classify(v) }
        if let s = Catalog.find(v), s.defaultPrice > 0, currency == "KRW", priceText.isEmpty || force { priceText = String(s.defaultPrice) }
    }

    func load() {
        guard let e = editing else { return }
        name = e.name
        if let c = e.currency, let a = e.foreignAmount { currency = c; priceText = String(a) } else { priceText = String(e.price) }
         category = e.category; catTouched = true; cycle = e.cycle
        nextDate = e.nextDate; pay = e.payMethod; people = e.people; memo = e.memo
        if let t = e.trialEnd { trial = true; trialEnd = t }
    }

    func save() {
        var s = editing ?? Subscription(name: "", price: 0, category: .etc, nextDate: nextDate)
        s.name = name.trimmingCharacters(in: .whitespaces); s.category = category
        let amt = Double(priceText) ?? 0
        if currency == "KRW" { s.currency = nil; s.foreignAmount = nil; s.price = Int(amt.rounded()) }
        else { s.currency = currency; s.foreignAmount = amt; s.price = FX.toKRW(amt, currency) }
        s.cycle = cycle; s.nextDate = nextDate; s.payMethod = pay; s.people = people; s.memo = memo
        s.trialEnd = trial ? trialEnd : nil
        if editing == nil { store.add(s) } else { store.update(s) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { saved = true }
        Task { try? await Task.sleep(nanoseconds: 900_000_000); dismiss() }
    }
}
