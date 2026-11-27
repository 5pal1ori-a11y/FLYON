import SwiftUI
import Charts

struct LedgerView: View {
    @Environment(Game.self) private var game
    @State private var showLoan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TodayReceipt()
                    profitChart
                    loanCard
                    entries
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper)
            .safeAreaInset(edge: .top, spacing: 0) { CashHeader() }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLoan) { LoanSheet() }
        }
    }

    // MARK: 최근 14일 순이익

    private var profitChart: some View {
        let days = Array(game.history.suffix(14))
        return VStack(alignment: .leading, spacing: 10) {
            Text("최근 \(days.count)일 순이익").sectionLabel()
            if days.isEmpty {
                Text("첫 영업일이 끝나면 여기에 기록이 쌓여요.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(days) { d in
                    BarMark(x: .value("일차", "\(d.day)"), y: .value("순이익", d.net))
                        .foregroundStyle(d.net >= 0 ? Palette.up : Palette.down)
                        .cornerRadius(3)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { v in
                        AxisGridLine().foregroundStyle(Palette.line)
                        AxisValueLabel {
                            if let n = v.as(Double.self) {
                                Text(Won.short(n)).font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 9))
                    }
                }
                .frame(height: 150)
            }
        }
        .paperCard()
    }

    // MARK: 대출

    private var loanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("은행").sectionLabel()
                Spacer()
                Text("일 이자 \(String(format: "%.2f", game.loanRate * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack {
                StatCell(label: "대출 잔액", value: Won.short(game.debt), tint: game.debt > 0 ? Palette.down : Palette.ink)
                StatCell(label: "추가 한도", value: Won.short(game.loanAvailable))
                StatCell(label: "하루 이자", value: Won.short(game.dailyInterest))
            }
            Button("대출 · 상환") { showLoan = true }
                .buttonStyle(LineButtonStyle())
        }
        .paperCard()
    }

    // MARK: 거래 내역

    private var entries: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("거래 내역").sectionLabel().padding(.bottom, 8)
            if game.ledger.isEmpty {
                Text("아직 큰 거래가 없어요.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, 12)
            }
            ForEach(game.ledger.prefix(40)) { e in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(e.day)일")
                        .font(.mono(11))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(width: 38, alignment: .leading)
                    Text(e.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(Won.signed(e.amount))
                        .font(.mono(12, .semibold))
                        .foregroundStyle(trendColor(e.amount))
                }
                .padding(.vertical, 9)
                Divider().overlay(Palette.line)
            }
        }
        .paperCard()
    }
}

// MARK: - 오늘 영수증

struct TodayReceipt: View {
    @Environment(Game.self) private var game

    var body: some View {
        let rent = game.stores.reduce(0) { $0 + game.rent($1) }
        let wages = game.stores.reduce(0) { $0 + game.wages($1) }
        let building = game.dailyBuildingIncome
        let interest = game.dailyInterest
        let revenue = game.today.revenue
        let expected = revenue + building - rent - wages - interest - game.dailySalaries

        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(game.companyName)
                    .font(.myeongjo(20))
                Text("\(game.day)일차 영업 중 · \(game.dayPhase)")
                    .font(.mono(11))
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 6)

            DashedLine()

            line("매출 (지금까지)", revenue)
            line("건물 월세", building)
            line("임대료", -rent)
            line("인건비", -wages)
            if game.dailySalaries > 0 { line("인재 급여", -game.dailySalaries) }
            line("대출 이자", -interest)

            DashedLine()

            HStack {
                Text("오늘 예상 손익")
                    .font(.mono(13, .bold))
                Spacer()
                Text(Won.signed(expected))
                    .font(.mono(15, .bold))
                    .foregroundStyle(trendColor(expected))
                    .contentTransition(.numericText())
            }

            Text("고정비는 마감 때 한꺼번에 빠져나갑니다")
                .font(.mono(10))
                .foregroundStyle(Palette.inkFaint)
                .padding(.bottom, 14)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .background(Palette.receipt)
        .clipShape(ZigzagEdge(tooth: 7))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    private func line(_ label: String, _ amount: Double) -> some View {
        HStack {
            Text(label).font(.mono(12))
            Spacer()
            Text(amount == 0 ? "0" : Won.signed(amount))
                .font(.mono(12, .semibold))
                .foregroundStyle(amount == 0 ? Palette.inkFaint : Palette.ink)
        }
    }
}

// MARK: - 대출 시트

struct LoanSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("순자산의 \(Int(game.loanLimitRatio * 100))%까지 빌릴 수 있어요. 이자는 매일 마감 때 나갑니다. 빚으로 산 가게가 이자보다 많이 벌면 이득, 아니면 독이에요.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)

                VStack(alignment: .leading, spacing: 10) {
                    Text("빌리기 · 한도 \(Won.full(game.loanAvailable))").sectionLabel()
                    HStack(spacing: 8) {
                        ForEach([0.1, 0.25, 0.5, 1.0], id: \.self) { r in
                            let amount = game.loanAvailable * r
                            Button {
                                game.borrow(amount)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(r == 1 ? "전부" : "\(Int(r * 100))%").font(.system(size: 12, weight: .bold))
                                    Text(Won.short(amount)).font(.num(11))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
                            }
                            .buttonStyle(PressStyle())
                            .disabled(amount < 1)
                            .foregroundStyle(amount < 1 ? Palette.inkFaint : Palette.ink)
                        }
                    }
                }
                .paperCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("갚기 · 잔액 \(Won.full(game.debt))").sectionLabel()
                    HStack(spacing: 10) {
                        Button("절반 상환") { game.repay(game.debt / 2) }
                            .buttonStyle(LineButtonStyle())
                        Button("전액 상환") { game.repay(game.debt) }
                            .buttonStyle(SignButtonStyle(enabled: game.debt > 0 && game.cash > 0))
                    }
                    .disabled(game.debt <= 0)
                }
                .paperCard()

                Spacer()
            }
            .padding(16)
            .background(Palette.paper)
            .navigationTitle("한평은행")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
