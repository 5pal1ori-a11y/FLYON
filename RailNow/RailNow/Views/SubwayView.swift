import SwiftUI

struct SubwayView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings
    @State private var segment = 0
    @State private var sheet: SubwaySheet?

    private var line: SubwayLine? { store.catalog.line(store.selectedLineID) }

    var body: some View {
        VStack(spacing: 0) {
            if let line {
                header(line)
                if line.segments.count > 1 { segmentPicker(line) }
                diagram(line)
            } else {
                Spacer()
                Text("노선 자료를 불러오지 못했어요")
                    .font(.pre(15))
                    .foregroundStyle(Palette.sub)
                Spacer()
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .task(id: store.selectedLineID) {
            while !Task.isCancelled {
                if let line = store.catalog.line(store.selectedLineID) {
                    await store.refreshSubway(line)
                }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        .onChange(of: store.selectedLineID) { _, _ in segment = 0 }
        .sheet(item: $sheet) { item in
            if let line {
                switch item {
                case .search:
                    StationSearchSheet { name in openStation(name, current: line) }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .lines:
                    LinePickerSheet { id in
                        store.selectedLineID = id
                        sheet = nil
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .train(let train):
                    SubwayTrainSheet(line: line, train: train)
                        .presentationDetents([.height(360)])
                        .presentationDragIndicator(.visible)
                case .station(let si, let index):
                    if si < line.segments.count, index < line.segments[si].count {
                        StationSheet(line: line, segment: si, index: index) { name, asOrigin in
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
        #if DEBUG
        .onAppear {
            // 시뮬레이터 스크린샷용: -screenshotSheet station|route|lines
            switch UserDefaults.standard.string(forKey: "screenshotSheet") {
            case "station": sheet = .station(segment: 0, index: 21)
            case "route": sheet = .route(from: "서울", to: "판교")
            case "lines": sheet = .lines
            default: break
            }
        }
        #endif
    }

    /// 검색한 역이 지금 노선에 있으면 그 노선에서, 없으면 그 역을 지나는 첫 노선에서 역 안내를 연다.
    private func openStation(_ name: String, current: SubwayLine) {
        let passing = RouteFinder.shared.stationLines[name] ?? []
        guard let target = passing.first(where: { $0.id == current.id }) ?? passing.first else {
            sheet = nil
            return
        }
        for (si, stations) in target.segments.enumerated() {
            if let index = stations.firstIndex(of: name) {
                store.selectedLineID = target.id
                sheet = .station(segment: si, index: index)
                return
            }
        }
        sheet = nil
    }

    /// 노선 이름을 크게 두고, 누르면 전체 노선 목록이 열린다.
    private func header(_ line: SubwayLine) -> some View {
        let favorite = settings.favorites.contains(line.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    sheet = .lines
                } label: {
                    HStack(spacing: 10) {
                        LineBadge(line: line, size: 36)
                        Text(line.name)
                            .font(.pre(28, .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.sub)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("노선 바꾸기, 지금 \(line.name)")

                Spacer(minLength: 4)
                CircleButton(icon: "magnifyingglass", label: "역 검색") {
                    sheet = .search
                }
                CircleButton(icon: "arrow.triangle.turn.up.right.diamond.fill", tint: Palette.accent, label: "경로 찾기") {
                    sheet = .route(from: "", to: "")
                }
                CircleButton(
                    icon: favorite ? "star.fill" : "star",
                    tint: favorite ? Palette.star : Palette.sub,
                    label: favorite ? "즐겨찾기 해제" : "즐겨찾기 추가"
                ) {
                    settings.toggleFavorite(line.id)
                }
            }
            HStack(spacing: 8) {
                SourcePill(source: store.subwaySource[line.id] ?? .preview)
                if let updated = store.subwayUpdated[line.id] {
                    Text("\(KST.hms(updated)) 기준 · 운행 중 \(store.subway[line.id]?.count ?? 0)대")
                        .font(.pre(12.5, .medium))
                        .foregroundStyle(Palette.sub)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private func segmentPicker(_ line: SubwayLine) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<line.segments.count, id: \.self) { i in
                    let on = i == min(segment, line.segments.count - 1)
                    Button {
                        segment = i
                    } label: {
                        Text(line.segmentTitle(i))
                            .font(.pre(13, on ? .bold : .medium))
                            .foregroundStyle(on ? Color.onColor(hex: line.color) : Palette.sub)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(on ? Color(hex: line.color) : Palette.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private func diagram(_ line: SubwayLine) -> some View {
        let si = min(segment, line.segments.count - 1)
        let stations = line.segments[si]
        let trains = store.placed(line).filter { $0.segment == si }
        let up = trains.filter(\.towardStart).count
        let loopMain = line.loop && si == 0

        return ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    LineDiagram(
                        line: line, stations: stations, trains: trains,
                        onStation: { sheet = .station(segment: si, index: $0) },
                        onSelect: { sheet = .train($0) }
                    )
                    .padding(.top, 8)
                    footer(line)
                } header: {
                    DiagramHeader(
                        upTitle: loopMain ? "외선순환" : "\(stations.first ?? "") 방면",
                        downTitle: loopMain ? "내선순환" : "\(stations.last ?? "") 방면",
                        upCount: up,
                        downCount: trains.count - up
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func footer(_ line: SubwayLine) -> some View {
        let source = store.subwaySource[line.id] ?? .preview
        VStack(alignment: .leading, spacing: 6) {
            switch source {
            case .live:
                Text("서울 열린데이터광장 실시간 열차 위치 · 20초마다 새로 받아요")
            case .preview:
                if line.live == nil {
                    Text("이 노선은 실시간 위치가 공개되지 않아 운행 간격으로 만든 미리보기를 보여 줘요. 실제 열차 위치와 다릅니다.")
                } else {
                    Text("인증키가 없어 운행 간격으로 만든 미리보기를 보여 주고 있어요. 실제 열차 위치와 다릅니다. 설정에서 키를 넣으면 실시간으로 바뀝니다.")
                }
            case .failed(let message):
                Text("실시간 정보를 받지 못해 미리보기를 보여 주고 있어요. (\(message))")
            }
        }
        .font(.pre(12.5))
        .foregroundStyle(Palette.sub)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 28)
    }
}

// 노선도 치수: 왼쪽은 위로 가는 열차, 가운데 굵은 선로, 그 옆에 역 이름, 오른쪽 끝은 아래로 가는 열차
private let sideColumn: CGFloat = 96
private let trackWidth: CGFloat = 30
private let sidePadding: CGFloat = 12
private let rowHeight: CGFloat = 52

private struct DiagramHeader: View {
    let upTitle: String
    let downTitle: String
    let upCount: Int
    let downCount: Int

    var body: some View {
        HStack(spacing: 0) {
            side(icon: "arrow.up", title: upTitle, count: upCount)
            Spacer(minLength: 8)
            side(icon: "arrow.down", title: downTitle, count: downCount)
        }
        .padding(.horizontal, sidePadding)
        .padding(.vertical, 9)
        .background(Palette.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
    }

    private func side(icon: String, title: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .heavy))
            Text(title)
                .font(.pre(12.5, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(count)")
                .font(.pre(12.5, .bold))
                .foregroundStyle(Palette.sub)
                .monospacedDigit()
        }
        .foregroundStyle(Palette.ink)
    }
}

private struct LineDiagram: View {
    let line: SubwayLine
    let stations: [String]
    let trains: [PlacedTrain]
    let onStation: (Int) -> Void
    let onSelect: (SubwayTrain) -> Void

    var body: some View {
        let tint = Color(hex: line.color)
        VStack(spacing: 0) {
            ForEach(Array(stations.enumerated()), id: \.offset) { index, name in
                Button {
                    onStation(index)
                } label: {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: sideColumn)
                        TrackCell(tint: tint, first: index == 0, last: index == stations.count - 1)
                        Text(name)
                            .font(.pre(16, .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.leading, 12)
                        Spacer(minLength: sideColumn)
                    }
                    .frame(height: rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, sidePadding)
        .overlay {
            GeometryReader { geo in
                ForEach(trains) { placed in
                    Button {
                        onSelect(placed.train)
                    } label: {
                        TrainChip(line: line, placed: placed)
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: placed.towardStart
                            ? sidePadding + sideColumn / 2
                            : geo.size.width - sidePadding - sideColumn / 2,
                        y: (CGFloat(placed.row) + 0.5) * rowHeight
                    )
                    .animation(.easeInOut(duration: 0.6), value: placed.row)
                }
            }
        }
    }
}

/// 굵은 선로 한 칸과 역 표시.
private struct TrackCell: View {
    let tint: Color
    let first: Bool
    let last: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(first ? Color.clear : tint).frame(width: 7)
                Rectangle().fill(last ? Color.clear : tint).frame(width: 7)
            }
            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(tint, lineWidth: 3))
        }
        .frame(width: trackWidth)
    }
}

private struct TrainChip: View {
    let line: SubwayLine
    let placed: PlacedTrain

    private var label: String {
        let d = SubwayLine.normalize(placed.train.destination)
        if d.isEmpty { return placed.train.number }
        return d.hasSuffix("순환") ? d : "\(d)행"
    }

    var body: some View {
        let ink = Color.onColor(hex: line.color)
        HStack(spacing: 4) {
            Image(systemName: placed.towardStart ? "arrow.up" : "arrow.down")
                .font(.system(size: 9.5, weight: .heavy))
            Text(label)
                .font(.pre(12, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if placed.train.express {
                Text("급")
                    .font(.pre(10, .bold))
                    .foregroundStyle(Color(hex: line.color))
                    .padding(.horizontal, 3)
                    .background(ink, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .frame(maxWidth: sideColumn - 6)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(hex: line.color), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: Color(hex: line.color).opacity(placed.train.estimated ? 0 : 0.55), radius: 6)
        .opacity(placed.train.estimated ? 0.9 : 1)
        .contentShape(Rectangle())
        .accessibilityLabel("\(label) 열차, \(placed.train.statusText)")
    }
}

/// 전체 노선 목록. 두 줄 격자로 보여 준다.
struct LinePickerSheet: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings
    let onPick: (String) -> Void

    var body: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("노선 선택")
                    .font(.pre(22, .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 26)
                    .padding(.bottom, 16)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.catalog.lines) { line in
                        let on = line.id == store.selectedLineID
                        Button {
                            onPick(line.id)
                        } label: {
                            HStack(spacing: 9) {
                                LineBadge(line: line, size: 28)
                                Text(line.name)
                                    .font(.pre(15, .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer(minLength: 0)
                                if settings.favorites.contains(line.id) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Palette.star)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 54)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(on ? Color(hex: line.color) : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("인천 1·2호선, 김포골드라인, 용인·의정부경전철은 실시간 위치가 공개되지 않아 미리보기로만 나옵니다.")
                    .font(.pre(12.5))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .background(Palette.background.ignoresSafeArea())
    }
}

struct SubwayTrainSheet: View {
    let line: SubwayLine
    let train: SubwayTrain

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LineBadge(line: line, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(train.destination.isEmpty ? line.name : "\(SubwayLine.normalize(train.destination)) 방면")
                        .font(.pre(20, .bold))
                        .foregroundStyle(Palette.ink)
                    Text(train.estimated ? "\(line.name) · 미리보기 열차" : "\(line.name) · 열차번호 \(train.number)")
                        .font(.pre(13))
                        .foregroundStyle(Palette.sub)
                }
                Spacer()
            }
            .padding(.top, 26)
            .padding(.bottom, 16)

            Text(train.statusText)
                .font(.pre(17, .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 10)

            Divider().overlay(Palette.hairline)
            DetailRow(label: "운행 구분", value: train.express ? "급행" : "일반")
            Divider().overlay(Palette.hairline)
            DetailRow(label: "막차 여부", value: train.lastCar ? "막차" : "아님")
            Divider().overlay(Palette.hairline)
            if let received = train.receivedAt {
                DetailRow(label: "위치 수신 시각", value: KST.hms(received))
            } else {
                DetailRow(label: "위치 수신 시각", value: "없음 (미리보기)")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background.ignoresSafeArea())
    }
}
