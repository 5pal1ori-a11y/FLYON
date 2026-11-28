import MapKit
import SwiftUI

struct ActiveRail: Identifiable {
    let train: RailTrain
    let position: RailPosition

    var id: String { train.id }
}

extension TrainStore {
    /// 지금 달리고 있는 열차와 추정 위치. 다음 역에 빨리 닿는 순서.
    func activeRail(at now: Date, kind: RailKind? = nil) -> [ActiveRail] {
        var out: [ActiveRail] = []
        for train in rail {
            if let kind, train.kind != kind { continue }
            if let position = train.position(at: now) {
                out.append(ActiveRail(train: train, position: position))
            }
        }
        return out.sorted { $0.position.nextTime < $1.position.nextTime }
    }
}

struct RailView: View {
    @EnvironmentObject private var store: TrainStore
    @State private var filter: RailKind?
    @State private var camera: MapCameraPosition = .region(RailCatalog.koreaRegion)
    @State private var selected: RailTrain?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            content(now: context.date)
        }
        .background(Palette.background.ignoresSafeArea())
        .task { await store.loadRail() }
        .onAppear { openFocused() }
        .onChange(of: store.focusedRailID) { _, _ in openFocused() }
        .sheet(item: $selected) { train in
            RailTrainSheet(train: train, source: store.railSource)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func openFocused() {
        guard let id = store.focusedRailID else { return }
        store.focusedRailID = nil
        if let train = store.rail.first(where: { $0.id == id }) {
            selected = train
        }
    }

    private func content(now: Date) -> some View {
        let active = store.activeRail(at: now, kind: filter)
        let routes = RailCatalog.routes.filter { filter == nil || $0.kind == filter }

        return VStack(spacing: 0) {
            ScreenHeader(title: "기차") {
                SourcePill(source: store.railSource, liveLabel: "오늘 시간표")
            }
            map(active: active, routes: routes)
            filterBar
            list(active: active, now: now)
        }
    }

    private func map(active: [ActiveRail], routes: [RailRoute]) -> some View {
        Map(position: $camera) {
            ForEach(routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(route.kind.color.opacity(0.75), lineWidth: 3)
            }
            ForEach(active) { item in
                Annotation(item.train.title, coordinate: item.position.coordinate, anchor: .center) {
                    Button {
                        selected = item.train
                    } label: {
                        Circle()
                            .fill(item.train.kind.color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: item.train.kind.color, radius: 5)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 330)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Palette.background.opacity(0), Palette.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 46)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            Text("위치는 시간표로 계산한 추정값")
                .font(.pre(11, .medium))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.raised.opacity(0.92), in: Capsule())
                .padding(.leading, 16)
                .padding(.bottom, 14)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "전체", kind: nil)
                ForEach(RailKind.allCases) { kind in
                    chip(title: kind.rawValue, kind: kind)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }

    private func chip(title: String, kind: RailKind?) -> some View {
        let on = filter == kind
        return Button {
            filter = kind
        } label: {
            HStack(spacing: 6) {
                if let kind {
                    Circle().fill(kind.color).frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.pre(13, on ? .semibold : .medium))
                    .foregroundStyle(on ? Palette.background : Palette.sub)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(on ? Palette.ink : Palette.raised, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func list(active: [ActiveRail], now: Date) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                SectionTitle(title: "지금 달리는 열차", trailing: "\(active.count)대")
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)

                if active.isEmpty {
                    Text("지금은 운행 중인 열차가 없어요")
                        .font(.pre(14))
                        .foregroundStyle(Palette.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                }
                ForEach(active) { item in
                    Button {
                        selected = item.train
                    } label: {
                        RailRow(item: item, now: now)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

/// 전광판 한 줄: 왼쪽 색 막대, 구간, 오른쪽에 다음 역까지 남은 시간.
struct RailRow: View {
    let item: ActiveRail
    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(item.train.kind.color)
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(item.train.title)
                        .font(.pre(12.5, .bold))
                        .foregroundStyle(Palette.sub)
                        .monospacedDigit()
                    Circle().fill(Palette.faint).frame(width: 3, height: 3)
                    Text("\(item.position.previous) – \(item.position.next)")
                        .font(.pre(12.5, .medium))
                        .foregroundStyle(Palette.sub)
                        .lineLimit(1)
                }
                Text("\(item.train.origin) → \(item.train.destination)")
                    .font(.pre(18, .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                ProgressBar(value: item.position.progress, tint: item.train.kind.color)
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)

            VStack(alignment: .trailing, spacing: 2) {
                Text(minutesText(item.position.nextTime.timeIntervalSince(now)))
                    .font(.pre(22, .bold))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                Text("\(item.position.next) 도착")
                    .font(.pre(12, .medium))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(1)
            }
            .frame(minWidth: 84, alignment: .trailing)
            .padding(.horizontal, 14)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.raised)
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 4)
    }
}

struct RailTrainSheet: View {
    let train: RailTrain
    let source: DataSource

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            content(now: context.date)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private func content(now: Date) -> some View {
        let position = train.position(at: now)
        let stops = train.stopTimes

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    KindBadge(kind: train.kind, text: train.kindName)
                    if !train.number.isEmpty {
                        Text("\(train.number) 열차")
                            .font(.pre(14, .semibold))
                            .foregroundStyle(Palette.sub)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text(train.route.name)
                        .font(.pre(13, .medium))
                        .foregroundStyle(Palette.sub)
                }
                .padding(.top, 28)

                Text("\(train.origin) → \(train.destination)")
                    .font(.pre(26, .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 12)

                Group {
                    if let position {
                        Text("\(position.next)까지 \(minutesText(position.nextTime.timeIntervalSince(now))) · \(KST.hm(position.nextTime)) 도착 예정")
                    } else if now < train.depart {
                        Text("\(KST.hm(train.depart)) 출발 예정")
                    } else {
                        Text("\(KST.hm(train.arrive)) 운행 종료")
                    }
                }
                .font(.pre(15, .medium))
                .foregroundStyle(Palette.accent)
                .monospacedDigit()
                .padding(.top, 6)

                ProgressBar(value: position?.progress ?? (now < train.depart ? 0 : 1), tint: train.kind.color)
                    .padding(.top, 16)
                    .padding(.bottom, 22)

                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    StopRow(
                        stop: stop,
                        tint: train.kind.color,
                        passed: stop.time <= now,
                        first: index == 0,
                        last: index == stops.count - 1
                    )
                }

                Text(note)
                    .font(.pre(12.5))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 22)
        }
    }

    private var note: String {
        if train.scheduled {
            return "출발·종착 시각은 공공데이터포털(국토교통부 TAGO) 시간표이고, 중간 역 시각과 현재 위치는 구간 비율로 계산한 추정값입니다. 지연은 반영되지 않으니 승차 전에는 운영사 안내를 확인하세요."
        }
        return "인증키가 없어 배차 간격으로 만든 미리보기 열차입니다. 실제 시간표와 다릅니다."
    }
}

private struct StopRow: View {
    let stop: RailStopTime
    let tint: Color
    let passed: Bool
    let first: Bool
    let last: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                VStack(spacing: 0) {
                    Rectangle().fill(first ? Color.clear : tint.opacity(0.4)).frame(width: 3)
                    Rectangle().fill(last ? Color.clear : tint.opacity(0.4)).frame(width: 3)
                }
                Circle()
                    .fill(passed ? tint : Palette.background)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(tint, lineWidth: 2.5))
            }
            .frame(width: 14)

            Text(stop.name)
                .font(.pre(15, first || last ? .semibold : .medium))
                .foregroundStyle(passed ? Palette.sub : Palette.ink)
            Spacer()
            Text(KST.hm(stop.time))
                .font(.pre(14, .medium))
                .foregroundStyle(passed ? Palette.faint : Palette.ink)
                .monospacedDigit()
        }
        .frame(height: 40)
    }
}
