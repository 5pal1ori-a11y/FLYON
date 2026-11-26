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
                VStack(alignment: .leading, spacing: 30) {
                    heroCard
                    checkInSection
                    gamesSection
                    missionsSection
                    Text("보상은 지금 선택한 거래소(\(store.exchange.name))의 현물 지갑으로 들어가요. 모든 보상은 앱 안에서만 쓰는 모의투자금이며 현금·상품으로 바꿀 수 없어요.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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

    // MARK: - 오늘의 진행 (요약)

    /// 오늘 할 수 있는 일: 출석 1 + 미션 4 + 퀴즈 3 + 예측 1
    private var todayProgress: (done: Int, total: Int) {
        let quiz = QuizQuestion.today(today).filter { wallet.quizAnswer($0, today: today) != nil }.count
        let missions = Mission.all.filter { wallet.missionClaimed($0, today: today) }.count
        let predicted = wallet.prediction(for: PredictionRound.upcoming(at: serverNow ?? Date()).key) != nil ? 1 : 0
        let checked = wallet.checkedIn(on: today) ? 1 : 0
        return (checked + missions + quiz + predicted, 1 + Mission.all.count + DailyRules.quizPerDay + 1)
    }

    private var heroCard: some View {
        let p = todayProgress
        let ratio = Double(p.done) / Double(max(p.total, 1))
        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("오늘의 혜택").font(.subheadline).opacity(0.7)
                Text(p.done == p.total ? "오늘 혜택을 모두 받았어요" : "\(p.total - p.done)개 남았어요")
                    .font(.title2.weight(.bold))
                Text("출석 · 미션 · 퀴즈 · 오를까 내릴까").font(.caption).opacity(0.6)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color(.systemBackground).opacity(0.2), lineWidth: 7)
                Circle().trim(from: 0, to: ratio)
                    .stroke(Color(.systemBackground), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: ratio)
                Text("\(p.done)/\(p.total)").font(.subheadline.weight(.bold)).monospacedDigit()
            }
            .frame(width: 66, height: 66)
        }
        .foregroundStyle(Color(.systemBackground))
        .padding(20)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 출석체크

    private var checkInSection: some View {
        let done = wallet.checkedIn(on: today)
        let streak = wallet.currentStreak(today: today)
        let inWeek = streak == 0 ? 0 : ((streak - 1) % DailyRules.streakBonusEvery) + 1
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("출석체크") {
                Label("\(streak)일 연속", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
            }
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    ForEach(1...DailyRules.streakBonusEvery, id: \.self) { i in
                        let filled = i <= inWeek
                        let isBonus = i == DailyRules.streakBonusEvery
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(filled ? (isBonus ? Color.orange : Color.primary) : Color.primary.opacity(0.06))
                                Image(systemName: isBonus ? "gift.fill" : (filled ? "checkmark" : "circle.fill"))
                                    .font(.system(size: isBonus ? 14 : (filled ? 13 : 5), weight: .bold))
                                    .foregroundStyle(filled ? Color(.systemBackground) : (isBonus ? .orange : Color.primary.opacity(0.2)))
                            }
                            .frame(width: 36, height: 36)
                            Text(isBonus ? "보너스" : "\(i)일")
                                .font(.caption2.weight(i == inWeek ? .bold : .regular))
                                .foregroundStyle(isBonus ? .orange : .secondary)
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
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    // MARK: - 게임 타일 (오를까 내릴까 · 퀴즈)

    private var gamesSection: some View {
        let round = PredictionRound.upcoming(at: serverNow ?? Date())
        let coin = round.market(from: store.markets)
        let mine = wallet.prediction(for: round.key)
        let questions = QuizQuestion.today(today)
        let answered = questions.filter { wallet.quizAnswer($0, today: today) != nil }.count
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("미니게임")
            HStack(spacing: 12) {
                NavigationLink {
                    PredictionGameView()
                } label: {
                    gameTile(
                        icon: AnyView(coin.map { AnyView(CoinIcon(symbol: $0.symbol, size: 34)) }
                                      ?? AnyView(IconTile(systemName: "chart.line.uptrend.xyaxis", tint: Theme.rise))),
                        title: "오를까 내릴까",
                        subtitle: mine.map { "\($0.choice.title) 참여 완료" } ?? "\(coin?.koreanName ?? "오늘의 코인") 맞히기",
                        reward: "적중 \(Fmt.man(TradexRules.predictionRewardKRW)) 원",
                        done: mine != nil)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    QuizView()
                } label: {
                    gameTile(
                        icon: AnyView(IconTile(systemName: "graduationcap.fill", tint: .indigo)),
                        title: "오늘의 퀴즈",
                        subtitle: "\(answered)/\(questions.count) 풀었어요",
                        reward: "문제당 \(Fmt.man(DailyRules.quizReward)) 원",
                        done: answered == questions.count)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func gameTile(icon: AnyView, title: String, subtitle: String, reward: String, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                icon
                Spacer()
                if done {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(reward)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    // MARK: - 미션

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("오늘의 미션") {
                Text("\(Mission.all.filter { wallet.missionClaimed($0, today: today) }.count)/\(Mission.all.count)")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            VStack(spacing: 0) {
                ForEach(Mission.all) { m in
                    missionRow(m)
                    if m.id != Mission.all.last?.id { Divider().padding(.leading, 50) }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private func missionRow(_ m: Mission) -> some View {
        let progress = wallet.missionProgress(m, today: today)
        let claimed = wallet.missionClaimed(m, today: today)
        let ready = progress >= m.goal && !claimed
        let tint: Color = switch m.id {
        case "buy": .orange
        case "predict": Theme.rise
        case "chart": .teal
        default: .indigo
        }
        return HStack(spacing: 14) {
            IconTile(systemName: m.icon, tint: claimed ? .gray : tint)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(m.title).font(.subheadline.weight(.semibold))
                        .strikethrough(claimed, color: .secondary)
                        .foregroundStyle(claimed ? .secondary : .primary)
                    Spacer()
                    Text("+\(Fmt.man(m.reward))").font(.caption.weight(.bold))
                        .foregroundStyle(claimed ? .secondary : .primary)
                }
                HStack(spacing: 8) {
                    ProgressBar(value: Double(progress) / Double(m.goal), tint: claimed ? .gray : tint)
                    Text("\(progress)/\(m.goal)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Button(claimed ? "완료" : "받기") { Task { await claim(m) } }
                .buttonStyle(PillButtonStyle(filled: ready))
                .disabled(!ready || busy || serverOffset == nil)
                .opacity(ready || claimed ? 1 : 0.4)
        }
        .padding(.vertical, 14)
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
                            if i == q.answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            else if i == picked { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.rise) }
                        }
                    }
                    .padding(12)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(picked != nil && i == q.answer ? Color.green : .clear, lineWidth: 1.5))
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
