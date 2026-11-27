import SwiftUI

struct GoalsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case open = "진행 중", done = "달성", all = "전체"
        var id: String { rawValue }
    }

    @Environment(Game.self) private var game
    @State private var filter: Filter = .open

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    missionsCard
                    achievementsCard
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper)
            .safeAreaInset(edge: .top, spacing: 0) { CashHeader() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var missionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘의 할 일").sectionLabel()
                Spacer()
                Text("마감 때 새로 바뀌어요")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkFaint)
            }
            ForEach(game.missions) { m in
                MissionRow(mission: m, compact: false)
            }
            Text("다 해 놓고 못 받은 보상은 마감 때 자동으로 들어옵니다.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkFaint)
        }
        .paperCard()
    }

    private var achievementsCard: some View {
        let list = Achievement.all.filter { a in
            switch filter {
            case .open: return !game.isClaimed(a)
            case .done: return game.isClaimed(a)
            case .all: return true
            }
        }
        .sorted { a, b in
            // 받을 수 있는 것 먼저
            let ra = game.isAchieved(a) && !game.isClaimed(a)
            let rb = game.isAchieved(b) && !game.isClaimed(b)
            return ra && !rb
        }
        let done = game.claimedAchievements.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("업적 \(done)/\(Achievement.all.count)").sectionLabel()
                Spacer()
            }
            Picker("보기", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if list.isEmpty {
                EmptyNote(title: filter == .done ? "아직 받은 업적이 없어요" : "모든 업적을 달성했어요!",
                          detail: filter == .done ? "진행 중 탭에서 목표를 확인해 보세요." : "그룹 회장님, 존경합니다.")
            }
            ForEach(list) { a in
                AchievementRow(achievement: a)
                if a.id != list.last?.id { Divider().overlay(Palette.line) }
            }
        }
        .paperCard()
    }
}

struct MissionRow: View {
    @Environment(Game.self) private var game
    let mission: Mission
    let compact: Bool

    var body: some View {
        let value = min(game.missionValue(mission), mission.target)
        let done = game.missionDone(mission)
        let progress = mission.target > 0 ? value / mission.target : 0

        HStack(spacing: 12) {
            Image(systemName: mission.claimed ? "checkmark.circle.fill" : mission.kind.symbol)
                .font(.system(size: compact ? 16 : 20))
                .foregroundStyle(mission.claimed ? Palette.inkFaint : done ? Palette.sign : Palette.inkSoft)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(mission.kind.title(mission.target))
                    .font(.system(size: compact ? 13 : 14, weight: .semibold))
                    .foregroundStyle(mission.claimed ? Palette.inkFaint : Palette.ink)
                    .strikethrough(mission.claimed)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule().fill(done ? Palette.sign : Palette.gold)
                            .frame(width: max(3, geo.size.width * progress))
                    }
                }
                .frame(height: 4)
                if !compact {
                    Text(progressText(value))
                        .font(.num(11))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 4)
            if mission.claimed {
                Text("완료").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkFaint)
            } else if !compact {
                Button {
                    game.claim(mission)
                } label: {
                    Text(done ? "받기" : Won.short(mission.reward))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(done ? .white : Palette.inkSoft)
                        .frame(width: 70, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9).fill(done ? Palette.sign : Palette.cardDeep))
                }
                .buttonStyle(PressStyle())
                .disabled(!done)
            } else {
                Text(Won.signed(mission.reward))
                    .font(.num(12, .bold))
                    .foregroundStyle(done ? Palette.sign : Palette.inkSoft)
            }
        }
        .animation(.easeOut(duration: 0.2), value: done)
    }

    private func progressText(_ value: Double) -> String {
        if mission.kind == .revenue { return "\(Won.short(value)) / \(Won.short(mission.target))" }
        return "\(Int(value)) / \(Int(mission.target))"
    }
}

struct AchievementRow: View {
    @Environment(Game.self) private var game
    let achievement: Achievement

    var body: some View {
        let a = achievement
        let current = min(a.current(game), a.target)
        let achieved = game.isAchieved(a)
        let claimed = game.isClaimed(a)
        let progress = a.target > 0 ? current / a.target : 0

        HStack(spacing: 12) {
            ZStack {
                Circle().fill(claimed ? Palette.gold.opacity(0.18) : achieved ? Palette.sign.opacity(0.15) : Palette.cardDeep)
                Image(systemName: a.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(claimed ? Palette.gold : achieved ? Palette.sign : Palette.inkFaint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(a.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(a.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
                if !claimed {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.line)
                            Capsule().fill(achieved ? Palette.sign : Palette.gold)
                                .frame(width: max(3, geo.size.width * progress))
                        }
                    }
                    .frame(height: 4)
                }
            }
            Spacer(minLength: 4)
            if claimed {
                Stamp(text: "달성", size: 40, color: Palette.gold)
            } else {
                Button {
                    game.claim(a)
                } label: {
                    VStack(spacing: 1) {
                        Text(achieved ? "받기" : "보상")
                            .font(.system(size: 11, weight: .bold))
                        Text(Won.short(game.achievementReward(a)))
                            .font(.num(11, .bold))
                    }
                    .foregroundStyle(achieved ? .white : Palette.inkSoft)
                    .frame(width: 70, height: 40)
                    .background(RoundedRectangle(cornerRadius: 9).fill(achieved ? Palette.sign : Palette.cardDeep))
                }
                .buttonStyle(PressStyle())
                .disabled(!achieved)
            }
        }
        .padding(.vertical, 4)
    }
}
