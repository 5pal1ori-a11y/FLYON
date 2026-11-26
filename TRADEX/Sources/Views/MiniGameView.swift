import SwiftUI

/// "내일 오를까? 내릴까?" 게임 화면 (혜택 탭에서 진입)
struct PredictionGameView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    /// 업비트 서버 시간 - 기기 시간 (시계 조작 방지용 보정값)
    @State private var serverOffset: TimeInterval?
    @State private var now = Date()
    @State private var pendingChoice: PredictionChoice?
    @State private var submitting = false
    @State private var errorText: String?
    @State private var results: [Prediction] = []

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var serverNow: Date? { serverOffset.map { now.addingTimeInterval($0) } }
    private var round: PredictionRound { .upcoming(at: serverNow ?? now) }
    private var coin: Market? { round.market(from: store.markets) }
    private var myPick: Prediction? { wallet.prediction(for: round.key) }
    private var waiting: [Prediction] {
        wallet.state.predictions.filter { $0.status == .pending && $0.roundKey != round.key }
    }

    var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    if let coin {
                        questionCard(coin)
                    } else {
                        ProgressView().padding(.top, 80)
                    }
                    if !waiting.isEmpty { waitingCard }
                    rulesCard
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("오를까 내릴까")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("이전 내역") { PredictionHistoryView() }
                }
            }
            .task { await refresh() }
            .refreshable { await refresh() }
            .onReceive(ticker) { date in
                now = date
                // 결과 시각이 지나면 자동 판정
                if let s = serverNow, waiting.contains(where: { PredictionRound(key: $0.roundKey).map { s >= $0.end } ?? false }),
                   Int(date.timeIntervalSince1970) % 30 == 0 {
                    Task { await settle() }
                }
            }
            .confirmationDialog(confirmTitle, isPresented: Binding(get: { pendingChoice != nil }, set: { if !$0 { pendingChoice = nil } }),
                                titleVisibility: .visible) {
                if let choice = pendingChoice {
                    Button("\(choice.title)로 참여하기") { Task { await submit(choice) } }
                }
            } message: {
                Text("한 라운드에 한 번만 참여할 수 있고, 참여 후에는 바꿀 수 없어요.")
            }
            .alert(resultTitle, isPresented: Binding(get: { !results.isEmpty }, set: { if !$0 { results = [] } })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(resultMessage)
            }
    }

    // MARK: - 문제 카드

    private func questionCard(_ coin: Market) -> some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                CoinIcon(symbol: coin.symbol, size: 84)
                Image(systemName: "clock")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Theme.card, in: Circle())
                    .offset(x: 6, y: 6)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(coin.koreanName).font(.title3.bold())
                Text("내일 오를까? 내릴까?").font(.title2.weight(.heavy))
                Text("맞히면 모의투자금 \(Fmt.krw(TradexRules.predictionRewardKRW)) 지급")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("(\(KST.dayHour(round.start)) → \(KST.dayHour(round.end)), 업비트 일봉 기준)")
                    .font(.caption).foregroundStyle(.secondary)
                if let t = store.tickers[coin.market] {
                    HStack(spacing: 6) {
                        Text("현재 ₩\(Fmt.price(t.tradePrice))").monospacedDigit()
                        RateBadge(rate: t.signedChangeRate)
                    }
                    .font(.caption)
                    .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 12) {
                choiceCard(.up, coin: coin)
                choiceCard(.down, coin: coin)
            }

            Group {
                if let pick = myPick {
                    Text("\(pick.choice.title)에 참여했어요 · 결과 \(KST.dayHour(round.end)) 발표")
                } else if serverOffset == nil {
                    Text("서버 시간 확인 중…")
                } else {
                    Text("\(KST.dayHour(round.start))까지 참여 가능 · 남은 시간 \(remaining(until: round.start))")
                        .monospacedDigit()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let errorText {
                Text(errorText).font(.footnote.weight(.medium)).foregroundStyle(Theme.rise)
            }
        }
        .card()
    }

    private func choiceCard(_ choice: PredictionChoice, coin: Market) -> some View {
        let color = choice == .up ? Theme.rise : Theme.fall
        let picked = myPick?.choice == choice
        let locked = myPick != nil || serverOffset == nil || submitting
        return VStack(spacing: 10) {
            Image(systemName: choice == .up ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.primary)
            Text(choice.title).font(.headline).foregroundStyle(color)
            Button {
                errorText = nil
                pendingChoice = choice
            } label: {
                Text(picked ? "내 선택" : "선택")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .bwBackground(selected: true)
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .opacity(locked && !picked ? 0.3 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.primary, lineWidth: picked ? 2 : 0.5))
        .scaleEffect(picked ? 1.03 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: picked)
    }

    // MARK: - 결과 대기 / 규칙

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("결과 대기 중").font(.subheadline.weight(.semibold))
            ForEach(waiting) { p in
                HStack {
                    CoinIcon(symbol: String(p.market.dropFirst(4)), size: 28)
                    Text(p.koreanName).font(.subheadline)
                    Text(p.choice.title).font(.caption.weight(.bold))
                        .foregroundStyle(p.choice == .up ? Theme.rise : Theme.fall)
                    Spacer()
                    if let r = PredictionRound(key: p.roundKey) {
                        Text("\(KST.dayHour(r.end)) 발표").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("참여 방법").font(.subheadline.weight(.semibold))
            Group {
                Text("• 매일 오전 9시에 시작하는 하루(24시간) 동안 코인 가격이 오를지 내릴지 맞혀요.")
                Text("• 오전 9시 전까지 하루 한 번, 무료로 참여할 수 있어요.")
                Text("• 다음 날 오전 9시에 업비트 일봉(전일 종가 대비)으로 결과가 나와요. 가격이 같으면 무승부예요.")
                Text("• 보상은 앱 안에서만 쓰는 모의투자금이며 현금·상품으로 바꿀 수 없어요.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 동작

    private var confirmTitle: String {
        guard let c = pendingChoice, let coin else { return "" }
        return "\(coin.koreanName), 내일 \(c.title)?"
    }

    private var resultTitle: String {
        results.contains { $0.status == .won } ? "적중! 🎉" : "결과가 나왔어요"
    }

    private var resultMessage: String {
        results.map { p in
            let rate = p.changeRate.map { Fmt.rate($0) } ?? "-"
            switch p.status {
            case .won: return "\(p.koreanName) \(p.choice.title) 적중 (\(rate)) · \(Fmt.krw(p.reward)) 지급"
            case .lost: return "\(p.koreanName) \(p.choice.title) 빗나감 (\(rate))"
            case .draw: return "\(p.koreanName) 무승부 (\(rate))"
            case .pending: return ""
            }
        }.joined(separator: "\n")
    }

    private func refresh() async {
        await syncServerTime()
        await settle()
    }

    private func syncServerTime() async {
        if let server = try? await UpbitAPI.serverNow() {
            serverOffset = server.timeIntervalSince(Date())
            now = Date()
        }
    }

    private func settle() async {
        let settled = await wallet.settlePendingPredictions(creditTo: store.exchange)
        if !settled.isEmpty {
            results = settled
            UINotificationFeedbackGenerator().notificationOccurred(settled.contains { $0.status == .won } ? .success : .warning)
        }
    }

    private func submit(_ choice: PredictionChoice) async {
        guard let coin else { return }
        submitting = true
        defer { submitting = false }
        do {
            // 제출 순간의 서버 시간으로 마감 여부를 다시 확인
            let server = try await UpbitAPI.serverNow()
            serverOffset = server.timeIntervalSince(Date())
            try wallet.placePrediction(round: round, market: coin, choice: choice, serverNow: server)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let e as Wallet.PredictionError {
            errorText = e.localizedDescription
        } catch {
            errorText = Wallet.PredictionError.noServerTime.localizedDescription
        }
    }

    private func remaining(until date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(serverNow ?? now)))
        return String(format: "%02d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    }
}

/// 한국시간 표시
enum KST {
    private static let dayHourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "M월 d일 H시"
        return f
    }()
    static func dayHour(_ d: Date) -> String { dayHourFormatter.string(from: d) }
}

struct PredictionHistoryView: View {
    @Environment(Wallet.self) private var wallet

    private var stats: (won: Int, total: Int, reward: Double) {
        let done = wallet.state.predictions.filter { $0.status != .pending }
        return (done.filter { $0.status == .won }.count, done.count, done.reduce(0) { $0 + $1.reward })
    }

    var body: some View {
        List {
            Section {
                HStack {
                    stat("적중", "\(stats.won)/\(stats.total)")
                    stat("적중률", stats.total > 0 ? "\(Int(Double(stats.won) / Double(stats.total) * 100))%" : "-")
                    stat("받은 보상", Fmt.krw(stats.reward))
                }
            }
            Section("기록") {
                if wallet.state.predictions.isEmpty {
                    Text("아직 참여 기록이 없어요.").foregroundStyle(.secondary)
                }
                ForEach(wallet.state.predictions) { p in
                    HStack(spacing: 12) {
                        CoinIcon(symbol: String(p.market.dropFirst(4)), size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(p.koreanName) · \(p.choice.title)").font(.subheadline.weight(.semibold))
                            Text(PredictionRound(key: p.roundKey).map { "\(KST.dayHour($0.start)) 일봉" } ?? p.roundKey)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            badge(p.status)
                            if let r = p.changeRate {
                                Text(Fmt.rate(r)).font(.caption).monospacedDigit().foregroundStyle(Theme.color(for: r))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("이전 내역")
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func badge(_ s: PredictionStatus) -> some View {
        let (text, color): (String, Color) = switch s {
        case .pending: ("대기", .secondary)
        case .won: ("적중", Theme.rise)
        case .lost: ("실패", Theme.fall)
        case .draw: ("무승부", .secondary)
        }
        return Text(text).font(.caption.weight(.bold)).foregroundStyle(color)
    }
}
