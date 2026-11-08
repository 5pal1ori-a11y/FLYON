import SwiftUI

/// 무료 체험 후보 (보통 이 정도 기간이 있어요. 프로모션은 바뀌니 가입 화면에서 꼭 확인)
struct TrialOffer: Identifiable {
    let id = UUID()
    let name: String
    let days: Int
    let note: String
}

enum TrialOffers {
    static let all: [TrialOffer] = [
        TrialOffer(name: "유튜브 프리미엄", days: 30, note: "신규 가입자 대상인 경우가 많아요"),
        TrialOffer(name: "쿠팡 와우", days: 30, note: "자료마다 달라서 가입 화면에서 확인이 필요해요"),
        TrialOffer(name: "애플 뮤직", days: 30, note: "기기 구매 혜택은 더 길 수 있어요"),
        TrialOffer(name: "스포티파이", days: 30, note: "프로모션에 따라 다르게 열려요"),
        TrialOffer(name: "밀리의 서재", days: 30, note: "첫 가입 때만 열리는 경우가 많아요"),
        TrialOffer(name: "윌라", days: 30, note: "첫 가입 때만 열리는 경우가 많아요"),
        TrialOffer(name: "Creative Cloud", days: 7, note: "체험 후 자동으로 결제될 수 있어요"),
        TrialOffer(name: "Notion", days: 14, note: "유료 요금제를 체험할 수 있어요"),
    ]
}

struct TrialPickView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @State private var asking: TrialOffer?
    @State private var added: String?

    var offers: [TrialOffer] {
        TrialOffers.all.filter { o in !store.active.contains { $0.service?.name == o.name || $0.name == o.name } && Catalog.all.contains { $0.name == o.name } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BigTitle("이런 무료 체험\n어때요?").stagger(0)
                    Text("체험이 끝나기 5시간 전에 알려드려요. 끝나면 자동 결제될 수 있으니 꼭 확인하세요.")
                        .font(.system(size: 13)).foregroundStyle(T.sub)
                    if let a = added {
                        HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundStyle(T.green); Text("\(a) 체험을 담았어요").font(.system(size: 14, weight: .semibold)) }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(T.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .transition(.scale.combined(with: .opacity))
                    }
                    if offers.isEmpty {
                        Text("추천할 체험을 다 쓰고 있어요 🎉").font(.system(size: 15)).foregroundStyle(T.sub).frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(Array(offers.enumerated()), id: \.element.id) { i, o in
                        let svc = Catalog.all.first { $0.name == o.name }
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                LogoView(name: o.name, category: svc?.category ?? .etc, size: 50)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(o.name).font(.system(size: 17, weight: .bold))
                                    Text("보통 \(o.days)일 무료 체험").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.blue)
                                }
                                Spacer()
                            }
                            Text("\(o.note) · 체험 뒤 \((svc?.defaultPrice ?? 0).won)").font(.system(size: 12)).foregroundStyle(T.sub)
                            Button {
                                if let u = svc?.joinURL { openURL(u) }
                                asking = o
                            } label: {
                                Text("체험하러 가기").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).frame(height: 46).background(T.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }.buttonStyle(PressCard())
                        }
                        .padding(18).background(T.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 12, y: 5)
                        .stagger(i + 1)
                    }
                    Text("체험 조건은 서비스마다, 그리고 시기마다 달라요. 실제 체험 여부와 기간은 가입 화면에서 확인하세요.").font(.system(size: 12)).foregroundStyle(T.faint)
                }.padding(20)
            }
            .background(T.bg)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .alert("체험을 시작했나요?", isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } })) {
                Button("시작했어요") { if let o = asking { start(o) }; asking = nil }
                Button("아직이에요", role: .cancel) { asking = nil }
            } message: { Text("시작했다면 끝나기 전에 알려드릴게요") }
        }
    }

    func start(_ o: TrialOffer) {
        let svc = Catalog.all.first { $0.name == o.name }
        let end = Calendar.current.date(byAdding: .day, value: o.days, to: Date())!
        var sub = Subscription(name: o.name, price: svc?.defaultPrice ?? 0, category: svc?.category ?? .etc, cycle: .monthly, nextDate: end)
        sub.trialEnd = end
        store.add(sub)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { added = o.name }
    }
}

/// 체험이 5시간 안에 끝나면 홈 맨 위에 실시간으로 보여줘요
struct TrialCountdownBanner: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL
    var soon: [Subscription] {
        store.active.filter { s in
            guard let t = s.trialEnd else { return false }
            let left = t.timeIntervalSinceNow
            return left > 0 && left <= 5 * 3600
        }
    }
    var body: some View {
        ForEach(soon) { s in
            HStack(spacing: 14) {
                LogoView(name: s.name, category: s.category, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(s.name) 체험이 곧 끝나요").font(.system(size: 15, weight: .bold)).foregroundStyle(T.text)
                    HStack(spacing: 4) {
                        Text(s.trialEnd ?? Date(), style: .timer).font(.system(size: 20, weight: .heavy).monospacedDigit()).foregroundStyle(.orange)
                        Text("남음 · 이후 \(s.price.won)").font(.system(size: 12)).foregroundStyle(T.sub)
                    }
                }
                Spacer()
            }
            .padding(16).background(T.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.orange.opacity(0.6), lineWidth: 1.5))
            .shadow(color: .orange.opacity(0.2), radius: 12, y: 5)
            .pulse(true)
        }
    }
}
