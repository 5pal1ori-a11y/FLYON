import Foundation

// MARK: - 등장하는 것들

struct Player {
    static let radius = 0.33

    var pos: V2
    var aim = V2(1, 0)
    var firing = false
    var moving = false
    var hp = 5
    var maxHp = 5
    var downed = false
    var revive = 0.0
    var invuln = 0.0
    var cooldown = 0.0
    var speed = 4.2
    var damage = 1.0
    var fireRate = 3.2
    var shots = 1
    var pierce = false
}

enum EnemyKind: UInt8 {
    case slime = 0, bat, eye, charger, boss

    var baseHp: Double {
        switch self {
        case .slime: return 3
        case .bat: return 2
        case .eye: return 4
        case .charger: return 6
        case .boss: return 70
        }
    }

    var radius: Double {
        switch self {
        case .slime: return 0.32
        case .bat: return 0.3
        case .eye: return 0.32
        case .charger: return 0.38
        case .boss: return 0.85
        }
    }

    /// 날아다녀서 바위를 넘는다
    var flying: Bool { self == .bat }
}

struct Enemy {
    var id: UInt16
    var kind: EnemyKind
    var pos: V2
    var hp: Double
    var maxHp: Double
    var timer = 1.0
    var state = 0
    var phase = 0.0
    var flash = 0.0
    var spawnT = 0.7
    var knock = V2.zero
    var chargeDir = V2.zero
}

struct Bullet {
    var pos: V2
    var vel: V2
    var friendly: Bool
    var owner: UInt8 = 0
    var damage = 1.0
    var life = 3.0
    var pierce = false
    var hitIds: [UInt16] = []
}

enum PickupKind: UInt8 {
    case heart = 0, stairs, dmg, rate, speed, multi, pierce, maxhp

    static let upgrades: [PickupKind] = [.dmg, .rate, .speed, .multi, .pierce, .maxhp]

    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .stairs: return "🪜"
        case .dmg: return "⚔️"
        case .rate: return "⚡️"
        case .speed: return "👟"
        case .multi: return "✨"
        case .pierce: return "🏹"
        case .maxhp: return "💖"
        }
    }

    var title: String {
        switch self {
        case .heart: return "체력 회복"
        case .stairs: return "다음 층"
        case .dmg: return "공격력 업!"
        case .rate: return "연사 속도 업!"
        case .speed: return "이동 속도 업!"
        case .multi: return "탄환 +1!"
        case .pierce: return "관통 탄환!"
        case .maxhp: return "최대 체력 +1!"
        }
    }
}

struct Pickup {
    var id: UInt16
    var kind: PickupKind
    var pos: V2
}

// MARK: - 게임 세계

/// 방장(host)이 규칙을 모두 계산하고, 참가자(client)는 방장이 보낸 상태를 그대로 따른다.
/// 단, 각자 자기 캐릭터의 이동은 자기 기기에서 바로 처리해 조작감이 좋게 한다.
final class World {
    let seed: UInt64
    let isHost: Bool
    let playerCount: Int
    let localIndex: Int

    private(set) var floorNum = 1
    private(set) var map: FloorMap
    private(set) var roomIndex = 0
    private(set) var rocks = Set<Int>()

    var cleared = Set<Int>()
    var visited = Set<Int>()
    var players: [Player] = []
    var enemies: [Enemy] = []
    var bullets: [Bullet] = []
    var roomPickups: [Int: [Pickup]] = [:]
    /// 방장이 캐릭터를 순간이동시킬 때마다(방·층 이동) 1씩 오른다
    var roomSerial: UInt16 = 0
    var gameOver = false
    private(set) var time = 0.0

    private var nextId: UInt16 = 1
    private var rng: SplitMix64

    var pickups: [Pickup] {
        get { roomPickups[roomIndex] ?? [] }
        set { roomPickups[roomIndex] = newValue }
    }

    var room: RoomInfo { map.rooms[roomIndex] }

