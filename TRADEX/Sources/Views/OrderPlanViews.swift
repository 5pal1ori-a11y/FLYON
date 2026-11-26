import SwiftUI

/// 미체결 주문 한 줄 (취소 버튼)
struct PendingOrderRow: View {
    let order: PendingOrder
    let price: Double?
    let exchange: ExchangeID

    @Environment(Wallet.self) private var wallet
    @State private var confirmCancel = false

    var body: some View {
        let o = order
        let gap = (price ?? 0) > 0 ? o.triggerPrice / (price ?? 1) - 1 : 0
        return HStack(spacing: 12) {
            CoinIcon(symbol: o.symbol, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(o.koreanName).font(.subheadline.weight(.semibold))
                    Text(o.kind.title)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
                }
                Text(o.kind.isBuy ? "\(Fmt.krw(o.krwAmount)) 어치" : "\(Fmt.qty(o.quantity)) \(o.symbol)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("₩ \(Fmt.price(o.triggerPrice))").font(.subheadline.weight(.semibold)).monospacedDigit()
                Text("현재가 대비 \(Fmt.rate(gap))").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            Button("취소") { confirmCancel = true }
                .buttonStyle(BWButtonStyle(verticalPadding: 6))
        }
        .padding(.vertical, 10)
        .confirmationDialog("\(o.koreanName) \(o.kind.title) 주문을 취소할까요?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("주문 취소", role: .destructive) {
                withAnimation(.snappy) { try? wallet.cancelOrder(id: o.id, on: exchange) }
            }
        }
    }
}

/// 적립식 자동 매수 목록
struct RecurringPlansView: View {
    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @State private var showNew = false

    var body: some View {
        let ex = store.exchange
        let plans = wallet.account(ex).plans
        List {
            Section {
                if plans.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("아직 적립식이 없어요").font(.headline)
                        Text("매일 또는 매주 정해진 금액만큼 자동으로 사는 투자 습관을 연습해 보세요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                ForEach(plans) { p in
                    planRow(p, ex: ex)
                        .swipeActions {
                            Button("삭제", role: .destructive) { withAnimation { wallet.deletePlan(p.id, on: ex) } }
                        }
                }
            } footer: {
                Text("매 회차 오전 9시(한국시간)에 \(ex.name) 현물 지갑에서 삽니다. 앱이 꺼져 있던 날은 다음에 앱을 열 때 그날 일봉 시가로 처리돼요. 잔액이 부족한 회차는 건너뛰어요.")
            }
        }
        .navigationTitle("적립식 자동 매수")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("적립식 추가")
            }
        }
        .sheet(isPresented: $showNew) {
            NewPlanSheet(preset: nil).presentationDetents([.large])
        }
    }

    private func planRow(_ p: RecurringPlan, ex: ExchangeID) -> some View {
        HStack(spacing: 12) {
            CoinIcon(symbol: p.symbol, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(p.koreanName) · \(Fmt.krw(p.krwAmount))").font(.subheadline.weight(.semibold))
                Text(p.scheduleText).font(.caption).foregroundStyle(.secondary)
                Text(p.paused ? "일시정지" : "다음 실행 \(p.nextRunKey)")
                    .font(.caption2).foregroundStyle(.secondary)
                if p.runs > 0 || p.lastResult != nil {
                    Text("누적 \(p.runs)회 · \(Fmt.krw(p.totalSpent))\(p.lastResult.map { " · \($0)" } ?? "")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { !p.paused }, set: { on in wallet.setPlanPaused(p.id, !on, on: ex) }))
                .labelsHidden()
                .tint(.primary)
        }
        .padding(.vertical, 4)
    }
}

/// 새 적립식 만들기
struct NewPlanSheet: View {
    let preset: Market?

    @Environment(MarketStore.self) private var store
    @Environment(Wallet.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Market?
    @State private var query = ""
    @State private var amountText = "100000"
    @State private var frequency: RecurringPlan.Frequency = .daily
    @State private var weekday = 2   // 월요일
    @State private var errorText: String?

    private var candidates: [Market] {
        let list = store.markets.sorted {
            (store.tickers[$0.market]?.accTradePrice24h ?? 0) > (store.tickers[$1.market]?.accTradePrice24h ?? 0)
        }
        guard !query.isEmpty else { return Array(list.prefix(30)) }
        let q = query.lowercased()
        return list.filter { $0.koreanName.lowercased().contains(q) || $0.symbol.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("코인") {
                    if let m = selected {
                        HStack(spacing: 12) {
                            CoinIcon(symbol: m.symbol, size: 32)
                            Text("\(m.koreanName) (\(m.symbol))").font(.subheadline.weight(.semibold))
                            Spacer()
                            if preset == nil {
                                Button("변경") { withAnimation { selected = nil } }
                                    .buttonStyle(BWButtonStyle(verticalPadding: 5))
                            }
                        }
                    } else {
                        TextField("코인명/심볼 검색", text: $query)
                        ForEach(candidates) { m in
                            Button {
                                withAnimation { selected = m }
                            } label: {
                                HStack(spacing: 10) {
                                    CoinIcon(symbol: m.symbol, size: 26)
                                    Text(m.koreanName).foregroundStyle(.primary)
                                    Text(m.symbol).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("회차당 금액") {
                    HStack {
                        TextField("금액", text: $amountText)
                            .keyboardType(.numberPad)
                            .font(.title3.weight(.semibold))
                        Text("원").foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach([50_000, 100_000, 500_000, 1_000_000], id: \.self) { v in
                            Button(Fmt.man(Double(v))) { amountText = String(v) }
                                .buttonStyle(BWButtonStyle(selected: amountText == String(v), verticalPadding: 6))
                        }
                    }
                }
                Section("주기") {
                    BWSegmented(options: RecurringPlan.Frequency.allCases.map { ($0, $0.title) }, selection: $frequency)
                        .listRowBackground(Color.clear)
                    if frequency == .weekly {
                        HStack(spacing: 4) {
                            ForEach(1...7, id: \.self) { d in
                                Button(RecurringPlan.weekdayNames[d]) { weekday = d }
                                    .buttonStyle(BWButtonStyle(selected: weekday == d, verticalPadding: 6))
                            }
                        }
                    }
                    Text("매 회차 오전 9시(한국시간)에 \(store.exchange.name) 현물 지갑에서 시장가로 사요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorText {
                    Text(errorText).foregroundStyle(Theme.rise)
                }
            }
            .navigationTitle("적립식 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }
                        .fontWeight(.bold)
                        .disabled(selected == nil)
                }
            }
            .onAppear { if selected == nil { selected = preset } }
        }
    }

    private func save() {
        guard let m = selected else { return }
        do {
            try wallet.addPlan(market: m, krwAmount: Double(amountText) ?? 0, frequency: frequency, weekday: weekday, on: store.exchange)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
