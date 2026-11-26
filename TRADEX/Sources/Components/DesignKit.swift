import SwiftUI

// 자산·혜택·설정 화면에서 같이 쓰는 작은 디자인 부품들

/// 섹션 제목 + 오른쪽 보조 정보
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 4)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

/// iOS 설정 앱 스타일의 둥근 사각형 아이콘
struct IconTile: View {
    let systemName: String
    var tint: Color = .primary
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint == .primary ? Color(.systemBackground) : .white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 얇은 진행 막대
struct ProgressBar: View {
    let value: Double   // 0...1
    var tint: Color = .primary
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(tint).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
        .animation(.snappy, value: value)
    }
}

/// 작은 캡슐 버튼 (충전 · 받기 등)
struct PillButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(filled ? Color(.systemBackground) : .primary)
            .background(filled ? Color.primary : Color.primary.opacity(0.08), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 자산 구성 막대 (코인 · 선물 · 원화 · TRADEX 비중)
struct AllocationBar: View {
    struct Segment: Identifiable {
        let label: String
        let value: Double
        let color: Color
        var id: String { label }
    }
    let segments: [Segment]

    private var total: Double { max(segments.reduce(0) { $0 + $1.value }, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segments.filter { $0.value > 0 }) { s in
                        Rectangle().fill(s.color)
                            .frame(width: max(3, (geo.size.width - 6) * s.value / total))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            HStack(spacing: 14) {
                ForEach(segments) { s in
                    HStack(spacing: 5) {
                        Circle().fill(s.color).frame(width: 7, height: 7)
                        Text(s.label).foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", s.value / total * 100)).fontWeight(.semibold)
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 업비트 | 빗썸 전환용 캡슐 세그먼트
struct ExchangeSegment: View {
    let selection: ExchangeID
    let onSelect: (ExchangeID) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExchangeID.allCases) { ex in
                Button {
                    onSelect(ex)
                } label: {
                    HStack(spacing: 6) {
                        ExchangeBadge(exchange: ex, size: 18)
                        Text(ex.name).font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selection == ex ? .primary : .secondary)
                    .background(selection == ex ? Theme.card : .clear, in: Capsule())
                    .shadow(color: .black.opacity(selection == ex ? 0.06 : 0), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == ex ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}
