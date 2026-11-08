import SwiftUI

struct Confetti: View {
    @State private var go = false
    var colors: [Color] { T.palette.colors + [.yellow, .orange, .pink, .mint] }
    var body: some View {
        GeometryReader { g in
            ZStack {
                ForEach(0..<48, id: \.self) { i in
                    let r = Double((i * 37) % 100) / 100
                    let r2 = Double((i * 53) % 100) / 100
                    RoundedRectangle(cornerRadius: 2).fill(colors[i % colors.count]).frame(width: 8, height: 14)
                        .rotationEffect(.degrees(go ? Double(i) * 47 : 0))
                        .position(x: g.size.width * (go ? 0.05 + 0.9 * r2 : 0.5), y: go ? g.size.height * (0.6 + 0.4 * r) : g.size.height * 0.38)
                        .opacity(go ? 0 : 1)
                        .animation(.easeOut(duration: 1.5 + r).delay(Double(i % 8) * 0.03), value: go)
                }
            }
        }.allowsHitTesting(false).onAppear { go = true }
    }
}

/// 구독을 해지·정리했을 때 나오는 축하 화면
struct CelebrationView: View {
    @EnvironmentObject var store: Store
    let saved: Int
    var close: () -> Void
    @State private var pop = false

    var goal: Int { store.saveGoal }
    var total: Int { Int(store.savedMonthly.rounded()) }
    var hit: Bool { goal > 0 && total >= goal }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: close)
            Confetti().ignoresSafeArea()
            VStack(spacing: 14) {
                Text(hit ? "🏆" : "🎉").font(.system(size: 64)).scaleEffect(pop ? 1 : 0.2).rotationEffect(.degrees(pop ? 0 : -25))
                Text(hit ? "목표 달성!" : "잘했어요!").font(.system(size: 26, weight: .heavy))
                VStack(spacing: 4) {
                    Text("한 달에").font(.system(size: 14)).foregroundStyle(T.sub)
                    CountingWon(target: Double(saved)).font(.system(size: 34, weight: .heavy)).foregroundStyle(T.blue)
                    Text("아꼈어요 · 1년이면 \((saved * 12).won)").font(.system(size: 14)).foregroundStyle(T.sub)
                }
                if goal > 0 {
                    VStack(spacing: 6) {
                        AnimBar(value: Double(total) / Double(goal), tint: hit ? T.green : T.blue)
                        Text("절약 목표 \(goal.won) 중 \(total.won)").font(.system(size: 12)).foregroundStyle(T.sub)
                    }.padding(.top, 6)
                }
                Button(action: close) {
                    Text("좋아요").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                        .background(T.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(PressCard()).padding(.top, 8)
            }
            .padding(26).frame(maxWidth: 320)
            .background(T.card, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .scaleEffect(pop ? 1 : 0.8).opacity(pop ? 1 : 0)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { pop = true }
        }
        .task { try? await Task.sleep(nanoseconds: 6_000_000_000); close() }
    }
}
