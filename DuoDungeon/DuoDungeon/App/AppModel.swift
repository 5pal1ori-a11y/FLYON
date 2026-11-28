import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Screen: Equatable {
        case menu
        case nearby(host: Bool)
        case playing
    }

    var screen: Screen = .menu
    var notice: String?
    private(set) var controller: GameController?
    private(set) var scene: GameScene?
    private(set) var bestFloor = Records.bestFloor

    let lobby = GameCenterLobby()
    @ObservationIgnored private var nearby: NearbyTransport?

    init() {
        lobby.onMatch = { [weak self] transport in self?.begin(transport) }
        lobby.onError = { [weak self] message in self?.notice = message }
    }

    func onLaunch() {
        lobby.authenticate()
    }

    func playSolo() {
        begin(nil)
    }

    func playOnline() {
        lobby.findMatch()
    }

    func startNearby(host: Bool) {
        cancelNearby()
        let t = NearbyTransport(host: host)
        t.onConnected = { [weak self, weak t] in
            guard let self, let t else { return }
            self.begin(t)
        }
        t.onFailure = { [weak self] message in
            self?.notice = message
            self?.cancelNearby()
        }
        nearby = t
        screen = .nearby(host: host)
    }

    func cancelNearby() {
        nearby?.close()
        nearby = nil
        if case .nearby = screen { screen = .menu }
    }

    private func begin(_ transport: Transport?) {
        if let n = nearby {
            n.onConnected = nil
            n.onFailure = nil
        }
        nearby = nil
        let c = GameController(transport: transport)
        controller = c
        scene = GameScene(controller: c)
        screen = .playing
    }

    func leave() {
        controller?.leave()
        controller = nil
        scene = nil
        bestFloor = Records.bestFloor
        screen = .menu
    }
}
