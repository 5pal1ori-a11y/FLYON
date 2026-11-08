import SwiftUI

/// 분석 탭: 통계 | 가격 비교
struct AnalysisView: View {
    @State private var mode = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) { Text("통계").tag(0); Text("가격 비교").tag(1) }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
            if mode == 0 { StatsView() } else { CompareView() }
        }
    }
}

struct CompareView: View {
    @EnvironmentObject var store: Store
    @State private var cat: Category = .ott
    @State private var calcID: UUID?
    @State private var yearlyText = ""

    var services: [Service] { Catalog.all.filter { $0.category == cat && $0.defaultPrice > 0 }.sorted { $0.defaultPrice < $1.defaultPrice } }
    var mine: [Subscription] { store.active.filter { $0.category == cat } }
    var cats: [Category] { Category.allCases.filter { c in Catalog.all.contains { $0.category == c && $0.defaultPrice > 0 } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cats) { c in
                            Button { cat = c } label: {
                                Text(c.rawValue).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(cat == c ? .white : T.sub).padding(.horizontal, 16).frame(height: 38)
                                    .background(cat == c ? T.blue : .white, in: Capsule())
                            }
                        }
                    }
                }.padding(.top, 8)

                if mine.count >= 2 {
                    let cheapest = mine.min { $0.monthly < $1.monthly }!
                    let save = Int(mine.reduce(0) { $0 + $1.monthly } - cheapest.monthly)
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(T.blue)
                        Text("\(cat.rawValue) \(mine.count)개 쓰는 중이에요. \(cheapest.name)만 남기면 한 달 \(save.won) 아껴요").font(.system(size: 14, weight: .semibold))
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(T.blueSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                let maxP = Double(services.map(\.defaultPrice).max() ?? 1)
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("한 달 요금 낮은 순").font(.system(size: 17, weight: .bold))
                        ForEach(services, id: \.name) { s in
                            let using = store.active.first { $0.service?.name == s.name }
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    LogoView(name: s.name, category: s.category, size: 36)
                                    Text(s.name).font(.system(size: 15, weight: .semibold))
                                    if using != nil { Text("이용 중").font(.system(size: 11, weight: .bold)).foregroundStyle(T.blue).padding(.horizontal, 8).padding(.vertical, 3).background(T.blueSoft, in: Capsule()) }
                                    Spacer()
                                    Text(s.defaultPrice.won).font(.system(size: 15, weight: .semibold))
                                }
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(T.bg)
                                        Capsule().fill(using != nil ? T.blue : T.faint).frame(width: max(8, g.size.width * Double(s.defaultPrice) / maxP))
                                    }
                                }.frame(height: 6)
                            }
                        }
                    }
                }

                calculator

                Text("요금은 참고용이에요. 실제 요금과 할인은 각 서비스에서 확인하세요.")
                    .font(.system(size: 12)).foregroundStyle(T.faint)
                Spacer(minLength: 120)
            }.padding(.horizontal, 20)
        }
    }

    /// 월 결제 vs 연 결제
    var calculator: some View {
        let monthlySubs = store.active.filter { $0.cycle == .monthly }
        let sel = monthlySubs.first { $0.id == calcID } ?? monthlySubs.first
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("월 결제 vs 연 결제").font(.system(size: 17, weight: .bold))
                if let sel {
                    Picker("구독", selection: Binding(get: { sel.id }, set: { calcID = $0; yearlyText = "" })) {
                        ForEach(monthlySubs) { Text($0.name).tag($0.id) }
                    }.tint(T.blue)
                    Text("지금은 한 달 \(sel.price.won), 1년이면 \((sel.price * 12).won)").font(.system(size: 14)).foregroundStyle(T.sub)
                    HStack {
                        TextField("연 결제 금액", text: $yearlyText).keyboardType(.numberPad)
                        Text("원").foregroundStyle(T.sub)
                    }.padding(14).background(T.bg, in: RoundedRectangle(cornerRadius: 14))
                    if let y = Int(yearlyText), y > 0 {
                        let diff = sel.price * 12 - y
                        Text(diff > 0 ? "연 결제로 바꾸면 1년에 \(diff.won) 아껴요" : diff < 0 ? "월 결제가 \((-diff).won) 더 저렴해요" : "비용이 같아요")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(diff > 0 ? T.green : T.text)
                    }
                } else { Text("월 결제 구독을 추가하면 비교해드려요").font(.system(size: 14)).foregroundStyle(T.sub) }
            }
        }
    }
}
