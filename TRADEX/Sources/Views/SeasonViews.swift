import SwiftUI
import AuthenticationServices

/// 혜택 탭: 이번 시즌 카드 (시즌명, 남은 기간, 내 AP)
struct SeasonSummaryView: View {
    @Environment(Wallet.self) private var wallet

    var body: some View {
        let season = wallet.season
        let ap = wallet.seasonAP
        let totalDays = max(1, Int(season.end.timeIntervalSince(Season.startDate(season)) / 86_400))
        let elapsed = 1 - Double(season.daysLeft()) / Double(totalDays)
        NavigationLink {
            SeasonView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(season.name).font(.title3.weight(.bold))
                        Text("\(season.monthsText) · \(season.daysLeft())일 남음").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Fmt.number(Double(ap))) AP")
                            .font(.title3.weight(.heavy)).monospacedDigit()
                            .contentTransition(.numericText(value: Double(ap)))
                            .animation(.snappy, value: ap)
                        Text("랭킹 보기").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
                ProgressBar(value: elapsed, height: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear { wallet.rollSeasonIfNeeded() }
    }
}

extension Season {
    static func startDate(_ s: Season) -> Date {
        PredictionRound.calendar.date(from: DateComponents(year: s.year, month: s.quarter * 3 - 2, day: 1)) ?? .now
    }
}

/// 시즌 화면: 내 AP, AP 얻는 법, 랭킹, 지난 시즌
struct SeasonView: View {
    @Environment(Wallet.self) private var wallet
    @Environment(RankingStore.self) private var ranking

    var body: some View {
        let season = wallet.season
        let ap = wallet.seasonAP
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 내 시즌
                VStack(alignment: .leading, spacing: 10) {
                    Text(season.name).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(Fmt.number(Double(ap))) AP").font(.system(size: 34, weight: .heavy)).monospacedDigit()
                    Text("\(season.monthsText) · 시즌 종료까지 \(season.daysLeft())일")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Text("오늘 얻은 AP").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(wallet.state.season.apDay == KST.dayKey(.now) ? wallet.state.season.apToday : 0) / \(XPRule.dailyAPCap)")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    .padding(.top, 4)
                }
                .tossCard()

                // 랭킹
                RankingCard()

                // AP 얻는 법
                VStack(alignment: .leading, spacing: 10) {
                    Text("AP 얻는 법").font(.title3.weight(.bold))
                    ForEach(XPRule.allCases, id: \.self) { r in
                        HStack {
                            Text(r.title).font(.subheadline)
                            Spacer()
                            Text("+\(r.ap) AP").font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }
                    Text("AP는 하루 \(XPRule.dailyAPCap)까지 쌓이고, 시즌이 바뀌면 0부터 다시 시작해요. 등급 경험치(XP)는 시즌과 상관없이 계속 쌓여요.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .tossCard()

                SeasonRewardGuide()

                // 지난 시즌 (등급 배지 · 순위 · 받은 보상)
                if !wallet.state.season.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("지난 시즌").font(.title3.weight(.bold))
                        ForEach(wallet.state.season.history) { h in
                            let result = wallet.state.season.results.first { $0.id == h.id }
                            HStack(spacing: 12) {
                                SeasonTierBadge(tier: result?.tier ?? SeasonTier.tier(for: h.ap), size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.displayName).font(.subheadline.weight(.semibold))
                                    Text(result.map { r in "\(r.tier.name)\(r.rank.map { " · \($0)위" } ?? "") · \(r.rewardTradex) TRADEX 받음" } ?? "보상 받기 전")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Fmt.number(Double(h.ap))) AP").font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                        }
                    }
                    .tossCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.tossBackground)
        .navigationTitle("시즌")
        .task { await ranking.sync(season: wallet.season, ap: wallet.seasonAP, force: true) }
        .refreshable { await ranking.sync(season: wallet.season, ap: wallet.seasonAP, force: true) }
    }
}


/// 시즌 랭킹 카드: 내 순위 + 상위 100명
struct RankingCard: View {
    @Environment(Wallet.self) private var wallet
    @Environment(RankingStore.self) private var ranking
    @State private var showJoin = false
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("시즌 랭킹").font(.title3.weight(.bold))
                Spacer()
                if let total = ranking.board?.total, total > 0 {
                    Text("\(Fmt.number(Double(total)))명 참여").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !ranking.isConfigured {
                Text("랭킹 서버가 아직 연결되지 않은 빌드예요.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                if let me = ranking.board?.me {
                    myRow(me)
                } else if !ranking.isJoined {
                    joinPrompt
                }
                if let top = ranking.board?.top, !top.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(top.prefix(showAll ? 100 : 10)) { e in
                            entryRow(e, isMe: e.nickname == ranking.nickname)
                        }
                    }
                    if top.count > 10 {
                        Button(showAll ? "접기" : "전체 순위 보기 (\(top.count)위까지)") {
                            withAnimation(.snappy) { showAll.toggle() }
                        }
                        .buttonStyle(BWButtonStyle(verticalPadding: 7))
                        .frame(maxWidth: .infinity)
                    }
                } else if ranking.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                } else if ranking.board != nil {
                    Text("아직 이번 시즌 참가자가 없어요. 첫 번째가 되어 보세요!")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let err = ranking.errorText {
                    Text(err).font(.caption).foregroundStyle(Theme.rise)
                }
            }
        }
        .tossCard()
        .sheet(isPresented: $showJoin) {
            JoinRankingSheet().presentationDetents([.large])
        }
    }

