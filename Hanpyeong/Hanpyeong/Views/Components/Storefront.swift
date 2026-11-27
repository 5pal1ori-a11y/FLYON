import SwiftUI

/// 가게 앞모습 — 간판 · 줄무늬 차양 · 쇼윈도 · 문
struct Storefront: View {
    let kind: BusinessKind
    let name: String
    var height: CGFloat = 170
    var lit: Bool = true

    private var tone: Color { kind.color }

    var body: some View {
        VStack(spacing: 0) {
            signboard
            Awning(color: tone, stripes: 9)
                .frame(height: height * 0.16)
                .zIndex(1)
            facade
                .padding(.top, -height * 0.04)
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(kind.info.title)")
    }

    private var signboard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tone)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                .padding(3)
            Text(name)
                .font(.myeongjo(height * 0.13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 14)
        }
        .frame(height: height * 0.24)
        .padding(.horizontal, 6)
    }

    private var facade: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                Rectangle().fill(Palette.cardDeep)
                HStack(alignment: .bottom, spacing: w * 0.04) {
                    window(width: w * 0.36, height: h * 0.62)
                    door(width: w * 0.2, height: h * 0.8)
                    window(width: w * 0.28, height: h * 0.62)
                }
                .padding(.bottom, 0)
                // 바닥 턱
                Rectangle().fill(Palette.line).frame(height: 3)
            }
        }
    }

    private func window(width: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Palette.glass)
            if lit {
                Rectangle().fill(Color(hex: 0xFFE8A8).opacity(0.35))
            }
            // 진열대
            VStack(spacing: h * 0.18) {
                Spacer()
                shelf(width: width)
                shelf(width: width)
            }
            .padding(.bottom, h * 0.1)
            // 창틀
            Rectangle().strokeBorder(Palette.ink.opacity(0.75), lineWidth: 2)
            Rectangle().fill(Palette.ink.opacity(0.75)).frame(width: 2)
        }
        .frame(width: width, height: h)
        .padding(.bottom, 3)
    }

    private func shelf(width: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i.isMultiple(of: 2) ? tone.opacity(0.75) : Palette.gold.opacity(0.7))
                    .frame(width: width * 0.12, height: width * 0.1)
            }
        }
    }

    private func door(width: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Palette.ink.opacity(0.85))
            Rectangle().fill(Palette.glass.opacity(0.8))
                .frame(width: width * 0.7, height: h * 0.45)
                .padding(.top, h * 0.1)
            Image(systemName: kind.info.symbol)
                .font(.system(size: width * 0.28, weight: .semibold))
                .foregroundStyle(tone)
                .padding(.top, h * 0.2)
            Circle().fill(Palette.gold)
                .frame(width: 5, height: 5)
                .offset(x: width * 0.3, y: h * 0.62)
        }
        .frame(width: width, height: h)
        .padding(.bottom, 3)
    }
}

/// 줄무늬 차양. 아래쪽이 물결처럼 둥글다.
struct Awning: View {
    let color: Color
    var stripes: Int = 8

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<stripes, id: \.self) { i in
                Rectangle().fill(i.isMultiple(of: 2) ? color : Color(hex: 0xFAF6EE))
            }
        }
        .mask(Scallop(count: stripes))
        .overlay(Scallop(count: stripes).stroke(color.opacity(0.9), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
    }
}

struct Scallop: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / CGFloat(count) / 2
        let edge = rect.height - r
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: edge))
        for i in (0..<count).reversed() {
            let cx = CGFloat(i) * 2 * r + r
            p.addArc(center: CGPoint(x: cx, y: edge), radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

/// 업종 아이콘 타일
struct KindTile: View {
    let kind: BusinessKind
    var size: CGFloat = 44

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(kind.color)
            Image(systemName: kind.info.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity)
            // 차양 줄무늬 띠
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    Rectangle().fill(i.isMultiple(of: 2) ? Color.white.opacity(0.9) : .clear)
                }
            }
            .frame(height: size * 0.14)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: size * 0.22, topTrailingRadius: size * 0.22))
        }
        .frame(width: size, height: size)
    }
}
