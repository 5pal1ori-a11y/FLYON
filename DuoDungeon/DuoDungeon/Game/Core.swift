import Foundation

// MARK: - 2D 벡터

struct V2: Equatable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static let zero = V2(0, 0)

    static func + (a: V2, b: V2) -> V2 { V2(a.x + b.x, a.y + b.y) }
    static func - (a: V2, b: V2) -> V2 { V2(a.x - b.x, a.y - b.y) }
    static func * (a: V2, s: Double) -> V2 { V2(a.x * s, a.y * s) }
    static func += (a: inout V2, b: V2) { a = a + b }

    var lengthSq: Double { x * x + y * y }
    var length: Double { lengthSq.squareRoot() }
    var normalized: V2 {
        let l = length
        return l > 1e-9 ? V2(x / l, y / l) : .zero
    }
    func rotated(_ a: Double) -> V2 {
        let c = cos(a), s = sin(a)
        return V2(x * c - y * s, x * s + y * c)
    }
}

// MARK: - 같은 시드면 두 기기에서 똑같은 결과가 나오는 난수

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ..< n
    mutating func int(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }

    /// 0.0 ..< 1.0
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}

// MARK: - 방과 층

/// 방 하나의 크기(타일). 바깥 한 줄은 벽이다.
let RW = 15
let RH = 9

enum Dir: Int, CaseIterable {
    case up = 0, right, down, left

    var dx: Int {
        switch self {
        case .right: return 1
        case .left: return -1
        default: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return 1
        case .down: return -1
        default: return 0
        }
    }

    var opposite: Dir { Dir(rawValue: (rawValue + 2) % 4) ?? .up }

    /// 이 방향의 문으로 새 방에 들어왔을 때 서는 자리
    var entryPoint: V2 {
        switch self {
        case .up: return V2(7.5, Double(RH) - 1.6)
        case .down: return V2(7.5, 1.6)
        case .left: return V2(1.6, 4.5)
        case .right: return V2(Double(RW) - 1.6, 4.5)
        }
    }

    /// 두 사람이 겹치지 않게 문과 나란한 방향으로 벌려 세운다
    var spread: V2 {
        switch self {
        case .up, .down: return V2(1, 0)
        case .left, .right: return V2(0, 1)
        }
    }

    /// 벽 타일 좌표가 이 방향 문(폭 3칸)에 해당하는지
    static func door(atX tx: Int, y ty: Int) -> Dir? {
        if ty == RH - 1 && (6...8).contains(tx) { return .up }
        if ty == 0 && (6...8).contains(tx) { return .down }
        if tx == 0 && (3...5).contains(ty) { return .left }
        if tx == RW - 1 && (3...5).contains(ty) { return .right }
        return nil
    }
}

enum TileKind {
    case floor, wall, rock, doorClosed, doorOpen
}

enum RoomKind: UInt8 {
    case start, normal, treasure, boss
}

/// 방 안 장애물 배치. 문 앞 칸은 비워 둔다.
enum Layouts {
    static let all: [[(Int, Int)]] = [
        [],
        [(3, 2), (11, 2), (3, 6), (11, 6)],
        [(5, 3), (5, 5), (9, 3), (9, 5), (7, 4)],
        [(3, 2), (4, 2), (5, 2), (9, 2), (10, 2), (11, 2), (3, 6), (4, 6), (5, 6), (9, 6), (10, 6), (11, 6)],
        [(4, 2), (4, 3), (4, 5), (4, 6), (10, 2), (10, 3), (10, 5), (10, 6)],
        [(2, 2), (4, 6), (6, 3), (8, 5), (10, 2), (12, 6)],
        [(6, 3), (7, 3), (8, 3), (6, 5), (7, 5), (8, 5)],
    ]
}

struct RoomInfo {
    let gx: Int
    let gy: Int
    var kind: RoomKind = .normal
    var layout = 0
    /// Dir.rawValue 순서의 이웃 방 번호
    var neighbors: [Int?] = [nil, nil, nil, nil]
}

/// 한 층의 방 배치. 시드와 층 번호만 같으면 두 기기에서 똑같이 만들어진다.
struct FloorMap {
    static let grid = 7

    private(set) var rooms: [RoomInfo] = []
    private(set) var boss = 0
    private(set) var treasure: Int?

    init(seed: UInt64, floor: Int) {
        var rng = SplitMix64(seed: seed ^ (UInt64(floor) &* 0x9E37_79B9_7F4A_7C15))
        let g = FloorMap.grid
        let target = min(6 + floor, 12)
        var cells: [(Int, Int)] = [(3, 3)]
        var lookup: [Int: Int] = [3 * 8 + 3: 0]

        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < g && y < g }

        var tries = 0
        while cells.count < target && tries < 4000 {
            tries += 1
            let base = cells[rng.int(cells.count)]
            let d = Dir.allCases[rng.int(4)]
            let nx = base.0 + d.dx
            let ny = base.1 + d.dy
            guard inside(nx, ny), lookup[nx * 8 + ny] == nil else { continue }
            var around = 0
            for dd in Dir.allCases where inside(nx + dd.dx, ny + dd.dy) && lookup[(nx + dd.dx) * 8 + ny + dd.dy] != nil {
                around += 1
            }
            // 방이 뭉치지 않고 가지처럼 뻗도록
            if around > 1 && rng.int(4) != 0 { continue }
            lookup[nx * 8 + ny] = cells.count
            cells.append((nx, ny))
        }

        rooms = cells.map { RoomInfo(gx: $0.0, gy: $0.1) }
        for i in rooms.indices {
            for d in Dir.allCases {
                let ax = rooms[i].gx + d.dx
                let ay = rooms[i].gy + d.dy
                if inside(ax, ay), let j = lookup[ax * 8 + ay] {
                    rooms[i].neighbors[d.rawValue] = j
                }
            }
        }

        // 시작 방에서 가장 먼 막다른 방이 보스 방
        var dist = [Int](repeating: -1, count: rooms.count)
        dist[0] = 0
        var queue = [0]
        var qi = 0
        while qi < queue.count {
            let c = queue[qi]
            qi += 1
            for nb in rooms[c].neighbors {
                if let nb, dist[nb] < 0 {
                    dist[nb] = dist[c] + 1
                    queue.append(nb)
                }
            }
        }
        let deadEnds = rooms.indices.filter { i in
            i != 0 && rooms[i].neighbors.compactMap { $0 }.count == 1
        }
        let bossPool = deadEnds.isEmpty ? Array(rooms.indices.dropFirst()) : deadEnds
        boss = bossPool.max { dist[$0] < dist[$1] } ?? max(0, rooms.count - 1)

        let treasurePool = deadEnds.filter { $0 != boss }
        let fallback = rooms.indices.filter { $0 != 0 && $0 != boss }
        let pool = treasurePool.isEmpty ? fallback : treasurePool
        if !pool.isEmpty { treasure = pool[rng.int(pool.count)] }

        for i in rooms.indices {
            if i == 0 {
                rooms[i].kind = .start
            } else if i == boss {
                rooms[i].kind = .boss
            } else if i == treasure {
                rooms[i].kind = .treasure
            } else {
                rooms[i].kind = .normal
                rooms[i].layout = rng.int(Layouts.all.count)
            }
        }
    }
}

// MARK: - 기록

enum Records {
    private static let key = "duo.bestFloor"

    static var bestFloor: Int { UserDefaults.standard.integer(forKey: key) }

    static func submit(floor: Int) {
        if floor > bestFloor { UserDefaults.standard.set(floor, forKey: key) }
    }
}
