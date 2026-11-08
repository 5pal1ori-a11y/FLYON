import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var budgetText = ""
    @State private var goalText = ""
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("마이").font(.system(size: 22, weight: .bold)).padding(.top, 8)
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
                }
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("결제 알림", isOn: store.$notifyOn).tint(T.blue).onChange(of: store.notifyOn) { _, _ in store.scheduleAll() }
                        if store.notifyOn {
                            Stepper("\(store.notifyDays)일 전에 알려줘요", value: store.$notifyDays, in: 0...7).onChange(of: store.notifyDays) { _, _ in store.scheduleAll() }
                            Stepper("오전 \(store.notifyHour)시", value: store.$notifyHour, in: 6...22).onChange(of: store.notifyHour) { _, _ in store.scheduleAll() }
                        }
                        Divider()
                        Toggle("Face ID 잠금", isOn: store.$faceLock).tint(T.blue)
                    }.font(.system(size: 16))
                }
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        ShareLink(item: store.csv()) { Label("CSV로 내보내기", systemImage: "square.and.arrow.up").foregroundStyle(T.text) }
                        Divider()
                        Button(role: .destructive) { confirmReset = true } label: { Label("모든 데이터 지우기", systemImage: "trash") }
                    }.font(.system(size: 16))
                }
                Text("데이터는 이 폰 안에만 저장돼요.\n결제 캡처는 기기에서만 읽고 서버로 보내지 않아요.\n해지는 각 서비스의 공식 페이지에서 직접 진행돼요.")
                    .font(.system(size: 13)).foregroundStyle(T.faint).padding(.horizontal, 4)
                Spacer(minLength: 100)
            }.padding(.horizontal, 20)
        }
        .onAppear { budgetText = store.budget > 0 ? String(store.budget) : ""; goalText = store.saveGoal > 0 ? String(store.saveGoal) : "" }
        .confirmationDialog("모두 지울까요?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("지우기", role: .destructive) { store.reset() }
        }
    }
}
