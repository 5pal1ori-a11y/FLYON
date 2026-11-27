import SwiftUI

/// 혜택 탭: 출석체크 · 오를까 내릴까 · 오늘의 미션 · 오늘의 퀴즈
struct RewardsView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    /// 업비트 서버 시간 - 기기 시간
    @State private var serverOffset: TimeInterval?
    @State private var toast: String?
    @State private var errorText: String?
    @State private var busy = false

    private var serverNow: Date? { serverOffset.map { Date().addingTimeInterval($0) } }
    private var today: String { KST.dayKey(serverNow ?? Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SeasonSummaryView().tossCard().appear(0)
                    LevelSummaryView().tossCard().appear(0.02)
                    summarySection.tossCard().appear(0.03)
                    attendanceSection.tossCard().appear(0.05)
                    gamesSection.tossCard(padding: 20).appear(0.1)
                    missionsSection.tossCard().appear(0.15)
                    Text("보상은 지금 선택한 거래소(\(store.exchange.name))의 현물 지갑으로 들어가요. 모든 보상은 앱 안에서만 쓰는 모의투자금이며, 현금·상품으로 바꿀 수 없어요.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .background(Theme.tossBackground)
            .navigationTitle("혜택")
            .task { await syncTime() }
            .refreshable { await syncTime() }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert("알림", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("확인", role: .cancel) {}
            } message: { Text(errorText ?? "") }
        }
    }

    /// 섹션 사이 굵은 구분 띠 (박스 대신)
    private var band: some View {
        Rectangle().fill(Theme.background).frame(height: 10).padding(.horizontal, -20)
    }

    private func sectionTitle(_ title: String, trailing: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let trailing { Text(trailing).font(.subheadline).foregroundStyle(.secondary).monospacedDigit() }
        }
        .padding(.bottom, 6)
    }

    // MARK: - 오늘 남은 혜택 요약

    private var summarySection: some View {
        let round = PredictionRound.upcoming(at: serverNow ?? Date())
        let checked = wallet.checkedIn(on: today)
        let streak = wallet.currentStreak(today: today)
        let quizLeft = QuizQuestion.today(today).filter { wallet.quizAnswer($0, today: today) == nil }.count
        let missionsLeft = Mission.all.filter { !wallet.missionClaimed($0, today: today) }
        let predicted = wallet.prediction(for: round.key) != nil
        let attendance = checked ? 0 : DailyRules.checkInReward
            + ((streak + 1) % DailyRules.streakBonusEvery == 0 ? DailyRules.streakBonus : 0)
        let left = attendance
            + missionsLeft.reduce(0) { $0 + $1.reward }
            + Double(quizLeft) * DailyRules.quizReward
            + (predicted ? 0 : TradexRules.predictionRewardKRW)
        let total = 1 + Mission.all.count + DailyRules.quizPerDay + 1
        let done = (checked ? 1 : 0) + (Mission.all.count - missionsLeft.count) + (DailyRules.quizPerDay - quizLeft) + (predicted ? 1 : 0)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("오늘 받을 수 있는 혜택").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Icon3D(name: "gift", size: 46, float: true).padding(.top, -6)
            }
            Text(left > 0 ? "최대 \(Fmt.krw(left))" : "오늘 혜택을 모두 받았어요")
                .font(.system(size: 28, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: left))
                .animation(.snappy, value: left)
            HStack(spacing: 10) {
                ProgressBar(value: Double(done) / Double(total))
                Text("\(done)/\(total) 완료").font(.caption.weight(.semibold)).monospacedDigit()
            }
        }
    }

    // MARK: - 출석체크

    private var attendanceSection: some View {
        let done = wallet.checkedIn(on: today)
        let streak = wallet.currentStreak(today: today)
        let inWeek = streak == 0 ? 0 : ((streak - 1) % DailyRules.streakBonusEvery) + 1
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Icon3D(name: "calendar", size: 30)
                Text("출석체크").font(.title3.weight(.bold))
                Spacer()
                if streak > 0 { Icon3D(name: "fire", size: 20) }
                Text("\(streak)일 연속").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.bottom, 6)
            HStack(spacing: 0) {
                ForEach(1...DailyRules.streakBonusEvery, id: \.self) { i in
                    let filled = i <= inWeek
                    let bonus = i == DailyRules.streakBonusEvery
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(filled ? Color.primary : Color.clear)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(filled ? 0 : 0.25), lineWidth: 1))
                                .scaleEffect(i == inWeek && done ? 1.08 : 1)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(Double(i) * 0.04), value: inWeek)
                            if bonus {
                                Icon3D(name: "gift", size: 24, dim: false)
                            } else if filled {
                                Image(systemName: "checkmark").font(.footnote.bold()).foregroundStyle(Color(.systemBackground))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 34, height: 34)
                        Text(bonus ? "보너스" : "\(i)일").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("매일 \(Fmt.krw(DailyRules.checkInReward))").font(.subheadline.weight(.semibold))
                    Text("\(DailyRules.streakBonusEvery)일 연속이면 \(Fmt.krw(DailyRules.streakBonus)) 더")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(done ? "출석 완료" : "출석하기") { Task { await checkIn() } }
                    .buttonStyle(PillButtonStyle(filled: !done))
                    .disabled(done || busy || serverOffset == nil)
            }
        }
    }

    // MARK: - 미니게임 (오를까 내릴까 · 퀴즈)

    private var gamesSection: some View {
        let round = PredictionRound.upcoming(at: serverNow ?? Date())
        let coin = round.market(from: store.markets)
        let mine = wallet.prediction(for: round.key)
        let questions = QuizQuestion.today(today)
        let answered = questions.filter { wallet.quizAnswer($0, today: today) != nil }.count
        return VStack(alignment: .leading, spacing: 0) {
            sectionTitle("미니게임")
            NavigationLink {
                PredictionGameView()
            } label: {
                gameRow(icon: AnyView(Icon3D(name: "alarm", size: 40)),
                        title: "내일 오를까? 내릴까?",
                        subtitle: "\(coin?.koreanName ?? "오늘의 코인") 맞히면 \(Fmt.krw(TradexRules.predictionRewardKRW))",
                        status: mine.map { "\($0.choice.title) 참여" } ?? "참여하기",
                        done: mine != nil)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 54)
            NavigationLink {
                QuizView()
            } label: {
                gameRow(icon: AnyView(Icon3D(name: "grad", size: 40)),
                        title: "오늘의 투자 퀴즈",
                        subtitle: "맞히면 문제당 \(Fmt.krw(DailyRules.quizReward))",
                        status: "\(answered)/\(questions.count)",
                        done: answered == questions.count)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 54)
            NavigationLink {
                ChartGameView()
            } label: {
                let left = wallet.chartGameRewardedLeft(today: today)
                gameRow(icon: AnyView(Icon3D(name: "chart", size: 40)),
                        title: "과거 차트 맞히기",
                        subtitle: "지난 차트의 다음 10시간 맞히면 \(Fmt.krw(ChartGameRules.reward))",
                        status: left > 0 ? "\(left)판 남음" : "연습",
                        done: left == 0)
            }
            .buttonStyle(.plain)
        }
    }

    private func gameRow(icon: AnyView, title: String, subtitle: String, status: String, done: Bool) -> some View {
        HStack(spacing: 14) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                if done { Image(systemName: "checkmark").font(.caption.bold()) }
                Text(status).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .foregroundStyle(done ? .secondary : .primary)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - 미션

    private var missionsSection: some View {
        let claimedCount = Mission.all.filter { wallet.missionClaimed($0, today: today) }.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Icon3D(name: "target", size: 30)
                Text("오늘의 미션").font(.title3.weight(.bold))
                Spacer()
                Text("\(claimedCount)/\(Mission.all.count)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.bottom, 6)
            ForEach(Mission.all) { m in
                missionRow(m)
                if m.id != Mission.all.last?.id { Divider().padding(.leading, 54) }
            }
        }
    }

    private func missionRow(_ m: Mission) -> some View {
        let progress = wallet.missionProgress(m, today: today)
        let claimed = wallet.missionClaimed(m, today: today)
        let ready = progress >= m.goal && !claimed
        return HStack(spacing: 14) {
            Icon3D(name: m.icon3D, size: 38, dim: claimed)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(m.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(claimed ? .secondary : .primary)
                        .strikethrough(claimed, color: .secondary)
                    Spacer()
                    Text("+\(Fmt.man(m.reward))").font(.caption.weight(.bold))
                        .foregroundStyle(claimed ? .secondary : .primary)
                }
                HStack(spacing: 8) {
                    ProgressBar(value: Double(progress) / Double(m.goal), tint: claimed ? .secondary : .primary, height: 4)
                    Text("\(progress)/\(m.goal)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Button(claimed ? "완료" : "받기") { Task { await claim(m) } }
                .buttonStyle(PillButtonStyle(filled: ready))
                .disabled(!ready || busy || serverOffset == nil)
                .opacity(ready || claimed ? 1 : 0.35)
                .sensoryFeedback(.success, trigger: claimed)
        }
        .padding(.vertical, 12)
    }

    // MARK: - 동작

    private func syncTime() async {
        if let s = try? await UpbitAPI.serverNow() { serverOffset = s.timeIntervalSince(Date()) }
    }

    private func checkIn() async {
        busy = true; defer { busy = false }
        do {
            let now = try await UpbitAPI.serverNow()
            serverOffset = now.timeIntervalSince(Date())
            let r = try wallet.checkIn(serverNow: now, creditTo: store.exchange)
            show(r.bonus > 0 ? "🎁 \(r.streak)일 연속! \(Fmt.krw(r.reward + r.bonus)) 받았어요" : "출석 완료! \(Fmt.krw(r.reward)) 받았어요")
        } catch let e as Wallet.DailyError {
            errorText = e.localizedDescription
        } catch {
            errorText = Wallet.PredictionError.noServerTime.localizedDescription
        }
    }

    private func claim(_ m: Mission) async {
        busy = true; defer { busy = false }
        do {
            let now = try await UpbitAPI.serverNow()
            serverOffset = now.timeIntervalSince(Date())
            try wallet.claimMission(m, serverNow: now, creditTo: store.exchange)
            show("미션 완료! \(Fmt.krw(m.reward)) 받았어요 (\(store.exchange.name) 현물)")
        } catch let e as Wallet.DailyError {
            errorText = e.localizedDescription
        } catch {
            errorText = Wallet.PredictionError.noServerTime.localizedDescription
        }
    }

    private func show(_ text: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.snappy) { toast = nil }
        }
    }
}