    init(seed: UInt64, isHost: Bool, playerCount: Int, localIndex: Int) {
        self.seed = seed
        self.isHost = isHost
        self.playerCount = playerCount
        self.localIndex = localIndex
        map = FloorMap(seed: seed, floor: 1)
        rng = SplitMix64(seed: seed ^ 0xA5A5_5A5A_1234_8765)
        for _ in 0..<playerCount { players.append(Player(pos: V2(7.5, 4.5))) }
        setFloor(1)
    }

    // MARK: 방 · 층

    func setFloor(_ f: Int) {
        floorNum = f
        map = FloorMap(seed: seed, floor: f)
        cleared = [0]
        visited = [0]
        roomPickups = [:]
        enemies = []
        bullets = []
        loadRoom(0)
        for i in players.indices {
            players[i].pos = V2(7.5 + (i == 0 ? -0.6 : 0.6), 4.5)
            if players[i].downed {
                players[i].downed = false
                players[i].hp = 1
            }
            players[i].revive = 0
            players[i].invuln = 1.0
        }
        roomSerial &+= 1
    }

    func loadRoom(_ idx: Int) {
        roomIndex = max(0, min(idx, map.rooms.count - 1))
        rocks = Set(Layouts.all[map.rooms[roomIndex].layout].map { $0.1 * RW + $0.0 })
    }

    func tile(_ tx: Int, _ ty: Int) -> TileKind {
        if tx < 0 || ty < 0 || tx >= RW || ty >= RH { return .wall }
        if tx == 0 || ty == 0 || tx == RW - 1 || ty == RH - 1 {
            if let d = Dir.door(atX: tx, y: ty), room.neighbors[d.rawValue] != nil {
                return cleared.contains(roomIndex) ? .doorOpen : .doorClosed
            }
            return .wall
        }
        return rocks.contains(ty * RW + tx) ? .rock : .floor
    }

    func isSolid(_ tx: Int, _ ty: Int, flying: Bool) -> Bool {
        switch tile(tx, ty) {
        case .wall, .doorClosed: return true
        case .rock: return !flying
        case .floor, .doorOpen: return false
        }
    }

    func isSolid(at p: V2, flying: Bool) -> Bool {
        isSolid(Int(floor(p.x)), Int(floor(p.y)), flying: flying)
    }

    private func overlapsSolid(_ p: V2, _ r: Double, _ flying: Bool) -> (Int, Int)? {
        let x0 = Int(floor(p.x - r)), x1 = Int(floor(p.x + r - 1e-9))
        let y0 = Int(floor(p.y - r)), y1 = Int(floor(p.y + r - 1e-9))
        for ty in y0...max(y0, y1) {
            for tx in x0...max(x0, x1) where isSolid(tx, ty, flying: flying) {
                return (tx, ty)
            }
        }
        return nil
    }

    /// 벽에 막히면 벽 앞에서 멈춘다. 벽에 부딪혔으면 true.
    @discardableResult
    func moveCircle(_ p: inout V2, _ delta: V2, r: Double, flying: Bool) -> Bool {
        var hit = false
        if delta.x != 0 {
            p.x += delta.x
            if let t = overlapsSolid(p, r, flying) {
                hit = true
                p.x = delta.x > 0 ? Double(t.0) - r - 0.001 : Double(t.0 + 1) + r + 0.001
            }
        }
        if delta.y != 0 {
            p.y += delta.y
            if let t = overlapsSolid(p, r, flying) {
                hit = true
                p.y = delta.y > 0 ? Double(t.1) - r - 0.001 : Double(t.1 + 1) + r + 0.001
            }
        }
        return hit
    }

    private func newId() -> UInt16 {
        nextId = nextId == UInt16.max ? 1 : nextId + 1
        return nextId
    }

    // MARK: 내 캐릭터 (양쪽 기기 모두)

