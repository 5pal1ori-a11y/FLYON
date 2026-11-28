import SwiftUI

/// 전체 노선도에 그릴 선과 역. 역의 실제 좌표(OpenStreetMap)를 평면에 옮긴 것이라
/// 손으로 그린 약도가 아니라 실제 지리 모양 그대로다.
final class NetworkGeometry {
    static let shared = NetworkGeometry()

    struct Track {
        let line: SubwayLine
        let segment: Int
        let points: [CGPoint]
        let closed: Bool
    }

    struct Station {
        let name: String
        let lineID: String
        let segment: Int
        let index: Int
        let point: CGPoint
    }

    let tracks: [Track]
    let stations: [Station]
    private let trackByKey: [String: Track]

    private static let originLat = 37.55
    private static let originLon = 126.99

    private static func project(_ c: [Double]) -> CGPoint {
        let x = (c[1] - originLon) * cos(originLat * .pi / 180)
        let y = -(c[0] - originLat)
        return CGPoint(x: x, y: y)
    }

    private init() {
        var tracks: [Track] = []
        var stations: [Station] = []
        var byKey: [String: Track] = [:]
        for line in SubwayCatalog.shared.lines {
            for (si, names) in line.segments.enumerated() {
                var points: [CGPoint] = []
                for name in names {
                    if let c = line.coords[name], c.count == 2 { points.append(NetworkGeometry.project(c)) }
                }
                guard points.count == names.count, points.count >= 2 else { continue }
                let track = Track(line: line, segment: si, points: points, closed: line.loop && si == 0)
                tracks.append(track)
                byKey["\(line.id)#\(si)"] = track
                for (i, name) in names.enumerated() {
                    stations.append(Station(name: name, lineID: line.id, segment: si, index: i, point: points[i]))
                }
            }
        }
        self.tracks = tracks
        self.stations = stations
        trackByKey = byKey
    }

    /// 노선도 위 열차 위치. `row`는 역 순서에 구간 내 위치를 더한 값이다.
    func point(lineID: String, segment: Int, row: Double) -> CGPoint? {
        guard let track = trackByKey["\(lineID)#\(segment)"] else { return nil }
        let last = Double(track.points.count - 1)
        let r = min(max(row, 0), last)
        let i = Int(r.rounded(.down))
        let j = min(i + 1, track.points.count - 1)
        let f = CGFloat(r - Double(i))
        let a = track.points[i]
        let b = track.points[j]
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    func station(named name: String) -> Station? {
        stations.first { $0.name == name }
    }
}

private enum MapSheet: Identifiable {
    case search
    case station(lineID: String, segment: Int, index: Int)
    case route(from: String, to: String)

    var id: String {
        switch self {
        case .search: return "search"
        case .station(let lineID, let segment, let index): return "station-\(lineID)-\(segment)-\(index)"
        case .route(let from, let to): return "route-\(from)-\(to)"
        }
    }
}

private struct TrainDot {
    let point: CGPoint
    let color: Color
}

struct NetworkMapView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings
    @State private var zoom: CGFloat = 1.5
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    @State private var sheet: MapSheet?

    private let geometry = NetworkGeometry.shared
    /// 확대 1배일 때 경위도 1도가 차지하는 화면 길이
    private let unit: CGFloat = 1500
    private let minZoom: CGFloat = 0.35
    private let maxZoom: CGFloat = 16

    private var liveKey: Bool { !settings.effectiveSeoulKey.isEmpty }

