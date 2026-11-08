import SwiftUI

/// 오늘 쓴 구독을 눌러 기록해요 (월 사용 횟수)
struct UsageSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BigTitle("오늘 쓴 구독을\n눌러주세요")
                    Text("숫자는 이번 달에 쓴 횟수예요").font(.system(size: 13)).foregroundStyle(T.faint)
                    // 오늘 쓴 구독 체크 (월 사용 횟수)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 18) {
                        ForEach(Array(store.active.enumerated()), id: \.element.id) { i, s in
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { store.markUsed(s) }
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        LogoView(name: s.name, category: s.category, size: 58)
                                        if s.usesThisMonth > 0 {
                                            Text("\(s.usesThisMonth)").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                                                .padding(.horizontal, 6).padding(.vertical, 2).background(T.blue, in: Capsule())
                                                .offset(x: 6, y: -6).transition(.scale)
                                        }
                                    }
                                    Text(s.name).font(.system(size: 12)).foregroundStyle(T.text).lineLimit(1)
                                }
                            }.buttonStyle(PressCard()).stagger(i)
                        }
                    }

                }.padding(20)
            }
            .background(T.bg)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
    }
}
