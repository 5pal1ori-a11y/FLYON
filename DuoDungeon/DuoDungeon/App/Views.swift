import SpriteKit
import SwiftUI

@main
struct DuoDungeonApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
        }
    }
}

private extension Color {
    static let bg = Color(red: 0.07, green: 0.055, blue: 0.11)
    static let panel = Color(red: 0.13, green: 0.10, blue: 0.19)
    static let p1 = Color(red: 0.29, green: 0.64, blue: 1.0)
    static let p2 = Color(red: 1.0, green: 0.60, blue: 0.24)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.24)
}

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            switch model.screen {
            case .menu:
                MenuView(model: model)
            case .nearby(let host):
                NearbyWaitView(host: host) { model.cancelNearby() }
            case .playing:
                if let controller = model.controller, let scene = model.scene {
                    GameView(controller: controller, scene: scene) { model.leave() }
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { model.onLaunch() }
        .alert("알림", isPresented: Binding(get: { model.notice != nil },
                                          set: { if !$0 { model.notice = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(model.notice ?? "")
        }
    }
}

// MARK: - 메뉴

struct MenuView: View {
    let model: AppModel
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 10) {
                Text("DUO DUNGEON")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.gold)
                    .tracking(3)
                Text("듀오 던전")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("둘이 함께 내려가는 무작위 던전.\n쓰러진 친구는 옆에 서서 살려 주세요.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 8) {
                    Circle().fill(Color.p1).frame(width: 14, height: 14)
                    Circle().fill(Color.p2).frame(width: 14, height: 14)
                    if model.bestFloor > 0 {
                        Text("최고 기록 \(model.bestFloor)층")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.gold)
                            .padding(.leading, 6)
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                MenuButton(title: "온라인 협동", subtitle: "Game Center로 친구 초대 · 자동 매칭", color: .p1) {
                    model.playOnline()
                }
                HStack(spacing: 10) {
                    MenuButton(title: "근처 방 만들기", subtitle: "같은 와이파이", color: .p2) {
                        model.startNearby(host: true)
                    }
                    MenuButton(title: "근처 방 참가", subtitle: "같은 와이파이", color: .p2) {
                        model.startNearby(host: false)
                    }
                }
                HStack(spacing: 10) {
                    MenuButton(title: "혼자 하기", subtitle: "연습 · 1인 모드", color: .gray) {
                        model.playSolo()
                    }
                    MenuButton(title: "도움말", subtitle: "조작 · 규칙", color: .gray) {
                        showHelp = true
                    }
                }
            }
            .frame(width: 360)
        }
        .padding(.horizontal, 48)
        .sheet(isPresented: $showHelp) { HelpView() }
    }
}

struct MenuButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4).padding(.vertical, 10)
            }
        }
        .buttonStyle(.plain)
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("조작") {
                    Label("화면 왼쪽을 누르고 끌면 이동", systemImage: "hand.point.left")
                    Label("화면 오른쪽을 누르고 끌면 그 방향으로 계속 발사", systemImage: "hand.point.right")
                }
                Section("규칙") {
                    Text("방의 적을 모두 쓰러뜨리면 문이 열려요.")
                    Text("🎁 보물 방에는 능력 3개가 있어요. 한 사람이 하나씩 가져가세요.")
                    Text("👑 보스를 쓰러뜨리면 🪜 계단이 나타나요. 내려갈수록 어려워져요.")
                    Text("체력이 0이 되면 쓰러져요. 친구가 옆에 2초 서 있으면 다시 일어나요.")
                    Text("둘 다 쓰러지면 끝! 몇 층까지 내려갔는지가 기록이에요.")
                }
                Section("능력") {
                    Text("⚔️ 공격력  ⚡️ 연사  👟 이동 속도  ✨ 탄환 +1  🏹 관통  💖 최대 체력")
                }
                Section("함께 하기") {
                    Text("온라인 협동: Game Center에 로그인한 친구를 초대하거나 자동 매칭해요.")
                    Text("근처 협동: 두 사람이 같은 와이파이에 있을 때 한 명은 ‘방 만들기’, 한 명은 ‘방 참가’를 눌러요.")
                    Text("주고받는 정보는 캐릭터 위치와 게임 상태뿐이에요. 채팅·개인정보 수집은 없어요.")
                }
            }
            .navigationTitle("도움말")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}

struct NearbyWaitView: View {
    let host: Bool
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text(host ? "친구가 들어오길 기다리는 중…" : "근처 방을 찾는 중…")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(host ? "친구 폰에서 ‘근처 방 참가’를 눌러 주세요." : "친구 폰에서 ‘근처 방 만들기’를 먼저 눌러 주세요.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Button("취소", action: onCancel)
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.top, 8)
        }
    }
}

// MARK: - 게임 화면

struct GameView: View {
    let controller: GameController
    let scene: GameScene
    let onLeave: () -> Void
    @State private var confirmLeave = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            Button {
                confirmLeave = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.35), in: Circle())
            }
            .padding(.top, 6)
            .padding(.trailing, 8)

            if controller.disconnected {
                ResultPanel(title: "친구와 연결이 끊겼어요",
                            detail: "메뉴로 돌아가 다시 연결해 주세요.",
                            primary: nil, onPrimary: {}, onLeave: onLeave)
            } else if controller.phase == .over {
                ResultPanel(title: controller.isSolo ? "쓰러졌어요" : "둘 다 쓰러졌어요",
                            detail: "도달한 층: \(controller.floorReached)층 · 최고 기록: \(Records.bestFloor)층",
                            primary: controller.isHost ? "다시 하기" : nil,
                            onPrimary: { controller.restart() },
                            onLeave: onLeave)
                if !controller.isHost {
                    Text("방장이 ‘다시 하기’를 누르면 바로 이어서 시작해요")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 24)
                }
            }
        }
        .confirmationDialog("게임에서 나갈까요?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("나가기", role: .destructive, action: onLeave)
            Button("계속하기", role: .cancel) {}
        }
    }
}

struct ResultPanel: View {
    let title: String
    let detail: String
    let primary: String?
    let onPrimary: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 12) {
                    if let primary {
                        Button(primary, action: onPrimary)
                            .buttonStyle(.borderedProminent)
                            .tint(Color.gold)
                            .foregroundStyle(.black)
                    }
                    Button("메뉴로", action: onLeave)
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