    private var joinPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("닉네임을 정하고 랭킹에 참가하면 이번 시즌 AP로 다른 트레이더와 순위를 겨뤄요.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("랭킹 참가하기") { showJoin = true }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func myRow(_ me: RankingAPI.Me) -> some View {
        HStack(spacing: 14) {
            LevelBadge(level: wallet.level, size: 40, filled: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(me.nickname).font(.headline)
                Text("내 순위").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(me.rank.map { "\($0)위" } ?? "순위 없음").font(.title3.weight(.heavy)).monospacedDigit()
                Text("\(Fmt.number(Double(me.ap))) AP").font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(12)
        .background(Theme.tossBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func entryRow(_ e: RankingAPI.Entry, isMe: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if e.rank <= 3 {
                    Image(systemName: "crown").font(.caption2).offset(y: -14)
                }
                Text("\(e.rank)").font(.headline.weight(e.rank <= 3 ? .heavy : .semibold)).monospacedDigit()
            }
            .frame(width: 30)
            Text(e.nickname).font(.subheadline.weight(isMe ? .bold : .medium))
            if isMe {
                Text("나").font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .bwBackground(selected: true)
            }
            Spacer()
            Text("\(Fmt.number(Double(e.ap))) AP").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .padding(.vertical, 9)
    }
}

/// 랭킹 참가: 닉네임 · 만 14세 이상 확인 · 공개 정보 동의 · Apple 계정 확인
struct JoinRankingSheet: View {
    @Environment(Wallet.self) private var wallet
    @Environment(RankingStore.self) private var ranking
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var ageOK = false
    @State private var consentOK = false
    @State private var working = false
    @State private var errorText: String?

    private var nicknameValid: Bool {
        nickname.range(of: "^[가-힣A-Za-z0-9_]{2,12}$", options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("닉네임 (한글·영문·숫자 2~12자)", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("랭킹에 보일 닉네임")
                } footer: {
                    Text("실명·연락처 등 개인을 알아볼 수 있는 닉네임은 쓰지 마세요.")
                }
                Section {
                    Toggle("만 14세 이상이에요", isOn: $ageOK)
                    Toggle("닉네임·시즌 AP·순위 공개에 동의해요", isOn: $consentOK)
                } footer: {
                    Text("서버에는 닉네임, 시즌별 AP, Apple 계정을 알아볼 수 없게 바꾼 값만 저장돼요. 설정에서 언제든 랭킹 참가를 해제하면 서버 기록이 모두 삭제돼요. 랭킹 보상은 앱 안의 혜택뿐이며 현금·상품은 없어요.")
                }
                Section {
                    if working {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        SignInWithAppleButton(.continue) { req in
                            req.requestedScopes = []
                        } onCompletion: { result in
                            Task { await handle(result) }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .disabled(!(nicknameValid && ageOK && consentOK))
                        .opacity(nicknameValid && ageOK && consentOK ? 1 : 0.4)
                    }
                } footer: {
                    Text("본인 확인을 위해 Apple 계정으로 한 번 더 확인해요. (Apple로 로그인한 계정만 참가할 수 있어요)")
                }
                if let errorText {
                    Text(errorText).foregroundStyle(Theme.rise)
                }
            }
            .navigationTitle("랭킹 참가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        errorText = nil
        guard case .success(let auth) = result,
              let cred = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
            if case .failure(let e) = result, (e as? ASAuthorizationError)?.code == .canceled { return }
            errorText = "Apple 계정 확인에 실패했어요."
            return
        }
        working = true
        defer { working = false }
        do {
            try await ranking.join(identityToken: token, nickname: nickname)
            await ranking.sync(season: wallet.season, ap: wallet.seasonAP, force: true)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// 시즌 등급 배지
struct SeasonTierBadge: View {
    let tier: SeasonTier
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: tier.icon)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tier == .none ? Color.secondary : Color(.systemBackground))
            .frame(width: size, height: size)
            .background(Circle().fill(tier == .none ? Color.clear : Color.primary))
            .overlay(Circle().strokeBorder(Color.primary.opacity(tier == .none ? 0.3 : 0), lineWidth: 1))
            .overlay(alignment: .bottom) {
                if tier == .silver || tier == .gold || tier == .diamond {
                    Text(tier.name).font(.system(size: size * 0.17, weight: .heavy))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color(.systemBackground)))
                        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 0.8))
                        .offset(y: size * 0.12)
                }
            }
            .accessibilityLabel("\(tier.name) 등급")
    }
}

