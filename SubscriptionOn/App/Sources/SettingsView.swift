import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("themeMode") private var themeMode = 0
    @AppStorage("accentHex") private var accentHex = 0
    @State private var budgetText = ""
    @State private var goalText = ""
    @State private var confirmReset = false
    @State private var testSent = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var iconName: String? = UIApplication.shared.alternateIconName
    @Namespace private var dayPill
    @Environment(\.openURL) private var openURL

    let dayOptions: [(Int, String)] = [(0, "당일"), (1, "1일 전"), (3, "3일 전"), (7, "7일 전")]

    var previewText: String {
        guard let s = store.upcoming.first else { return "구독을 추가하면 미리 보여드려요" }
        let when = store.notifyDays == 0 ? "당일" : "\(store.notifyDays)일 전"
        return "\(s.name) 결제 \(when) 오전 \(store.notifyHour)시에 알려드려요"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("마이").font(.system(size: 22, weight: .bold)).padding(.top, 8).stagger(0)

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("이름", text: store.$userName)
                        Divider()
                        HStack { Text("한 달 예산"); Spacer(); TextField("0", text: $budgetText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 120)
                            .onChange(of: budgetText) { _, v in store.budget = Int(v) ?? 0 }; Text("원") }
                        Divider()
                        HStack { Text("절약 목표"); Spacer(); TextField("0", text: $goalText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 120)
                            .onChange(of: goalText) { _, v in store.saveGoal = Int(v) ?? 0 }; Text("원") }
                    }.font(.system(size: 16))
                }.stagger(1)

                // 알림
                Card {
                    VStack(alignment: .leading, spacing: 16) {
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
                            VStack(alignment: .leading, spacing: 14) {
                                Text("언제 알려드릴까요?").font(.system(size: 13)).foregroundStyle(T.sub)
                                HStack(spacing: 8) {
                                    ForEach(dayOptions, id: \.0) { v, label in
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { store.notifyDays = v }
                                            store.scheduleAll()
                                        } label: {
                                            Text(label).font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(store.notifyDays == v ? .white : T.sub)
                                                .frame(maxWidth: .infinity).frame(height: 40)
                                                .background {
                                                    ZStack {
                                                        Capsule().fill(T.bg)
                                                        if store.notifyDays == v { Capsule().fill(T.blue).matchedGeometryEffect(id: "day", in: dayPill) }
                                                    }
                                                }
                                        }
                                    }
                                }
                                HStack {
                                    Text("오전").font(.system(size: 15)).foregroundStyle(T.sub)
                                    Text("\(store.notifyHour)시").font(.system(size: 17, weight: .bold)).contentTransition(.numericText())
                                    Spacer()
                                    Stepper("", value: Binding(get: { store.notifyHour }, set: { v in withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.notifyHour = v }; store.scheduleAll() }), in: 6...22).labelsHidden()
                                }
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "bell.fill").foregroundStyle(T.blue).font(.system(size: 13)).padding(.top, 2)
                                    Text(previewText).font(.system(size: 13)).foregroundStyle(T.text).contentTransition(.opacity)
                                }
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .animation(.easeInOut(duration: 0.25), value: previewText)

                                Button {
                                    store.requestNotify(); store.sendTestNotification()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { testSent = true }
                                    Task { try? await Task.sleep(nanoseconds: 5_500_000_000); withAnimation { testSent = false } }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: testSent ? "checkmark.circle.fill" : "paperplane.fill").contentTransition(.symbolEffect(.replace))
                                        Text(testSent ? "5초 뒤에 올 거예요" : "테스트 알림 보내보기")
                                    }
                                    .font(.system(size: 15, weight: .bold)).foregroundStyle(testSent ? T.green : T.blue)
                                    .frame(maxWidth: .infinity).frame(height: 46)
                                    .background((testSent ? T.green : T.blue).opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }.buttonStyle(PressCard())
                                if authStatus == .denied {
                                    Button { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } } label: {
                                        Text("알림이 꺼져 있어요. 설정에서 켜주세요").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.red)
                                    }
                                }
                            }
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }.stagger(2)

                // 화면
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("화면").font(.system(size: 17, weight: .bold))
                        HStack(spacing: 10) {
                            ForEach([(0, "시스템", "circle.lefthalf.filled"), (1, "라이트", "sun.max.fill"), (2, "다크", "moon.fill")], id: \.0) { v, label, icon in
                                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { themeMode = v } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: icon).font(.system(size: 20)).symbolEffect(.bounce, value: themeMode == v)
                                        Text(label).font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(themeMode == v ? T.blue : T.sub).frame(maxWidth: .infinity).frame(height: 64)
                                    .background(themeMode == v ? T.blueSoft : T.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(T.blue, lineWidth: themeMode == v ? 1.5 : 0))
                                }.buttonStyle(PressCard())
                            }
                        }
                        Text("포인트 색").font(.system(size: 13)).foregroundStyle(T.sub)
                        HStack(spacing: 14) {
                            ForEach(T.accents, id: \.1) { name, hex in
                                let on = (accentHex == 0 ? 0x3182F6 : accentHex) == Int(hex)
                                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { accentHex = Int(hex) } } label: {
                                    Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                                        .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).opacity(on ? 1 : 0).scaleEffect(on ? 1 : 0.3))
                                        .scaleEffect(on ? 1.15 : 1)
                                }.accessibilityLabel(name)
                            }
                        }
                        Text("앱 아이콘").font(.system(size: 13)).foregroundStyle(T.sub)
                        HStack(spacing: 12) {
                            ForEach([(nil as String?, "기본", "IconPrevDefault"), ("AppIcon-White", "화이트", "IconPrevWhite"), ("AppIcon-Blue", "블루", "IconPrevBlue")], id: \.1) { name, label, img in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    UIApplication.shared.setAlternateIconName(name) { _ in }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { iconName = name }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(img).resizable().scaledToFit().frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(T.blue, lineWidth: iconName == name ? 2.5 : 0))
                                            .scaleEffect(iconName == name ? 1.08 : 1)
                                        Text(label).font(.system(size: 12)).foregroundStyle(iconName == name ? T.blue : T.sub)
                                    }.frame(maxWidth: .infinity)
                                }.buttonStyle(PressCard())
                            }
                        }
                    }
                }.stagger(3)

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Face ID 잠금", isOn: store.$faceLock).tint(T.blue)
                        Divider()
                        ShareLink(item: store.csv()) { Label("CSV로 내보내기", systemImage: "square.and.arrow.up").foregroundStyle(T.text) }
                        Divider()
                        Button(role: .destructive) { confirmReset = true } label: { Label("모든 데이터 지우기", systemImage: "trash") }
                    }.font(.system(size: 16))
                }.stagger(4)
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
    }
}
