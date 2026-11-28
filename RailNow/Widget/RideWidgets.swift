import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RailNowWidgetBundle: WidgetBundle {
    var body: some Widget {
        RideLiveActivity()
    }
}

private func tint(_ hex: String) -> Color {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return Color(
        .sRGB,
        red: Double((v >> 16) & 0xFF) / 255,
        green: Double((v >> 8) & 0xFF) / 255,
        blue: Double(v & 0xFF) / 255,
        opacity: 1
    )
}

/// 남은 정거장 수를 노선색 고리 안에 쓴다.
private struct CountRing: View {
    let state: RideActivityAttributes.ContentState
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle().stroke(tint(state.colorHex), lineWidth: size * 0.14)
            Text("\(state.remaining)")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
    }
}

private struct LineTag: View {
    let state: RideActivityAttributes.ContentState

    var body: some View {
        Text(state.lineShort)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(minWidth: 22, minHeight: 22)
            .background(tint(state.colorHex), in: Capsule())
    }
}

private func summary(_ state: RideActivityAttributes.ContentState) -> String {
    if state.remaining <= 0 { return "\(state.target) \(state.action)" }
    return "\(state.target) \(state.action)까지 \(state.remaining)정거장"
}

struct RideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // 잠금화면·알림 배너
            HStack(spacing: 14) {
                CountRing(state: context.state, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        LineTag(state: context.state)
                        Text(context.state.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(context.state.station)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(summary(context.state))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.82))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CountRing(state: context.state, size: 40)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LineTag(state: context.state)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.state.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(context.state.station)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(summary(context.state))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            } compactLeading: {
                CountRing(state: context.state, size: 22)
            } compactTrailing: {
                Text(context.state.station)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 72)
            } minimal: {
                CountRing(state: context.state, size: 22)
            }
            .keylineTint(tint(context.state.colorHex))
        }
    }
}
