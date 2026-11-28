import Foundation
import GameKit
import MultipeerConnectivity
import UIKit

/// 두 기기를 잇는 통로. 콜백은 모두 메인 스레드에서 호출된다.
protocol Transport: AnyObject {
    /// 게임 규칙을 계산하는 쪽인지
    var isHost: Bool { get }
    var onData: ((Data) -> Void)? { get set }
    var onDisconnect: (() -> Void)? { get set }
    func send(_ data: Data, reliable: Bool)
    func close()
}

// MARK: - Game Center 실시간 매치 (인터넷)

final class GameCenterTransport: NSObject, Transport, GKMatchDelegate {
    let match: GKMatch
    var onData: ((Data) -> Void)?
    var onDisconnect: (() -> Void)?
    /// 상대가 접속을 마쳐 게임을 시작할 수 있을 때 한 번 호출
    var onReady: (() -> Void)?
    private var readyFired = false
    private var closed = false

    init(match: GKMatch) {
        self.match = match
        super.init()
        match.delegate = self
    }

    /// 두 사람의 Game Center ID를 비교해 작은 쪽이 방장. 양쪽 기기가 같은 결론을 낸다.
    var isHost: Bool {
        let me = GKLocalPlayer.local.gamePlayerID
        guard let other = match.players.first?.gamePlayerID else { return true }
        return me < other
    }

    func checkReady() {
        guard !readyFired, match.expectedPlayerCount == 0, !match.players.isEmpty else { return }
        readyFired = true
        onReady?()
    }

    func send(_ data: Data, reliable: Bool) {
        guard !closed else { return }
        try? match.sendData(toAllPlayers: data, with: reliable ? .reliable : .unreliable)
    }

    func close() {
        guard !closed else { return }
        closed = true
        match.delegate = nil
        match.disconnect()
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async { [weak self] in self?.onData?(data) }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.closed else { return }
            switch state {
            case .connected:
                self.checkReady()
            case .disconnected:
                self.onDisconnect?()
            default:
                break
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.closed else { return }
            self.onDisconnect?()
        }
    }
}

// MARK: - 근처 기기 (같은 와이파이 또는 블루투스, 인터넷 불필요)

final class NearbyTransport: NSObject, Transport, MCSessionDelegate,
    MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {

    static let serviceType = "duodgn"

    let isHost: Bool
    var onData: ((Data) -> Void)?
    var onDisconnect: (() -> Void)?
    var onConnected: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private let peerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invited = false
    private var connected = false
    private var closed = false

    init(host: Bool) {
        isHost = host
        // 기기 이름 대신 임의의 이름을 쓴다 (개인정보를 주고받지 않도록)
        peerID = MCPeerID(displayName: "Duo-\(Int.random(in: 1000...9999))")
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
        if host {
            let adv = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
            adv.delegate = self
            adv.startAdvertisingPeer()
            advertiser = adv
        } else {
            let br = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
            br.delegate = self
            br.startBrowsingForPeers()
            browser = br
        }
    }

    func send(_ data: Data, reliable: Bool) {
        guard !closed, !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: reliable ? .reliable : .unreliable)
    }

    func close() {
        guard !closed else { return }
        closed = true
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.delegate = nil
        session.disconnect()
    }

    private func stopSearching() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
    }

    // 방장: 초대를 받으면 한 명만 받아들인다
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let accept = !closed && session.connectedPeers.isEmpty
        invitationHandler(accept, accept ? session : nil)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onFailure?("방을 만들지 못했어요. 와이파이와 로컬 네트워크 권한을 확인해 주세요.")
        }
    }

    // 참가자: 방을 찾으면 바로 들어간다
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard !closed, !invited, session.connectedPeers.isEmpty else { return }
        invited = true
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onFailure?("방을 찾지 못했어요. 와이파이와 로컬 네트워크 권한을 확인해 주세요.")
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.closed else { return }
            switch state {
            case .connected:
                guard !self.connected else { return }
                self.connected = true
                self.stopSearching()
                self.onConnected?()
            case .notConnected:
                if self.connected {
                    self.onDisconnect?()
                } else {
                    // 초대가 실패하면 다시 찾는다
                    self.invited = false
                }
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in self?.onData?(data) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Game Center 로그인과 매치메이킹

final class GameCenterLobby: NSObject, GKMatchmakerViewControllerDelegate, GKLocalPlayerListener {
    var onMatch: ((GameCenterTransport) -> Void)?
    var onError: ((String) -> Void)?
    private(set) var isAuthenticated = false
    private var started = false
    private var pending: GameCenterTransport?

    @MainActor
    func authenticate() {
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            Task { @MainActor in
                guard let self else { return }
                if let vc {
                    topViewController()?.present(vc, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated { GKLocalPlayer.local.register(self) }
            }
        }
    }

    @MainActor
    func findMatch() {
        guard GKLocalPlayer.local.isAuthenticated else {
            onError?("Game Center에 로그인해야 온라인 협동을 할 수 있어요.\n설정 앱 > Game Center에서 로그인해 주세요.")
            return
        }
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        guard let vc = GKMatchmakerViewController(matchRequest: request) else {
            onError?("매치 화면을 열지 못했어요.")
            return
        }
        vc.matchmakerDelegate = self
        topViewController()?.present(vc, animated: true)
    }

    @MainActor
    private func present(invite: GKInvite) {
        guard let vc = GKMatchmakerViewController(invite: invite) else { return }
        vc.matchmakerDelegate = self
        topViewController()?.present(vc, animated: true)
    }

    @MainActor
    private func handle(match: GKMatch) {
        let t = GameCenterTransport(match: match)
        pending = t
        t.onReady = { [weak self, weak t] in
            guard let self, let t else { return }
            self.pending = nil
            self.onMatch?(t)
        }
        t.onDisconnect = { [weak self] in
            self?.pending = nil
            self?.onError?("상대방과 연결하지 못했어요. 다시 시도해 주세요.")
        }
        t.checkReady()
    }

    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        Task { @MainActor in viewController.dismiss(animated: true) }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            viewController.dismiss(animated: true)
            self.onError?("매치를 찾지 못했어요: \(message)")
        }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        Task { @MainActor in
            viewController.dismiss(animated: true)
            self.handle(match: match)
        }
    }

    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor in self.present(invite: invite) }
    }
}

@MainActor
func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var vc = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
}
