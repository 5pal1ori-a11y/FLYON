import SpriteKit
import UIKit

/// 화면에 그 자리에서 나타나는 가상 조이스틱
@MainActor
final class Stick {
    let radius: CGFloat = 54
    let base: SKShapeNode
    let knob: SKShapeNode
    private(set) var touch: UITouch?
    private(set) var value = CGVector.zero
    private var origin = CGPoint.zero

    init() {
        base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = UIColor(white: 1, alpha: 0.07)
        base.strokeColor = UIColor(white: 1, alpha: 0.35)
        base.lineWidth = 2
        knob = SKShapeNode(circleOfRadius: 24)
        knob.fillColor = UIColor(white: 1, alpha: 0.35)
        knob.strokeColor = .clear
        base.zPosition = 300
        knob.zPosition = 301
        base.isHidden = true
        knob.isHidden = true
    }

    var active: Bool { touch != nil }

    func begin(_ t: UITouch, at p: CGPoint) {
        touch = t
        origin = p
        base.position = p
        knob.position = p
        value = .zero
        base.isHidden = false
        knob.isHidden = false
    }

    func move(to p: CGPoint) {
        var dx = p.x - origin.x
        var dy = p.y - origin.y
        let l = hypot(dx, dy)
        if l > radius {
            dx *= radius / l
            dy *= radius / l
        }
        knob.position = CGPoint(x: origin.x + dx, y: origin.y + dy)
        value = CGVector(dx: dx / radius, dy: dy / radius)
    }

    func end() {
        touch = nil
        value = .zero
        base.isHidden = true
        knob.isHidden = true
    }
}

@MainActor
final class GameScene: SKScene {
    let controller: GameController

    private let worldNode = SKNode()
    private let roomNode = SKNode()
    private let hud = SKNode()
    private let moveStick = Stick()
    private let aimStick = Stick()

    private var lastTime: TimeInterval = 0
    private var tileSize: CGFloat = 40
    private var shake = 0.0

    private var roomKey = ""
    private var playerNodes: [SKSpriteNode] = []
    private var reviveBars: [SKSpriteNode] = []
    private var enemyNodes: [UInt16: SKSpriteNode] = [:]
    private var enemyKinds: [UInt16: EnemyKind] = [:]
    private var bulletNodes: [SKSpriteNode] = []
    private var pickupNodes: [UInt16: SKNode] = [:]

    private let heartsLocal = SKNode()
    private let heartsOther = SKNode()
    private let minimap = SKNode()
    private let floorLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
    private let toastLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
    private let bannerLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
    private let waitingLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
    private let hintLeft = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
    private let hintRight = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
    private let bossBarBack = SKSpriteNode(color: UIColor(white: 0, alpha: 0.6), size: CGSize(width: 240, height: 10))
    private let bossBarFill = SKSpriteNode(color: UIColor(hex: 0xE0405A), size: CGSize(width: 236, height: 6))
    private let damageFlash = SKSpriteNode(color: UIColor(hex: 0xFF2040), size: CGSize(width: 10, height: 10))

    private var heartsKey = ""
    private var mapKey = ""
    private var prevHp = -1
    private var prevStats: [Double] = []
    private var prevCleared = true
    private var prevFloor = 0
    private var prevRoom = -1
    private var prevPhaseOver = false
    private var hintsShown = true

