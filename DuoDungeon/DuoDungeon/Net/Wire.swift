import Foundation

/// 통신 메시지 종류
enum Msg: UInt8 {
    /// 방장 → 참가자: 새 게임 시작 (게임 번호, 시드)
    case start = 1
    /// 참가자 → 방장: 내 위치·조준·발사 (초당 30번)
    case input = 2
    /// 방장 → 참가자: 게임 전체 상태 (초당 20번)
    case snapshot = 3
}

// MARK: - 바이트 단위 읽기/쓰기 (Game Center 비신뢰 전송은 1KB 안쪽이 안전해서 직접 압축한다)

struct BinWriter {
    private(set) var bytes: [UInt8] = []

    var data: Data { Data(bytes) }

    mutating func u8(_ v: UInt8) { bytes.append(v) }
    mutating func i8(_ v: Int8) { bytes.append(UInt8(bitPattern: v)) }
    mutating func u16(_ v: UInt16) {
        bytes.append(UInt8(v & 0xFF))
        bytes.append(UInt8(v >> 8))
    }
    mutating func u32(_ v: UInt32) {
        for k in 0..<4 { bytes.append(UInt8((v >> (8 * UInt32(k))) & 0xFF)) }
    }
    mutating func u64(_ v: UInt64) {
        for k in 0..<8 { bytes.append(UInt8((v >> (8 * UInt64(k))) & 0xFF)) }
    }
    /// 위치: 0.001칸 단위
    mutating func pos(_ p: V2) {
        u16(UInt16(clamping: Int((p.x * 1000).rounded())))
        u16(UInt16(clamping: Int((p.y * 1000).rounded())))
    }
    /// 방향: -1...1
    mutating func dir(_ d: V2) {
        i8(Int8(clamping: Int((d.x * 127).rounded())))
        i8(Int8(clamping: Int((d.y * 127).rounded())))
    }
    /// 속도: 0.1칸/초 단위 (-12.7...12.7)
    mutating func vel(_ v: V2) {
        i8(Int8(clamping: Int((v.x * 10).rounded())))
        i8(Int8(clamping: Int((v.y * 10).rounded())))
    }
    mutating func tenth(_ v: Double) { u8(UInt8(clamping: Int((v * 10).rounded()))) }
}

struct BinReader {
    private let bytes: [UInt8]
    private var i = 0

    init(_ data: Data) { bytes = [UInt8](data) }

    /// 끝을 넘어 읽으려 했으면 false (잘린 메시지는 버린다)
    var ok: Bool { i <= bytes.count }

    mutating func u8() -> UInt8 {
        guard i < bytes.count else {
            i = bytes.count + 1
            return 0
        }
        let v = bytes[i]
        i += 1
        return v
    }
    mutating func i8() -> Int8 { Int8(bitPattern: u8()) }
    mutating func u16() -> UInt16 {
        let lo = UInt16(u8())
        let hi = UInt16(u8())
        return lo | (hi << 8)
    }
    mutating func u32() -> UInt32 {
        var v: UInt32 = 0
        for k in 0..<4 { v |= UInt32(u8()) << (8 * UInt32(k)) }
        return v
    }
    mutating func u64() -> UInt64 {
        var v: UInt64 = 0
        for k in 0..<8 { v |= UInt64(u8()) << (8 * UInt64(k)) }
        return v
    }
    mutating func pos() -> V2 {
        let x = Double(u16()) / 1000
        let y = Double(u16()) / 1000
        return V2(x, y)
    }
    mutating func dir() -> V2 {
        let x = Double(i8()) / 127
        let y = Double(i8()) / 127
        return V2(x, y)
    }
    mutating func vel() -> V2 {
        let x = Double(i8()) / 10
        let y = Double(i8()) / 10
        return V2(x, y)
    }
    mutating func tenth() -> Double { Double(u8()) / 10 }
}

// MARK: - 메시지 내용

struct NetInput {
    var serial: UInt16
    var pos: V2
    var aim: V2
    var firing: Bool
    var moving: Bool
}

struct SnapPlayer {
    var pos: V2
    var aim: V2
    var hp: Int
    var maxHp: Int
    var downed: Bool
    var invuln: Bool
    var firing: Bool
    var pierce: Bool
    var moving: Bool
    var revive: Double
    var speed: Double
    var damage: Double
    var fireRate: Double
    var shots: Int
}

