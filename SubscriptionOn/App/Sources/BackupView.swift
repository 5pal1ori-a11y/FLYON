import SwiftUI
import UniformTypeIdentifiers

struct BackupDoc: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// 설정 > 백업·복원 (파일 앱에서 iCloud Drive를 고르면 iCloud에 저장돼요)
struct BackupView: View {
    @EnvironmentObject var store: Store
    @State private var exporting = false
    @State private var importing = false
    @State private var pending: Data?
    @State private var done: String?
    @State private var failed = false

    var lastText: String {
        store.lastBackup == 0 ? "아직 없어요" : Date(timeIntervalSince1970: store.lastBackup).formatted(.dateTime.month().day().hour().minute())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BigTitle("데이터를\n지키세요").stagger(0)
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "externaldrive.fill.badge.checkmark").foregroundStyle(T.green).font(.system(size: 20))
                                .symbolEffect(.bounce, value: store.lastBackup)
                            Text("자동 백업").font(.system(size: 17, weight: .bold))
                        }
                        Text("앱을 닫을 때마다 폰 안에 저장해요. 마지막: \(lastText)").font(.system(size: 14)).foregroundStyle(T.sub)
                        Text("파일 앱 > 이 iPhone > 구독온 에서 볼 수 있어요").font(.system(size: 12)).foregroundStyle(T.faint)
                    }
                }.stagger(1)

                SectionLabel("iCloud나 다른 곳에 보관")
                Button {
                    store.autoBackup(); exporting = true
                } label: { action("icloud.and.arrow.up.fill", T.blue, "백업 파일 저장하기", "저장 위치에서 iCloud Drive를 고르세요") }
                    .buttonStyle(PressCard()).stagger(2)
                Button { importing = true } label: { action("arrow.down.doc.fill", T.accent2, "백업에서 복원하기", "저장해 둔 파일을 골라요") }
                    .buttonStyle(PressCard()).stagger(3)

                if let d = done {
                    HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundStyle(T.green); Text(d).font(.system(size: 14, weight: .semibold)) }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(T.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                }
                Text("백업 파일에는 구독 목록, 월별 기록, 예산이 들어 있어요. 그대로 다른 폰에서 복원할 수 있어요.\n실시간 iCloud 동기화는 앱 정식 출시 때 함께 켤 수 있어요.")
                    .font(.system(size: 12)).foregroundStyle(T.faint)
                Spacer(minLength: 60)
            }.padding(.horizontal, 20)
        }
        .background(T.bg)
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: BackupDoc(data: store.makeBackup()), contentType: .json, defaultFilename: "구독온-백업") { r in
            if case .success = r { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { done = "백업 파일을 저장했어요" }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            guard case .success(let url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let d = try? Data(contentsOf: url) { pending = d } else { failed = true }
        }
        .confirmationDialog("어떻게 복원할까요?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            Button("지금 것과 합치기") { apply(merge: true) }
            Button("백업으로 덮어쓰기", role: .destructive) { apply(merge: false) }
            Button("취소", role: .cancel) { pending = nil }
        } message: { Text("합치기는 없는 구독만 더해요. 덮어쓰기는 지금 데이터가 백업으로 바뀌어요.") }
        .alert("파일을 읽지 못했어요", isPresented: $failed) { Button("확인", role: .cancel) {} }
    }

    func apply(merge: Bool) {
        guard let d = pending else { return }
        pending = nil
        if let n = store.restore(d, merge: merge) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { done = "구독 \(n)개를 불러왔어요" }
        } else { failed = true }
    }

    func action(_ icon: String, _ color: Color, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 40, height: 40).background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(T.text)
                Text(sub).font(.system(size: 12)).foregroundStyle(T.sub)
            }
            Spacer(); Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(T.faint)
        }
        .padding(16).background(T.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 12, y: 5)
    }
}
