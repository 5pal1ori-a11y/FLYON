import MapKit
import SwiftUI

/// 전체 노선도에 그릴 선과 역. 역의 실제 좌표(OpenStreetMap)를 그대로 써서 지도 위에 얹는다.
final class NetworkGeometry {
    static let shared = NetworkGeometry()

    struct Track: Identifiable {
        let id: String
        let line: SubwayLine
        let segment: Int
        let coordinates: [CLLocationCoordinate2D]
    }

    struct Station: Identifiable {
        let id: String
        let name: String
        let lineID: String
        let color: String
        let segment: Int
        let index: Int
        let coordinate: CLLocationCoordinate2D
    }

    let tracks: [Track]
    let stations: [Station]
    private let trackByKey: [String: Track]

    private init() {
        var tracks: [Track] = []
        var stations: [Station] = []
        var byKey: [String: Track] = [:]
        for line in SubwayCatalog.shared.lines {
            for (si, names) in line.segments.enumerated() {
                var points: [CLLocationCoordinate2D] = []
                for name in names {
                    if let c = line.coords[name], c.count == 2 {
                        points.append(CLLocationCoordinate2D(latitude: c[0], longitude: c[1]))
                    }
                }
                guard points.count == names.count, points.count >= 2 else { continue }
                for (i, name) in names.enumerated() {
                    stations.append(Station(
                        id: "\(line.id)#\(si)#\(i)", name: name, lineID: line.id, color: line.color,
                        segment: si, index: i, coordinate: points[i]
                    ))
                }
                let key = "\(line.id)#\(si)"
                // 순환선은 마지막 역에서 첫 역으로 선을 닫는다.
                let drawn = line.loop && si == 0 ? points + [points[0]] : points
                let track = Track(id: key, line: line, segment: si, coordinates: drawn)
                tracks.append(track)
                byKey[key] = track
            }
        }
        self.tracks = tracks
        self.stations = stations
        trackByKey = byKey
    }

    /// 노선 위 열차 좌표. `row`는 역 순서에 구간 내 위치를 더한 값이다.
    func coordinate(lineID: String, segment: Int, row: Double) -> CLLocationCoordinate2D? {
        guard let track = trackByKey["\(lineID)#\(segment)"] else { return nil }
        let last = Double(track.coordinates.count - 1)
        let r = min(max(row, 0), last)
        let i = Int(r.rounded(.down))
        let j = min(i + 1, track.coordinates.count - 1)
        let f = r - Double(i)
        let a = track.coordinates[i]
        let b = track.coordinates[j]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * f,
            longitude: a.longitude + (b.longitude - a.longitude) * f
        )
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

private struct TrainDot: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let color: Color
}

struct NetworkMapView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings
    @State private var camera: MapCameraPosition = .region(NetworkMapView.seoul)
    @State private var region = NetworkMapView.seoul
    @State private var sheet: MapSheet?

    private let geometry = NetworkGeometry.shared

    private static let seoul = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.545, longitude: 126.99),
        span: MKCoordinateSpan(latitudeDelta: 0.24, longitudeDelta: 0.24)
    )

    private var liveKey: Bool { !settings.effectiveSeoulKey.isEmpty }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            map(dots: trainDots(at: context.date))
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottomLeading) { legend }
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

    // MARK: 지도

    private func inView(_ c: CLLocationCoordinate2D) -> Bool {
        abs(c.latitude - region.center.latitude) <= region.span.latitudeDelta * 0.6
            && abs(c.longitude - region.center.longitude) <= region.span.longitudeDelta * 0.6
    }

    private func map(dots: [TrainDot]) -> some View {
        // 역 표시는 충분히 확대했을 때 화면 안에 있는 것만 그린다.
        let span = region.span.latitudeDelta
        let showStations = span < 0.14
        let showNames = span < 0.07
        let stations = showStations ? geometry.stations.filter { inView($0.coordinate) } : []
        let visibleDots = dots.filter { inView($0.coordinate) }
        let width: CGFloat = span < 0.1 ? 6 : (span < 0.3 ? 4.5 : 3)

        return MapReader { proxy in
            Map(position: $camera) {
                ForEach(geometry.tracks) { track in
                    MapPolyline(coordinates: track.coordinates)
                        .stroke(Color(hex: track.line.color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
                ForEach(stations) { station in
                    Annotation(station.name, coordinate: station.coordinate, anchor: .center) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Color(hex: station.color), lineWidth: 3))
                            .allowsHitTesting(false)
                    }
                    .annotationTitles(showNames ? .visible : .hidden)
                }
                ForEach(visibleDots) { dot in
                    Annotation("", coordinate: dot.coordinate, anchor: .center) {
                        Circle()
                            .fill(dot.color)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .background(Circle().fill(dot.color.opacity(0.3)).frame(width: 25, height: 25))
                            .allowsHitTesting(false)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in
                region = context.region
            }
            .onTapGesture { location in
                if let coordinate = proxy.convert(location, from: .local) {
                    tap(coordinate)
                }
            }
        }
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
                      let c = geometry.coordinate(lineID: line.id, segment: placed.segment, row: placed.row) else { continue }
                out.append(TrainDot(id: "\(line.id)#\(train.id)", coordinate: c, color: color))
            }
        }
        return out
    }

    // MARK: 조작

    /// 누른 곳에서 가장 가까운 역을 연다. 화면에 보이는 범위의 4% 안쪽만 인정한다.
    private func tap(_ c: CLLocationCoordinate2D) {
        let limit = region.span.latitudeDelta * 0.04
        let scale = cos(c.latitude * .pi / 180)
        var best: NetworkGeometry.Station?
        var bestDistance = limit
        for station in geometry.stations {
            let dx = (station.coordinate.longitude - c.longitude) * scale
            let dy = station.coordinate.latitude - c.latitude
            let d = (dx * dx + dy * dy).squareRoot()
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
        let target = MKCoordinateRegion(
            center: station.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        )
        camera = .region(target)
        region = target
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
                .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
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
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("경로 찾기")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var legend: some View {
        Text(liveKey ? "색 점은 실시간 열차 · 열어 본 노선만 표시" : "색 점은 미리보기 열차 · 실제 위치와 다름")
            .font(.pre(11.5, .medium))
            .foregroundStyle(Palette.sub)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.surface.opacity(0.94), in: Capsule())
            .padding(.leading, 16)
            .padding(.bottom, 40)
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
