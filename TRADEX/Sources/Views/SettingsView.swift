import SwiftUI

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(Wallet.self) private var wallet
    @State private var confirmReset = false
    @State private var confirmDelete = false

    // TODO: 출시 전 실제 주소로 교체 (앱스토어 심사 시 개인정보처리방침 URL 필수)
    private let privacyURL = URL(string: "https://example.com/tradex/privacy")!
    private let termsURL = URL(string: "https://example.com/tradex/terms")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("Logo").resizable().scaledToFit().frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.user?.displayName ?? "-").font(.headline)
                            Text(session.user?.provider == "apple" ? "Apple로 로그인" : "개발용 계정")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("모의투자") {
                    LabeledContent("보유 TRADEX", value: "\(wallet.state.tradex)")
                    LabeledContent("TRADEX 가치", value: "1 TRADEX = \(Fmt.krw(TradexRules.krwPerTradex))")
                    LabeledContent("매매 수수료", value: String(format: "%.2f%%", TradexRules.feeRate * 100))
                    Button("모의투자 초기화", role: .destructive) { confirmReset = true }
                }

                Section("정보") {
                    Link("개인정보처리방침", destination: privacyURL)
                    Link("이용약관", destination: termsURL)
                    NavigationLink("오픈소스 라이선스") { OpenSourceView() }
                    LabeledContent("시세 제공", value: "업비트 · 빗썸 Open API")
                    LabeledContent("버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }

                Section {
                    Text("TRADEX는 실제 가상자산을 사고팔지 않는 모의투자 서비스입니다. 화면의 시세는 실제 거래소 시세를 표시하지만, 앱 안의 모든 자산·TRADEX는 가상이며 현금·상품·실제 가상자산으로 교환되지 않습니다. 앱의 어떤 내용도 투자 권유가 아닙니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("로그아웃") { session.signOut() }
                    Button("계정 삭제", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("설정")
            .confirmationDialog("모든 거래소의 코인·원화·포지션이 사라지고, 지급받은 TRADEX만 다시 돌려받아요.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("초기화", role: .destructive) { wallet.reset() }
            }
            .confirmationDialog("계정과 모든 모의투자 기록이 삭제돼요. 되돌릴 수 없어요.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("계정 삭제", role: .destructive) { session.deleteAccount() }
            }
        }
    }
}
