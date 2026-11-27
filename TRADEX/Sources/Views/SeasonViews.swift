import SwiftUI

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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("시즌 랭킹").font(.title3.weight(.bold))
                        Spacer()
                        Text("준비 중").font(.caption.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
                    }
                    ForEach(1...3, id: \.self) { rank in
                        HStack(spacing: 14) {
                            Text("\(rank)").font(.headline.weight(.heavy)).frame(width: 24)
                            Circle().fill(Color.primary.opacity(0.06)).frame(width: 36, height: 36)
                            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)).frame(width: 110, height: 12)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)).frame(width: 60, height: 12)
                        }
                    }
                    Text("다른 트레이더와 AP로 경쟁하는 랭킹은 서버가 연결되면 열려요. 지금 쌓은 AP는 그대로 반영돼요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .tossCard()

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

                // 지난 시즌
                if !wallet.state.season.history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("지난 시즌").font(.title3.weight(.bold))
                        ForEach(wallet.state.season.history) { h in
                            HStack {
                                Text(h.id.replacingOccurrences(of: "-Q", with: " 시즌 ")).font(.subheadline)
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
    }
}
