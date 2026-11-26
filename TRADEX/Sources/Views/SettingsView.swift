import SwiftUI

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(Wallet.self) private var wallet
    @State private var confirmReset = false
    @State private var confirmDelete = false

    // TODO: 출시 전 실제 주소로 교체 (앱스토어 심사 시 개인정보처리방침 URL 필수)
    private let privacyURL = URL(string: "https://example.com/tradex/privacy")!
    private let termsURL = URL(string: "https://example.com/tradex/terms")!

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection

                Section {
                    row("bitcoinsign.circle.fill", .orange, "보유 TRADEX", "\(wallet.state.tradex)개")
                    row("wonsign.circle.fill", .green, "TRADEX 가치", "1개 = \(Fmt.man(TradexRules.krwPerTradex)) 원")
                    row("percent", .blue, "현물 수수료", String(format: "%.2f%%", TradexRules.feeRate * 100))
                    row("chart.line.uptrend.xyaxis", .purple, "선물", "최대 \(TradexRules.maxLeverage)배 · 수수료 없음")
                    Button {
                        confirmReset = true
                    } label: {
                        HStack(spacing: 14) {
                            IconTile(systemName: "arrow.counterclockwise", tint: .red, size: 30)
                            Text("모의투자 초기화").foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("모의투자")
                }

                Section {
                    linkRow("hand.raised.fill", .blue, "개인정보처리방침", privacyURL)
                    linkRow("doc.text.fill", .gray, "이용약관", termsURL)
                    NavigationLink {
                        OpenSourceView()
                    } label: {
                        HStack(spacing: 14) {
                            IconTile(systemName: "shippingbox.fill", tint: .brown, size: 30)
                            Text("오픈소스 라이선스")
                        }
                    }
                    row("antenna.radiowaves.left.and.right", .teal, "시세 제공", "업비트 · 빗썸 Open API")
                    row("info.circle.fill", .gray, "버전", version)
                } header: {
                    Text("정보")
                }

                Section {
                    Label {
                        Text("TRADEX는 실제 가상자산을 사고팔지 않는 모의투자 서비스예요. 시세는 실제 거래소 시세지만 앱 안의 자산과 TRADEX는 모두 가상이며, 현금·상품·실제 가상자산으로 바꿀 수 없어요. 앱의 어떤 내용도 투자 권유가 아니에요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                    }
                }

                Section {
                    Button("로그아웃") { session.signOut() }
                        .frame(maxWidth: .infinity)
                    Button("계정 삭제", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("설정")
            .confirmationDialog("모든 거래소의 코인·원화·포지션이 사라지고, 지급받은 TRADEX만 다시 돌려받아요.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("초기화", role: .destructive) { wallet.reset() }
            }
            .confirmationDialog("계정과 모든 모의투자 기록이 삭제돼요. 되돌릴 수 없어요.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("계정 삭제", role: .destructive) { session.deleteAccount() }
            }
        }
    }

    // MARK: - 프로필

    private var profileSection: some View {
        let name = session.user?.displayName ?? "트레이더"
        return Section {
            HStack(spacing: 16) {
                Text(String(name.prefix(1)))
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 60, height: 60)
                    .background(Color.primary, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.title3.weight(.bold))
                    HStack(spacing: 4) {
                        Image(systemName: session.user?.provider == "apple" ? "apple.logo" : "hammer.fill")
                        Text(session.user?.provider == "apple" ? "Apple로 로그인" : "개발용 계정")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                TradexLogo(height: 22, showsWordmark: false)
                    .opacity(0.8)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 행

    private func row(_ icon: String, _ tint: Color, _ title: String, _ value: String) -> some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon, tint: tint, size: 30)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func linkRow(_ icon: String, _ tint: Color, _ title: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                IconTile(systemName: icon, tint: tint, size: 30)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

/// 오픈소스 라이선스 고지 (코인 아이콘)
struct OpenSourceView: View {
    private let items: [(String, String, String)] = [
        ("web3icons", "MIT License · Copyright (c) 0xa3k5", "코인 아이콘"),
        ("@iconify-json/token-branded", "MIT License (원본 web3icons)", "코인 아이콘"),
        ("@ledgerhq/crypto-icons-ui", "MIT License · Copyright (c) 2022 Ledger", "코인 아이콘 (단색 심볼을 브랜드 색 배경에 배치)"),
        ("cryptocurrency-icons", "CC0 1.0", "코인 아이콘"),
    ]

    private let mit = """
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """

    var body: some View {
        List {
            Section {
                ForEach(items, id: \.0) { name, license, use in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name).font(.subheadline.weight(.semibold))
                        Text(license).font(.caption).foregroundStyle(.secondary)
                        Text(use).font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("각 코인 로고는 해당 프로젝트의 상표일 수 있으며, 해당 코인을 표시하는 용도로만 사용해요.")
            }
            Section("MIT License") {
                Text(mit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("오픈소스 라이선스")
    }
}
