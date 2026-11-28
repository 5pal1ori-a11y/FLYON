import SwiftUI

/// 지하철 화면에서 띄우는 시트 종류.
enum SubwaySheet: Identifiable {
    case train(SubwayTrain)
    case station(segment: Int, index: Int)
    case route(from: String, to: String)

    var id: String {
        switch self {
        case .train(let train): return "train-\(train.id)"
        case .station(let segment, let index): return "station-\(segment)-\(index)"
        case .route(let from, let to): return "route-\(from)-\(to)"
        }
    }
}

// MARK: - 역 안내

struct StationSheet: View {
    @EnvironmentObject private var store: TrainStore
    let line: SubwayLine
    let segment: Int
    let index: Int
    /// (역 이름, 출발역으로 쓸지)
    let onRoute: (String, Bool) -> Void

    private struct Arrival: Identifiable {
        let train: SubwayTrain
        let distance: Double
        var id: String { train.id }

        var where_: String {
            if distance < 0.15 { return "도착" }
            if distance < 1 { return "곧 도착" }
            return "\(Int((distance - 0.01).rounded(.up)))정거장 전"
        }

        var eta: String {
            distance < 0.15 ? "지금" : "약 \(max(1, Int((distance * 2).rounded())))분"
        }
    }

    private var stations: [String] { line.segments[segment] }
    private var loopMain: Bool { line.loop && segment == 0 }

    private func arrivals(towardStart: Bool) -> [Arrival] {
        let n = Double(stations.count)
        var out: [Arrival] = []
        for placed in store.placed(line) where placed.segment == segment && placed.towardStart == towardStart {
            var d = towardStart ? placed.row - Double(index) : Double(index) - placed.row
            if loopMain && d < -0.05 { d += n }
            if d >= -0.05 { out.append(Arrival(train: placed.train, distance: max(d, 0))) }
        }
        return Array(out.sorted { $0.distance < $1.distance }.prefix(3))
    }

    var body: some View {
        let name = stations[index]
        let n = stations.count
        let before: String? = index > 0 ? stations[index - 1] : (loopMain ? stations[n - 1] : nil)
        let after: String? = index < n - 1 ? stations[index + 1] : (loopMain ? stations[0] : nil)
        let others = (RouteFinder.shared.stationLines[name] ?? []).filter { $0.id != line.id }
        let source = store.subwaySource[line.id] ?? .preview

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    LineBadge(line: line, size: 24)
                    ForEach(others) { other in
                        LineBadge(line: other, size: 24)
                    }
                    Spacer()
                    SourcePill(source: source)
                }
                .padding(.top, 26)

                sign(name: name, before: before, after: after)
                    .padding(.top, 18)
                    .padding(.bottom, 24)

                if before != nil {
                    direction(
                        title: loopMain ? "외선순환" : "\(stations[0]) 방면",
                        icon: "arrow.up",
                        list: arrivals(towardStart: true)
                    )
                    .padding(.bottom, 12)
                }
                if after != nil {
                    direction(
                        title: loopMain ? "내선순환" : "\(stations[n - 1]) 방면",
                        icon: "arrow.down",
                        list: arrivals(towardStart: false)
                    )
                }

                HStack(spacing: 10) {
                    routeButton(title: "여기서 출발", filled: false) { onRoute(name, true) }
                    routeButton(title: "여기로 도착", filled: true) { onRoute(name, false) }
                }
                .padding(.top, 20)

