import SwiftUI

/// 출석 보상 — 7일 주기, 7일째 대박
struct DailyRewardOverlay: View {
    @Environment(Game.self) private var game
    let offer: DailyRewardOffer
    @State private var appear = false
    @State private var claimed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("\(offer.streak)일째 출석")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Palette.sign)
                    Text("오늘도 문 열었습니다")
                        .font(.myeongjo(24))
                        .foregroundStyle(Palette.ink)
                }

                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        dayCell(i)
                    }
                }

                Text(Won.full(offer.amount))
                    .font(.myeongjo(30))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .scaleEffect(claimed ? 1.15 : 1)

                Button(claimed ? "받았어요" : "받기") {
                    guard !claimed else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { claimed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.25)) { game.claimDailyReward() }
                    }
                }
                .buttonStyle(SignButtonStyle())
            }
            .padding(24)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 24)
            .scaleEffect(appear ? 1 : 0.85)
            .opacity(appear ? 1 : 0)
        }
        .sensoryFeedback(.success, trigger: claimed)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { appear = true }
        }
    }

    private func dayCell(_ i: Int) -> some View {
        let done = i < offer.dayIndex
        let today = i == offer.dayIndex
        let big = i == 6
        return VStack(spacing: 4) {
            Image(systemName: big ? "gift.fill" : done || (today && claimed) ? "checkmark" : "wonsign")
                .font(.system(size: big ? 18 : 14, weight: .heavy))
                .foregroundStyle(today || done ? .white : big ? Palette.gold : Palette.inkFaint)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(today ? Palette.sign : done ? Palette.inkSoft : Palette.cardDeep)
                )
                .scaleEffect(today && appear ? 1.08 : 1)
            Text("\(i + 1)일")
                .font(.system(size: 11, weight: today ? .heavy : .medium))
                .foregroundStyle(today ? Palette.sign : Palette.inkSoft)
        }
    }
}

/// 회사 탭: 가업 승계
struct PassDownCard: View {
    @Environment(Game.self) private var game
    @State private var confirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("가업 승계").sectionLabel()
                Spacer()
                Text("명성 \(game.legacy) · 매출 +\(game.legacy * 5)%")
                    .font(.num(14, .bold))
                    .foregroundStyle(Palette.gold)
            }
            HStack(spacing: 14) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.gold)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Palette.gold.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(game.generation + 1)대 사장에게 물려주기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(game.canPassDown ? "명성 +\(game.legacyGain) · 처음부터 더 빠르게"
                                          : "중견기업 대표부터 가능")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Button("승계하기") { confirm = true }
                .buttonStyle(SignButtonStyle(enabled: game.canPassDown))
                .disabled(!game.canPassDown)
        }
        .paperCard()
        .confirmationDialog("가업을 물려줄까요?", isPresented: $confirm, titleVisibility: .visible) {
            Button("\(game.generation + 1)대 사장으로 새 출발") { game.passDown() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("가게·건물·돈은 처음으로 돌아가고, 명성 +\(game.legacyGain)(매출 +\(game.legacyGain * 5)%)이 영원히 남아요. 업적은 유지됩니다.")
        }
    }
}
