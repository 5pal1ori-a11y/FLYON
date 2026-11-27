import SwiftUI

struct RootView: View {
    @Environment(Game.self) private var game
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var game = game

        ZStack {
            Palette.paper.ignoresSafeArea()

            if game.started {
                MainTabs()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if let rank = game.pendingRankUp {
                RankUpOverlay(rank: rank) {
                    withAnimation(.easeOut(duration: 0.25)) { game.pendingRankUp = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: game.started)
        .animation(.easeOut(duration: 0.25), value: game.pendingRankUp?.id)
        .overlay(alignment: .bottom) { ToastView() }
        .sheet(item: $game.offlineReport) { report in
            OfflineSheet(report: report)
        }
        .onChange(of: phase, initial: true) { _, new in
            switch new {
            case .active: game.becameActive()
            case .background: game.wentBackground()
            default: break
            }
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            ShopView()
                .tabItem { Label("가게", systemImage: "storefront") }
            MarketView()
                .tabItem { Label("매물", systemImage: "tag") }
            LedgerView()
                .tabItem { Label("장부", systemImage: "book.closed") }
            CompanyView()
                .tabItem { Label("회사", systemImage: "building.columns") }
        }
    }
}

// MARK: - 토스트

struct ToastView: View {
    @Environment(Game.self) private var game

    var body: some View {
        ZStack {
            if let text = game.toast {
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.paper)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Palette.ink))
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(text)
            }
        }
        .padding(.bottom, 64)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: game.toast)
        .task(id: game.toast) {
            guard game.toast != nil else { return }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled { game.toast = nil }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 자리 비운 사이

struct OfflineSheet: View {
    let report: OfflineReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 34))
                .foregroundStyle(Palette.gold)
                .padding(.top, 28)
            Text("자리 비운 \(Won.duration(report.seconds)) 동안")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            Text(Won.full(report.earned))
                .font(.myeongjo(32))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("알바생들이 가게를 지켰어요. 사장님이 없을 땐 평소의 절반만 법니다.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            Button("장부에 적기") { dismiss() }
                .buttonStyle(SignButtonStyle())
                .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
        .presentationDetents([.height(380)])
        .presentationCornerRadius(24)
    }
}

// MARK: - 승급

struct RankUpOverlay: View {
    let rank: Rank
    let onClose: () -> Void

    @State private var stamped = false
    @State private var showText = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                Text("승급")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(Palette.inkSoft)

                Stamp(text: rank.stamp, size: 120)
                    .scaleEffect(stamped ? 1 : 2.6)
                    .opacity(stamped ? 1 : 0)

                VStack(spacing: 8) {
                    Text(rank.title)
                        .font(.myeongjo(28))
                        .foregroundStyle(Palette.ink)
                    Text(rank.line)
                        .font(.myeongjo(14, bold: false))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 8)

                if !rank.unlockedKinds.isEmpty || !rank.unlockedDistricts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rank.unlockedKinds) { k in
                            Label("새 업종 · \(k.info.title)", systemImage: k.info.symbol)
                        }
                        ForEach(rank.unlockedDistricts) { d in
                            Label("새 지역 · \(d.info.name)", systemImage: "map")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Palette.cardDeep, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(showText ? 1 : 0)
                }

                Button("계속하기", action: onClose)
                    .buttonStyle(SignButtonStyle())
                    .opacity(showText ? 1 : 0)
            }
            .padding(24)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 28)
        }
        .sensoryFeedback(.success, trigger: stamped)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.15)) { stamped = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.55)) { showText = true }
        }
    }
}
