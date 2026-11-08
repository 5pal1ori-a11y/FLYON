import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: Store
    @State private var mode = 1  // 0 주 1 월 2 연
    var total: Double { mode == 0 ? store.weeklyTotal : mode == 1 ? store.monthlyTotal : store.yearlyTotal }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("통계").font(.system(size: 22, weight: .bold)).padding(.top, 8)
                Picker("", selection: $mode) { Text("주").tag(0); Text("월").tag(1); Text("연").tag(2) }.pickerStyle(.segmented)
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode == 0 ? "이번 주 평균" : mode == 1 ? "한 달에" : "1년이면").font(.system(size: 15)).foregroundStyle(T.sub)
                        Text(total.won).font(.system(size: 32, weight: .heavy))
                        if store.budget > 0 {
                            ProgressView(value: min(1, store.monthlyTotal / Double(store.budget))).tint(store.overBudget ? T.red : T.blue).padding(.top, 6)
                            Text("예산 \(store.budget.won) 중 \(Int(store.monthlyTotal / Double(store.budget) * 100))%").font(.system(size: 13)).foregroundStyle(T.sub)
                        }
                    }
                }
                if store.active.isEmpty {
                    Text("구독을 추가하면 보여드려요").foregroundStyle(T.sub).frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(t: "어디에 많이 쓰나요")
                            Chart(store.byCategory(), id: \.0) { c, v in
                                SectorMark(angle: .value("금액", v), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(c.color).cornerRadius(5)
                            }.frame(height: 190)
                            ForEach(store.byCategory(), id: \.0) { c, v in
                                HStack { Circle().fill(c.color).frame(width: 10, height: 10); Text(c.rawValue); Spacer()
                                    Text(v.won).foregroundStyle(T.sub) }.font(.system(size: 15))
                            }
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(t: "앞으로 6개월")
                            Chart(projection(), id: \.0) { m, v in
                                BarMark(x: .value("월", m), y: .value("금액", v)).foregroundStyle(T.blue).cornerRadius(6)
                            }.frame(height: 160).chartYAxis(.hidden)
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
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(t: "구독 건강도")
                            Text("\(store.health)점").font(.system(size: 28, weight: .heavy)).foregroundStyle(store.health >= 70 ? T.green : store.health >= 40 ? .orange : T.red)
                            if store.saveGoal > 0 {
                                let r = min(1, Double(store.potentialSave) / Double(store.saveGoal))
                                ProgressView(value: r).tint(T.green)
                                Text("절약 목표 \(store.saveGoal.won) 중 \(Int(r * 100))%").font(.system(size: 13)).foregroundStyle(T.sub)
                            }
                        }
                    }
                }
                Spacer(minLength: 100)
            }.padding(.horizontal, 20)
        }
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
