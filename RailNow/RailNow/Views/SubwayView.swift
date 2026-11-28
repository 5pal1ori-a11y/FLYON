import SwiftUI

struct SubwayView: View {
    @EnvironmentObject private var store: TrainStore
    @EnvironmentObject private var settings: AppSettings
    @State private var segment = 0
    @State private var selected: SubwayTrain?

    private var line: SubwayLine? { store.catalog.line(store.selectedLineID) }

    var body: some View {
        VStack(spacing: 0) {
            if let line {
                header(line)
                linePicker(line)
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
        .sheet(item: $selected) { train in
            if let line {
                SubwayTrainSheet(line: line, train: train)
                    .presentationDetents([.height(360)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func header(_ line: SubwayLine) -> some View {
        let favorite = settings.favorites.contains(line.id)
        return ScreenHeader(title: "지하철") {
            HStack(spacing: 10) {
                SourcePill(source: store.subwaySource[line.id] ?? .preview)
                Button {
                    settings.toggleFavorite(line.id)
                } label: {
                    Image(systemName: favorite ? "star.fill" : "star")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(favorite ? Palette.accent : Palette.sub)
                        .frame(width: 36, height: 36)
                        .background(Palette.surface, in: Circle())
                        .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))
                }
                .accessibilityLabel(favorite ? "즐겨찾기 해제" : "즐겨찾기 추가")
            }
        }
    }

    private func linePicker(_ current: SubwayLine) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.catalog.lines) { item in
                        let on = item.id == current.id
                        Button {
                            store.selectedLineID = item.id
                        } label: {
                            HStack(spacing: 7) {
                                LineBadge(line: item, size: 24)
                                if on {
                                    Text(item.name)
                                        .font(.pre(14, .semibold))
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, on ? 12 : 6)
                            .padding(.vertical, 6)
                            .background(on ? Palette.surface : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(on ? Palette.hairline : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .accessibilityLabel(item.name)
                    }
                }
                .padding(.horizontal, 14)
            }
            .onAppear { proxy.scrollTo(current.id, anchor: .center) }
            .onChange(of: current.id) { _, id in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .padding(.bottom, 10)
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
                            .font(.pre(13, on ? .semibold : .medium))
                            .foregroundStyle(on ? Palette.background : Palette.sub)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(on ? Palette.ink : Palette.raised, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
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
                    LineDiagram(line: line, stations: stations, trains: trains) { selected = $0 }
                        .padding(.top, 6)
                    footer(line)
                } header: {
                    DiagramHeader(
                        upTitle: loopMain ? "외선순환" : "\(stations.first ?? "") 방면",
                        downTitle: loopMain ? "내선순환" : "\(stations.last ?? "") 방면",
                        upCount: up,
                        downCount: trains.count - up,
                        updated: store.subwayUpdated[line.id]
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

private let trackColumn: CGFloat = 86
private let rowHeight: CGFloat = 46

private struct DiagramHeader: View {
    let upTitle: String
    let downTitle: String
    let upCount: Int
    let downCount: Int
    let updated: Date?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("운행 중 \(upCount + downCount)대")
                    .font(.pre(14, .semibold))
                    .foregroundStyle(Palette.ink)
                if let updated {
                    Text("\(KST.hms(updated)) 기준")
                        .font(.pre(11.5))
                        .foregroundStyle(Palette.sub)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 8)
            column(icon: "arrow.up", title: upTitle, count: upCount)
            column(icon: "arrow.down", title: downTitle, count: downCount)
        }
        .padding(.leading, 20)
        .padding(.vertical, 9)
        .background(Palette.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
    }

    private func column(icon: String, title: String, count: Int) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.pre(11.5, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Palette.ink)
            Text("\(count)대")
                .font(.pre(11))
                .foregroundStyle(Palette.sub)
                .monospacedDigit()
        }
        .frame(width: trackColumn)
    }
}

/// 역을 위에서 아래로 늘어놓고, 오른쪽 두 줄의 선로 위에 열차를 올린다.
private struct LineDiagram: View {
    let line: SubwayLine
    let stations: [String]
    let trains: [PlacedTrain]
    let onSelect: (SubwayTrain) -> Void

    var body: some View {
        let tint = Color(hex: line.color)
        VStack(spacing: 0) {
            ForEach(Array(stations.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 0) {
                    Text(name)
                        .font(.pre(15, .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    TrackCell(tint: tint, first: index == 0, last: index == stations.count - 1)
                    TrackCell(tint: tint, first: index == 0, last: index == stations.count - 1)
                }
                .frame(height: rowHeight)
                .padding(.leading, 20)
            }
        }
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
                        x: geo.size.width - trackColumn * (placed.towardStart ? 1.5 : 0.5),
                        y: (CGFloat(placed.row) + 0.5) * rowHeight
                    )
                    .animation(.easeInOut(duration: 0.6), value: placed.row)
                }
            }
        }
    }
}

private struct TrackCell: View {
    let tint: Color
    let first: Bool
    let last: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(first ? Color.clear : tint.opacity(0.4)).frame(width: 3)
                Rectangle().fill(last ? Color.clear : tint.opacity(0.4)).frame(width: 3)
            }
            Circle()
                .fill(Palette.background)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(tint, lineWidth: 2.5))
        }
        .frame(width: trackColumn)
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
        HStack(spacing: 3) {
            Image(systemName: placed.towardStart ? "arrow.up" : "arrow.down")
                .font(.system(size: 8.5, weight: .heavy))
            Text(label)
                .font(.pre(11, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if placed.train.express {
                Text("급")
                    .font(.pre(9.5, .bold))
                    .foregroundStyle(Color(hex: line.color))
                    .padding(.horizontal, 3)
                    .background(ink, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .frame(maxWidth: trackColumn - 8)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(hex: line.color), in: Capsule())
        .overlay(Capsule().stroke(Palette.background, lineWidth: 1.5))
        .opacity(placed.train.estimated ? 0.82 : 1)
        .contentShape(Rectangle())
        .accessibilityLabel("\(label) 열차, \(placed.train.statusText)")
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
