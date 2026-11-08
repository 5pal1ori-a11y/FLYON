import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var budgetText = ""
    @State private var goalText = ""
    @State private var confirmReset = false
    @State private var testSent = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.openURL) private var openURL

    let dayOptions: [(Int, String)] = [(0, "당일"), (1, "1일 전"), (3, "3일 전"), (7, "7일 전")]

    var unusedPreview: String {
        guard let s = store.upcoming.first else { return "구독을 추가하면 미리 보여드려요" }
        let when = store.notifyDays == 0 ? "당일" : "\(store.notifyDays)일 전"
        return "\(s.name) 결제 \(when) 오전 \(store.notifyHour)시에 알려드려요"
    }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BigTitle("나에게\n맞게").stagger(0)

                // 프로필
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(.white.opacity(0.22)).frame(width: 64, height: 64)
                        Text(String((store.userName.isEmpty ? "구" : store.userName).prefix(1))).font(.system(size: 28, weight: .heavy)).foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("", text: store.$userName, prompt: Text("이름을 적어주세요").foregroundColor(.white.opacity(0.65)))
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        Text("구독 \(store.active.count)개 · 한 달 \(store.monthlyTotal.won)").font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.hero)
                .overlay(alignment: .topTrailing) { Circle().fill(.white.opacity(0.1)).frame(width: 130).offset(x: 40, y: -50) }
                .overlay(alignment: .bottomTrailing) { Circle().fill(T.accent3.opacity(0.45)).frame(width: 100).blur(radius: 6).offset(x: 10, y: 40) }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: T.blue.opacity(0.3), radius: 18, y: 10)
                .stagger(1)

                // 목표
                SectionLabel("목표")
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        row("wonsign.circle.fill", T.blue, "한 달 예산") {
                            TextField("0", text: $budgetText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 110)
                                .onChange(of: budgetText) { _, v in store.budget = Int(v) ?? 0 }
                            Text("원").foregroundStyle(T.sub)
                        }
                        Divider()
                        row("target", T.accent3, "절약 목표") {
                            TextField("0", text: $goalText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 110)
                                .onChange(of: goalText) { _, v in store.saveGoal = Int(v) ?? 0 }
                            Text("원").foregroundStyle(T.sub)
                        }
                    }.font(.system(size: 16))
                }.stagger(2)

                SectionLabel("알림")
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: store.notifyOn ? "bell.badge.fill" : "bell.slash.fill")
                                .font(.system(size: 20)).foregroundStyle(store.notifyOn ? T.blue : T.faint)
                                .symbolEffect(.bounce, value: store.notifyOn).contentTransition(.symbolEffect(.replace))
                            Text("결제 알림").font(.system(size: 17, weight: .bold))
                            Spacer()
                            Toggle("", isOn: $store.notifyOn.animation(.spring(response: 0.45, dampingFraction: 0.8))).labelsHidden().tint(T.blue)
                                .onChange(of: store.notifyOn) { _, _ in store.scheduleAll() }
                        }
                        if store.notifyOn {
                            HStack(spacing: 8) {
                                Menu {
                                    ForEach(dayOptions, id: \.0) { v, label in
                                        Button(label) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.notifyDays = v }; store.scheduleAll() }
                                    }
                                } label: { chip(dayOptions.first { $0.0 == store.notifyDays }?.1 ?? "\(store.notifyDays)일 전") }
                                Menu {
                                    ForEach(6...22, id: \.self) { h in
                                        Button("오전 \(h)시") { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.notifyHour = h }; store.scheduleAll() }
                                    }
                                } label: { chip("오전 \(store.notifyHour)시") }
                                Spacer()
                                Button {
                                    store.requestNotify(); store.sendTestNotification()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { testSent = true }
                                    Task { try? await Task.sleep(nanoseconds: 5_500_000_000); withAnimation { testSent = false } }
                                } label: {
                                    Label(testSent ? "5초 뒤" : "테스트", systemImage: testSent ? "checkmark" : "paperplane.fill")
                                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(testSent ? T.green : T.sub)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            if authStatus == .denied {
                                Button { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } } label: {
                                    Text("알림이 꺼져 있어요. 설정에서 켜주세요").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.red)
                                }
                            }
                        }
                    }
                }.stagger(3)

                // 앱 꾸미기 (테마 · 화면 · 아이콘)
                SectionLabel("앱")
                Card {
                    NavigationLink { AppearanceView() } label: {
                        row("paintpalette.fill", T.accent2, "테마 · 화면 · 아이콘") {
                            HStack(spacing: -6) {
                                ForEach(Array(T.palette.colors.enumerated()), id: \.offset) { _, c in Circle().fill(c).frame(width: 16, height: 16).overlay(Circle().stroke(T.card, lineWidth: 2)) }
                            }
                            Text(T.palette.name).font(.system(size: 14)).foregroundStyle(T.sub)
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(T.faint)
                        }.font(.system(size: 16)).foregroundStyle(T.text)
                    }.buttonStyle(.plain)
                }.stagger(4)

                SectionLabel("데이터·보안")
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        row("faceid", .green, "Face ID 잠금") { Toggle("", isOn: store.$faceLock).labelsHidden().tint(T.blue) }
                        Divider()
                        ShareLink(item: store.csv()) { rowLabel("square.and.arrow.up", T.accent2, "CSV로 내보내기", chevron: true) }
                        Divider()
                        Button(role: .destructive) { confirmReset = true } label: { rowLabel("trash", T.red, "모든 데이터 지우기", chevron: false, color: T.red) }
                    }.font(.system(size: 16))
                }.stagger(5)
                Text("데이터는 이 폰 안에만 저장돼요.\n결제 캡처와 명세서는 기기에서만 읽고 서버로 보내지 않아요.\n환율은 공개 환율 정보만 받아와요.\n해지는 각 서비스의 공식 페이지에서 직접 진행돼요.")
                    .font(.system(size: 13)).foregroundStyle(T.faint).padding(.horizontal, 4)
                Spacer(minLength: 100)
            }.padding(.horizontal, 20)
        }
        .onAppear {
            budgetText = store.budget > 0 ? String(store.budget) : ""; goalText = store.saveGoal > 0 ? String(store.saveGoal) : ""
            UNUserNotificationCenter.current().getNotificationSettings { s in DispatchQueue.main.async { authStatus = s.authorizationStatus } }
        }
        .confirmationDialog("모두 지울까요?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("지우기", role: .destructive) { store.reset() }
        }
        .background(T.bg)
        .toolbar(.hidden, for: .navigationBar)
        }
    }

    func chip(_ t: String) -> some View {
        HStack(spacing: 4) { Text(t).contentTransition(.numericText()); Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)) }
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(T.blue)
            .padding(.horizontal, 12).padding(.vertical, 8).background(T.blueSoft, in: Capsule())
    }
    func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            .frame(width: 30, height: 30).background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    func row<C: View>(_ ic: String, _ color: Color, _ title: String, @ViewBuilder trailing: () -> C) -> some View {
        HStack(spacing: 12) { icon(ic, color); Text(title); Spacer(); trailing() }
    }
    func rowLabel(_ ic: String, _ color: Color, _ title: String, chevron: Bool, color tc: Color = T.text) -> some View {
        HStack(spacing: 12) {
            icon(ic, color); Text(title).foregroundStyle(tc); Spacer()
            if chevron { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(T.faint) }
        }
    }
}
