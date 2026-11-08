import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    let sub: Subscription
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var askDone = false
    @State private var celebrate = false
    @State private var celebrateAmount = 0

    // 최신 값
    var s: Subscription { store.subs.first { $0.id == sub.id } ?? sub }

    var brand: Color { s.service.map { Color(hex: $0.color) } ?? s.category.color }
    var dText: String { s.dDay <= 0 ? "D-DAY" : "D-\(s.dDay)" }
    var cycleUnit: String { s.cycle == .monthly ? "/ 1개월" : s.cycle == .yearly ? "/ 1년" : "/ 1주" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        hero.stagger(0)
                        stats.stagger(1)
                        info.stagger(2)
                        usage.stagger(3)
                        if s.history.count > 1 { priceHistory.stagger(4) }
                        stateButtons.stagger(5)
                        Spacer(minLength: 110)
                    }.padding(.horizontal, 20).padding(.top, 8)
                }
                bottomBar
            }
            .background(T.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { editing = true } label: { Image(systemName: "pencil") } }
            }
            .overlay { if celebrate { CelebrationView(saved: celebrateAmount) { withAnimation { celebrate = false } }.environmentObject(store).transition(.opacity) } }
            .sheet(isPresented: $editing) { AddView(editing: s).environmentObject(store) }
            .alert("해지를 마쳤나요?", isPresented: $askDone) {
                Button("마쳤어요") { let amt = Int(s.monthly.rounded()); var n = s; n.status = .cancelled; store.update(n); celebrateAmount = amt; withAnimation { celebrate = true } }
                Button("아직이에요", role: .cancel) {}
            } message: { Text("해지는 서비스 안에서 직접 눌러야 끝나요") }
            .confirmationDialog("삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { store.delete(s); dismiss() }
            }
        }
    }

    // MARK: 위쪽 큰 카드
    var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                LogoView(name: s.name, category: s.category, size: 64)
                    .overlay(RoundedRectangle(cornerRadius: 64 * 0.3, style: .continuous).stroke(.white.opacity(0.6), lineWidth: 2))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.name).font(.system(size: 22, weight: .heavy)).foregroundStyle(.white).lineLimit(2)
                    HStack(spacing: 6) {
                        chip(s.status.rawValue, filled: s.isActive)
                        chip(s.category.rawValue, filled: false)
                    }
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.price.won).font(.system(size: 38, weight: .heavy)).foregroundStyle(.white).contentTransition(.numericText())
                    Text(cycleUnit).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }
                if let c = s.currency, let a = s.foreignAmount {
                    Text("\(FX.label(a, c)) · 오늘 환율 기준").font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                }
            }
            if s.isActive {
                HStack(spacing: 8) {
                    Text(dText).font(.system(size: 13, weight: .heavy)).foregroundStyle(brand).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white, in: Capsule()).pulse(s.dDay <= 0)
                    Text(s.dDay <= 0 ? "오늘 \(s.price.won) 결제돼요" : "\(s.nextDate.formatted(.dateTime.month().day())) 결제 예정이에요")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
            }
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [brand, brand.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(alignment: .topTrailing) { Circle().fill(.white.opacity(0.1)).frame(width: 150).offset(x: 50, y: -60) }
        .overlay(alignment: .bottomTrailing) { Circle().fill(.white.opacity(0.07)).frame(width: 110).offset(x: 20, y: 40) }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: brand.opacity(0.35), radius: 20, y: 10)
    }

    func chip(_ t: String, filled: Bool) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).foregroundStyle(filled ? brand : .white)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(filled ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.22)), in: Capsule())
    }

    // MARK: 숫자 3개
    var stats: some View {
        HStack(spacing: 10) {
            tile("calendar", "다음 결제", s.nextDate.formatted(.dateTime.month().day()))
            tile("arrow.triangle.2.circlepath", "결제 횟수", "\(s.payCount)회")
            tile("sum", "1년 환산", s.yearly.won)
        }
    }
    func tile(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(T.blue)
                .frame(width: 28, height: 28).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label).font(.system(size: 12)).foregroundStyle(T.sub)
            Text(value).font(.system(size: 15, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 10, y: 4)
    }

    // MARK: 정보
    var info: some View {
        Card {
            VStack(spacing: 0) {
                infoRow("creditcard.fill", T.blue, "결제수단", s.payMethod.isEmpty ? "미입력" : s.payMethod, dim: s.payMethod.isEmpty)
                if s.people > 1 { divider; infoRow("person.2.fill", T.accent2, "인원수", "\(s.people)명 · 1인당 \(Int((s.monthly / Double(s.people)).rounded()).won)") }
                divider
                infoRow("wonsign.circle.fill", T.accent3, "누적 지출", s.totalPaid.won)
                if let t = s.trialEnd {
                    divider
                    infoRow("clock.fill", .orange, "무료 체험", t >= Calendar.current.startOfDay(for: Date()) ? "\(t.formatted(.dateTime.month().day()))까지" : "끝났어요")
                }
                if !s.memo.isEmpty { divider; infoRow("note.text", T.sub, "메모", s.memo) }
            }
        }
    }
    var divider: some View { Divider().padding(.vertical, 12) }
    func infoRow(_ icon: String, _ c: Color, _ k: String, _ v: String, dim: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 30, height: 30).background(c, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(k).font(.system(size: 15)).foregroundStyle(T.sub)
            Spacer()
            Text(v).font(.system(size: 15, weight: .semibold)).foregroundStyle(dim ? T.faint : T.text).multilineTextAlignment(.trailing)
        }
    }

    // MARK: 사용 (최근 7일 점)
    var usage: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
        let used = Set((s.usage ?? []).map { cal.startOfDay(for: $0) })
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("이번 달 사용").font(.system(size: 17, weight: .bold))
                    Spacer()
                    Text("\(s.usesThisMonth)번").font(.system(size: 17, weight: .heavy)).foregroundStyle(T.blue).contentTransition(.numericText())
                }
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { d in
                        let on = used.contains(cal.startOfDay(for: d))
                        VStack(spacing: 6) {
                            Circle().fill(on ? T.blue : T.bg).frame(width: 28, height: 28)
                                .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white).opacity(on ? 1 : 0).scaleEffect(on ? 1 : 0.3))
                            Text(d.formatted(.dateTime.weekday(.narrow))).font(.system(size: 11)).foregroundStyle(cal.isDateInToday(d) ? T.blue : T.faint)
                        }.frame(maxWidth: .infinity)
                    }
                }
                if let c = s.costPerUse { Text("한 번 쓸 때 \(c.won)").font(.system(size: 14)).foregroundStyle(T.sub) }
                else { Text("아직 안 썼어요. 쓴 날 눌러서 기록해요").font(.system(size: 14)).foregroundStyle(T.sub) }
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.markUsed(s) }
                } label: {
                    Label("오늘 썼어요", systemImage: "checkmark.circle.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(T.blue)
                        .frame(maxWidth: .infinity).frame(height: 46).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }.buttonStyle(PressCard())
            }
        }
    }

    // MARK: 가격 변동
    var priceHistory: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(t: "가격이 바뀌었어요")
                let list = Array(s.history.enumerated().reversed())
                ForEach(list, id: \.offset) { i, h in
                    HStack(spacing: 12) {
                        Circle().fill(i == s.history.count - 1 ? T.blue : T.faint).frame(width: 8, height: 8)
                        Text(h.date.formatted(.dateTime.year().month().day())).font(.system(size: 14)).foregroundStyle(T.sub)
                        Spacer()
                        if i > 0 {
                            let d = h.price - s.history[i - 1].price
                            Text(d > 0 ? "+\(d.won)" : "\(d.won)").font(.system(size: 12, weight: .bold)).foregroundStyle(d > 0 ? T.red : T.green)
                        }
                        Text(h.price.won).font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
    }

    // MARK: 상태 버튼
    @ViewBuilder var stateButtons: some View {
        if s.status != .cancelled {
            Button {
                let pausing = s.status != .paused
                let amt = Int(s.monthly.rounded())
                var n = s; n.status = s.status == .paused ? .active : .paused; store.update(n)
                if pausing { celebrateAmount = amt; withAnimation { celebrate = true } }
            } label: {
                Label(s.status == .paused ? "다시 시작하기" : "잠깐 멈추기", systemImage: s.status == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(T.sub)
                    .frame(maxWidth: .infinity).frame(height: 48).background(T.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(PressCard())
        } else {
            VStack(spacing: 10) {
                Button { var n = s; n.status = .active; store.update(n) } label: {
                    Label("다시 이용 중으로", systemImage: "arrow.uturn.backward").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.sub)
                        .frame(maxWidth: .infinity).frame(height: 48).background(T.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(PressCard())
                if let u = s.service?.joinURL {
                    Button { openURL(u) } label: {
                        Label("다시 가입하러 가기", systemImage: "arrow.up.right.square").font(.system(size: 15, weight: .bold)).foregroundStyle(T.blue)
                            .frame(maxWidth: .infinity).frame(height: 48).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }.buttonStyle(PressCard())
                }
            }
        }
    }

    // MARK: 아래 고정 바
    var bottomBar: some View {
        HStack(spacing: 10) {
            Button { confirmDelete = true } label: {
                Image(systemName: "trash").foregroundStyle(T.sub).frame(width: 56, height: 56).background(T.bg, in: RoundedRectangle(cornerRadius: 18))
            }
            if s.status == .cancelled {
                BigButton(title: "해지했어요", color: T.bg, fg: T.faint) {}.disabled(true)
            } else {
                BigButton(title: "해지하기", color: Color(hex: 0xFFD6D9), fg: T.red) { cancel() }
            }
        }
        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6).padding(.horizontal, 16)
    }

    /// 공식 해지 페이지로 이동하고, 마쳤는지 물어봐요 (실제 해지는 해당 서비스에서 진행)
    func cancel() {
        // 앱스토어로 결제한 구독은 애플 구독 관리 화면, 그 외에는 서비스 공식 해지 페이지
        let apple = s.payMethod.contains("애플") || s.payMethod.lowercased().contains("apple") || s.payMethod.contains("앱스토어")
        var link = apple ? "https://apps.apple.com/account/subscriptions" : (s.service?.cancelURL ?? "")
        if link.isEmpty, let q = "\(s.name) 해지 방법".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { link = "https://www.google.com/search?q=" + q }
        if let u = URL(string: link), !link.isEmpty { openURL(u) }
        askDone = true
    }
}