    func stepLocal(_ dt: Double, move: V2, aim: V2, firing: Bool) {
        guard players.indices.contains(localIndex) else { return }
        var p = players[localIndex]
        let m = move.length > 1 ? move.normalized : move
        let canAct = !p.downed && !gameOver
        if canAct {
            moveCircle(&p.pos, m * (p.speed * dt), r: Player.radius, flying: false)
        }
        p.moving = canAct && m.length > 0.1
        p.firing = canAct && firing && aim.length > 0.2
        if p.firing {
            p.aim = aim.normalized
        } else if m.length > 0.2 {
            p.aim = m.normalized
        }
        players[localIndex] = p
    }

    // MARK: 참가자: 받은 상태 사이를 이어 그린다

    func stepClient(_ dt: Double) {
        time += dt
        bullets = bullets.compactMap { old in
            var b = old
            b.pos += b.vel * dt
            return isSolid(at: b.pos, flying: false) ? nil : b
        }
        for i in enemies.indices {
            enemies[i].flash = max(0, enemies[i].flash - dt)
        }
    }

    // MARK: 방장: 게임 규칙 전체

    func stepHost(_ dt: Double) {
        time += dt
        guard !gameOver else { return }

        for i in players.indices {
            players[i].invuln = max(0, players[i].invuln - dt)
            players[i].cooldown = max(0, players[i].cooldown - dt)
            if players[i].downed { players[i].firing = false }
            let p = players[i]
            if !p.downed && p.firing && p.cooldown <= 0 {
                players[i].cooldown = 1.0 / p.fireRate
                fire(from: i)
            }
        }

        updateBullets(dt)
        updateEnemies(dt)
        contactDamage()
        updateRevive(dt)
        updatePickups()
        checkClear()
        checkDoors()

        if players.allSatisfy({ $0.downed }) { gameOver = true }
    }

    private func fire(from i: Int) {
        let p = players[i]
        let dir = p.aim.normalized
        guard dir.lengthSq > 0 else { return }
        let n = max(1, p.shots)
        for k in 0..<n {
            let off = (Double(k) - Double(n - 1) / 2) * 0.16
            bullets.append(Bullet(pos: p.pos + dir * 0.35, vel: dir.rotated(off) * 9.0, friendly: true,
                                  owner: UInt8(i), damage: p.damage, life: 0.7, pierce: p.pierce))
        }
    }

    private func shoot(from pos: V2, dir: V2, speed: Double) {
        guard dir.lengthSq > 0 else { return }
        bullets.append(Bullet(pos: pos, vel: dir.normalized * speed, friendly: false, life: 4))
    }

    private func ring(from pos: V2, count: Int, speed: Double, offset: Double) {
        for k in 0..<count {
            let a = offset + Double(k) / Double(count) * 2 * Double.pi
            shoot(from: pos, dir: V2(cos(a), sin(a)), speed: speed)
        }
    }

    private func hurt(_ i: Int) {
        guard !players[i].downed, players[i].invuln <= 0 else { return }
        players[i].hp -= 1
        players[i].invuln = 1.0
        if players[i].hp <= 0 {
            players[i].hp = 0
            players[i].downed = true
            players[i].revive = 0
            players[i].firing = false
        }
    }