struct Snapshot {
    var floor = 1
    var room = 0
    var serial: UInt16 = 0
    var gameOver = false
    var cleared: UInt32 = 0
    var visited: UInt32 = 0
    var players: [SnapPlayer] = []
    var enemies: [Enemy] = []
    var bullets: [Bullet] = []
    var pickups: [Pickup] = []
}

private func mask(_ s: Set<Int>) -> UInt32 {
    var m: UInt32 = 0
    for i in s where i >= 0 && i < 32 { m |= UInt32(1) << UInt32(i) }
    return m
}

private func unmask(_ m: UInt32) -> Set<Int> {
    var s = Set<Int>()
    for i in 0..<32 where m & (UInt32(1) << UInt32(i)) != 0 { s.insert(i) }
    return s
}

extension World {
    static func startMessage(gameId: UInt32, seed: UInt64) -> Data {
        var w = BinWriter()
        w.u8(Msg.start.rawValue)
        w.u32(gameId)
        w.u64(seed)
        return w.data
    }

    // MARK: 입력 (참가자 → 방장)

    func encodeInput(gameId: UInt32) -> Data {
        var w = BinWriter()
        w.u8(Msg.input.rawValue)
        w.u32(gameId)
        w.u16(roomSerial)
        let p = players[localIndex]
        w.pos(p.pos)
        w.dir(p.aim)
        var f: UInt8 = 0
        if p.firing { f |= 1 }
        if p.moving { f |= 2 }
        w.u8(f)
        return w.data
    }

    static func decodeInput(_ r: inout BinReader) -> NetInput? {
        let serial = r.u16()
        let pos = r.pos()
        let aim = r.dir()
        let f = r.u8()
        guard r.ok else { return nil }
        return NetInput(serial: serial, pos: pos, aim: aim, firing: f & 1 != 0, moving: f & 2 != 0)
    }

    func applyInput(_ inp: NetInput, to i: Int) {
        guard players.indices.contains(i) else { return }
        // 방을 옮긴 직후에 도착한 예전 위치는 무시한다 (안 그러면 문 앞으로 되돌아간다)
        if inp.serial == roomSerial && !players[i].downed { players[i].pos = inp.pos }
        if inp.aim.lengthSq > 0.01 { players[i].aim = inp.aim }
        players[i].firing = inp.firing && !players[i].downed
        players[i].moving = inp.moving
    }

    // MARK: 상태 (방장 → 참가자)

    func encodeSnapshot(gameId: UInt32, tick: UInt32) -> Data {
        var w = BinWriter()
        w.u8(Msg.snapshot.rawValue)
        w.u32(gameId)
        w.u32(tick)
        w.u8(UInt8(clamping: floorNum))
        w.u8(UInt8(clamping: roomIndex))
        w.u16(roomSerial)
        w.u8(gameOver ? 1 : 0)
        w.u32(mask(cleared))
        w.u32(mask(visited))

        w.u8(UInt8(players.count))
        for p in players {
            w.pos(p.pos)
            w.dir(p.aim)
            w.u8(UInt8(clamping: p.hp))
            w.u8(UInt8(clamping: p.maxHp))
            var f: UInt8 = 0
            if p.downed { f |= 1 }
            if p.invuln > 0 { f |= 2 }
            if p.firing { f |= 4 }
            if p.pierce { f |= 8 }
            if p.moving { f |= 16 }
            w.u8(f)
            w.u8(UInt8(clamping: Int(p.revive * 100)))
            w.tenth(p.speed)
            w.tenth(p.damage)
            w.tenth(p.fireRate)
            w.u8(UInt8(clamping: p.shots))
        }

        let es = enemies.prefix(32)
        w.u8(UInt8(es.count))
        for e in es {
            w.u16(e.id)
            w.u8(e.kind.rawValue)
            w.pos(e.pos)
            w.u8(UInt8(clamping: Int(max(0, min(1, e.hp / max(e.maxHp, 0.001))) * 255)))
            var f: UInt8 = 0
            if e.flash > 0 { f |= 1 }
            if e.spawnT > 0 { f |= 2 }
            if e.kind == .charger && e.state == 1 { f |= 4 }
            w.u8(f)
        }

        // 피해야 하는 적 탄환을 먼저 넣는다
        let ordered = bullets.filter { !$0.friendly } + bullets.filter { $0.friendly }
        let bs = ordered.prefix(60)
        w.u8(UInt8(bs.count))
        for b in bs {
            w.pos(b.pos)
            w.vel(b.vel)
            w.u8((b.friendly ? 1 : 0) | (b.owner << 1))
        }

        let pk = pickups.prefix(12)
        w.u8(UInt8(pk.count))
        for p in pk {
            w.u16(p.id)
            w.u8(p.kind.rawValue)
            w.pos(p.pos)
        }
        return w.data
    }

