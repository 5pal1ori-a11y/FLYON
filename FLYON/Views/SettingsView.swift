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
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.displayName ?? "여행자").font(.headline)
                            Label("Apple로 로그인됨", systemImage: "checkmark.seal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("알림") {
                    HStack {
                        Label("가격 알림", systemImage: "bell")
                        Spacer()
                        Text("준비 중").font(.footnote).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }

                Section("정보") {
                    NavigationLink {
                        DataNoticeView()
                    } label: {
                        Label("가격 데이터 안내", systemImage: "chart.bar.doc.horizontal")
                    }
                    legalRow("개인정보처리방침", systemImage: "hand.raised", url: LegalLinks.privacyPolicy)
                    legalRow("이용약관", systemImage: "doc.text", url: LegalLinks.termsOfUse)
                }

                Section("계정") {
                    Button {
                        auth.signOut()
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("계정 삭제", systemImage: "trash")
                    }
                }

                Section {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                            .foregroundStyle(.secondary)
                    }
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
    private func legalRow(_ title: String, systemImage: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                Label(title, systemImage: systemImage)
            }
        } else {
            HStack {
                Label(title, systemImage: systemImage)
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
            item("clock.arrow.circlepath", "수집 기반 참고 가격",
                 "가격은 최근 검색된 항공권 데이터를 모아 분석한 참고 값이에요. 실시간 판매 가격이 아니에요.")
            item("exclamationmark.triangle", "실제 가격과 다를 수 있어요",
                 "예약 시점의 좌석 상황, 수하물, 수수료에 따라 실제 가격은 달라질 수 있어요.")
            item("chart.line.uptrend.xyaxis", "분석은 참고용이에요",
                 "'저렴해요', '비싸요' 표시는 최근 30일 평균과 비교한 결과이며 미래 가격을 보장하지 않아요.")
            item("cart.badge.minus", "판매·예약 중개를 하지 않아요",
                 "FLYON은 항공권을 판매하거나 예약을 대행하지 않아요.")
        }
        .navigationTitle("가격 데이터 안내")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func item(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
