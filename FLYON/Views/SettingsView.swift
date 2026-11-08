import SwiftUI

/// 출시 전에 실제 주소를 채워야 한다. App Store 제출에는 개인정보처리방침 URL이 필수.
enum LegalLinks {
    static let privacyPolicy: URL? = nil   // TODO
    static let termsOfUse: URL? = nil      // TODO
}

struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppState.self) private var appState
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String((auth.displayName ?? "F").prefix(1)))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Theme.headerGradient, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.displayName ?? "여행자").font(.headline)
                            Text("Apple 계정").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink("가격 데이터 안내") { DataNoticeView() }
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
            .navigationTitle("설정")
            .alert("계정을 삭제할까요?", isPresented: $confirmDelete) {
                Button("삭제", role: .destructive) {
                    appState.clearAllLocalData()
                    auth.deleteAccount()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("관심 노선과 검색 기록이 모두 삭제되며 되돌릴 수 없어요.")
            }
        }
    }

    @ViewBuilder
    private func legalRow(_ title: String, url: URL?) -> some View {
        if let url {
            Link(title, destination: url)
        } else {
            HStack {
                Text(title)
                Spacer()
                Text("준비 중").font(.footnote).foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct DataNoticeView: View {
    var body: some View {
        List {
            Section {
                Text("가격은 최근 검색된 항공권 데이터를 모아 분석한 참고 값이에요. 실시간 판매 가격이 아니고, 실제 예약 가격과 다를 수 있어요.")
                Text("'저렴해요', '비싸요' 표시는 최근 가격 흐름을 평균과 비교한 결과이며 미래 가격을 보장하지 않아요.")
                Text("FLYON은 항공권을 판매하거나 예약을 중개하지 않아요.")
            }
            Section("데이터 출처") {
                Text("공항 목록은 공개 도메인 데이터(OurAirports)를 바탕으로 해요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("가격 데이터 안내")
        .navigationBarTitleDisplayMode(.inline)
    }
}
