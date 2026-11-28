import Foundation
import Observation

/// 한 판을 진행한다. 혼자 하기면 transport가 없다.
@Observable
final class GameController {
    enum Phase {
        case waiting, playing, over
    }

    private(set) var phase: Phase = .waiting
    private(set) var disconnected = false
    private(set) var floorReached = 1

    let transport: Transport?
    let isHost: Bool
    let playerCount: Int
    let localIndex: Int
    @ObservationIgnored private(set) var world: World?

    @ObservationIgnored private var gameId: UInt32 = 0
    @ObservationIgnored private var tick: UInt32 = 0
    @ObservationIgnored private var lastTick: UInt32 = 0
    @ObservationIgnored private var netAccum = 0.0
    @ObservationIgnored private var startAccum = 0.0
    @ObservationIgnored private var peerReady = false

    var isSolo: Bool { transport == nil }

    init(transport: Transport?) {
        self.transport = transport
        isHost = transport?.isHost ?? true
        playerCount = transport == nil ? 1 : 2
        localIndex = (transport?.isHost ?? true) ? 0 : 1
        transport?.onData = { [weak self] data in self?.receive(data) }
        transport?.onDisconnect = { [weak self] in self?.disconnected = true }
        if isHost { newGame() }
    }

    /// 방장(또는 혼자)만 다시 시작할 수 있다
    func restart() {
        guard isHost else { return }
        newGame()
    }

    func leave() {
        transport?.onData = nil
        transport?.onDisconnect = nil
        transport?.close()
    }

    private func newGame() {
        gameId = UInt32.random(in: 1...UInt32.max)
        let seed = UInt64.random(in: 1...UInt64.max)
        world = World(seed: seed, isHost: true, playerCount: playerCount, localIndex: 0)
        tick = 0
        peerReady = false
        startAccum = 1
        phase = .playing
    }

    func update(dt: Double, move: V2, aim: V2, firing: Bool) {
        guard let world else { return }
        world.stepLocal(dt, move: move, aim: aim, firing: firing)

        if isHost {
            world.stepHost(dt)
            if let transport {
                // 참가자가 응답할 때까지 시작 신호를 반복해서 보낸다
                if !peerReady {
                    startAccum += dt
                    if startAccum >= 0.5 {
                        startAccum = 0
                        transport.send(World.startMessage(gameId: gameId, seed: world.seed), reliable: true)
                    }
                }
                netAccum += dt
                if netAccum >= 0.05 {
                    netAccum = 0
                    tick &+= 1
                    transport.send(world.encodeSnapshot(gameId: gameId, tick: tick), reliable: false)
                }
            }
        } else {
            world.stepClient(dt)
            netAccum += dt
            if netAccum >= 1.0 / 30 {
                netAccum = 0
                transport?.send(world.encodeInput(gameId: gameId), reliable: false)
            }
        }

        if world.gameOver {
            if phase != .over {
                floorReached = world.floorNum
                Records.submit(floor: world.floorNum)
                phase = .over
            }
        } else if phase == .over {
            phase = .playing
        }
    }

    private func receive(_ data: Data) {
        var r = BinReader(data)
        guard let type = Msg(rawValue: r.u8()) else { return }
        switch type {
        case .start:
            guard !isHost else { return }
            let gid = r.u32()
            let seed = r.u64()
            guard r.ok, gid != gameId else { return }
            gameId = gid
            lastTick = 0
            let w = World(seed: seed, isHost: false, playerCount: 2, localIndex: 1)
            world = w
            phase = .playing
            transport?.send(w.encodeInput(gameId: gid), reliable: true)
        case .input:
            guard isHost, let world else { return }
            let gid = r.u32()
            guard gid == gameId, let inp = World.decodeInput(&r) else { return }
            peerReady = true
            world.applyInput(inp, to: 1)
        case .snapshot:
            guard !isHost, let world else { return }
            let gid = r.u32()
            let t = r.u32()
            // 늦게 도착한 예전 상태는 버린다
            guard gid == gameId, t > lastTick, let snap = World.decodeSnapshot(&r) else { return }
            lastTick = t
            world.apply(snap)
        }
    }
}
