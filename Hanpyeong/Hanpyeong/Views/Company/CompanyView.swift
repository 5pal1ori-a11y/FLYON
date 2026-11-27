import SwiftUI

struct CompanyView: View {
    @Environment(Game.self) private var game
    @State private var confirmReset = false
    @State private var showCredits = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    identity
                    worthCard
                    talentsLink
                    LeaderboardCard()
                    ladder
                    statsCard
                    settings
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("처음부터 다시 시작할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("모든 기록 지우기", role: .destructive) { game.reset() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("점포, 건물, 장부가 전부 사라지고 되돌릴 수 없어요.")
            }
            .sheet(isPresented: $showCredits) { CreditsSheet() }
        }
    }

    // MARK: 명함

    private var identity: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(game.highestRank >= 4 ? "\(game.companyName)그룹" : game.legalName)
                    .font(.myeongjo(28))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(game.rank.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.gold)
                Text(game.rank.line)
                    .font(.myeongjo(13, bold: false))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").foregroundStyle(Palette.sign)
                    Text("평판 \(Int(game.reputation)) · \(game.reputationTitle)")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Stamp(text: stampText, size: 84)
        }
        .padding(.top, 12)
    }

    private var stampText: String { game.rank.stamp }

    // MARK: 인재

    private var talentsLink: some View {
        NavigationLink {
            TalentsView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.ink)
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("인재 영입")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(game.hiredTalents.isEmpty
                         ? "장인, 세무사, 중개사… 사람이 가게를 키운다"
                         : game.hiredTalents.map(\.name).joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(game.talents.count)/\(Talent.all.count)")
                    .font(.num(15, .bold))
                    .foregroundStyle(Palette.inkSoft)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .paperCard(padding: 14)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 순자산

    private var worthCard: some View {
        let cash = max(0, game.cash)
        let stores = game.storesValue
        let buildings = game.buildingsValue
        let total = max(1, cash + stores + buildings)
        let next = game.rank.next

        return VStack(alignment: .leading, spacing: 12) {
            Text("순자산").sectionLabel()
            Text(Won.full(game.netWorth))
                .font(.myeongjo(26))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle().fill(Palette.ink).frame(width: geo.size.width * cash / total)
                    Rectangle().fill(Palette.sign).frame(width: geo.size.width * stores / total)
                    Rectangle().fill(Palette.gold).frame(width: geo.size.width * buildings / total)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)

            HStack {
                legend("현금", cash, Palette.ink)
                legend("점포", stores, Palette.sign)
                legend("건물", buildings, Palette.gold)
                legend("부채", -game.debt, Palette.down)
            }

            if let next {
                DashedLine().padding(.vertical, 2)
                let prevReq = game.rank.requirement
                let progress = min(1, max(0, (game.netWorth - prevReq) / (next.requirement - prevReq)))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("다음 직함 · \(next.title)").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text(Won.short(next.requirement)).font(.num(14, .semibold)).foregroundStyle(Palette.inkSoft)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.line)
                            Capsule().fill(Palette.gold).frame(width: max(4, geo.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                    Text(unlockText(next))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.inkSoft)
                }
            } else {
                DashedLine().padding(.vertical, 2)
                Text("한 평짜리 구멍가게에서 시작해 그룹 회장까지 왔습니다. 이제부터는 기록 경신입니다.")
                    .font(.myeongjo(14, bold: false))
                    .foregroundStyle(Palette.ink)
            }
        }
        .paperCard()
    }

    private func legend(_ label: String, _ v: Double, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(c).frame(width: 6, height: 6)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkSoft)
            }
            Text(Won.short(v)).font(.num(14, .bold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func unlockText(_ r: Rank) -> String {
        var parts: [String] = []
        let kinds = r.unlockedKinds.map(\.info.title)
        let districts = r.unlockedDistricts.map(\.info.name)
        if !kinds.isEmpty { parts.append("업종 " + kinds.joined(separator: ", ")) }
        if !districts.isEmpty { parts.append("지역 " + districts.joined(separator: ", ")) }
        return parts.isEmpty ? "명예와 기록" : "열리는 것: " + parts.joined(separator: " · ")
    }

    // MARK: 직함 사다리

    private var ladder: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("걸어온 길").sectionLabel().padding(.bottom, 10)
            ForEach(Rank.all) { r in
                let done = r.id <= game.highestRank
                let current = r.id == game.highestRank
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(done ? Palette.sign : Palette.line, lineWidth: 1.5)
                            .background(Circle().fill(current ? Palette.sign : .clear))
                        if done {
                            Image(systemName: current ? "star.fill" : "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(current ? .white : Palette.sign)
                        }
                    }
                    .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title)
                            .font(.system(size: 16, weight: current ? .heavy : .semibold))
                            .foregroundStyle(done ? Palette.ink : Palette.inkFaint)
                        Text(r.id == 0 ? "시작" : "순자산 \(Won.short(r.requirement))")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                }
                .padding(.vertical, 7)
                if r.id < Rank.all.count - 1 {
                    Rectangle()
                        .fill(r.id < game.highestRank ? Palette.sign : Palette.line)
                        .frame(width: 1.5, height: 10)
                        .padding(.leading, 10.25)
                }
            }
        }
        .paperCard()
    }

    // MARK: 기록

    private var statsCard: some View {
        let s = game.stats
        return VStack(alignment: .leading, spacing: 12) {
            Text("기록").sectionLabel()
            HStack {
                StatCell(label: "영업일", value: "\(game.day)일")
                StatCell(label: "손님 계산", value: "\(s.taps)번")
                StatCell(label: "개업", value: "\(s.storesOpened)곳")
            }
            HStack {
                StatCell(label: "누적 매출", value: Won.short(s.totalRevenue))
                StatCell(label: "매매", value: "\(s.trades)건")
                StatCell(label: "매각 차익", value: Won.signed(s.tradeProfit), tint: trendColor(s.tradeProfit))
            }
            HStack {
                StatCell(label: "시설 투자", value: "\(s.improvementsBought)건")
                StatCell(label: "결정", value: "\(s.decisionsMade)번")
                StatCell(label: "할 일 완료", value: "\(s.missionsDone)개")
            }
            HStack {
                StatCell(label: "운영해 본 업종", value: "\(s.kindsOwned.count)/\(BusinessKind.allCases.count)")
                StatCell(label: "최고 하루 순이익", value: Won.short(s.bestDailyNet))
            }
            StatCell(label: "최고 순자산", value: Won.full(s.peakNetWorth))
        }
        .paperCard()
    }

    // MARK: 설정

    private var settings: some View {
        @Bindable var game = game
        return VStack(spacing: 0) {
            Toggle("진동", isOn: $game.hapticsOn)
                .font(.system(size: 16, weight: .semibold))
                .tint(Palette.sign)
                .padding(.vertical, 10)
            Divider().overlay(Palette.line)
            Button {
                showCredits = true
            } label: {
                HStack {
                    Text("만든 사람 · 라이선스")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Palette.inkFaint)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 12)
            }
            Divider().overlay(Palette.line)
            Button {
                confirmReset = true
            } label: {
                HStack {
                    Text("처음부터 다시 하기")
                    Spacer()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.sign)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line))
    }
}

struct CreditsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("한평상회").font(.myeongjo(24))
                    Text("구멍가게 하나로 시작해 그룹을 일구는 경영 시뮬레이션.")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.inkSoft)
                    DashedLine()
                    Text("게임 속 상호, 지역, 인물, 뉴스는 모두 지어낸 것이며 실제 기업·브랜드와 관계없습니다. 게임 내 돈은 실제 돈으로 바꿀 수 없습니다.")
                        .font(.system(size: 15))
                    Text("글꼴: 나눔명조 (NAVER Corporation, SIL Open Font License 1.1). 라이선스 전문은 앱 번들의 OFL-NanumFont.txt에 포함되어 있습니다.")
                        .font(.system(size: 15))
                    Text("아이콘: Apple SF Symbols")
                        .font(.system(size: 15))
                }
                .foregroundStyle(Palette.ink)
                .padding(20)
            }
            .background(Palette.paper)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}
