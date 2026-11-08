import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    let sub: Subscription
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var askDone = false

    // 최신 값
    var s: Subscription { store.subs.first { $0.id == sub.id } ?? sub }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        if s.isActive, s.dDay <= 7 {
                            Text(s.dDay <= 0 ? "오늘 \(s.price.won) 결제돼요" : "\(s.dDay)일 후 \(s.price.won) 결제 예정이에요")
                                .font(.system(size: 14)).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.name).font(.system(size: 16)).foregroundStyle(T.sub)
                                    Text(s.price.won).font(.system(size: 28, weight: .heavy))
                                    Text("\(s.cycle.rawValue) · \(s.category.rawValue)").font(.system(size: 14)).foregroundStyle(T.sub)
                                }
                                Spacer()
                                LogoView(name: s.name, category: s.category, size: 56)
                            }
                        }.stagger(0)
                        Card {
                            VStack(spacing: 14) {
                                row("다음 결제일", s.nextDate.formatted(.dateTime.year().month().day()))
                                row("결제주기", s.cycle.rawValue)
                                if !s.payMethod.isEmpty { row("결제수단", s.payMethod) }
                                if s.people > 1 { row("인원수", "\(s.people)명") }
                                if !s.memo.isEmpty { row("메모", s.memo) }
                                if let t = s.trialEnd { row("체험 종료", t.formatted(.dateTime.month().day())) }
                                Divider()
                                row("결제 횟수", "\(s.payCount)회", blue: true)
                                row("누적 지출", s.totalPaid.won)
                                row("1년 환산", s.yearly.won)
                                row("상태", s.status.rawValue)
                            }
                        }.stagger(1)
                        if s.history.count > 1 {
                            Card {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(t: "가격이 바뀌었어요")
                                    ForEach(s.history.reversed(), id: \.self) { h in row(h.date.formatted(.dateTime.year().month().day()), h.price.won) }
                                }
                            }
                        }
                        if s.status != .cancelled {
                            Button(s.status == .paused ? "다시 시작" : "일시중지") {
                                var n = s; n.status = s.status == .paused ? .active : .paused; store.update(n)
                            }.font(.system(size: 15)).foregroundStyle(T.sub)
                        } else {
                            Button("다시 이용 중으로") { var n = s; n.status = .active; store.update(n) }.foregroundStyle(T.sub)
                            if let u = s.service?.joinURL { Button("다시 가입하러 가기") { openURL(u) }.foregroundStyle(T.blue) }
                        }
                        Spacer(minLength: 110)
                    }.padding(20)
                }
                HStack(spacing: 10) {
                    Button { confirmDelete = true } label: {
                        Image(systemName: "trash").foregroundStyle(T.sub).frame(width: 56, height: 56).background(T.bg, in: RoundedRectangle(cornerRadius: 18))
                    }
                    BigButton(title: "해지하기", color: Color(hex: 0xFFD6D9), fg: T.red) { cancel() }
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 28)).padding(.horizontal, 16)
            }
            .background(T.bg)
            .navigationBarTitleDisplayMode(.inline).navigationTitle("구독 정보")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { editing = true } label: { Image(systemName: "pencil") } }
            }
            .sheet(isPresented: $editing) { AddView(editing: s).environmentObject(store) }
            .alert("해지를 마쳤나요?", isPresented: $askDone) {
                Button("마쳤어요") { var n = s; n.status = .cancelled; store.update(n) }
                Button("아직이에요", role: .cancel) {}
            } message: { Text("해지는 서비스 안에서 직접 눌러야 끝나요") }
            .confirmationDialog("삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { store.delete(s); dismiss() }
            }
        }
    }

    /// 공식 해지 페이지로 이동하고, 해지 상태로 표시해요 (실제 해지는 해당 서비스에서 진행)
    func cancel() {
        // 앱스토어로 결제한 구독은 애플 구독 관리 화면, 그 외에는 서비스 공식 해지 페이지
        let apple = s.payMethod.contains("애플") || s.payMethod.lowercased().contains("apple") || s.payMethod.contains("앱스토어")
        var link = apple ? "https://apps.apple.com/account/subscriptions" : (s.service?.cancelURL ?? "")
        if link.isEmpty, let q = "\(s.name) 해지 방법".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { link = "https://www.google.com/search?q=" + q }
        if let u = URL(string: link), !link.isEmpty { openURL(u) }
        askDone = true
    }

    func row(_ k: String, _ v: String, blue: Bool = false) -> some View {
        HStack { Text(k).foregroundStyle(T.sub); Spacer(); Text(v).foregroundStyle(blue ? T.blue : T.text).multilineTextAlignment(.trailing) }.font(.system(size: 15))
    }
}