    private func updateBullets(_ dt: Double) {
        var kept: [Bullet] = []
        kept.reserveCapacity(bullets.count)
        for var b in bullets {
            b.pos += b.vel * dt
            b.life -= dt
            if b.life <= 0 || isSolid(at: b.pos, flying: false) { continue }
            var dead = false
            if b.friendly {
                for e in enemies.indices where enemies[e].spawnT <= 0 && enemies[e].hp > 0 {
                    if b.hitIds.contains(enemies[e].id) { continue }
                    let rr = enemies[e].kind.radius + 0.14
                    if (enemies[e].pos - b.pos).lengthSq < rr * rr {
                        enemies[e].hp -= b.damage
                        enemies[e].flash = 0.08
                        if enemies[e].kind != .boss { enemies[e].knock = b.vel.normalized * 2.5 }
                        if b.pierce {
                            b.hitIds.append(enemies[e].id)
                        } else {
                            dead = true
                            break
                        }
                    }
                }
            } else {
                for pi in players.indices where !players[pi].downed && players[pi].invuln <= 0 {
                    let rr = Player.radius + 0.12
                    if (players[pi].pos - b.pos).lengthSq < rr * rr {
                        hurt(pi)
                        dead = true
                        break
                    }
                }
            }
            if !dead { kept.append(b) }
        }
        bullets = kept

        var alive: [Enemy] = []
        for e in enemies {
            if e.hp > 0 {
                alive.append(e)
            } else if e.kind != .boss && rng.unit() < 0.06 {
                var list = pickups
                list.append(Pickup(id: newId(), kind: .heart, pos: e.pos))
                pickups = list
            }
        }
        enemies = alive
    }

    private func nearestAlive(to p: V2) -> V2? {
        var best: V2?
        var bestD = Double.infinity
        for pl in players where !pl.downed {
            let d = (pl.pos - p).lengthSq
            if d < bestD {
                bestD = d
                best = pl.pos
            }
        }
        return best
    }

    private func updateEnemies(_ dt: Double) {
        var spawns: [(EnemyKind, V2)] = []
        for i in enemies.indices {
            var e = enemies[i]
            e.flash = max(0, e.flash - dt)
            if e.spawnT > 0 {
                e.spawnT -= dt
                enemies[i] = e
                continue
            }
            let target = nearestAlive(to: e.pos)
            let toT = target.map { $0 - e.pos } ?? .zero
            let dist = toT.length
            let dirT = toT.normalized
            var vel = V2.zero

            switch e.kind {
            case .slime:
                let hop = 0.45 + 0.55 * max(0, sin(time * 5 + e.phase))
                vel = dirT * (1.5 * hop)
            case .bat:
                let perp = V2(-dirT.y, dirT.x)
                vel = (dirT + perp * (sin(time * 4 + e.phase) * 0.9)).normalized * 2.5
            case .eye:
                if dist < 3.2 {
                    vel = dirT * -1.0
                } else if dist > 5.5 {
                    vel = dirT * 0.9
                } else {
                    vel = V2(-dirT.y, dirT.x) * (e.phase > 3 ? 0.6 : -0.6)
                }
                e.timer -= dt
                if e.timer <= 0 && target != nil {
                    e.timer = max(1.1, 2.0 - 0.1 * Double(floorNum))
                    shoot(from: e.pos, dir: dirT, speed: 4.2)
                }
            case .charger:
                switch e.state {
                case 0:
                    vel = dirT * 1.0
                    e.timer -= dt
                    if e.timer <= 0 && dist < 7 && target != nil {
                        e.state = 1
                        e.timer = 0.55
                        e.chargeDir = dirT
                    }
                case 1:
                    e.timer -= dt
                    if e.timer <= 0 {
                        e.state = 2
                        e.timer = 0.75
                    }
                default:
                    vel = e.chargeDir * 7.5
                    e.timer -= dt
                    if e.timer <= 0 {
                        e.state = 0
                        e.timer = 1.2 + rng.unit()
                    }
                }
            case .boss:
                vel = dirT * 0.8
                e.timer -= dt
                if e.timer <= 0 && target != nil {
                    let enraged = e.hp < e.maxHp * 0.5
                    e.timer = max(1.0, 2.4 - 0.12 * Double(floorNum)) * (enraged ? 0.7 : 1.0)
                    switch e.state % 3 {
                    case 0:
                        ring(from: e.pos, count: enraged ? 18 : 14, speed: 3.6, offset: e.phase)
                        e.phase += 0.2
                    case 1:
                        for k in -2...2 { shoot(from: e.pos, dir: dirT.rotated(Double(k) * 0.2), speed: 5.0) }
                    default:
                        if enemies.count + spawns.count < 7 {
                            spawns.append((.slime, e.pos + V2(-1.2, -0.6)))
                            spawns.append((.slime, e.pos + V2(1.2, -0.6)))
                        } else {
                            ring(from: e.pos, count: 10, speed: 3.0, offset: e.phase + 0.3)
                        }
                    }
                    e.state += 1
                }
            }

            let delta = (vel + e.knock) * dt
            e.knock = e.knock * max(0, 1 - dt * 8)
            let hitWall = moveCircle(&e.pos, delta, r: e.kind.radius, flying: e.kind.flying)
            if hitWall && e.kind == .charger && e.state == 2 {
                e.state = 0
                e.timer = 1.0
            }
            enemies[i] = e
        }
        for s in spawns {
            var p = s.1
            p.x = min(max(p.x, 1.5), Double(RW) - 1.5)
            p.y = min(max(p.y, 1.5), Double(RH) - 1.5)
            if !isSolid(at: p, flying: false) { spawnEnemy(s.0, at: p) }
        }
    }