    var body: some View {
        GeometryReader { geo in
            let z = min(max(zoom * pinch, minZoom), maxZoom)
            let factor = z / zoom
            let offset = CGSize(width: pan.width * factor + drag.width, height: pan.height * factor + drag.height)

            TimelineView(.periodic(from: .now, by: 10)) { context in
                canvas(size: geo.size, z: z, offset: offset, dots: trainDots(at: context.date))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        pan.width += value.translation.width
                        pan.height += value.translation.height
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in setZoom(zoom * value.magnification) }
            )
            .onTapGesture(coordinateSpace: .local) { location in
                tap(location, size: geo.size, z: z, offset: offset)
            }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: .bottomTrailing) { zoomButtons }
            .overlay(alignment: .bottomLeading) { legend }
        }
        .background(Palette.background.ignoresSafeArea())
        .sheet(item: $sheet) { item in
            switch item {
            case .search:
                StationSearchSheet { name in focus(name) }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .station(let lineID, let segment, let index):
                if let line = store.catalog.lines.first(where: { $0.id == lineID }) {
                    StationSheet(line: line, segment: segment, index: index) { name, asOrigin in
                        sheet = asOrigin ? .route(from: name, to: "") : .route(from: "", to: name)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            case .route(let from, let to):
                RouteSheet(from: from, to: to)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: 그리기

    private func place(_ p: CGPoint, size: CGSize, z: CGFloat, offset: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + p.x * unit * z + offset.width,
            y: size.height / 2 + p.y * unit * z + offset.height
        )
    }

    private func canvas(size: CGSize, z: CGFloat, offset: CGSize, dots: [TrainDot]) -> some View {
        Canvas { context, canvasSize in
            let width = min(7, 2.2 + z * 0.55)
            for track in geometry.tracks {
                var path = Path()
                for (i, p) in track.points.enumerated() {
                    let q = place(p, size: canvasSize, z: z, offset: offset)
                    if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
                }
                if track.closed { path.closeSubpath() }
                context.stroke(
                    path,
                    with: .color(Color(hex: track.line.color)),
                    style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                )
            }

            let bounds = CGRect(origin: .zero, size: canvasSize).insetBy(dx: -30, dy: -30)
            if z >= 1.8 {
                let r = min(5.5, 1.6 + z * 0.45)
                for station in geometry.stations {
                    let q = place(station.point, size: canvasSize, z: z, offset: offset)
                    guard bounds.contains(q) else { continue }
                    let dot = Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2))
                    context.fill(dot, with: .color(.white))
                    context.stroke(dot, with: .color(Color(hex: lineColor(station.lineID))), lineWidth: max(1.2, r * 0.45))
                }
            }

            for dot in dots {
                let q = place(dot.point, size: canvasSize, z: z, offset: offset)
                guard bounds.contains(q) else { continue }
                let r = min(7, 3 + z * 0.5)
                let halo = Path(ellipseIn: CGRect(x: q.x - r * 1.9, y: q.y - r * 1.9, width: r * 3.8, height: r * 3.8))
                context.fill(halo, with: .color(dot.color.opacity(0.28)))
                let core = Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2))
                context.fill(core, with: .color(dot.color))
                context.stroke(core, with: .color(.white), lineWidth: 1.6)
            }

            if z >= 4.2 {
                var drawn = Set<String>()
                for station in geometry.stations where drawn.insert(station.name).inserted {
                    let q = place(station.point, size: canvasSize, z: z, offset: offset)
                    guard bounds.contains(q) else { continue }
                    context.draw(
                        Text(station.name).font(.pre(11, .semibold)).foregroundColor(Palette.ink),
                        at: CGPoint(x: q.x, y: q.y + 13)
                    )
                }
            }
        }
    }

    private func lineColor(_ id: String) -> String {
        store.catalog.lines.first { $0.id == id }?.color ?? "#888888"
    }

    /// 지도에 찍을 열차. 인증키가 없으면 전 노선 미리보기, 있으면 이미 받아 둔 노선의 실제 위치만.
    private func trainDots(at now: Date) -> [TrainDot] {
        var out: [TrainDot] = []
        for line in store.catalog.lines {
            let trains: [SubwayTrain]
            if let loaded = store.subway[line.id], store.subwaySource[line.id]?.isLive == true {
                trains = loaded
            } else if !liveKey {
                trains = SubwayEstimator.trains(line: line, at: now)
            } else {
                trains = []
            }
            let color = Color(hex: line.color)
            for train in trains {
                guard let placed = line.place(train),
                      let p = geometry.point(lineID: line.id, segment: placed.segment, row: placed.row) else { continue }
                out.append(TrainDot(point: p, color: color))
            }
        }
        return out
    }

    // MARK: 조작

    private func setZoom(_ value: CGFloat) {
        let next = min(max(value, minZoom), maxZoom)
        let factor = next / zoom
        pan = CGSize(width: pan.width * factor, height: pan.height * factor)
        zoom = next
    }

    private func tap(_ location: CGPoint, size: CGSize, z: CGFloat, offset: CGSize) {
        var best: NetworkGeometry.Station?
        var bestDistance: CGFloat = 26
        for station in geometry.stations {
            let q = place(station.point, size: size, z: z, offset: offset)
            let d = hypot(q.x - location.x, q.y - location.y)
            if d < bestDistance {
                bestDistance = d
                best = station
            }
        }
        if let station = best { open(station) }
    }

    private func open(_ station: NetworkGeometry.Station) {
        sheet = .station(lineID: station.lineID, segment: station.segment, index: station.index)
        if let line = store.catalog.lines.first(where: { $0.id == station.lineID }) {
            Task { await store.refreshSubway(line) }
        }
    }

    /// 검색한 역으로 지도를 옮기고 역 안내를 연다.
    private func focus(_ name: String) {
        guard let station = geometry.station(named: name) else {
            sheet = nil
            return
        }
        let next = max(zoom, 6)
        zoom = next
        pan = CGSize(width: -station.point.x * unit * next, height: -station.point.y * unit * next)
        open(station)
    }

    // MARK: 덧붙는 부품

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                sheet = .search
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.sub)
                    Text("역 이름 검색")
                        .font(.pre(15, .medium))
                        .foregroundStyle(Palette.sub)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
            }
            .buttonStyle(.plain)

            Button {
                sheet = .route(from: "", to: "")
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("경로 찾기")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var zoomButtons: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { setZoom(zoom * 1.6) }
            } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("확대")
            Rectangle().fill(Palette.hairline).frame(width: 28, height: 1)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { setZoom(zoom / 1.6) }
            } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("축소")
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Palette.ink)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }

    private var legend: some View {
        Text(liveKey ? "점은 실시간 열차 · 열어 본 노선만 표시" : "점은 미리보기 열차 · 실제 위치와 다름")
            .font(.pre(11.5, .medium))
            .foregroundStyle(Palette.sub)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.surface.opacity(0.94), in: Capsule())
            .padding(.leading, 16)
            .padding(.bottom, 22)
    }
}

/// 역 이름으로 찾기.
struct StationSearchSheet: View {
    let onPick: (String) -> Void
    @State private var query = ""
    @FocusState private var focused: Bool

    private let finder = RouteFinder.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("역 검색")
                .font(.pre(22, .bold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 26)
                .padding(.bottom, 14)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.sub)
                TextField("역 이름", text: $query)
                    .font(.pre(16))
                    .foregroundStyle(Palette.ink)
                    .autocorrectionDisabled()
                    .focused($focused)
            }
            .padding(.horizontal, 13)
            .frame(height: 46)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(finder.search(query).prefix(80)), id: \.self) { name in
                        Button {
                            onPick(name)
                        } label: {
                            HStack(spacing: 6) {
                                Text(name)
                                    .font(.pre(16, .medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                ForEach(finder.stationLines[name] ?? []) { line in
                                    LineBadge(line: line, size: 21)
                                }
                            }
                            .frame(height: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background.ignoresSafeArea())
        .onAppear { focused = true }
    }
}
