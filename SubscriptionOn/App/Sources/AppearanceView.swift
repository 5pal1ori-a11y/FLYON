import SwiftUI

/// 설정 > 앱: 테마, 화면 모드, 앱 아이콘
struct AppearanceView: View {
    @AppStorage("themeMode") private var themeMode = 0
    @AppStorage("themeID") private var themeID = "default"
    @State private var iconName: String? = UIApplication.shared.alternateIconName

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BigTitle("앱을\n꾸며보세요").stagger(0)
                SectionLabel("테마")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(T.palettes) { p in
                            let on = themeID == p.id
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { themeID = p.id }
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    ZStack(alignment: .leading) {
                                        ForEach(Array(p.colors.enumerated()), id: \.offset) { i, c in
                                            Circle().fill(c).frame(width: 34, height: 34).overlay(Circle().stroke(T.card, lineWidth: 3)).offset(x: CGFloat(i) * 22)
                                        }
                                    }.frame(width: 80, height: 34, alignment: .leading)
                                    HStack(spacing: 4) {
                                        Text(p.name).font(.system(size: 14, weight: .bold)).foregroundStyle(T.text)
                                        if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.colors[0]).font(.system(size: 14)).transition(.scale) }
                                    }
                                }
                                .padding(16).frame(width: 130, alignment: .leading)
                                .background(T.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(p.colors[0], lineWidth: on ? 2 : 0))
                                .scaleEffect(on ? 1.04 : 1)
                                .shadow(color: Color(hex: 0x1B2A4A).opacity(0.05), radius: 12, y: 5)
                            }.buttonStyle(PressCard())
                        }
                    }.padding(.vertical, 8).padding(.horizontal, 2)
                }.stagger(1)

                SectionLabel("화면")
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ForEach([(0, "시스템", "circle.lefthalf.filled"), (1, "라이트", "sun.max.fill"), (2, "다크", "moon.fill")], id: \.0) { v, label, icon in
                                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { themeMode = v } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: icon).font(.system(size: 20)).symbolEffect(.bounce, value: themeMode == v)
                                        Text(label).font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(themeMode == v ? T.blue : T.sub).frame(maxWidth: .infinity).frame(height: 64)
                                    .background(themeMode == v ? T.blueSoft : T.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(T.blue, lineWidth: themeMode == v ? 1.5 : 0))
                                }.buttonStyle(PressCard())
                            }
                        }
                        Text("앱 아이콘").font(.system(size: 13)).foregroundStyle(T.sub)
                        HStack(spacing: 12) {
                            ForEach([(nil as String?, "기본", "IconPrevDefault"), ("AppIcon-White", "화이트", "IconPrevWhite"), ("AppIcon-Blue", "블루", "IconPrevBlue")], id: \.1) { name, label, img in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    UIApplication.shared.setAlternateIconName(name) { _ in }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { iconName = name }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(img).resizable().scaledToFit().frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(T.blue, lineWidth: iconName == name ? 2.5 : 0))
                                            .scaleEffect(iconName == name ? 1.08 : 1)
                                        Text(label).font(.system(size: 12)).foregroundStyle(iconName == name ? T.blue : T.sub)
                                    }.frame(maxWidth: .infinity)
                                }.buttonStyle(PressCard())
                            }
                        }
                    }
                }.stagger(2)

                Spacer(minLength: 60)
            }.padding(.horizontal, 20)
        }
        .background(T.bg)
        .navigationBarTitleDisplayMode(.inline)
    }
}
