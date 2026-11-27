import SwiftUI

/// 상호마다 고유한 로고. 이름으로 모양·글꼴·장식이 정해져서 같은 이름은 늘 같은 로고가 된다.
struct BrandLogo: View {
    let name: String
    var color: Color = Palette.sign
    var size: CGFloat = 44
    /// 업종 아이콘을 오른쪽 아래 작은 배지로
    var badge: String? = nil
    /// 간판 위처럼 어두운 바탕에 올릴 때: 흰 바탕 + 컬러 글자
    var inverted = false

    private var seed: Int {
        name.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
    }

    private var glyph: String {
        let cleaned = name.replacingOccurrences(of: "(주)", with: "")
        guard let c = cleaned.first(where: { !$0.isWhitespace }) else { return "·" }
        return String(c)
    }

    private var serif: Bool { (seed / 7) % 2 == 0 }
    private var style: Int { seed % 5 }

    private var fill: Color { inverted ? .white : color }
    private var ink: Color { inverted ? color : .white }

    var body: some View {
        ZStack {
            shape
            Text(glyph)
                .font(serif ? .myeongjo(size * 0.5) : .system(size: size * 0.46, weight: .black))
                .foregroundStyle(style == 2 ? (inverted ? .white : color) : ink)
                .minimumScaleFactor(0.5)
                .offset(y: serif ? size * 0.02 : 0)
            accent
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if let badge {
                Image(systemName: badge)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: size * 0.38, height: size * 0.38)
                    .background(Circle().fill(Palette.card))
                    .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
                    .offset(x: size * 0.1, y: size * 0.1)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var shape: some View {
        switch style {
        case 0:
            Circle().fill(fill)
            Circle().strokeBorder(ink.opacity(0.55), lineWidth: max(1, size * 0.03)).padding(size * 0.08)
        case 1:
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(fill)
        case 2:
            Circle().fill(inverted ? color.opacity(0.2) : color.opacity(0.1))
            Circle().strokeBorder(inverted ? .white : color, lineWidth: max(1.5, size * 0.07))
        case 3:
            Hexagon().fill(fill)
        default:
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(fill)
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .mask(VStack(spacing: 0) { Color.clear; Color.black }.frame(height: size))
        }
    }

    @ViewBuilder private var accent: some View {
        switch (seed / 3) % 4 {
        case 0:
            Circle().fill(style == 2 ? color : ink.opacity(0.9))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: size * 0.27, y: -size * 0.27)
        case 1:
            Capsule().fill(style == 2 ? color : ink.opacity(0.85))
                .frame(width: size * 0.3, height: max(1.5, size * 0.04))
                .offset(y: size * 0.31)
        default:
            EmptyView()
        }
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.25))
        p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.75))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w * 0.05, y: h * 0.75))
        p.addLine(to: CGPoint(x: w * 0.05, y: h * 0.25))
        p.closeSubpath()
        return p
    }
}

/// 가상의 경쟁사 로고 색
enum LogoPalette {
    static let colors: [UInt32] = [0x1E3A8A, 0x0F766E, 0x9D174D, 0xB45309, 0x4338CA, 0x065F46,
                                   0x7C2D12, 0x1D4ED8, 0x6D28D9, 0xBE123C, 0x0E7490, 0x3F6212]

    static func color(for name: String) -> Color {
        let seed = name.unicodeScalars.reduce(11) { ($0 &* 33 &+ Int($1.value)) & 0x7fff_ffff }
        return Color(hex: colors[seed % colors.count])
    }
}
