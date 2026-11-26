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
                VStack(spacing: 16) {
                    checkInCard.appear(0)
                    predictionCard.appear(0.06)
                    missionsCard.appear(0.12)
                    quizCard.appear(0.18)
                    Text("보상은 지금 선택한 거래소(\(store.exchange.name))의 현물 지갑으로 들어가요. 모든 보상은 앱 안에서만 쓰는 모의투자금이며, 현금·상품으로 바꿀 수 없어요.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Theme.background)
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

    // MARK: - 출석체크

    private var checkInCard: some View {
        let done = wallet.checkedIn(on: today)
        let streak = wallet.currentStreak(today: today)
        let inWeek = streak == 0 ? 0 : ((streak - 1) % DailyRules.streakBonusEvery) + 1
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("출석체크", systemImage: "calendar.badge.checkmark").font(.headline)
                Spacer()
                Text("\(streak)일 연속").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(1...DailyRules.streakBonusEvery, id: \.self) { i in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(i <= inWeek ? Color.primary : Color(.systemBackground))
                                .overlay(Circle().strokeBorder(Color.primary, lineWidth: i <= inWeek ? 0 : 1))
                                .scaleEffect(i == inWeek && done ? 1.08 : 1)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(Double(i) * 0.04), value: inWeek)
                            if i == DailyRules.streakBonusEvery {
                                Image(systemName: "gift").font(.caption)
                                    .foregroundStyle(i <= inWeek ? Color(.systemBackground) : .primary)
                            } else if i <= inWeek {
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color(.systemBackground))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 32, height: 32)
                        Text("\(i)일").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("매일 \(Fmt.krw(DailyRules.checkInReward)), \(DailyRules.streakBonusEvery)일 연속이면 \(Fmt.krw(DailyRules.streakBonus)) 추가")
                .font(.caption).foregroundStyle(.secondary)
            Button(done ? "오늘 출석 완료" : "출석하고 \(Fmt.krw(DailyRules.checkInReward)) 받기") {
                Task { await checkIn() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(done || busy || serverOffset == nil)
            .opacity(done ? 0.4 : 1)
        }
        .card()
    }

    // MARK: - 오를까 내릴까

    private var predictionCard: some View {
        let round = PredictionRound.upcoming(at: serverNow ?? Date())
        let coin = round.market(from: store.markets)
        let mine = wallet.prediction(for: round.key)
        return NavigationLink {
            PredictionGameView()
        } label: {
            HStack(spacing: 14) {
                if let coin { CoinIcon(symbol: coin.symbol, size: 44) }
                VStack(alignment: .leading, spacing: 3) {
                    Text("내일 오를까? 내릴까?").font(.headline)
                    Text(mine.map { "\($0.koreanName) · \($0.choice.title) 참여 완료" }
                         ?? "\(coin?.koreanName ?? "오늘의 코인") 맞히면 \(Fmt.krw(TradexRules.predictionRewardKRW))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: - 미션

    private var missionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("오늘의 미션", systemImage: "target").font(.headline)
            ForEach(Mission.all) { m in
                let progress = wallet.missionProgress(m, today: today)
                let claimed = wallet.missionClaimed(m, today: today)
                HStack(spacing: 12) {
                    Image(systemName: m.icon)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.title).font(.subheadline.weight(.medium))
                        Text("\(progress)/\(m.goal) · \(Fmt.krw(m.reward))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Button {
                        Task { await claim(m) }
                    } label: {
                        Text(claimed ? "완료" : "받기")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .bwBackground(selected: progress >= m.goal && !claimed)
                            .opacity(progress >= m.goal || claimed ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: claimed)
                    .disabled(claimed || progress < m.goal || busy || serverOffset == nil)
                }
            }
        }
        .card()
    }

    // MARK: - 퀴즈

    private var quizCard: some View {
        let questions = QuizQuestion.today(today)
        let answered = questions.filter { wallet.quizAnswer($0, today: today) != nil }.count
        return NavigationLink {
            QuizView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("오늘의 투자 퀴즈").font(.headline)
                    Text("\(answered)/\(questions.count) 풀었어요 · 맞히면 문제당 \(Fmt.krw(DailyRules.quizReward))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
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
