import SwiftUI

struct OnboardingView: View {
    @Environment(Game.self) private var game
    @State private var name = "한평상회"
    @State private var step = 0
    @FocusState private var focused: Bool

    private let lines = [
        "통장 잔고 3만 원.",
        "할머니가 물려주신\n한 평짜리 구멍가게.",
        "간판은 낡았지만,\n자리는 나쁘지 않다."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(lines.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(.myeongjo(26))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(6)
                        .opacity(step > item.offset ? 1 : 0)
                        .offset(y: step > item.offset ? 0 : 10)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Storefront(kind: .cornerShop, name: name.isEmpty ? "　" : name, height: 150, lit: step > 3)

                Text("간판에 새길 이름").sectionLabel().padding(.top, 8)
                TextField("상호", text: $name)
                    .font(.myeongjo(22))
                    .focused($focused)
                    .submitLabel(.done)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
                    .onChange(of: name) { _, new in
                        if new.count > 10 { name = String(new.prefix(10)) }
                    }

                Button("셔터 올리기") {
                    focused = false
                    game.begin(name: name)
                }
                .buttonStyle(SignButtonStyle())
                .padding(.top, 4)
            }
            .opacity(step > 2 ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .background(Palette.paper)
        .contentShape(Rectangle())
        .task {
            for i in 1...4 {
                try? await Task.sleep(nanoseconds: i == 1 ? 400_000_000 : 1_100_000_000)
                if step < i { withAnimation(.easeOut(duration: 0.7)) { step = i } }
            }
        }
        .onTapGesture {
            focused = false
            if step < 4 { withAnimation(.easeOut(duration: 0.3)) { step = 4 } }
        }
    }
}
