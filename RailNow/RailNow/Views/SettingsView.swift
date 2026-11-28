import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings
    @State private var seoulDraft = ""
    @State private var railDraft = ""
    @FocusState private var focused: Bool

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "설정") { EmptyView() }
                    .padding(.horizontal, -20)

                SectionTitle(title: "데이터 연결")
                    .padding(.bottom, 12)
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        statusRow(
                            title: "지하철 실시간 위치",
                            detail: "서울 열린데이터광장",
                            connected: !settings.effectiveSeoulKey.isEmpty
                        )
                        Divider().overlay(Palette.hairline).padding(.vertical, 12)
                        statusRow(
                            title: "기차 시간표",
                            detail: "공공데이터포털 · 국토교통부 TAGO",
                            connected: !settings.effectiveRailKey.isEmpty
                        )
                    }
                }

                SectionTitle(title: "인증키")
                    .padding(.top, 30)
                    .padding(.bottom, 6)
                Text("두 곳 모두 회원가입 후 무료로 발급받을 수 있어요. 키는 이 기기에만 저장됩니다.")
                    .font(.pre(13))
                    .foregroundStyle(Palette.sub)
                    .padding(.bottom, 12)

                keyField(
                    title: "서울 열린데이터광장 인증키",
                    hint: "‘지하철 실시간 열차 위치정보’ 인증키",
                    text: $seoulDraft
                )
                if let url = URL(string: "https://data.seoul.go.kr") {
                    Link("data.seoul.go.kr에서 발급받기", destination: url)
                        .font(.pre(13, .medium))
                        .tint(Palette.accent)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                }

                keyField(
                    title: "공공데이터포털 인증키",
                    hint: "‘국토교통부_(TAGO)_열차정보’ 일반 인증키",
                    text: $railDraft
                )
                if let url = URL(string: "https://www.data.go.kr") {
                    Link("data.go.kr에서 발급받기", destination: url)
                        .font(.pre(13, .medium))
                        .tint(Palette.accent)
                        .padding(.top, 8)
                }

                Button {
                    focused = false
                    settings.seoulKey = seoulDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    settings.railKey = railDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await store.loadRail(force: true) }
                } label: {
                    Text("저장하고 다시 연결")
                        .font(.pre(15, .semibold))
                        .foregroundStyle(Palette.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)

                SectionTitle(title: "알아 두세요")
                    .padding(.top, 34)
                    .padding(.bottom, 12)
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        note("지하철 위치는 서울시가 제공하는 실시간 정보이며, 수신 시점에 따라 실제와 조금 다를 수 있습니다. 인천 1·2호선, 김포골드라인, 용인·의정부경전철은 실시간 위치가 공개되지 않습니다.")
                        note("KTX·SRT·ITX-새마을·무궁화호는 열차 좌표를 주는 공개 API가 없어, 시간표로 계산한 추정 위치를 보여 줍니다. 지연은 반영되지 않습니다.")
                        note("이 앱은 한국철도공사, 에스알, 서울교통공사 등 운영기관과 관계없는 비공식 앱입니다. 승차권과 정확한 운행 정보는 각 운영기관에서 확인하세요.")
                        note("이 앱은 개인정보를 수집하거나 서버로 보내지 않습니다.")
                    }
                }

                SectionTitle(title: "자료 출처")
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        note("지하철 실시간 열차 위치: 서울특별시, 서울 열린데이터광장")
                        note("열차 시간표: 국토교통부 TAGO 열차정보, 공공데이터포털")
                        note(store.catalog.attribution.isEmpty ? "역·노선 자료 © OpenStreetMap contributors (ODbL 1.0)" : store.catalog.attribution)
                        note("글꼴: Pretendard (SIL Open Font License 1.1)")
                    }
                }

                Text("레일나우 \(version)")
                    .font(.pre(12.5))
                    .foregroundStyle(Palette.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            seoulDraft = settings.seoulKey
            railDraft = settings.railKey
        }
    }

    private func statusRow(title: String, detail: String, connected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.pre(15, .semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.pre(12.5))
                    .foregroundStyle(Palette.sub)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(connected ? Palette.live : Palette.faint)
                    .frame(width: 6, height: 6)
                Text(connected ? "키 등록됨" : "키 없음")
                    .font(.pre(13, .semibold))
                    .foregroundStyle(connected ? Palette.live : Palette.sub)
            }
        }
    }

    private func keyField(title: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.pre(13.5, .semibold))
                .foregroundStyle(Palette.ink)
            TextField(hint, text: text)
                .font(.pre(14))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.hairline, lineWidth: 1)
                )
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.pre(13.5))
            .foregroundStyle(Palette.sub)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}
