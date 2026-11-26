import SwiftUI
import Charts

/// 과거 차트 맞히기: 실제 지난 1시간 봉 차트 40개를 보여 주고, 10시간 뒤 오를지 내릴지 맞힌다.
/// 문제를 푸는 동안 코인 이름과 날짜는 가린다.
struct ChartGameView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    struct Round {
        let market: Market
        let points: [ChartPoint]   // visible + hidden
        var startPrice: Double { points[ChartGameRules.visible - 1].price }
        var endPrice: Double { points[points.count - 1].price }
        var answer: PredictionChoice? { endPrice == startPrice ? nil : (endPrice > startPrice ? .up : .down) }
    }

    @State private var round: Round?
    @State private var shown = ChartGameRules.visible
    @State private var guess: PredictionChoice?
    @State private var reward: Double = 0
    @State private var loading = false
    @State private var errorText: String?
    @State private var today = KST.dayKey(.now)
    @State private var streak = 0

    private var revealed: Bool { guess != nil && shown == round?.points.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                chart
                    .frame(height: 260)
                if let round, revealed { resultView(round) } else { choiceButtons }
                Text("실제 \(store.exchange.name) 1시간 봉 기록이에요. 하루 \(ChartGameRules.rewardedPerDay)판까지 맞히면 \(Fmt.krw(ChartGameRules.reward))과 경험치를 받고, 그 뒤로는 연습으로 계속할 수 있어요.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .navigationTitle("차트 맞히기")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let s = try? await UpbitAPI.serverNow() { today = KST.dayKey(s) }
            if round == nil { await newRound() }
        }
    }

    private var header: some View {
        let left = wallet.chartGameRewardedLeft(today: today)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(revealed ? (round.map { "\($0.market.koreanName) (\($0.market.symbol))" } ?? "") : "이 코인, 10시간 뒤엔?")
                    .font(.title2.weight(.bold))
                    .contentTransition(.opacity)
                Spacer()
                if streak > 1 {
                    Label("\(streak)연속", systemImage: "flame").font(.subheadline.weight(.semibold))
                }
            }
            Text(revealed ? (round.map { dateRange($0) } ?? "") : "코인과 날짜는 정답 공개 때 알려 줘요")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(left > 0 ? "오늘 보상 남은 판 \(left)/\(ChartGameRules.rewardedPerDay)" : "오늘 보상은 모두 받았어요 · 연습 모드")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.4), lineWidth: 1))
        }
        .animation(.snappy, value: revealed)
    }

    @ViewBuilder private var chart: some View {
        if let round {
            let visible = Array(round.points.prefix(shown))
            let boundary = ChartGameRules.visible - 1
            let prices = round.points.map(\.price)
            let lo = prices.min() ?? 0, hi = prices.max() ?? 1
            let pad = max((hi - lo) * 0.12, hi * 0.0005)
            let resultColor: Color = round.answer == .up ? Theme.rise : (round.answer == .down ? Theme.fall : .secondary)
            Chart {
                // 정답 구간 (아직 가려진 영역)
                RectangleMark(xStart: .value("시작", boundary), xEnd: .value("끝", round.points.count - 1),
                              yStart: .value("최저", lo - pad), yEnd: .value("최고", hi + pad))
                    .foregroundStyle(Color.primary.opacity(0.05))
                    .annotation(position: .overlay) {
                        if guess == nil {
                            Text("?").font(.system(size: 40, weight: .heavy)).foregroundStyle(.tertiary)
                        }
                    }
                ForEach(Array(visible.enumerated()), id: \.offset) { i, p in
                    LineMark(x: .value("시간", i), y: .value("가격", p.price), series: .value("구간", i <= boundary ? "과거" : "정답"))
                        .foregroundStyle(i <= boundary ? Color.primary : resultColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                }
                // 정답 구간은 경계점부터 이어 그리기
                if shown > ChartGameRules.visible {
                    LineMark(x: .value("시간", boundary), y: .value("가격", round.startPrice), series: .value("구간", "정답"))
                        .foregroundStyle(resultColor)
                }
                RuleMark(x: .value("기준", boundary))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                PointMark(x: .value("기준", boundary), y: .value("가격", round.startPrice))
                    .foregroundStyle(Color.primary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("지금").font(.caption2.weight(.bold))
                    }
            }
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        } else if let errorText {
            VStack(spacing: 12) {
                Text(errorText).font(.footnote).foregroundStyle(.secondary)
                Button("다시 시도") { Task { await newRound() } }.buttonStyle(BWButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var choiceButtons: some View {
        HStack(spacing: 10) {
            choice(.up)
            choice(.down)
        }
        .disabled(round == nil || guess != nil)
    }

    private func choice(_ c: PredictionChoice) -> some View {
        Button {
            Task { await answer(c) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: c == .up ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis").font(.title2)
                Text(c.title).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .bwBackground(selected: guess == c, cornerRadius: 16)
        }
        .buttonStyle(PressScaleStyle())
    }

    private func resultView(_ round: Round) -> some View {
        let correct = guess == round.answer
        let change = round.startPrice > 0 ? round.endPrice / round.startPrice - 1 : 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: round.answer == nil ? "equal.circle" : (correct ? "checkmark.circle" : "xmark.circle"))
                    .font(.system(size: 34, weight: .light))
                    .symbolEffect(.bounce, value: revealed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(round.answer == nil ? "변동 없음" : (correct ? "정답!" : "아쉬워요"))
                        .font(.title3.weight(.bold))
                    Text("10시간 동안 \(Fmt.rate(change)) · ₩\(Fmt.price(round.startPrice)) → ₩\(Fmt.price(round.endPrice))")
                        .font(.subheadline).foregroundStyle(Theme.color(for: change)).monospacedDigit()
                }
            }
            if reward > 0 {
                Text("+\(Fmt.krw(reward)) · +\(XPRule.chartGame.amount + XPRule.chartGameWin.amount) XP")
                    .font(.subheadline.weight(.semibold))
            }
            Button("다음 문제") { Task { await newRound() } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func dateRange(_ r: Round) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "M월 d일 H시"
        guard let a = r.points.first?.date, let b = r.points.last?.date else { return "" }
        return "\(f.string(from: a)) ~ \(f.string(from: b))"
    }

    // MARK: - 동작

    private func newRound() async {
        loading = true
        errorText = nil
        defer { loading = false }
        let pool = Array(store.markets.sorted {
            (store.tickers[$0.market]?.accTradePrice24h ?? 0) > (store.tickers[$1.market]?.accTradePrice24h ?? 0)
        }.prefix(30))
        guard let m = pool.randomElement() else { errorText = "시세를 불러오는 중이에요."; return }
        do {
            let all = try await UpbitAPI.hourCloses(market: m.market, count: 200, on: store.exchange)
            let need = ChartGameRules.visible + ChartGameRules.hidden
            guard all.count >= need + 1 else { throw URLError(.cannotParseResponse) }
            // 가장 최근 구간은 빼고(지금 시세로 답을 알 수 있으므로) 과거 아무 구간이나
            let start = Int.random(in: 0...(all.count - need - 1))
            withAnimation(.snappy) {
                round = Round(market: m, points: Array(all[start..<(start + need)]))
                shown = ChartGameRules.visible
                guess = nil
                reward = 0
            }
        } catch {
            errorText = "차트를 불러오지 못했어요."
        }
    }

    private func answer(_ c: PredictionChoice) async {
        guard let round, guess == nil else { return }
        guess = c
        // 가려 둔 구간을 한 칸씩 그리며 공개
        for i in (ChartGameRules.visible + 1)...round.points.count {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.12)) { shown = i }
        }
        let correct = c == round.answer
        streak = correct ? streak + 1 : 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            reward = round.answer == nil ? 0 : wallet.recordChartGame(correct: correct, today: today, creditTo: store.exchange)
        }
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }
}
