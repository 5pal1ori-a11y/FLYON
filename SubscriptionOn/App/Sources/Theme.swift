import SwiftUI

enum T {
    static let bg = Color(hex: 0xF2F4F6)
    static let card = Color.white
    static let blue = Color(hex: 0x3182F6)
    static let blueSoft = Color(hex: 0xE8F3FF)
    static let text = Color(hex: 0x191F28)
    static let sub = Color(hex: 0x6B7684)
    static let faint = Color(hex: 0xB0B8C1)
    static let red = Color(hex: 0xF04452)
    static let green = Color(hex: 0x1FCB5D)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
