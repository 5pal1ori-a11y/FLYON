import SwiftUI

/// 노선 번호 배지. 숫자 노선은 원, 이름 노선은 둥근 사각형.
struct LineBadge: View {
    let line: SubwayLine
    var size: CGFloat = 26

    var body: some View {
        let single = line.short.count == 1
        Text(line.short)
            .font(.pre(single ? size * 0.54 : size * 0.42, .bold))
            .foregroundStyle(Color.onColor(hex: line.color))
            .lineLimit(1)
            .padding(.horizontal, single ? 0 : size * 0.26)
            .frame(minWidth: size, minHeight: size)
            .frame(height: size)
            .background(Color(hex: line.color), in: Capsule())
    }
}

struct KindBadge: View {
    let kind: RailKind
    var text: String? = nil

    var body: some View {
        Text(text ?? kind.rawValue)
            .font(.pre(11.5, .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(kind.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// 데이터가 실제 수신값인지, 미리보기인지 알려 주는 표시.
struct SourcePill: View {
    let source: DataSource
    var liveLabel = "실시간"

    private var label: String {
        switch source {
        case .live: return liveLabel
        case .preview: return "미리보기"
        case .failed: return "연결 실패 · 미리보기"
        }
    }

    private var tint: Color {
        switch source {
        case .live: return Palette.live
        case .preview: return Palette.sub
        case .failed: return Palette.accent
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(label)
                .font(.pre(12, .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.pre(18, .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.pre(13, .medium))
                    .foregroundStyle(Palette.sub)
                    .monospacedDigit()
            }
        }
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
    }
}

/// 화면 맨 위 제목 줄.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.pre(26, .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.pre(14))
                .foregroundStyle(Palette.sub)
            Spacer()
            Text(value)
                .font(.pre(14, .semibold))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .padding(.vertical, 11)
    }
}