/// 시즌 보상 안내 카드
struct SeasonRewardGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("시즌 종료 보상").font(.title3.weight(.bold))
            ForEach(SeasonTier.allCases.filter { $0 != .none }, id: \.self) { t in
                HStack(spacing: 12) {
                    SeasonTierBadge(tier: t, size: 32)
                    Text(t.name).font(.subheadline.weight(.semibold))
                    Text("\(Fmt.number(Double(t.minAP))) AP 이상").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(t.rewardTradex) TRADEX").font(.subheadline.weight(.semibold))
                }
            }
            Divider()
            Text("랭킹 참가자 최종 순위 보너스: 1위 +5 · 10위 안 +3 · 100위 안 +1 TRADEX")
                .font(.caption).foregroundStyle(.secondary)
            Text("시즌이 끝나면 다음에 앱을 열 때 결과와 보상을 받을 수 있어요. 보상은 앱 안의 모의투자금(TRADEX)뿐이에요.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .tossCard()
    }
}

/// 시즌 종료 결과 화면 (보상 받기)
struct SeasonResultOverlay: View {
    let record: SeasonRecord
    let onClose: () -> Void

    @Environment(Wallet.self) private var wallet
    @Environment(RankingStore.self) private var ranking
    @State private var rank: Int?
    @State private var loadingRank = true
    @State private var claimed: SeasonResult?
    @State private var pop = false

    var body: some View {
        let tier = SeasonTier.tier(for: record.ap)
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("\(record.displayName) 종료").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                SeasonTierBadge(tier: tier, size: 96)
                    .scaleEffect(pop ? 1 : 0.3)
                    .rotationEffect(.degrees(pop ? 0 : -20))
                Text(tier == .none ? "다음 시즌엔 등급에 도전해요" : "\(tier.name) 달성!")
                    .font(.system(size: 28, weight: .heavy))
                HStack(spacing: 24) {
                    stat("AP", Fmt.number(Double(record.ap)))
                    stat("최종 순위", loadingRank ? "…" : (rank.map { "\($0)위" } ?? "-"))
                }
                let reward = tier.rewardTradex + SeasonTier.rankBonus(rank)
                Text(reward > 0 ? "보상 \(reward) TRADEX" : "이번 시즌 보상은 없어요")
                    .font(.headline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
                Button(claimed == nil ? (reward > 0 ? "보상 받기" : "확인") : "확인") {
                    if claimed == nil {
                        claimed = wallet.claimSeasonReward(record, rank: rank)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    onClose()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(loadingRank)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
            rank = await ranking.finalRank(seasonID: record.id)
            loadingRank = false
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(t).font(.caption).foregroundStyle(.secondary)
            Text(v).font(.title3.weight(.bold)).monospacedDigit()
        }
    }
}