    private func contactDamage() {
        for e in enemies where e.spawnT <= 0 {
            for pi in players.indices where !players[pi].downed && players[pi].invuln <= 0 {
                let rr = e.kind.radius + Player.radius - 0.05
                if (players[pi].pos - e.pos).lengthSq < rr * rr { hurt(pi) }
            }
        }
    }

    private func updateRevive(_ dt: Double) {
        for d in players.indices where players[d].downed {
            let helped = players.indices.contains { o in
                o != d && !players[o].downed && (players[o].pos - players[d].pos).length < 1.3
            }
            if helped {
                players[d].revive += dt
            } else {
                players[d].revive = max(0, players[d].revive - dt * 0.5)
            }
            if players[d].revive >= 2.0 {
                players[d].downed = false
                players[d].hp = max(1, players[d].maxHp / 2)
                players[d].invuln = 1.5
                players[d].revive = 0
            }
        }
    }

    private func apply(_ kind: PickupKind, to i: Int) {
        switch kind {
        case .dmg: players[i].damage += 0.5
        case .rate: players[i].fireRate *= 1.2
        case .speed: players[i].speed += 0.5
        case .multi: players[i].shots = min(5, players[i].shots + 1)
        case .pierce:
            if players[i].pierce { players[i].damage += 0.5 } else { players[i].pierce = true }
        case .maxhp:
            players[i].maxHp = min(10, players[i].maxHp + 1)
            players[i].hp = min(players[i].maxHp, players[i].hp + 2)
        case .heart, .stairs: break
        }
    }

    private func updatePickups() {
        var list = pickups
        guard !list.isEmpty else { return }
        var goDown = false
        var k = 0
        while k < list.count {
            var taken = false
            for pi in players.indices where !players[pi].downed {
                guard (players[pi].pos - list[k].pos).length < 0.6 else { continue }
                switch list[k].kind {
                case .stairs:
                    goDown = true
                case .heart:
                    if players[pi].hp < players[pi].maxHp {
                        players[pi].hp += 1
                        taken = true
                    }
                default:
                    apply(list[k].kind, to: pi)
                    taken = true
                }
                if taken { break }
            }
            if taken { list.remove(at: k) } else { k += 1 }
        }
        pickups = list
        if goDown { setFloor(floorNum + 1) }
    }

    private func freeSpot(near c: (Int, Int)) -> V2 {
        for r in 0...4 {
            for dy in -r...r {
                for dx in -r...r {
                    let tx = c.0 + dx, ty = c.1 + dy
                    if tile(tx, ty) == .floor { return V2(Double(tx) + 0.5, Double(ty) + 0.5) }
                }
            }
        }
        return V2(7.5, 4.5)
    }

