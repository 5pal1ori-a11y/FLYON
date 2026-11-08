import SwiftUI

extension Color {
    /// 라이트/다크에 따라 바뀌는 색
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        func ui(_ h: UInt32) -> UIColor { UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1) }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

enum T {
    static var accentHex: UInt32 { let v = UserDefaults.standard.integer(forKey: "accentHex"); return v == 0 ? 0x3182F6 : UInt32(v) }
    static let accents: [(String, UInt32)] = [("파랑", 0x3182F6), ("보라", 0x7C5CFA), ("초록", 0x12B76A), ("주황", 0xF97316), ("핑크", 0xEC4899)]
    static var blue: Color { Color(hex: accentHex) }
    static var blueSoft: Color { Color(hex: accentHex).opacity(0.13) }
    static var hero: LinearGradient { LinearGradient(colors: [Color(hex: accentHex), Color(hex: accentHex).opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static let bg = Color.dyn(0xF2F4F6, 0x0E1014)
    static let card = Color.dyn(0xFFFFFF, 0x1C1F26)
    static let text = Color.dyn(0x191F28, 0xF2F4F6)
    static let sub = Color.dyn(0x6B7684, 0xA3ABB8)
    static let faint = Color.dyn(0xB0B8C1, 0x5E6572)
    static let red = Color(hex: 0xF04452)
    static let green = Color(hex: 0x1FCB5D)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 14, y: 6)
    }
}

struct BigButton: View {
    let title: String
    var color: Color = T.blue
    var fg: Color = .white
    var action: () -> Void
    var body: some View {
        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() } label: {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(fg)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(Press())
    }
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DBadge: View {
    let d: Int
    var body: some View {
        Text(d <= 0 ? "D-day" : "D-\(d)").font(.system(size: 13, weight: .bold))
            .foregroundStyle(d <= 0 ? .white : T.blue)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(d <= 0 ? T.blue : T.blueSoft, in: Capsule())
            .pulse(d <= 0)
    }
}

struct SectionTitle: View {
    let t: String
    var body: some View { Text(t).font(.system(size: 20, weight: .bold)).foregroundStyle(T.text) }
}

struct SubRow: View {
    let s: Subscription
    var body: some View {
        HStack(spacing: 14) {
            LogoView(name: s.name, category: s.category, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(T.text)
                Text(s.price.won).font(.system(size: 14)).foregroundStyle(T.sub)
            }
            Spacer()
            if s.isActive { DBadge(d: s.dDay) } else { Text(s.status.rawValue).font(.system(size: 13)).foregroundStyle(T.faint) }
        }.contentShape(Rectangle())
    }
}

// MARK: 애니메이션 도구
/// 아래에서 부드럽게 떠오르며 순서대로 나타나요
struct Stagger: ViewModifier {
    let i: Int
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0).offset(y: on ? 0 : 16).scaleEffect(on ? 1 : 0.98)
            .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(Double(min(i, 12)) * 0.06)) { on = true } }
    }
}
extension View { func stagger(_ i: Int) -> some View { modifier(Stagger(i: i)) } }

/// 숫자가 0에서 올라가듯 변해요
struct CountText: View, Animatable {
    var value: Double
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View { Text(Int(value.rounded()).won) }
}
struct CountingWon: View {
    let target: Double
    @State private var shown: Double = 0
    var body: some View {
        CountText(value: shown)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = target } }
            .onChange(of: target) { _, v in withAnimation(.easeOut(duration: 0.6)) { shown = v } }
    }
}

/// 차오르는 진행 막대
struct AnimBar: View {
    let value: Double
    var tint: Color = T.blue
    var track: Color = T.bg
    @State private var shown: Double = 0
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(tint).frame(width: max(8, g.size.width * shown))
            }
        }
        .frame(height: 8)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.25)) { shown = min(1, max(0, value)) } }
        .onChange(of: value) { _, v in withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { shown = min(1, max(0, v)) } }
    }
}

/// 두근두근 (오늘 결제 등 강조)
struct Pulse: ViewModifier {
    let active: Bool
    @State private var on = false
    func body(content: Content) -> some View {
        content.scaleEffect(active && on ? 1.08 : 1)
            .onAppear { guard active else { return }; withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true } }
    }
}
extension View { func pulse(_ active: Bool) -> some View { modifier(Pulse(active: active)) } }

/// 눌렀을 때 살짝 눌리는 카드
struct PressCard: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 둥둥 떠 있는 느낌
struct Float: ViewModifier {
    @State private var up = false
    func body(content: Content) -> some View {
        content.offset(y: up ? -8 : 8)
            .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { up = true } }
    }
}
extension View { func floating() -> some View { modifier(Float()) } }
