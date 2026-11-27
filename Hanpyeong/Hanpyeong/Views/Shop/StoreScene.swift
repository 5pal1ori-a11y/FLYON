import SwiftUI

/// 살아 있는 가게 앞 풍경: 시간대에 따라 하늘색이 바뀌고, 비·눈이 내리고, 손님이 지나간다.
struct StoreScene: View {
    let kind: BusinessKind
    let name: String
    let dayFraction: Double
    let weather: Weather
    let walkers: Int
    var height: CGFloat = 210
    var pressed = false

    private var isNight: Bool { dayFraction >= 0.78 }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(sky)
                .animation(.easeInOut(duration: 1.2), value: skyKey)

            // 해 / 달
            Circle()
                .fill(isNight ? Color(hex: 0xF4EBC8) : Color(hex: 0xFFD36B))
                .frame(width: 26, height: 26)
                .shadow(color: (isNight ? Color.white : Color.orange).opacity(0.5), radius: 10)
                .offset(x: sunX, y: -height + 46)
                .opacity(weather == .rain || weather == .snow || weather == .cloudy ? 0.25 : 1)
                .animation(.easeInOut(duration: 1.2), value: dayFraction)

            WeatherLayer(weather: weather)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

            Storefront(kind: kind, name: name, height: height - 40, lit: isNight || weather == .rain || weather == .snow)
                .padding(.horizontal, 22)
                .scaleEffect(x: pressed ? 1.03 : 1, y: pressed ? 0.95 : 1, anchor: .bottom)

            // 인도
            Rectangle()
                .fill(Palette.line)
                .frame(height: 10)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18))

            WalkersLayer(count: walkers)
                .frame(height: 40)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
        }
        .frame(height: height)
    }

    private var skyKey: Int { Int(dayFraction * 10) * 10 + Weather.allCases.firstIndex(of: weather)! }

    private var sky: Color {
        let gloomy = weather == .rain || weather == .snow || weather == .cloudy
        switch dayFraction {
        case ..<0.2: return gloomy ? Color(hex: 0xD5D8D6) : Color(hex: 0xF6E3BF)
        case ..<0.62: return gloomy ? Color(hex: 0xC8D1D6) : Color(hex: 0xCFE6F0)
        case ..<0.78: return gloomy ? Color(hex: 0xB9A9A0) : Color(hex: 0xF0B98E)
        default: return Color(hex: 0x2C3552)
        }
    }

    private var sunX: CGFloat {
        // 아침엔 왼쪽, 저녁엔 오른쪽
        CGFloat(dayFraction - 0.5) * 260
    }
}

/// 비·눈 입자
struct WeatherLayer: View {
    let weather: Weather

    var body: some View {
        if weather == .rain || weather == .snow {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let count = weather == .rain ? 46 : 34
                    for i in 0..<count {
                        let seed = Double(i) * 97.13
                        let speed = weather == .rain ? 260.0 + Double(i % 7) * 30 : 28.0 + Double(i % 5) * 7
                        let x0 = (seed * 13).truncatingRemainder(dividingBy: Double(size.width))
                        let y = (t * speed + seed * 31).truncatingRemainder(dividingBy: Double(size.height + 20)) - 10
                        if weather == .rain {
                            var p = Path()
                            p.move(to: CGPoint(x: x0, y: y))
                            p.addLine(to: CGPoint(x: x0 - 3, y: y + 11))
                            ctx.stroke(p, with: .color(Color(hex: 0x6C8FAE).opacity(0.55)), lineWidth: 1.4)
                        } else {
                            let x = x0 + sin(t * 1.3 + seed) * 8
                            let r = 2.0 + Double(i % 3)
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.9)))
                        }
                    }
                }
            }
        }
    }
}

/// 가게 앞을 지나가는 손님들
struct WalkersLayer: View {
    let count: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                var figure = ctx.resolve(Image(systemName: "figure.walk"))
                figure.shading = .color(Palette.ink)
                let w = Double(size.width) + 40
                for i in 0..<max(0, count) {
                    let speed = 22.0 + Double(i * 7 % 13)
                    let leftward = i % 2 == 1
                    var x = (t * speed + Double(i) * 137).truncatingRemainder(dividingBy: w) - 20
                    if leftward { x = w - 40 - x }
                    let bob = abs(sin(t * 6 + Double(i))) * 1.5
                    var layer = ctx
                    layer.translateBy(x: x, y: Double(size.height) - 14 - bob)
                    if leftward { layer.scaleBy(x: -1, y: 1) }
                    layer.opacity = 0.75
                    layer.draw(figure, in: CGRect(x: -8, y: -22, width: 16, height: 24))
                }
            }
        }
    }
}

/// 탭할 때 튀어나오는 동전
struct CoinBurst: View {
    let angle: Double
    @State private var go = false

    var body: some View {
        Image(systemName: "wonsign.circle.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Palette.gold)
            .background(Circle().fill(Color(hex: 0xFFF3C4)).padding(2))
            .offset(x: go ? cos(angle) * 70 : 0, y: go ? sin(angle) * 60 - 40 : 0)
            .rotationEffect(.degrees(go ? 180 : 0))
            .scaleEffect(go ? 0.6 : 1)
            .opacity(go ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) { go = true }
            }
            .allowsHitTesting(false)
    }
}

/// 가게 앞에 나타나는 VIP 손님 말풍선
struct VIPBubble: View {
    let visit: VIPVisit
    let onTap: () -> Void
    @State private var bob = false
    @State private var appear = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: visit.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Palette.gold))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(visit.title).font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.ink)
                        Text(visit.line).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Palette.gold, lineWidth: 2))
                .shadow(color: Palette.gold.opacity(0.45), radius: 10, y: 3)
                Text("눌러서 모시기")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.gold))
            }
            .offset(y: bob ? -5 : 3)
            .scaleEffect(appear ? 1 : 0.3)
            .opacity(appear ? 1 : 0)
        }
        .buttonStyle(PressStyle())
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { appear = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bob = true }
        }
    }
}

/// 러시 타임 띠 (남은 시간 표시)
struct RushBadge: View {
    let until: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let left = max(0, until.timeIntervalSince(ctx.date))
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                Text("러시 타임 · 계산 ×3")
                Text("\(Int(left.rounded(.up)))초").monospacedDigit()
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Palette.gold))
            .shadow(color: Palette.gold.opacity(0.5), radius: 8, y: 2)
        }
    }
}
