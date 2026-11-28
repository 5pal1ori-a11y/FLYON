import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings

    private var favoriteLines: [SubwayLine] {
        settings.favorites.compactMap { id in
            store.catalog.lines.first { $0.id == id }
        }
    }

    private var needsKey: Bool {
        settings.effectiveSeoulKey.isEmpty || settings.effectiveRailKey.isEmpty
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            content(now: context.date)
        }
        .background(Palette.background.ignoresSafeArea())
        .task(id: settings.favorites) {
            while !Task.isCancelled {
                for line in favoriteLines {
                    await store.refreshSubway(line)
                }
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        .task { await store.loadRail() }
    }

    private func content(now: Date) -> some View {
        let active = store.activeRail(at: now)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KST.day(now))
                        .font(.pre(14, .medium))
                        .foregroundStyle(Palette.sub)
                    Text("지금 열차는 어디쯤")
                        .font(.pre(28, .bold))
                        .foregroundStyle(Palette.ink)
                }
                .padding(.top, 14)
                .padding(.bottom, 22)

                if needsKey {
                    keyNotice
                        .padding(.bottom, 26)
                }

                SectionTitle(title: "즐겨찾는 노선")
                    .padding(.bottom, 12)
                if favoriteLines.isEmpty {
                    Card {
                        Text("지하철 화면에서 별표를 누르면 여기에 노선이 모여요.")
                            .font(.pre(14))
                            .foregroundStyle(Palette.sub)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(favoriteLines) { line in
                            Button {
                                store.openLine(line.id)
                            } label: {
                                FavoriteCard(
                                    line: line,
                                    trains: store.placed(line),
                                    source: store.subwaySource[line.id]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionTitle(title: "달리고 있는 기차", trailing: "\(active.count)대")
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                kindGrid(active)

                if !active.isEmpty {
                    SectionTitle(title: "곧 다음 역에 닿는 열차")
                        .padding(.top, 30)
                        .padding(.bottom, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(active.prefix(5))) { item in
                            Button {
                                store.openRail(item.train.id)
                            } label: {
                                RailRow(item: item, now: now)
                                    .padding(.horizontal, -20)
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(Palette.hairline).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private var keyNotice: some View {
        Button {
            store.tab = .settings
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text("지금은 미리보기 데이터예요")
                        .font(.pre(15, .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("공공데이터 인증키를 넣으면 실제 지하철 위치와 오늘 열차 시간표로 바뀝니다.")
                        .font(.pre(13))
                        .foregroundStyle(Palette.sub)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.faint)
            }
            .padding(14)
            .background(Palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func kindGrid(_ active: [ActiveRail]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(RailKind.allCases) { kind in
                let count = active.filter { $0.train.kind == kind }.count
                Button {
                    store.tab = .rail
                } label: {
                    Card(padding: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Circle().fill(kind.color).frame(width: 8, height: 8)
                                Text(kind.rawValue)
                                    .font(.pre(13.5, .semibold))
                                    .foregroundStyle(Palette.sub)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(count)")
                                    .font(.pre(26, .bold))
                                    .foregroundStyle(Palette.ink)
                                    .monospacedDigit()
                                Text("대 운행 중")
                                    .font(.pre(13))
                                    .foregroundStyle(Palette.sub)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 즐겨찾는 노선 카드. 본선 위 열차 위치를 가로 띠에 점으로 찍는다.
private struct FavoriteCard: View {
    let line: SubwayLine
    let trains: [PlacedTrain]
    let source: DataSource?

    var body: some View {
        let main = trains.filter { $0.segment == 0 }
        let stations = line.segments.first ?? []
        let span = Double(max(stations.count - 1, 1))

        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    LineBadge(line: line, size: 26)
                    Text(line.name)
                        .font(.pre(16, .semibold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    if let source {
                        Text("\(trains.count)대")
                            .font(.pre(15, .bold))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                        Circle()
                            .fill(source.isLive ? Palette.live : Palette.faint)
                            .frame(width: 6, height: 6)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: line.color).opacity(0.28))
                            .frame(height: 3)
                        ForEach(main) { placed in
                            Circle()
                                .fill(Color(hex: line.color))
                                .frame(width: 7, height: 7)
                                .offset(x: (geo.size.width - 7) * min(max(placed.row / span, 0), 1))
                        }
                    }
                    .frame(height: 8)
                }
                .frame(height: 8)

                HStack {
                    Text(line.loop ? "순환" : stations.first ?? "")
                    Spacer()
                    Text(line.loop ? "" : stations.last ?? "")
                }
                .font(.pre(11.5))
                .foregroundStyle(Palette.sub)
            }
        }
    }
}
