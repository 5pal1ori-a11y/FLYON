import SwiftUI

/// 가게 탭 맨 위에 뜨는 '결정할 일' 띠
struct DecisionBanner: View {
    @Environment(Game.self) private var game
    let onTap: () -> Void

    var body: some View {
        if let d = game.currentDecision {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Palette.sign)
                        Image(systemName: d.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("결정할 일")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Palette.sign)
                        Text(d.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Text("열기")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.sign)
                }
                .padding(12)
                .background(Palette.sign.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.sign.opacity(0.4)))
            }
            .buttonStyle(PressStyle())
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// 결정 카드
struct DecisionSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let result = game.decisionResult {
                resultView(result)
            } else if let d = game.currentDecision {
                questionView(d)
            } else {
                EmptyNote(title: "지금은 결정할 일이 없어요", detail: "하루가 끝나면 가끔 찾아옵니다.")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.paper)
        .presentationDetents([.large])
        .interactiveDismissDisabled(game.decisionResult != nil)
    }

    private func questionView(_ d: Decision) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: d.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.sign)
                Text("결정할 일").sectionLabel()
            }
            .padding(.top, 8)
            Text(d.title)
                .font(.myeongjo(26))
                .foregroundStyle(Palette.ink)
            Text(d.body)
                .font(.myeongjo(16, bold: false))
                .foregroundStyle(Palette.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            DashedLine().padding(.vertical, 4)

            ForEach(Array(d.options.enumerated()), id: \.offset) { item in
                optionButton(item.element)
            }
            Spacer(minLength: 0)
            Text("금액은 지금 가게 규모(하루 매출 약 \(Won.short(game.cashAmount(1))))에 맞춰 정해집니다.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkFaint)
        }
    }

    private func optionButton(_ o: DecisionOption) -> some View {
        let scale = game.cashAmount(1)
        let preview = game.describe(o.success, scale: scale)
        return Button {
            withAnimation(.snappy) { game.resolve(o) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(o.label)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    if o.chance < 1 {
                        Tag(text: "성공 \(Int(o.chance * 100))%", color: Palette.gold)
                    }
                }
                if !o.hint.isEmpty {
                    Text(o.hint)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSoft)
                }
                if !preview.isEmpty {
                    Text((o.chance < 1 ? "성공 시 · " : "") + preview.joined(separator: " · "))
                        .font(.num(13, .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(padding: 14)
        }
        .buttonStyle(PressStyle())
    }

    private func resultView(_ r: DecisionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(r.title).sectionLabel().padding(.top, 8)
            Stamp(text: r.good ? "잘함" : "아쉽", size: 90, color: r.good ? Palette.sign : Palette.down)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            Text(r.text)
                .font(.myeongjo(19))
                .foregroundStyle(Palette.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if !r.lines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(r.lines, id: \.self) { line in
                        Text(line).font(.mono(14, .semibold)).foregroundStyle(Palette.ink)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.receipt, in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer(minLength: 0)
            Button("확인") {
                game.decisionResult = nil
                dismiss()
            }
            .buttonStyle(SignButtonStyle())
        }
    }
}
