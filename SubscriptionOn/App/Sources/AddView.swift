import SwiftUI
import PhotosUI

struct AddView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var editing: Subscription? = nil

    enum Method { case manual, photo, text }
    enum Stage { case pick, form }
    @State private var stage: Stage = .pick
    @State private var query = ""
    @State private var aiText = ""
    @State private var aiBusy = false
    @State private var saved = false
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

    var body: some View {
        NavigationStack {
            ScrollView {
                if stage == .pick && editing == nil { pickView.transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))) } else {
                VStack(alignment: .leading, spacing: 20) {
                    if editing == nil {
                        if method == .photo { photoBox }
                        if method == .text { textBox }
                    }
                    field("무엇을 구독하세요?") {
                        TextField("서비스 이름을 적어주세요", text: $name).font(.system(size: 18, weight: .semibold))
                            .onChange(of: name) { _, v in autofill(v) }
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            let svc = Catalog.find(name)
                            HStack(spacing: 12) {
                                LogoView(name: name, category: category, size: 44).id(svc?.name ?? "none").transition(.scale(scale: 0.6).combined(with: .opacity))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(svc?.name ?? name).font(.system(size: 16, weight: .semibold))
                                    Text(svc != nil ? "\(category.rawValue)로 분류했어요" : "처음 보는 서비스예요. 종류를 골라주세요")
                                        .font(.system(size: 13)).foregroundStyle(T.sub).contentTransition(.opacity)
                                }
                            }.animation(.spring(response: 0.4, dampingFraction: 0.7), value: svc?.name)
                        }
                        let hits = Catalog.search(name).filter { $0.name != Catalog.find(name)?.name }
                        if !hits.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(hits.prefix(12), id: \.name) { s in
                                        Button { name = s.name; catTouched = false; autofill(s.name, force: true) } label: {
                                            VStack(spacing: 6) { LogoView(name: s.name, category: s.category, size: 48); Text(s.name).font(.system(size: 11)).foregroundStyle(T.sub).lineLimit(1) }.frame(width: 64)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    field("얼마예요?") {
                        TextField("0", text: $priceText).keyboardType(.numberPad).font(.system(size: 28, weight: .heavy))
                        if let v = Int(priceText), v > 0 { Text(v.won).font(.system(size: 14)).foregroundStyle(T.sub) }
                    }
                    field("종류") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(Category.allCases) { c in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { category = c; catTouched = true } } label: {
                                    Text(c.rawValue).font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(category == c ? .white : T.sub).frame(maxWidth: .infinity).frame(height: 40)
                                        .background(category == c ? c.color : T.bg, in: Capsule()).scaleEffect(category == c ? 1.05 : 1)
                                }
                            }
                        }
                        if !catTouched && !name.isEmpty { Text("자동으로 골랐어요").font(.system(size: 12)).foregroundStyle(T.faint) }
                    }
                    field("언제 결제돼요?") {
                        Picker("", selection: $cycle) { ForEach(Cycle.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        DatePicker("다음 결제일", selection: $nextDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                    field("더 적어둘래요?") {
                        TextField("결제수단 (예: 토스 체크카드)", text: $pay)
                        Divider()
                        Stepper("인원 \(people)명", value: $people, in: 1...10)
                        Divider()
                        Toggle("무료 체험 중이에요", isOn: $trial).tint(T.blue)
                        if trial { DatePicker("체험 종료일", selection: $trialEnd, displayedComponents: .date).environment(\.locale, Locale(identifier: "ko_KR")) }
                        Divider()
                        TextField("메모", text: $memo)
                    }
                    BigButton(title: editing == nil ? "추가하기" : "저장", action: save)
                        .opacity(canSave ? 1 : 0.4).disabled(!canSave)
                }.padding(20).transition(.move(edge: .trailing).combined(with: .opacity)) }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stage)
            .background(T.bg)
            .navigationTitle(editing == nil ? "구독 추가" : "수정").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if stage == .form && editing == nil { Button("뒤로") { stage = .pick } } else { Button("닫기") { dismiss() } }
                }
            }
            .onAppear { load() }
            .overlay {
                if saved {
                    ZStack {
                        Color.white.opacity(0.92).ignoresSafeArea()
                        VStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 84)).foregroundStyle(T.green)
                                .symbolEffect(.bounce, value: saved)
                            Text(editing == nil ? "추가했어요" : "저장했어요").font(.system(size: 20, weight: .bold))
                        }.transition(.scale(scale: 0.5).combined(with: .opacity))
                    }.transition(.opacity)
                }
            }
        }
    }


    // MARK: 1단계 — 말로 추가 / 검색
    var results: [Service] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? Catalog.all : Catalog.search(q)
    }
    var pickView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("말로 추가").font(.system(size: 14, weight: .semibold)).foregroundStyle(T.sub)
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(T.blue)
                TextField("예: 유튜브 프리미엄 매달 15일 14,900원", text: $aiText).submitLabel(.done).onSubmit(runAI)
                if aiBusy { ProgressView() } else if !aiText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: runAI) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundStyle(T.blue) }
                }
            }
            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(SmartParse.aiAvailable ? "Apple Intelligence가 기기 안에서 읽고, 추가하기 전에 확인할 수 있어요" : "기기 안에서 읽고, 추가하기 전에 확인할 수 있어요")
                .font(.system(size: 12)).foregroundStyle(T.faint)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(T.faint)
                TextField("서비스 검색", text: $query).submitLabel(.search)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.faint) } }
            }
            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                quick("photo", "캡처로") { method = .photo; stage = .form }
                quick("text.bubble", "문자·메일로") { method = .text; stage = .form }
            }

            let q = query.trimmingCharacters(in: .whitespaces)
            if q.isEmpty {
                ForEach(Category.allCases) { cat in
                    let items = Catalog.all.filter { $0.category == cat }
                    if !items.isEmpty {
                        Text(cat.rawValue).font(.system(size: 14, weight: .semibold)).foregroundStyle(T.sub).padding(.top, 6)
                        Card { VStack(spacing: 0) { ForEach(items, id: \.name) { serviceRow($0) } } }
                    }
                }
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(results, id: \.name) { serviceRow($0) }
                        Button { name = q; catTouched = false; autofill(q, force: true); stage = .form } label: {
                            HStack(spacing: 14) {
                                LogoView(name: q, category: Catalog.classify(q), size: 40)
                                Text("‘\(q)’ 그대로 추가").font(.system(size: 16)).foregroundStyle(T.text)
                                Spacer(); Image(systemName: "plus").foregroundStyle(T.blue)
                            }.padding(.vertical, 10).contentShape(Rectangle())
                        }
                    }
                }
            }
            Button("직접 입력") { stage = .form }.font(.system(size: 15)).foregroundStyle(T.sub).frame(maxWidth: .infinity)
        }.padding(20)
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
        let t = aiText.trimmingCharacters(in: .whitespaces)
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

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (Int(priceText) ?? 0) > 0 }

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
                    Button("읽기") { apply(Scanner.parse(pasted)) }.font(.system(size: 16, weight: .bold)).foregroundStyle(T.blue)
                }
                if !scanMsg.isEmpty { Text(scanMsg).font(.system(size: 14)).foregroundStyle(T.sub) }
            }
        }
    }

    func apply(_ p: ParsedPayment) {
        if !p.name.isEmpty { name = p.name; autofill(p.name, force: true) }
        if p.price > 0 { priceText = String(p.price) }
        if let d = p.date { nextDate = d < Date() ? Cycle.monthly.next(after: d) : d }
        scanMsg = (p.name.isEmpty && p.price == 0) ? "찾지 못했어요. 직접 적어주세요" : "찾았어요! 확인해주세요"
        if p.name.isEmpty && p.price > 0 { scanMsg = "금액만 찾았어요. 이름을 적어주세요" }
        method = .manual
    }

    func autofill(_ v: String, force: Bool = false) {
        if editing != nil && !force { return }
        if !catTouched || force { category = Catalog.classify(v) }
        if let s = Catalog.find(v), s.defaultPrice > 0, priceText.isEmpty || force { priceText = String(s.defaultPrice) }
    }

    func load() {
        guard let e = editing else { return }
        name = e.name; priceText = String(e.price); category = e.category; catTouched = true; cycle = e.cycle
        nextDate = e.nextDate; pay = e.payMethod; people = e.people; memo = e.memo
        if let t = e.trialEnd { trial = true; trialEnd = t }
    }

    func save() {
        var s = editing ?? Subscription(name: "", price: 0, category: .etc, nextDate: nextDate)
        s.name = name.trimmingCharacters(in: .whitespaces); s.price = Int(priceText) ?? 0; s.category = category
        s.cycle = cycle; s.nextDate = nextDate; s.payMethod = pay; s.people = people; s.memo = memo
        s.trialEnd = trial ? trialEnd : nil
        if editing == nil { store.add(s) } else { store.update(s) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { saved = true }
        Task { try? await Task.sleep(nanoseconds: 900_000_000); dismiss() }
    }
}