struct QuizView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var serverOffset: TimeInterval?
    @State private var errorText: String?

    private var today: String { KST.dayKey(serverOffset.map { Date().addingTimeInterval($0) } ?? Date()) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(QuizQuestion.today(today).enumerated()), id: \.element.id) { index, q in
                    questionCard(index + 1, q)
                }
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(Theme.rise)
                }
                Text("퀴즈는 투자 공부를 돕기 위한 일반 지식이며 특정 코인을 권하지 않아요.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("오늘의 퀴즈")
        .task {
            if let s = try? await UpbitAPI.serverNow() { serverOffset = s.timeIntervalSince(Date()) }
        }
    }

    private func questionCard(_ number: Int, _ q: QuizQuestion) -> some View {
        let picked = wallet.quizAnswer(q, today: today)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Q\(number). \(q.question)").font(.headline)
            ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                Button {
                    Task { await answer(q, i) }
                } label: {
                    HStack {
                        Text(choice).font(.subheadline).multilineTextAlignment(.leading)
                        Spacer()
                        if let picked {
                            if i == q.answer { Image(systemName: "checkmark.circle").foregroundStyle(.primary) }
                            else if i == picked { Image(systemName: "xmark.circle").foregroundStyle(.primary) }
                        }
                    }
                    .padding(12)
                    .bwBackground(selected: picked != nil && i == q.answer, cornerRadius: 10)
                    .opacity(picked != nil && i != q.answer && i != picked ? 0.45 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: picked)
                }
                .buttonStyle(.plain)
                .disabled(picked != nil || serverOffset == nil)
            }
            if let picked {
                Text(picked == q.answer ? "정답! \(Fmt.krw(DailyRules.quizReward)) 지급" : "아쉬워요, 오답이에요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(picked == q.answer ? .green : Theme.rise)
                Text(q.explanation).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func answer(_ q: QuizQuestion, _ choice: Int) async {
        do {
            let now = try await UpbitAPI.serverNow()
            serverOffset = now.timeIntervalSince(Date())
            let correct = try wallet.answerQuiz(q, choice: choice, serverNow: now, creditTo: store.exchange)
            UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        } catch let e as Wallet.DailyError {
            errorText = e.localizedDescription
        } catch {
            errorText = Wallet.PredictionError.noServerTime.localizedDescription
        }
    }
}
