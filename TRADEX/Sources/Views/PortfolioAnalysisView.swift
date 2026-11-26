import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 내 모의투자 분석 — 숫자는 앱이 정확히 계산하고, Apple Intelligence(기기 내 모델)는 그 숫자를 쉬운 말로 풀어 준다.
/// - 데이터는 기기 밖으로 나가지 않는다 (온디바이스 모델).
/// - 특정 코인 매수·매도·보유 권유, 가격 예측은 하지 않도록 지시한다. (투자 조언이 아닌 학습용)
struct PortfolioAnalysisView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet

    @State private var output = ""
    @State private var running = false
    @State private var errorText: String?

    private var stats: PortfolioStats { PortfolioStats(wallet: wallet, prices: store.tickers) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statsCard
                aiCard
                Text("이 분석은 모의투자 기록을 바탕으로 한 학습용 요약이며 투자 권유가 아니에요. 분석은 기기 안에서만 처리돼요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("AI 투자 분석")
    }

    // MARK: - 숫자 요약 (앱 계산)

    private var statsCard: some View {
        let s = stats
        return VStack(alignment: .leading, spacing: 12) {
            Text("한눈에 보기").font(.headline)
            row("총 수익률", Fmt.rate(s.totalReturn), Theme.color(for: s.totalReturn))
            row("현금 비중", percent(s.cashRatio))
            row("보유 코인", "\(s.holdings.count)개")
            if let top = s.holdings.first {
                row("가장 큰 비중", "\(top.name) \(percent(top.weight))")
            }
            row("거래 횟수", "매수 \(s.buyCount) · 매도 \(s.sellCount) (최근 7일 \(s.recentTrades))")
            if s.sellCount > 0 {
                row("수익 낸 매도", "\(s.winningSells)/\(s.sellCount)")
                row("실현 손익", "\(Fmt.signedKRW(s.realizedPnL))원", Theme.color(for: s.realizedPnL))
            }
            if s.predictionsDone > 0 {
                row("오를까 내릴까 적중", "\(s.predictionsWon)/\(s.predictionsDone)")
            }
        }
        .card()
    }

    private func row(_ title: String, _ value: String, _ color: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(color).monospacedDigit()
        }
        .font(.subheadline)
    }

    private func percent(_ v: Double) -> String { String(format: "%.0f%%", v * 100) }

    // MARK: - Apple Intelligence

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Intelligence 분석", systemImage: "sparkles").font(.headline)
            switch AIAvailability.current {
            case .available:
                if output.isEmpty && !running {
                    Text("내 투자 습관을 기기 안의 AI가 분석해요.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(output.isEmpty ? "분석 중…" : output)
                        .font(.subheadline)
                        .textSelection(.enabled)
                    if !output.isEmpty {
                        Text("Apple Intelligence로 생성된 내용이에요. 정확하지 않을 수 있어요.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(Theme.rise)
                }
                Button(running ? "분석 중…" : (output.isEmpty ? "분석하기" : "다시 분석하기")) {
                    Task { await analyze() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(running)
            case let unavailable:
                Text(unavailable.message).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func analyze() async {
        running = true
        errorText = nil
        output = ""
        defer { running = false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: PortfolioStats.instructions)
                let stream = session.streamResponse(to: stats.prompt)
                for try await partial in stream {
                    output = partial.content
                }
            } catch {
                errorText = "분석하지 못했어요. 잠시 후 다시 시도해 주세요. (기기 언어가 지원되지 않으면 실패할 수 있어요)"
            }
        }
        #endif
    }
}

enum AIAvailability {
    case available, unsupportedOS, deviceNotEligible, notEnabled, notReady, unknown

    static var current: AIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .available
            case .unavailable(.deviceNotEligible): return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
            case .unavailable(.modelNotReady): return .notReady
            default: return .unknown
            }
        }
        #endif
        return .unsupportedOS
    }

    var message: String {
        switch self {
        case .available: return ""
        case .unsupportedOS: return "iOS 26 이상에서 사용할 수 있어요."
        case .deviceNotEligible: return "이 기기는 Apple Intelligence를 지원하지 않아요. (iPhone 15 Pro 이상 등)"
        case .notEnabled: return "설정 > Apple Intelligence 및 Siri에서 Apple Intelligence를 켜 주세요."
        case .notReady: return "Apple Intelligence 모델을 내려받는 중이에요. 잠시 후 다시 열어 주세요."
        case .unknown: return "지금은 Apple Intelligence를 사용할 수 없어요."
        }
    }
}

