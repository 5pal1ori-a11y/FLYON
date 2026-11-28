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
        let subwayCount = favoriteLines.reduce(0) { $0 + (store.subway[$1.id]?.count ?? 0) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image("LogoMark")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                        .foregroundStyle(Palette.accent)
                    Text("잇고")
                        .font(.pre(19, .bold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text(KST.day(now))
                        .font(.pre(13, .medium))
                        .foregroundStyle(Palette.sub)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // 시계와 두 개의 큰 숫자
                Text(KST.hm(now))
                    .font(.pre(64, .bold))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                Text("지금 달리고 있는 열차")
                    .font(.pre(15, .medium))
                    .foregroundStyle(Palette.sub)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                HStack(spacing: 10) {
                    stat(value: subwayCount, label: "즐겨찾는 지하철", tint: Palette.live) {
                        store.tab = .subway
                    }
                    stat(value: active.count, label: "KTX·SRT·일반열차", tint: Palette.accent) {
                        store.tab = .rail
                    }
                }
                .padding(.horizontal, 20)

                if needsKey {
                    keyNotice
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                SectionTitle(title: "즐겨찾는 노선")
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                if favoriteLines.isEmpty {
                    Card {
                        Text("지하철 화면에서 별표를 누르면 여기에 노선이 모여요.")
                            .font(.pre(14))
                            .foregroundStyle(Palette.sub)
                    }
                    .padding(.horizontal, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(favoriteLines) { line in
                                Button {
                                    store.openLine(line.id)
                                } label: {
                                    FavoriteTile(
                                        line: line,
                                        trains: store.placed(line),
                                        source: store.subwaySource[line.id]
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                SectionTitle(title: "기차 전광판", trailing: "\(active.count)대 운행 중")
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                kinds(active)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    ForEach(Array(active.prefix(5))) { item in
                        Button {
                            store.openRail(item.train.id)
                        } label: {
                            RailRow(item: item, now: now)
                        }
                        .buttonStyle(.plain)
                    }
                    if active.isEmpty {
                        Card {
                            Text("지금은 운행 중인 열차가 없어요")
                                .font(.pre(14))
                                .foregroundStyle(Palette.sub)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
    }

    private func stat(value: Int, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(tint).frame(width: 26, height: 4)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(value)")
                        .font(.pre(40, .bold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Text("대")
                        .font(.pre(16, .semibold))
                        .foregroundStyle(Palette.sub)
                }
                Text(label)
                    .font(.pre(13, .medium))
                    .foregroundStyle(Palette.sub)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var keyNotice: some View {
        Button {
            store.tab = .settings
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.star)
                Text("미리보기 데이터예요. 인증키를 넣으면 실제 정보로 바뀝니다.")
                    .font(.pre(13, .medium))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.star.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func kinds(_ active: [ActiveRail]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(RailKind.allCases) { kind in
                    let count = active.filter { $0.train.kind == kind }.count
                    HStack(spacing: 6) {
                        Circle().fill(kind.color).frame(width: 7, height: 7)
                        Text(kind.rawValue)
                            .font(.pre(13, .medium))
                            .foregroundStyle(Palette.sub)
                        Text("\(count)")
                            .font(.pre(13, .bold))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.surface, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// 즐겨찾는 노선 타일. 노선색을 바탕에 깔고 본선 위 열차 위치를 점으로 찍는다.
private struct FavoriteTile: View {
    let line: SubwayLine
    let trains: [PlacedTrain]
    let source: DataSource?

    var body: some View {
        let tint = Color(hex: line.color)
        let ink = Color.onColor(hex: line.color)
        let main = trains.filter { $0.segment == 0 }
        let stations = line.segments.first ?? []
        let span = Double(max(stations.count - 1, 1))

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(line.name)
                    .font(.pre(16, .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if source?.isLive == true {
                    Text("실시간")
                        .font(.pre(10.5, .bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ink, in: Capsule())
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(source == nil ? "–" : "\(trains.count)")
                    .font(.pre(40, .bold))
                    .monospacedDigit()
                Text("대")
                    .font(.pre(15, .semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(ink)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.opacity(0.28)).frame(height: 3)
                    ForEach(main) { placed in
                        Circle()
                            .fill(ink)
                            .frame(width: 6, height: 6)
                            .offset(x: (geo.size.width - 6) * min(max(placed.row / span, 0), 1))
                    }
                }
                .frame(height: 8)
            }
            .frame(height: 8)
            .padding(.top, 8)

            Text(line.loop ? "순환선" : "\(stations.first ?? "") – \(stations.last ?? "")")
                .font(.pre(11.5, .medium))
                .foregroundStyle(ink.opacity(0.8))
                .lineLimit(1)
                .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 168, height: 178)
        .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
