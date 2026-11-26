import SwiftUI

/// 혜택 탭 맨 위: 내 등급과 다음 등급까지 경험치
struct LevelSummaryView: View {
    @Environment(Wallet.self) private var wallet

    var body: some View {
        let xp = wallet.state.xp
        let level = wallet.level
        NavigationLink {
            LevelListView()
        } label: {
            HStack(spacing: 14) {
                LevelBadge(level: level, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(level.name).font(.title3.weight(.bold))
                        Text("\(Fmt.number(Double(xp))) XP").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(xp)))
                            .animation(.snappy, value: xp)
                    }
                    ProgressBar(value: level.progress(xp: xp), height: 5)
                    Text(level.next.map { "\($0.name)까지 \(Fmt.number(Double($0.minXP - xp))) XP" } ?? "최고 등급이에요")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 등급 배지 (검정 외곽선 원 + 아이콘)
struct LevelBadge: View {
    let level: TraderLevel
    var size: CGFloat = 40
    var filled = false

    var body: some View {
        Image(systemName: level.icon)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(filled ? Color(.systemBackground) : .primary)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? Color.primary : .clear))
            .overlay(Circle().strokeBorder(Color.primary, lineWidth: filled ? 0 : 1.2))
            .accessibilityLabel(level.name)
    }
}

/// 등급 안내: 5단계, 필요 경험치, 보상, 경험치 얻는 법
struct LevelListView: View {
    @Environment(Wallet.self) private var wallet

    var body: some View {
        let xp = wallet.state.xp
        let current = wallet.level
        List {
            Section {
                ForEach(TraderLevel.all) { lv in
                    HStack(spacing: 14) {
                        LevelBadge(level: lv, size: 40, filled: lv.index <= current.index)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(lv.name).font(.headline)
                                if lv == current {
                                    Text("현재").font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
                                }
                            }
                            Text(lv.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(Fmt.number(Double(lv.minXP))) XP").font(.subheadline.weight(.semibold)).monospacedDigit()
                            if lv.rewardTradex > 0 {
                                Text("보상 \(lv.rewardTradex) TRADEX").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .opacity(lv.index <= current.index ? 1 : 0.55)
                }
            } header: {
                Text("내 경험치 \(Fmt.number(Double(xp))) XP")
            } footer: {
                Text("등급이 오르면 TRADEX 보너스를 받아요. 1 TRADEX = \(Fmt.krw(TradexRules.krwPerTradex))")
            }

            Section {
                ForEach(XPRule.allCases, id: \.self) { r in
                    HStack {
                        Text(r.title)
                        Spacer()
                        Text("+\(r.amount) XP").fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.subheadline)
                }
            } header: {
                Text("경험치 얻는 법")
            } footer: {
                Text("현물 거래·주문·선물로 얻는 경험치는 하루 \(XPRule.dailyTradeCap) XP까지예요. 오늘 \(wallet.state.daily.tradeXPDay == KST.dayKey(.now) ? wallet.state.daily.tradeXP : 0)/\(XPRule.dailyTradeCap)")
            }
        }
        .navigationTitle("트레이더 등급")
    }
}

/// 등급이 오르면 전체 화면에 뜨는 축하 화면
struct LevelUpOverlay: View {
    let level: TraderLevel
    let onClose: () -> Void

    @State private var pop = false
    @State private var rings = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 18) {
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                            .frame(width: 96, height: 96)
                            .scaleEffect(rings ? 1.8 + Double(i) * 0.35 : 1)
                            .opacity(rings ? 0 : 1)
                            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(i) * 0.25), value: rings)
                    }
                    LevelBadge(level: level, size: 96, filled: true)
                        .scaleEffect(pop ? 1 : 0.3)
                        .rotationEffect(.degrees(pop ? 0 : -30))
                }
                .frame(height: 150)
                Text("등급 상승!").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(level.name).font(.system(size: 34, weight: .heavy))
                Text(level.summary).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if level.rewardTradex > 0 {
                    Text("보너스 \(level.rewardTradex) TRADEX 지급")
                        .font(.headline)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
                }
                Button("확인", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
            .scaleEffect(pop ? 1 : 0.9)
        }
        .sensoryFeedback(.success, trigger: pop)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
            rings = true
        }
    }
}