/// 앱이 계산한 포트폴리오 통계 (AI에는 이 숫자만 전달)
@MainActor
struct PortfolioStats {
    struct Item { let name: String; let symbol: String; let weight: Double; let pnlRate: Double }

    var totalReturn = 0.0
    var cashRatio = 0.0
    var holdings: [Item] = []
    var buyCount = 0, sellCount = 0, recentTrades = 0, winningSells = 0
    var realizedPnL = 0.0
    var predictionsDone = 0, predictionsWon = 0

    init(wallet: Wallet, prices: [String: Ticker]) {
        let v = wallet.valuation(prices: prices)
        let total = max(v.total, 1)
        totalReturn = wallet.baseValue > 0 ? v.total / wallet.baseValue - 1 : 0
        cashRatio = (v.krw + v.tradexValue) / total
        holdings = wallet.state.holdings.map { code, h in
            let price = prices[code]?.tradePrice ?? h.averagePrice
            return Item(name: h.koreanName, symbol: String(code.dropFirst(4)),
                        weight: price * h.quantity / total,
                        pnlRate: h.averagePrice > 0 ? price / h.averagePrice - 1 : 0)
        }.sorted { $0.weight > $1.weight }
        let trades = wallet.state.trades
        buyCount = trades.filter { $0.side == .buy }.count
        sellCount = trades.filter { $0.side == .sell }.count
        recentTrades = trades.filter { $0.date > Date().addingTimeInterval(-7 * 86_400) }.count
        winningSells = trades.filter { ($0.realizedPnL ?? 0) > 0 }.count
        realizedPnL = trades.compactMap(\.realizedPnL).reduce(0, +)
        let done = wallet.state.predictions.filter { $0.status != .pending }
        predictionsDone = done.count
        predictionsWon = done.filter { $0.status == .won }.count
    }

    static let instructions = """
    너는 모의투자(가상 자금) 앱의 학습 도우미다. 사용자의 가상 포트폴리오 통계를 보고 한국어로 친절하게 분석한다.
    반드시 지킬 규칙:
    - 특정 코인을 사라, 팔라, 계속 보유하라고 권하지 않는다.
    - 앞으로의 가격이나 수익을 예측하지 않는다.
    - 주어진 숫자만 사용하고, 없는 숫자를 지어내지 않는다.
    - 실제 돈이 아닌 모의투자 기록이라는 점을 전제로 한다.
    형식:
    1) '한눈에 보기' 2~3문장
    2) '투자 습관' 관찰 3개 이내 (분산 정도, 현금 비중, 거래 빈도, 손익 관리 등)
    3) '공부해 볼 개념' 2~3개 (분산투자, 손절 원칙, 수수료, 변동성 같은 일반 개념)
    전체 500자 이내.
    """

    var prompt: String {
        var lines = [
            "[모의투자 계좌 통계 — 가상 자금]",
            "총 수익률: \(String(format: "%.2f", totalReturn * 100))%",
            "현금 비중: \(String(format: "%.0f", cashRatio * 100))%",
            "보유 코인 수: \(holdings.count)",
        ]
        for h in holdings.prefix(8) {
            lines.append("- \(h.name)(\(h.symbol)): 비중 \(String(format: "%.0f", h.weight * 100))%, 평균단가 대비 \(String(format: "%+.1f", h.pnlRate * 100))%")
        }
        lines += [
            "매수 \(buyCount)회, 매도 \(sellCount)회, 최근 7일 거래 \(recentTrades)회",
            "수익 낸 매도: \(winningSells)/\(sellCount)회, 실현 손익 합계: \(Int(realizedPnL))원",
            "오를까 내릴까 미니게임 적중: \(predictionsWon)/\(predictionsDone)",
        ]
        return lines.joined(separator: "\n")
    }
}