    private func checkClear() {
        guard !cleared.contains(roomIndex), enemies.isEmpty else { return }
        guard room.kind == .normal || room.kind == .boss else { return }
        cleared.insert(roomIndex)
        var list = pickups
        if room.kind == .boss {
            list.append(Pickup(id: newId(), kind: .stairs, pos: V2(7.5, 4.5)))
            let up = PickupKind.upgrades[rng.int(PickupKind.upgrades.count)]
            list.append(Pickup(id: newId(), kind: up, pos: V2(5.5, 4.5)))
            list.append(Pickup(id: newId(), kind: .heart, pos: V2(9.5, 4.5)))
        } else if rng.unit() < 0.3 {
            list.append(Pickup(id: newId(), kind: .heart, pos: freeSpot(near: (7, 4))))
        }
        pickups = list
    }

    private func checkDoors() {
        guard cleared.contains(roomIndex) else { return }
        for p in players where !p.downed {
            for d in Dir.allCases {
                guard let nb = room.neighbors[d.rawValue] else { continue }
                let crossed: Bool
                switch d {
                case .up: crossed = p.pos.y > Double(RH - 1) + 0.05
                case .down: crossed = p.pos.y < 0.95
                case .left: crossed = p.pos.x < 0.95
                case .right: crossed = p.pos.x > Double(RW - 1) + 0.05
                }
                if crossed {
                    enterRoom(nb, via: d.opposite)
                    return
                }
            }
        }
    }

    private func enterRoom(_ idx: Int, via side: Dir) {
        loadRoom(idx)
        visited.insert(idx)
        bullets = []
        let entry = side.entryPoint
        for i in players.indices {
            let off = players.count > 1 ? (i == 0 ? -0.6 : 0.6) : 0
            players[i].pos = entry + side.spread * off
        }
        roomSerial &+= 1
        populate(entry: entry)
    }

    private func spawnEnemy(_ kind: EnemyKind, at p: V2) {
        let scale = (1 + 0.3 * Double(floorNum - 1)) * (playerCount > 1 ? 1.5 : 1.0)
        let hp = kind.baseHp * scale
        enemies.append(Enemy(id: newId(), kind: kind, pos: p, hp: hp, maxHp: hp,
                             timer: 0.8 + rng.unit() * 1.2, phase: rng.unit() * 6.28))
    }

    private func populate(entry: V2) {
        guard !cleared.contains(roomIndex) else { return }
        switch room.kind {
        case .start:
            cleared.insert(roomIndex)
        case .treasure:
            var pool = PickupKind.upgrades
            var list = pickups
            for x in [5.5, 7.5, 9.5] {
                let k = pool.remove(at: rng.int(pool.count))
                list.append(Pickup(id: newId(), kind: k, pos: V2(x, 4.5)))
            }
            pickups = list
            cleared.insert(roomIndex)
        case .boss:
            spawnEnemy(.boss, at: V2(7.5, 4.8))
            if floorNum >= 2 {
                spawnEnemy(.bat, at: V2(3.5, 6.5))
                spawnEnemy(.bat, at: V2(11.5, 6.5))
            }
        case .normal:
            let pool: [EnemyKind]
            switch floorNum {
            case 1: pool = [.slime, .slime, .bat, .eye]
            case 2: pool = [.slime, .bat, .eye, .charger]
            default: pool = [.slime, .bat, .bat, .eye, .eye, .charger, .charger]
            }
            let count = min(9, 3 + rng.int(3) + floorNum / 2)
            var placed = 0
            var tries = 0
            while placed < count && tries < 200 {
                tries += 1
                let tx = 1 + rng.int(RW - 2), ty = 1 + rng.int(RH - 2)
                guard tile(tx, ty) == .floor else { continue }
                let p = V2(Double(tx) + 0.5, Double(ty) + 0.5)
                guard (p - entry).length > 4 else { continue }
                spawnEnemy(pool[rng.int(pool.count)], at: p)
                placed += 1
            }
            if placed == 0 { cleared.insert(roomIndex) }
        }
    }
}
