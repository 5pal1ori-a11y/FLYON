import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("themeMode") private var themeMode = 0
    @AppStorage("themeID") private var themeID = "default"
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
                }.stagger(3)

                // 테마
                SectionLabel("테마")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(T.palettes) { p in
                            let on = themeID == p.id
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { themeID = p.id }
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    ZStack(alignment: .leading) {
                                        ForEach(Array(p.colors.enumerated()), id: \.offset) { i, c in
                                            Circle().fill(c).frame(width: 34, height: 34).overlay(Circle().stroke(T.card, lineWidth: 3)).offset(x: CGFloat(i) * 22)
                                        }
                                    }.frame(width: 80, height: 34, alignment: .leading)
                                    HStack(spacing: 4) {
                                        Text(p.name).font(.system(size: 14, weight: .bold)).foregroundStyle(T.text)
                                        if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.colors[0]).font(.system(size: 14)).transition(.scale) }
                                    }
                                }
                                .padding(16).frame(width: 130, alignment: .leading)
                                .background(T.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(p.colors[0], lineWidth: on ? 2 : 0))
                                .scaleEffect(on ? 1.04 : 1)
                                .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 12, y: 5)
                            }.buttonStyle(PressCard())
                        }
                    }.padding(.vertical, 8).padding(.horizontal, 2)
                }.stagger(4)

                // 화면
                SectionLabel("화면")
                Card {
                    VStack(alignment: .leading, spacing: 16) {
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
                }.stagger(5)

                SectionLabel("데이터·보안")
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        row("faceid", .green, "Face ID 잠금") { Toggle("", isOn: store.$faceLock).labelsHidden().tint(T.blue) }
                        Divider()
                        ShareLink(item: store.csv()) { rowLabel("square.and.arrow.up", T.accent2, "CSV로 내보내기", chevron: true) }
                        Divider()
                        Button(role: .destructive) { confirmReset = true } label: { rowLabel("trash", T.red, "모든 데이터 지우기", chevron: false, color: T.red) }
                    }.font(.system(size: 16))
                }.stagger(6)
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
