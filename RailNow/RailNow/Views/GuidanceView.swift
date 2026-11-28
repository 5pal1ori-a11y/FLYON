import SwiftUI

/// 탑승 안내 화면. 지금 역을 크게 보여 주고, 내릴 역까지 남은 정거장과 지나갈 역을 늘어놓는다.
struct GuidanceView: View {
    @EnvironmentObject private var guide: RideGuide
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("탑승 안내")
                    .font(.pre(17, .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                CircleButton(icon: "chevron.down", label: "안내 화면 내리기") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if let current = guide.current {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            hero(current)
                            stats
                                .padding(.top, 10)
                            sourceNote
                                .padding(.top, 12)

                            if guide.phase == .waiting {
                                Button {
                                    guide.boarded()
                                } label: {
                                    Text("열차에 탔어요")
                                        .font(.pre(16, .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 16)
                            }

                            SectionTitle(title: "지나가는 역", trailing: "역을 누르면 지금 위치로 맞춰요")
                                .padding(.top, 28)
                                .padding(.bottom, 8)
                            ForEach(guide.stops) { stop in
                                Button {
                                    guide.setCurrent(stop.id)
                                } label: {
                                    StopLine(
                                        stop: stop,
                                        state: stop.id < guide.index ? .passed : (stop.id == guide.index ? .current : .ahead),
                                        first: stop.id == 0,
                                        last: stop.id == guide.stops.count - 1
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(stop.id)
                            }

                            Text("지하에서는 GPS가 잘 잡히지 않아요. 그럴 때는 역 사이 평균 시간으로 위치를 추정하므로 실제와 한두 정거장 다를 수 있어요. 위치는 이 기기 안에서 가까운 역을 찾는 데만 쓰고, 저장하거나 밖으로 보내지 않아요.")
                                .font(.pre(12.5))
                                .foregroundStyle(Palette.sub)
                                .lineSpacing(3)
                                .padding(.top, 20)

                            Button {
                                guide.stop()
                                dismiss()
                            } label: {
                                Text(guide.phase == .finished ? "안내 마치기" : "안내 종료")
                                    .font(.pre(15, .semibold))
                                    .foregroundStyle(guide.phase == .finished ? Color.white : Palette.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        guide.phase == .finished ? Palette.accent : Palette.raised,
                                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 20)
                            .padding(.bottom, 30)
                        }
                        .padding(.horizontal, 20)
                    }
                    .onChange(of: guide.index) { _, id in
                        withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(max(id - 1, 0), anchor: .center) }
                    }
                }
            } else {
                Spacer()
                Text("진행 중인 안내가 없어요")
                    .font(.pre(15))
                    .foregroundStyle(Palette.sub)
                Spacer()
            }
        }
        .background(Palette.background.ignoresSafeArea())
    }

    /// 노선색 판 위에 지금 역 이름을 크게 쓴다.
    private func hero(_ current: RideStop) -> some View {
        let tint = Color(hex: current.line.color)
        let ink = Color.onColor(hex: current.line.color)
        let label: String
        switch guide.phase {
        case .waiting: label = "출발역"
        case .finished: label = "도착했어요"
        default: label = "이번 역"
        }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(current.line.name)
                    .font(.pre(13, .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(ink, in: Capsule())
                Text(label)
                    .font(.pre(14, .semibold))
                    .foregroundStyle(ink.opacity(0.85))
                Spacer()
            }
            Text(current.name)
                .font(.pre(44, .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 14)

            if current.kind == .transfer, let nextLine = current.nextLine {
                Text("내려서 \(nextLine.name)으로 갈아타세요")
                    .font(.pre(16, .semibold))
                    .foregroundStyle(ink)
                    .padding(.top, 6)
            } else if let next = guide.next, guide.phase != .finished {
                HStack(spacing: 5) {
                    Text("다음 역")
                        .foregroundStyle(ink.opacity(0.75))
                    Text(next.name)
                        .foregroundStyle(ink)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ink.opacity(0.75))
                }
                .font(.pre(16, .semibold))
                .padding(.top, 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var stats: some View {
        let target = guide.target
        let word = target?.kind == .transfer ? "환승" : "도착"
        return HStack(spacing: 10) {
            tile(
                label: "\(target?.name ?? "") \(word)까지",
                value: guide.phase == .finished ? "0" : "\(guide.stopsToTarget)",
                unit: "정거장"
            )
            tile(
                label: "\(guide.destination)까지 남은 시간",
                value: guide.phase == .finished ? "0" : "약 \(guide.minutesLeft)",
                unit: "분"
            )
        }
    }

    private func tile(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.pre(12.5, .medium))
                .foregroundStyle(Palette.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.pre(28, .bold))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                Text(unit)
                    .font(.pre(14, .semibold))
                    .foregroundStyle(Palette.sub)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var sourceNote: some View {
        let icon: String
        let text: String
        let tint: Color
        if guide.phase == .waiting {
            icon = "figure.wave"
            text = "열차에 타면 아래 버튼을 눌러 주세요. 역을 벗어나면 자동으로 시작돼요."
            tint = Palette.sub
        } else if guide.phase == .finished {
            icon = "checkmark.circle.fill"
            text = "안내가 끝났어요."
            tint = Palette.live
        } else {
            switch guide.source {
            case .gps:
                icon = "location.fill"
                text = "GPS로 위치를 확인했어요"
                tint = Palette.live
            case .manual:
                icon = "hand.tap.fill"
                text = "직접 고른 위치에서 이어 가요"
                tint = Palette.accent
            case .time:
                icon = "clock.fill"
                text = guide.locationDenied ? "위치 권한이 없어 시간으로 추정해요" : "GPS가 약해 시간으로 추정하고 있어요"
                tint = Palette.star
            }
        }
        return HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.pre(13, .medium))
                .foregroundStyle(Palette.sub)
        }
    }
}

private struct StopLine: View {
    enum Mode {
        case passed, current, ahead
    }

    let stop: RideStop
    let state: Mode
    let first: Bool
    let last: Bool

    var body: some View {
        let tint = Color(hex: stop.line.color)
        let after = Color(hex: (stop.nextLine ?? stop.line).color)
        HStack(spacing: 14) {
            ZStack {
                VStack(spacing: 0) {
                    Rectangle().fill(first ? Color.clear : tint.opacity(state == .ahead ? 1 : 0.35)).frame(width: 5)
                    Rectangle().fill(last ? Color.clear : after.opacity(state == .passed ? 0.35 : 1)).frame(width: 5)
                }
                Circle()
                    .fill(state == .current ? tint : Color.white)
                    .frame(width: state == .current ? 20 : 12, height: state == .current ? 20 : 12)
                    .overlay(Circle().stroke(state == .current ? Color.white : tint.opacity(state == .passed ? 0.35 : 1), lineWidth: 3))
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.pre(state == .current ? 18 : 16, state == .current ? .bold : .medium))
                    .foregroundStyle(state == .passed ? Palette.faint : Palette.ink)
                if let caption {
                    Text(caption)
                        .font(.pre(12.5, .semibold))
                        .foregroundStyle(state == .passed ? Palette.faint : Palette.accent)
                }
            }
            Spacer()
            if state == .current {
                Text("지금")
                    .font(.pre(12, .bold))
                    .foregroundStyle(Color.onColor(hex: stop.line.color))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tint, in: Capsule())
            }
        }
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private var caption: String? {
        switch stop.kind {
        case .board: return "\(stop.line.name) 승차"
        case .transfer: return "\(stop.nextLine?.name ?? "") 환승"
        case .arrive: return "도착"
        case .pass: return nil
        }
    }
}

/// 안내 중일 때 화면 위에 붙는 작은 줄. 누르면 안내 화면이 다시 열린다.
struct GuidanceBar: View {
    @EnvironmentObject private var guide: RideGuide
    let action: () -> Void

    var body: some View {
        if let current = guide.current {
            Button(action: action) {
                HStack(spacing: 10) {
                    LineBadge(line: current.line, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(guide.phase == .waiting ? "출발역 \(current.name)" : "이번 역 \(current.name)")
                            .font(.pre(14, .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(guide.target?.name ?? "")까지 \(guide.stopsToTarget)정거장")
                            .font(.pre(12, .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("안내 중")
                        .font(.pre(12, .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color(hex: "#14161A"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
        }
    }
}
