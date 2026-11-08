import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: Store
    @State private var mode = 1  // 0 주 1 월 2 연
    @State private var grow = false
    var total: Double { mode == 0 ? store.weeklyTotal : mode == 1 ? store.monthlyTotal : store.yearlyTotal }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $mode) { Text("주").tag(0); Text("월").tag(1); Text("연").tag(2) }.pickerStyle(.segmented)
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode == 0 ? "이번 주 평균" : mode == 1 ? "한 달에" : "1년이면").font(.system(size: 15)).foregroundStyle(T.sub)
                        CountingWon(target: total).font(.system(size: 32, weight: .heavy))
                        if store.budget > 0 {
                            ProgressView(value: min(1, store.monthlyTotal / Double(store.budget))).tint(store.overBudget ? T.red : T.blue).padding(.top, 6)
                            Text("예산 \(store.budget.won) 중 \(Int(store.monthlyTotal / Double(store.budget) * 100))%").font(.system(size: 13)).foregroundStyle(T.sub)
                        }
                    }
                }
                NoticeCard()
                if store.active.isEmpty {
                    Text("구독을 추가하면 보여드려요").foregroundStyle(T.sub).frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(t: "어디에 많이 쓰나요")
                            Chart(store.byCategory(), id: \.0) { c, v in
                                SectorMark(angle: .value("금액", v), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(c.color).cornerRadius(5)
                            }.frame(height: 190).scaleEffect(grow ? 1 : 0.5).rotationEffect(.degrees(grow ? 0 : -90)).opacity(grow ? 1 : 0)
                            ForEach(store.byCategory(), id: \.0) { c, v in
                                HStack { Circle().fill(c.color).frame(width: 10, height: 10); Text(c.rawValue); Spacer()
                                    Text(v.won).foregroundStyle(T.sub) }.font(.system(size: 15))
                            }
                        }
                    }
                    if store.history.count >= 1 {
                        Card {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(t: "월별 지출 기록")
                                let items = store.history.sorted { $0.key < $1.key }.suffix(6).map { (String($0.key.suffix(2)) + "월", Double($0.value)) }
                                Chart(items, id: \.0) { m, v in
                                    BarMark(x: .value("월", m), y: .value("금액", grow ? v : 0)).foregroundStyle(LinearGradient(colors: [T.blue, T.accent3], startPoint: .bottom, endPoint: .top)).cornerRadius(6)
                                }.frame(height: 150).chartYAxis(.hidden).animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.2), value: grow)
                                Text("앱을 쓴 달부터 기록돼요").font(.system(size: 12)).foregroundStyle(T.faint)
                            }
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(t: "구독 건강도")
                            Text("\(store.health)점").font(.system(size: 28, weight: .heavy)).foregroundStyle(store.health >= 70 ? T.green : store.health >= 40 ? .orange : T.red)
                            if store.saveGoal > 0 {
                                let got = Int(store.savedMonthly.rounded())
                                let r = min(1, Double(got) / Double(store.saveGoal))
                                AnimBar(value: r, tint: T.green)
                                Text("절약 목표 \(store.saveGoal.won) 중 \(got.won) 아꼈어요").font(.system(size: 13)).foregroundStyle(T.sub)
                            }
                        }
                    }

                    DisclosureGroup {
                        VStack(spacing: 16) {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(t: "앞으로 6개월")
                            Chart(projection(), id: \.0) { m, v in
                                BarMark(x: .value("월", m), y: .value("금액", grow ? v : 0)).foregroundStyle(T.blue).cornerRadius(6)
                            }.frame(height: 160).chartYAxis(.hidden).animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.2), value: grow)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(t: "이번 달 사용 횟수")
                            ForEach(store.active.sorted { $0.usesThisMonth > $1.usesThisMonth }) { s in
                                HStack(spacing: 12) {
                                    LogoView(name: s.name, category: s.category, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).font(.system(size: 15))
                                        Text(s.usesThisMonth == 0 ? "아직 안 썼어요" : "한 번에 \((s.costPerUse ?? 0).won)").font(.system(size: 12)).foregroundStyle(s.usesThisMonth == 0 ? T.red : T.sub)
                                    }
                                    Spacer()
                                    Text("\(s.usesThisMonth)번").font(.system(size: 15, weight: .semibold))
                                }
                            }
                            Text("다른 앱을 열었는지는 알 수 없어서, 쓴 날 직접 눌러 기록해요").font(.system(size: 12)).foregroundStyle(T.faint)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(t: "서비스별")
                            ForEach(store.active.sorted { $0.monthly > $1.monthly }) { s in
                                HStack { LogoView(name: s.name, category: s.category, size: 32); Text(s.name).font(.system(size: 15)); Spacer(); Text(s.monthly.won).font(.system(size: 15)).foregroundStyle(T.sub) }
                            }
                        }
                    }
                        }.padding(.top, 12)
                    } label: {
                        Text("자세히 보기").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.sub)
                    }
                    .tint(T.sub).padding(18).background(T.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                Spacer(minLength: 100)
            }.padding(.horizontal, 20)
        }
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.15)) { grow = true } }
    }

    func projection() -> [(String, Double)] {
        let cal = Calendar.current
        return (0..<6).map { i in
            let m = cal.date(byAdding: .month, value: i, to: Date())!
            let sum = store.active.reduce(0.0) { acc, s in acc + (s.cycle == .yearly ? (cal.component(.month, from: s.nextDate) == cal.component(.month, from: m) ? Double(s.price) : 0) : s.monthly) }
            return ("\(cal.component(.month, from: m))월", sum)
        }
    }
}
