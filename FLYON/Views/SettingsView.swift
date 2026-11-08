import SwiftUI

/// 출시 전에 실제 주소를 채워야 한다. App Store 제출에는 개인정보처리방침 URL이 필수.
enum LegalLinks {
    static let privacyPolicy: URL? = nil   // TODO
    static let termsOfUse: URL? = nil      // TODO
}

struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppState.self) private var appState
    @Environment(PushManager.self) private var push
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String((auth.displayName ?? "F").prefix(1)))
                            .font(.app(20, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Theme.headerGradient, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.displayName ?? "여행자").font(.app(17, .semibold))
                            Text("Apple 계정").font(.app(13)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        Text("푸시 알림")
                        Spacer()
                        Text(push.isAuthorized ? "켜짐" : "꺼짐").foregroundStyle(.secondary)
                    }
                    NavigationLink("가격 정보 안내") { DataNoticeView() }
                    legalRow("개인정보처리방침", url: LegalLinks.privacyPolicy)
                    legalRow("이용약관", url: LegalLinks.termsOfUse)
                }

                Section {
                    Button("로그아웃") { auth.signOut() }
                    Button("계정 삭제", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("버전 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")")
                }
            }
            .font(.app(16))
            .navigationTitle("설정")
            .task { await push.refreshStatus() }
            .alert("계정을 삭제할까요?", isPresented: $confirmDelete) {
                Button("삭제", role: .destructive) { deleteAccount() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("관심 노선, 검색 기록, 가격 알림이 모두 삭제돼요.")
            }
        }
    }

    private func deleteAccount() {
        if let client = AppConfig.makeAlertsClient(), let token = push.deviceToken {
            Task { try? await client.deleteAll(token: token) }
        }
        appState.clearAllLocalData()
        auth.deleteAccount()
    }

    @ViewBuilder
    private func legalRow(_ title: String, url: URL?) -> some View {
        if let url {
            Link(title, destination: url)
        } else {
            HStack {
                Text(title)
                Spacer()
                Text("준비 중").foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct DataNoticeView: View {
    var body: some View {
        List {
            Text("가격은 최근 검색된 항공권 정보를 모은 참고 값이에요. 실제 예약 가격과 다를 수 있어요.")
            Text("FLYON은 항공권을 판매하거나 예약을 중개하지 않아요.")
            Section("출처") {
                Text("가격·항공사 로고: Travelpayouts(Aviasales)")
                Text("공항 목록: OurAirports (공개 도메인)")
                Text("글꼴: Pretendard (SIL Open Font License)")
            }
            .font(.app(14))
            .foregroundStyle(.secondary)
        }
        .font(.app(15))
        .navigationTitle("가격 정보 안내")
        .navigationBarTitleDisplayMode(.inline)
    }
}