                Text(source.isLive
                     ? "남은 시간은 열차 위치에 정거장당 약 2분을 곱한 추정값이에요."
                     : "미리보기 데이터라 실제 열차 위치와 다릅니다.")
                    .font(.pre(12.5))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 22)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    /// 승강장 역명판처럼 이전 역과 다음 역 사이에 지금 역을 크게 둔다.
    private func sign(name: String, before: String?, after: String?) -> some View {
        let tint = Color(hex: line.color)
        let ink = Color.onColor(hex: line.color)
        return ZStack {
            HStack(spacing: 4) {
                if let before {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text(before).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 130)
                if let after {
                    Text(after).lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
            }
            .font(.pre(13, .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(tint, in: Capsule())

            Text(name)
                .font(.pre(21, .bold))
                .foregroundStyle(Color(hex: "#14161A"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 22)
                .frame(minWidth: 120, maxWidth: 170)
                .frame(height: 60)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(tint, lineWidth: 5))
        }
    }

    private func direction(title: String, icon: String, list: [Arrival]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 11, weight: .bold))
                    Text(title).font(.pre(14, .semibold))
                }
                .foregroundStyle(Palette.sub)
                .padding(.bottom, 8)

                if list.isEmpty {
                    Text("들어오는 열차가 없어요")
                        .font(.pre(14))
                        .foregroundStyle(Palette.faint)
                        .padding(.vertical, 8)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { order, item in
                    if order > 0 { Divider().overlay(Palette.hairline) }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.where_)
                                .font(.pre(16, .semibold))
                                .foregroundStyle(order == 0 ? Palette.ink : Palette.sub)
                            Text(trainLabel(item.train))
                                .font(.pre(12.5))
                                .foregroundStyle(Palette.sub)
                        }
                        Spacer()
                        Text(item.eta)
                            .font(.pre(16, .bold))
                            .foregroundStyle(order == 0 ? Palette.accent : Palette.sub)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    private func trainLabel(_ train: SubwayTrain) -> String {
        let dest = SubwayLine.normalize(train.destination)
        var parts: [String] = []
        if !dest.isEmpty { parts.append(dest.hasSuffix("순환") ? dest : "\(dest)행") }
        if train.express { parts.append("급행") }
        if train.lastCar { parts.append("막차") }
        if !train.number.isEmpty { parts.append(train.number) }
        parts.append("현재 \(SubwayLine.normalize(train.station))")
        return parts.joined(separator: " · ")
    }

    private func routeButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pre(15, .semibold))
                .foregroundStyle(filled ? Color.white : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(filled ? Palette.accent : Palette.raised, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 경로 찾기

struct RouteSheet: View {
    @State var from: String
    @State var to: String
    @State private var picking: Slot?
    @State private var query = ""
    @FocusState private var searching: Bool

    private enum Slot {
        case from, to
    }

    private let finder = RouteFinder.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("경로 찾기")
                .font(.pre(22, .bold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 26)
                .padding(.bottom, 14)

            fields

            if picking != nil {
                picker
            } else if from.isEmpty || to.isEmpty {
                hint("출발역과 도착역을 골라 주세요")
            } else if let plan = finder.plan(from: from, to: to) {
                result(plan)
            } else {
                hint(from == to ? "출발역과 도착역이 같아요" : "이어지는 길을 찾지 못했어요")
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            if from.isEmpty { pick(.from) } else if to.isEmpty { pick(.to) }
        }
    }

    private func pick(_ slot: Slot) {
        picking = slot
        query = ""
        searching = true
    }

    private var fields: some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                field(label: "출발", value: from, tint: Palette.live, active: picking == .from) { pick(.from) }
                Rectangle().fill(Palette.hairline).frame(height: 1).padding(.leading, 44)
                field(label: "도착", value: to, tint: Palette.accent, active: picking == .to) { pick(.to) }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairline, lineWidth: 1))

            Button {
                let old = from
                from = to
                to = old
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(Palette.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("출발역과 도착역 바꾸기")
        }
    }

    private func field(label: String, value: String, tint: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().stroke(tint, lineWidth: 3).frame(width: 11, height: 11)
                Text(label)
                    .font(.pre(13, .medium))
                    .foregroundStyle(Palette.sub)
                Text(value.isEmpty ? "역 선택" : value)
                    .font(.pre(16, .semibold))
                    .foregroundStyle(value.isEmpty ? Palette.faint : Palette.ink)
                Spacer()
                if active {
                    Circle().fill(Palette.accent).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var picker: some View {
        VStack(spacing: 0) {
            TextField("역 이름 검색", text: $query)
                .font(.pre(15))
                .foregroundStyle(Palette.ink)
                .autocorrectionDisabled()
                .focused($searching)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(Palette.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 14)
                .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(finder.search(query).prefix(60)), id: \.self) { name in
                        Button {
                            if picking == .from { from = name } else { to = name }
                            searching = false
                            if from.isEmpty { pick(.from) } else if to.isEmpty { pick(.to) } else { picking = nil }
                        } label: {
                            HStack(spacing: 6) {
                                Text(name)
                                    .font(.pre(15, .medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                ForEach(finder.stationLines[name] ?? []) { line in
                                    LineBadge(line: line, size: 20)
                                }
                            }
                            .frame(height: 46)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func barWidth(_ leg: RouteLeg, plan: RoutePlan, total: CGFloat) -> CGFloat {
        let riding = plan.legs.reduce(0) { $0 + $1.minutes }
        let usable = total - CGFloat(plan.legs.count - 1) * 3
        let share = CGFloat(leg.minutes) / CGFloat(max(riding, 1))
        return max(10, usable * share)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.pre(14))
            .foregroundStyle(Palette.sub)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private func result(_ plan: RoutePlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("약 \(plan.totalMinutes)분")
                        .font(.pre(30, .bold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Text(plan.transfers == 0 ? "환승 없음 · \(plan.hops)개 역" : "환승 \(plan.transfers)회 · \(plan.hops)개 역")
                        .font(.pre(14, .medium))
                        .foregroundStyle(Palette.sub)
                }
                .padding(.top, 22)

                // 구간 길이에 비례한 색 띠
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(plan.legs) { leg in
                            Capsule()
                                .fill(Color(hex: leg.line.color))
                                .frame(width: barWidth(leg, plan: plan, total: geo.size.width))
                        }
                    }
                }
                .frame(height: 6)
                .padding(.top, 12)
                .padding(.bottom, 24)

                ForEach(plan.legs) { leg in
                    if leg.id > 0 {
                        HStack(spacing: 12) {
                            VStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle().fill(Palette.faint).frame(width: 3, height: 3)
                                }
                            }
                            .frame(width: 26)
                            Text("환승 · 약 \(Int(RouteFinder.transferMinutes))분")
                                .font(.pre(12.5, .medium))
                                .foregroundStyle(Palette.sub)
                        }
                        .frame(height: 34)
                    }
                    LegView(leg: leg)
                }

                Text("소요 시간은 노선별 평균 역 간 시간과 환승 4분으로 계산한 추정값이에요. 실제 시간표, 급행 여부, 환승 거리에 따라 달라집니다.")
                    .font(.pre(12.5))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 22)
                    .padding(.bottom, 30)
            }
        }
    }
}

private struct LegView: View {
    let leg: RouteLeg
    @State private var expanded = false

    var body: some View {
        let tint = Color(hex: leg.line.color)
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                LineBadge(line: leg.line, size: 26)
                Rectangle().fill(tint).frame(width: 4)
                Circle()
                    .fill(Palette.background)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(tint, lineWidth: 3.5))
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 0) {
                Text(leg.from)
                    .font(.pre(17, .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(height: 26)
                Text("\(leg.line.name) · \(leg.heading)")
                    .font(.pre(13))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 4)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(leg.hops)개 역 · 약 \(leg.minutes)분")
                            .font(.pre(13, .semibold))
                        if leg.hops > 1 {
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Palette.raised, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(leg.hops <= 1)
                .padding(.top, 10)

                if expanded {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(leg.stations.dropFirst().dropLast()), id: \.self) { name in
                            Text(name)
                                .font(.pre(13.5))
                                .foregroundStyle(Palette.sub)
                        }
                    }
                    .padding(.top, 10)
                }

                Text(leg.to)
                    .font(.pre(17, .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 14)
            }
            Spacer(minLength: 0)
        }
    }
}
