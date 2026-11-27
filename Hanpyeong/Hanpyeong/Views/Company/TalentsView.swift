import SwiftUI

struct TalentsView: View {
    @Environment(Game.self) private var game
    @State private var confirm: Talent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                ForEach(Talent.all) { t in
                    TalentCard(talent: t) { confirm = t }
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Palette.paper)
        .navigationTitle("인재 영입 \(game.talents.count)/\(Talent.all.count)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("영입할까요?", isPresented: Binding(
            get: { confirm != nil }, set: { if !$0 { confirm = nil } }
        ), titleVisibility: .visible) {
            if let t = confirm {
                Button("\(Won.full(t.cost))에 영입") { game.recruit(t) }
            }
            Button("취소", role: .cancel) { confirm = nil }
        } message: {
            if let t = confirm {
                Text("\(t.role) \(t.name) · \(t.effectText)")
            }
        }
    }
}

struct TalentCard: View {
    @Environment(Game.self) private var game
    let talent: Talent
    let onRecruit: () -> Void

    var body: some View {
        let t = talent
        let hired = game.hasTalent(t.id)
        let locked = t.unlockRank > game.highestRank
        let blocker = game.talentBlocker(t)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(hired ? Palette.sign : locked ? Palette.cardDeep : Palette.ink)
                    Image(systemName: locked ? "lock.fill" : t.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(locked ? Palette.inkFaint : .white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(locked ? "???" : t.name)
                            .font(.myeongjo(18))
                            .foregroundStyle(Palette.ink)
                        if hired { Tag(text: "함께하는 중", color: Palette.sign, filled: true) }
                    }
                    Text(t.role)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                Text(t.effectText)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(locked ? Palette.inkFaint : Palette.ink)

            if !hired {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("영입비 \(Won.full(t.cost))").font(.num(14, .bold)).foregroundStyle(Palette.ink)
                        Text(t.salary == 0 ? "일당 없음" : "일당 \(Won.short(t.salary))")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Button(action: onRecruit) {
                        Text(blocker ?? "영입하기")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(blocker == nil ? .white : Palette.inkFaint)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(RoundedRectangle(cornerRadius: 10).fill(blocker == nil ? Palette.sign : Palette.cardDeep))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(blocker != nil)
                }
            }
        }
        .paperCard(padding: 14)
        .opacity(locked ? 0.7 : 1)
    }
}

struct LeaderboardCard: View {
    @Environment(Game.self) private var game

    var body: some View {
        let rows = game.leaderboard
        let me = game.leaderboardPosition

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("재계 순위").sectionLabel()
                Spacer()
                Text("\(me)위 / \(rows.count)")
                    .font(.num(15, .bold))
                    .foregroundStyle(Palette.sign)
            }
            .padding(.bottom, 10)

            ForEach(Array(rows.enumerated()), id: \.element.id) { item in
                let r = item.element
                HStack(spacing: 10) {
                    Text("\(item.offset + 1)")
                        .font(.num(15, .bold))
                        .foregroundStyle(item.offset < 3 ? Palette.gold : Palette.inkFaint)
                        .frame(width: 24, alignment: .leading)
                    BrandLogo(name: r.name, color: r.isPlayer ? Palette.sign : LogoPalette.color(for: r.name), size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.name)
                            .font(.system(size: 16, weight: r.isPlayer ? .heavy : .semibold))
                            .foregroundStyle(r.isPlayer ? Palette.sign : Palette.ink)
                        Text(r.isPlayer ? "우리 회사" : "회장 \(r.owner)")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Text(Won.short(r.worth))
                        .font(.num(15, .semibold))
                        .foregroundStyle(r.isPlayer ? Palette.sign : Palette.ink)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, r.isPlayer ? 8 : 0)
                .background(r.isPlayer ? Palette.sign.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .paperCard()
    }
}
