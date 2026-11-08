import SwiftUI

struct ChatMsg: Identifiable, Equatable { let id = UUID(); let mine: Bool; var text: String }

struct AssistantView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var msgs: [ChatMsg] = []
    @State private var input = ""
    @State private var busy = false
    @FocusState private var focus: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            BigTitle("구독에 대해\n물어보세요").stagger(0)
                            Text(SmartParse.aiAvailable ? "Apple Intelligence가 기기 안에서 답해요" : "내 구독 정보로 답해요. 서버로 보내지 않아요")
                                .font(.system(size: 13)).foregroundStyle(T.faint)
                            if msgs.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(Assistant.suggestions.enumerated()), id: \.offset) { i, q in
                                        Button { send(q) } label: {
                                            HStack {
                                                Image(systemName: "sparkles").foregroundStyle(T.blue)
                                                Text(q).font(.system(size: 15, weight: .semibold)).foregroundStyle(T.text)
                                                Spacer()
                                            }.padding(16).background(T.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        }.buttonStyle(PressCard()).stagger(i + 1)
                                    }
                                }.padding(.top, 8)
                            }
                            ForEach(msgs) { m in bubble(m).id(m.id).transition(.move(edge: .bottom).combined(with: .opacity)) }
                            if busy { TypingDots().padding(.leading, 6) }
                            Color.clear.frame(height: 1).id("end")
                        }.padding(20)
                    }
                    .onChange(of: msgs) { _, _ in withAnimation { proxy.scrollTo("end") } }
                    .onChange(of: busy) { _, _ in withAnimation { proxy.scrollTo("end") } }
                }
                HStack(spacing: 10) {
                    TextField("예: 안 쓰는 구독 있어?", text: $input).focused($focus).submitLabel(.send).onSubmit { send(input) }
                        .padding(14).background(T.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button { send(input) } label: {
                        Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 46, height: 46).background(T.blue, in: Circle())
                    }.buttonStyle(PressCard()).disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }.padding(.horizontal, 16).padding(.vertical, 10).background(T.bg)
            }
            .background(T.bg)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }

    func bubble(_ m: ChatMsg) -> some View {
        HStack {
            if m.mine { Spacer(minLength: 50) }
            Text(m.text).font(.system(size: 15)).foregroundStyle(m.mine ? .white : T.text)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(m.mine ? AnyShapeStyle(T.blue) : AnyShapeStyle(T.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if !m.mine { Spacer(minLength: 50) }
        }
    }

    func send(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !busy else { return }
        input = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { msgs.append(ChatMsg(mine: true, text: q)); busy = true }
        Task {
            let a = await Assistant.answer(q, store: store)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { busy = false; msgs.append(ChatMsg(mine: false, text: a)) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

struct TypingDots: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(T.faint).frame(width: 8, height: 8).offset(y: on ? -4 : 3)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: on)
            }
        }.padding(14).background(T.card, in: Capsule()).onAppear { on = true }
    }
}