    init(controller: GameController) {
        self.controller = controller
        super.init(size: CGSize(width: 844, height: 390))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = Palette.bg

        addChild(worldNode)
        worldNode.addChild(roomNode)
        addChild(hud)
        hud.zPosition = 200

        for l in [floorLabel, toastLabel, bannerLabel, waitingLabel, hintLeft, hintRight] {
            l.fontColor = .white
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            hud.addChild(l)
        }
        floorLabel.fontSize = 15
        floorLabel.horizontalAlignmentMode = .right
        toastLabel.fontSize = 22
        toastLabel.alpha = 0
        bannerLabel.fontSize = 15
        bannerLabel.fontColor = UIColor(hex: 0xFFD0D8)
        waitingLabel.fontSize = 18
        waitingLabel.text = "방장이 게임을 여는 중…"
        hintLeft.fontSize = 14
        hintRight.fontSize = 14
        hintLeft.fontColor = UIColor(white: 1, alpha: 0.45)
        hintRight.fontColor = UIColor(white: 1, alpha: 0.45)
        hintLeft.text = "왼손 엄지: 이동"
        hintRight.text = "오른손 엄지: 조준·발사"

        hud.addChild(heartsLocal)
        hud.addChild(heartsOther)
        hud.addChild(minimap)
        hud.addChild(bossBarBack)
        bossBarBack.addChild(bossBarFill)
        bossBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        bossBarFill.position = CGPoint(x: -118, y: 0)
        bossBarBack.isHidden = true

        damageFlash.anchorPoint = .zero
        damageFlash.alpha = 0
        damageFlash.zPosition = 150
        hud.addChild(damageFlash)

        for s in [moveStick, aimStick] {
            addChild(s.base)
            addChild(s.knob)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    // MARK: 배치

    private func layout() {
        guard size.width > 0, size.height > 0 else { return }
        tileSize = floor(min(size.width / CGFloat(RW), size.height / CGFloat(RH)))
        let roomW = tileSize * CGFloat(RW)
        let roomH = tileSize * CGFloat(RH)
        worldNode.setScale(tileSize)
        worldNode.position = CGPoint(x: (size.width - roomW) / 2, y: (size.height - roomH) / 2)

        let side: CGFloat = 56
        heartsLocal.position = CGPoint(x: side + 8, y: size.height - 22)
        heartsOther.position = CGPoint(x: side + 8, y: size.height - 44)
        floorLabel.position = CGPoint(x: size.width - side - 10, y: 22)
        toastLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        bannerLabel.position = CGPoint(x: size.width / 2, y: 26)
        waitingLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        hintLeft.position = CGPoint(x: size.width * 0.22, y: size.height * 0.25)
        hintRight.position = CGPoint(x: size.width * 0.78, y: size.height * 0.25)
        bossBarBack.position = CGPoint(x: size.width / 2, y: size.height - 18)
        damageFlash.size = size
        mapKey = ""
    }

    private func worldPoint(_ v: V2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    // MARK: 조작

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            if p.x < size.width / 2 {
                if !moveStick.active { moveStick.begin(t, at: p) }
            } else if !aimStick.active {
                aimStick.begin(t, at: p)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if t === moveStick.touch {
                moveStick.move(to: t.location(in: self))
            } else if t === aimStick.touch {
                aimStick.move(to: t.location(in: self))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if t === moveStick.touch { moveStick.end() }
            if t === aimStick.touch { aimStick.end() }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: 매 프레임

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(0.05, max(0, currentTime - lastTime))
        lastTime = currentTime

        let mv = V2(Double(moveStick.value.dx), Double(moveStick.value.dy))
        let av = V2(Double(aimStick.value.dx), Double(aimStick.value.dy))
        controller.update(dt: dt, move: mv, aim: av, firing: aimStick.active && av.length > 0.3)

        guard let world = controller.world else {
            waitingLabel.isHidden = false
            return
        }
        waitingLabel.isHidden = true
        if hintsShown && (moveStick.active || aimStick.active) {
            hintsShown = false
            hintLeft.run(.fadeOut(withDuration: 0.6))
            hintRight.run(.fadeOut(withDuration: 0.6))
        }

        renderRoom(world)
        renderPlayers(world, dt)
        renderEnemies(world, dt)
        renderBullets(world)
        renderPickups(world)
        renderHUD(world, dt)

        // 맞았을 때 화면 흔들림
        let base = CGPoint(x: (size.width - tileSize * CGFloat(RW)) / 2, y: (size.height - tileSize * CGFloat(RH)) / 2)
        if shake > 0 {
            shake = max(0, shake - dt)
            let a = CGFloat(shake) * 24
            worldNode.position = CGPoint(x: base.x + CGFloat.random(in: -a...a), y: base.y + CGFloat.random(in: -a...a))
        } else {
            worldNode.position = base
        }
    }

    // MARK: 방

    private func renderRoom(_ world: World) {
        let isCleared = world.cleared.contains(world.roomIndex)
        let key = "\(world.floorNum)-\(world.roomIndex)-\(isCleared)"
        guard key != roomKey else { return }
        roomKey = key
        roomNode.removeAllChildren()
        for ty in 0..<RH {
            for tx in 0..<RW {
                let kind = world.tile(tx, ty)
                let center = CGPoint(x: Double(tx) + 0.5, y: Double(ty) + 0.5)
                let floorTex = Sprites.floors[(tx * 7 + ty * 13 + world.roomIndex) % Sprites.floors.count]
                switch kind {
                case .wall:
                    addTile(Sprites.wall, at: center, z: 1)
                case .floor, .doorOpen:
                    addTile(floorTex, at: center, z: 0)
                case .rock:
                    addTile(floorTex, at: center, z: 0)
                    addTile(Sprites.rock, at: center, z: 2)
                case .doorClosed:
                    addTile(Sprites.gate, at: center, z: 1)
                }
            }
        }
        // 벽 아래 그림자
        let shadow = SKSpriteNode(color: UIColor(white: 0, alpha: 0.25), size: CGSize(width: Double(RW - 2), height: 0.25))
        shadow.position = CGPoint(x: Double(RW) / 2, y: Double(RH - 1) - 0.125)
        shadow.zPosition = 1.5
        roomNode.addChild(shadow)
    }

    private func addTile(_ tex: SKTexture, at p: CGPoint, z: CGFloat) {
        let s = SKSpriteNode(texture: tex, size: CGSize(width: 1.001, height: 1.001))
        s.position = p
        s.zPosition = z
        roomNode.addChild(s)
    }

    // MARK: 캐릭터

    private func renderPlayers(_ world: World, _ dt: Double) {
        while playerNodes.count < world.players.count {
            let i = playerNodes.count
            let n = SKSpriteNode(texture: Sprites.players[min(i, 1)], size: CGSize(width: 1, height: 1))
            n.zPosition = 40
            worldNode.addChild(n)
            playerNodes.append(n)

            let bar = SKSpriteNode(color: Palette.player(i), size: CGSize(width: 0.9, height: 0.1))
            bar.anchorPoint = CGPoint(x: 0, y: 0.5)
            bar.zPosition = 60
            bar.isHidden = true
            worldNode.addChild(bar)
            reviveBars.append(bar)
        }
        let t = world.time
        for (i, p) in world.players.enumerated() {
            let n = playerNodes[i]
            let target = worldPoint(p.pos)
            if i == world.localIndex || hypot(n.position.x - target.x, n.position.y - target.y) > 1.5 {
                n.position = target
            } else {
                let k = CGFloat(min(1, dt * 16))
                n.position = CGPoint(x: n.position.x + (target.x - n.position.x) * k,
                                     y: n.position.y + (target.y - n.position.y) * k)
            }
            if p.aim.x < -0.1 { n.xScale = -1 } else if p.aim.x > 0.1 { n.xScale = 1 }
            if p.downed {
                n.zRotation = .pi / 2
                n.alpha = 0.55
            } else {
                n.zRotation = 0
                n.alpha = p.invuln > 0 ? (Int(t * 20) % 2 == 0 ? 0.35 : 1) : 1
                if p.moving {
                    n.position.y += CGFloat(abs(sin(t * 14)) * 0.07)
                }
            }
            let bar = reviveBars[i]
            bar.isHidden = !(p.downed && p.revive > 0.01)
            bar.position = CGPoint(x: n.position.x - 0.45, y: n.position.y + 0.75)
            bar.xScale = CGFloat(min(1, p.revive / 2.0))
        }
    }

    private func renderEnemies(_ world: World, _ dt: Double) {
        var seen = Set<UInt16>()
        let t = world.time
        for e in world.enemies {
            seen.insert(e.id)
            let node: SKSpriteNode
            if let existing = enemyNodes[e.id] {
                node = existing
            } else {
                node = SKSpriteNode(texture: Sprites.enemy(e.kind, time: t), size: Sprites.enemySize(e.kind))
                node.zPosition = e.kind == .boss ? 35 : 30
                node.position = worldPoint(e.pos)
                node.colorBlendFactor = 0
                node.color = .white
                worldNode.addChild(node)
                enemyNodes[e.id] = node
                enemyKinds[e.id] = e.kind
            }
            let target = worldPoint(e.pos)
            if world.isHost {
                node.position = target
            } else {
                let k = CGFloat(min(1, dt * 14))
                node.position = CGPoint(x: node.position.x + (target.x - node.position.x) * k,
                                        y: node.position.y + (target.y - node.position.y) * k)
            }
            if e.kind == .bat { node.texture = Sprites.enemy(.bat, time: t + Double(e.id)) }
            if e.kind == .slime {
                node.yScale = CGFloat(1 + 0.12 * sin(t * 10 + Double(e.id)))
            }
            node.colorBlendFactor = e.flash > 0 ? 0.9 : 0
            if e.spawnT > 0 {
                node.alpha = Int(t * 16) % 2 == 0 ? 0.25 : 0.6
            } else {
                node.alpha = 1
            }
            // 돌진 준비 중이면 덜덜 떤다
            if e.kind == .charger && e.state == 1 {
                node.position.x += CGFloat.random(in: -0.05...0.05)
            }
        }
        for (id, node) in enemyNodes where !seen.contains(id) {
            burst(at: node.position, color: Sprites.enemyColor(enemyKinds[id] ?? .slime),
                  count: enemyKinds[id] == .boss ? 30 : 9)
            node.removeFromParent()
            enemyNodes[id] = nil
            enemyKinds[id] = nil
        }
    }

    private func burst(at p: CGPoint, color: UIColor, count: Int) {
        for _ in 0..<count {
            let s = SKSpriteNode(texture: Sprites.pixel, size: CGSize(width: 0.14, height: 0.14))
            s.color = color
            s.colorBlendFactor = 1
            s.position = p
            s.zPosition = 70
            worldNode.addChild(s)
            let a = Double.random(in: 0..<(2 * Double.pi))
            let d = Double.random(in: 0.4...1.2)
            let move = SKAction.moveBy(x: CGFloat(cos(a) * d), y: CGFloat(sin(a) * d), duration: 0.35)
            move.timingMode = .easeOut
            s.run(.sequence([.group([move, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private func renderBullets(_ world: World) {
        let list = world.bullets
        while bulletNodes.count < list.count {
            let n = SKSpriteNode(texture: Sprites.bulletFriendly, size: CGSize(width: 0.32, height: 0.32))
            n.zPosition = 50
            worldNode.addChild(n)
            bulletNodes.append(n)
        }
        for (i, n) in bulletNodes.enumerated() {
            if i < list.count {
                let b = list[i]
                n.isHidden = false
                n.position = worldPoint(b.pos)
                n.texture = b.friendly ? Sprites.bulletFriendly : Sprites.bulletEnemy
                n.size = b.friendly ? CGSize(width: 0.3, height: 0.3) : CGSize(width: 0.36, height: 0.36)
            } else {
                n.isHidden = true
            }
        }
    }

    private func renderPickups(_ world: World) {
        var seen = Set<UInt16>()
        let t = world.time
        for p in world.pickups {
            seen.insert(p.id)
            let node: SKNode
            if let existing = pickupNodes[p.id] {
                node = existing
            } else {
                node = makePickupNode(p.kind)
                node.position = worldPoint(p.pos)
                node.zPosition = 20
                worldNode.addChild(node)
                pickupNodes[p.id] = node
            }
            node.position = worldPoint(p.pos)
            if p.kind != .stairs, let icon = node.childNode(withName: "icon") {
                icon.position.y = 0.15 + CGFloat(sin(t * 3 + Double(p.id)) * 0.06)
            }
        }
        for (id, node) in pickupNodes where !seen.contains(id) {
            node.run(.sequence([.group([.scale(to: 1.6, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
            pickupNodes[id] = nil
        }
    }

    private func makePickupNode(_ kind: PickupKind) -> SKNode {
        let root = SKNode()
        switch kind {
        case .stairs:
            root.addChild(SKSpriteNode(texture: Sprites.stairs, size: CGSize(width: 1, height: 1)))
        case .heart:
            let icon = SKSpriteNode(texture: Sprites.heart, size: CGSize(width: 0.55, height: 0.47))
            icon.name = "icon"
            root.addChild(icon)
        default:
            let ped = SKSpriteNode(texture: Sprites.pedestal, size: CGSize(width: 1, height: 0.5))
            ped.position = CGPoint(x: 0, y: -0.3)
            root.addChild(ped)
            let icon = SKSpriteNode(texture: Sprites.pickupEmoji[kind], size: CGSize(width: 0.7, height: 0.7))
            icon.name = "icon"
            icon.zPosition = 1
            root.addChild(icon)
        }
        return root
    }

    // MARK: 화면 위 정보

    private func renderHUD(_ world: World, _ dt: Double) {
        let me = world.players[world.localIndex]

        let hk = world.players.map { "\($0.hp)/\($0.maxHp)/\($0.downed)" }.joined(separator: ",")
        if hk != heartsKey {
            heartsKey = hk
            drawHearts(heartsLocal, player: me, index: world.localIndex, label: world.playerCount > 1 ? "나" : nil)
            if world.playerCount > 1 {
                let oi = world.localIndex == 0 ? 1 : 0
                drawHearts(heartsOther, player: world.players[oi], index: oi, label: "친구")
            }
        }

        // 맞으면 화면이 붉게 번쩍
        if prevHp >= 0 && me.hp < prevHp {
            shake = 0.22
            damageFlash.removeAllActions()
            damageFlash.alpha = 0.32
            damageFlash.run(.fadeOut(withDuration: 0.35))
        }
        prevHp = me.hp

        // 능력치가 오르면 알림
        let stats: [Double] = [me.damage, me.fireRate, me.speed, Double(me.shots), me.pierce ? 1 : 0, Double(me.maxHp)]
        if prevStats.count == stats.count {
            let kinds: [PickupKind] = [.dmg, .rate, .speed, .multi, .pierce, .maxhp]
            for k in stats.indices where stats[k] > prevStats[k] + 0.001 {
                toast("\(kinds[k].emoji) \(kinds[k].title)")
                break
            }
        }
        prevStats = stats

        let isCleared = world.cleared.contains(world.roomIndex)
        if world.floorNum != prevFloor {
            if prevFloor != 0 { toast("🪜 \(world.floorNum)층") }
            prevFloor = world.floorNum
            prevRoom = world.roomIndex
            prevCleared = isCleared
        } else if world.roomIndex != prevRoom {
            prevRoom = world.roomIndex
            prevCleared = isCleared
            if world.room.kind == .boss && !isCleared { toast("👑 보스 등장!") }
            if world.room.kind == .treasure { toast("🎁 보물 방! 하나씩 골라 가져가세요") }
        } else if isCleared && !prevCleared {
            prevCleared = true
            toast(world.room.kind == .boss ? "👑 보스 처치! 계단으로 내려가세요" : "방 클리어!")
        }

        floorLabel.text = "\(world.floorNum)층"

        // 보스 체력
        if let boss = world.enemies.first(where: { $0.kind == .boss }) {
            bossBarBack.isHidden = false
            bossBarFill.xScale = CGFloat(max(0, min(1, boss.hp / max(boss.maxHp, 0.001))))
        } else {
            bossBarBack.isHidden = true
        }

        // 쓰러짐 안내
        if world.gameOver {
            bannerLabel.text = ""
        } else if me.downed && world.playerCount > 1 {
            bannerLabel.text = "쓰러졌어요… 친구가 옆에 2초 서 있으면 다시 일어나요"
        } else if world.playerCount > 1 && world.players.contains(where: { $0.downed }) {
            bannerLabel.text = "친구가 쓰러졌어요! 옆에 붙어 서서 살려 주세요"
        } else {
            bannerLabel.text = ""
        }

        drawMinimap(world)
    }

    private func drawHearts(_ node: SKNode, player: Player, index: Int, label: String?) {
        node.removeAllChildren()
        var x: CGFloat = 0
        if let label {
            let l = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            l.text = label
            l.fontSize = 12
            l.fontColor = Palette.player(index)
            l.horizontalAlignmentMode = .left
            l.verticalAlignmentMode = .center
            node.addChild(l)
            x = 32
        }
        let small = label == "친구"
        let w: CGFloat = small ? 14 : 18
        for k in 0..<player.maxHp {
            let tex = k < player.hp ? Sprites.heart : Sprites.heartEmpty
            let h = SKSpriteNode(texture: tex, size: CGSize(width: w, height: w * 6 / 7))
            h.position = CGPoint(x: x + CGFloat(k) * (w + 3) + w / 2, y: 0)
            node.addChild(h)
        }
    }

    private func drawMinimap(_ world: World) {
        let key = "\(world.floorNum)-\(world.roomIndex)-\(world.visited.sorted())-\(world.cleared.count)-\(size.width)"
        guard key != mapKey else { return }
        mapKey = key
        minimap.removeAllChildren()
        let cell: CGFloat = 9
        let gap: CGFloat = 2
        var known = world.visited
        for v in world.visited {
            for nb in world.map.rooms[v].neighbors { if let nb { known.insert(nb) } }
        }
        let rooms = world.map.rooms
        let xs = known.map { rooms[$0].gx }
        let ys = known.map { rooms[$0].gy }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return }
        let w = CGFloat(maxX - minX + 1) * (cell + gap)
        let h = CGFloat(maxY - minY + 1) * (cell + gap)
        minimap.position = CGPoint(x: size.width - 56 - w - 8, y: size.height - 12 - h)
        for i in known {
            let r = rooms[i]
            let node = SKSpriteNode(color: .white, size: CGSize(width: cell, height: cell))
            node.anchorPoint = .zero
            node.position = CGPoint(x: CGFloat(r.gx - minX) * (cell + gap), y: CGFloat(r.gy - minY) * (cell + gap))
            if i == world.roomIndex {
                node.color = .white
            } else if world.visited.contains(i) {
                node.color = UIColor(white: 0.6, alpha: 0.9)
            } else {
                node.color = UIColor(white: 0.3, alpha: 0.8)
            }
            if r.kind == .boss {
                node.color = i == world.roomIndex ? UIColor(hex: 0xFF8090) : UIColor(hex: 0xC03050)
            } else if r.kind == .treasure && i != world.roomIndex {
                node.color = UIColor(hex: 0xC8A030)
            }
            minimap.addChild(node)
        }
    }

    private func toast(_ text: String) {
        toastLabel.removeAllActions()
        toastLabel.text = text
        toastLabel.alpha = 0
        toastLabel.setScale(0.8)
        toastLabel.run(.sequence([
            .group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.15)]),
            .wait(forDuration: 1.4),
            .fadeOut(withDuration: 0.4),
        ]))
    }
}