    static func decodeSnapshot(_ r: inout BinReader) -> Snapshot? {
        var s = Snapshot()
        s.floor = Int(r.u8())
        s.room = Int(r.u8())
        s.serial = r.u16()
        s.gameOver = r.u8() & 1 != 0
        s.cleared = r.u32()
        s.visited = r.u32()

        let pc = Int(r.u8())
        for _ in 0..<min(pc, 4) {
            let pos = r.pos()
            let aim = r.dir()
            let hp = Int(r.u8())
            let maxHp = Int(r.u8())
            let f = r.u8()
            let revive = Double(r.u8()) / 100
            let speed = r.tenth()
            let damage = r.tenth()
            let rate = r.tenth()
            let shots = Int(r.u8())
            s.players.append(SnapPlayer(pos: pos, aim: aim, hp: hp, maxHp: maxHp,
                                        downed: f & 1 != 0, invuln: f & 2 != 0, firing: f & 4 != 0,
                                        pierce: f & 8 != 0, moving: f & 16 != 0, revive: revive,
                                        speed: speed, damage: damage, fireRate: rate, shots: shots))
        }

        let ec = Int(r.u8())
        for _ in 0..<ec {
            let id = r.u16()
            let kind = EnemyKind(rawValue: r.u8()) ?? .slime
            let pos = r.pos()
            let frac = Double(r.u8()) / 255
            let f = r.u8()
            var e = Enemy(id: id, kind: kind, pos: pos, hp: frac, maxHp: 1)
            e.flash = f & 1 != 0 ? 0.08 : 0
            e.spawnT = f & 2 != 0 ? 0.3 : 0
            e.state = f & 4 != 0 ? 1 : 0
            s.enemies.append(e)
        }

        let bc = Int(r.u8())
        for _ in 0..<bc {
            let pos = r.pos()
            let vel = r.vel()
            let f = r.u8()
            s.bullets.append(Bullet(pos: pos, vel: vel, friendly: f & 1 != 0, owner: f >> 1))
        }

        let kc = Int(r.u8())
        for _ in 0..<kc {
            let id = r.u16()
            let kind = PickupKind(rawValue: r.u8()) ?? .heart
            let pos = r.pos()
            s.pickups.append(Pickup(id: id, kind: kind, pos: pos))
        }
        return r.ok ? s : nil
    }

    func apply(_ s: Snapshot) {
        if s.floor != floorNum { setFloor(s.floor) }
        let teleported = s.serial != roomSerial
        if s.room != roomIndex { loadRoom(s.room) }
        roomSerial = s.serial
        cleared = unmask(s.cleared)
        visited = unmask(s.visited)
        gameOver = s.gameOver

        for (i, sp) in s.players.enumerated() where i < players.count {
            var p = players[i]
            if i != localIndex || teleported { p.pos = sp.pos }
            if i != localIndex {
                p.aim = sp.aim
                p.firing = sp.firing
                p.moving = sp.moving
            }
            p.hp = sp.hp
            p.maxHp = sp.maxHp
            p.downed = sp.downed
            p.invuln = sp.invuln ? 0.1 : 0
            p.revive = sp.revive
            p.speed = sp.speed
            p.damage = sp.damage
            p.fireRate = sp.fireRate
            p.shots = sp.shots
            p.pierce = sp.pierce
            players[i] = p
        }
        enemies = s.enemies
        bullets = s.bullets
        pickups = s.pickups
    }
}
