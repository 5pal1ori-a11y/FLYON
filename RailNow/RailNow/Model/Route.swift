import Foundation

/// 한 노선을 타고 가는 구간.
struct RouteLeg: Identifiable {
    let id: Int
    let line: SubwayLine
    let stations: [String]
    let minutes: Int

    var from: String { stations.first ?? "" }
    var to: String { stations.last ?? "" }
    var heading: String { stations.count > 1 ? "\(stations[1]) 방향" : "" }
    var hops: Int { max(stations.count - 1, 0) }
}

struct RoutePlan {
    let legs: [RouteLeg]
    let totalMinutes: Int

    var transfers: Int { max(legs.count - 1, 0) }
    var hops: Int { legs.reduce(0) { $0 + $1.hops } }
}

/// 역 순서 자료만으로 가장 빠른 길을 찾는다.
/// 역 사이 시간은 노선별 평균값이고 환승은 한 번에 4분으로 잡은 추정이라 실제 시간표와 다르다.
final class RouteFinder {
    static let shared = RouteFinder()
    static let transferMinutes = 4.0

    private struct Node: Hashable {
        let line: String
        let station: String
    }

    private var edges: [Node: [(node: Node, cost: Double)]] = [:]
    private let linesByID: [String: SubwayLine]
    /// 역 이름 → 지나는 노선
    let stationLines: [String: [SubwayLine]]
    let stationNames: [String]

    /// 이름은 같지만 서로 다른 역이라 갈아탈 수 없는 조합
    private static let notConnected: Set<String> = ["신촌|2|gyeongui", "양평|5|gyeongui"]
    /// 이름은 다르지만 갈아탈 수 있는 역
    private static let aliases: [(String, String, String, String)] = [("4", "총신대입구", "7", "이수")]

    static func hopMinutes(_ lineID: String) -> Double {
        switch lineID {
        case "gtx-a": return 5
        case "arex": return 4
        case "gyeongui", "gyeongchun", "gyeonggang", "seohae": return 3
        case "1", "shinbundang", "suin": return 2.5
        default: return 2
        }
    }

    private init() {
        let lines = SubwayCatalog.shared.lines
        var byID: [String: SubwayLine] = [:]
        var byStation: [String: [SubwayLine]] = [:]
        var graph: [Node: [(node: Node, cost: Double)]] = [:]

        func link(_ a: Node, _ b: Node, _ cost: Double) {
            graph[a, default: []].append((b, cost))
            graph[b, default: []].append((a, cost))
        }

        for line in lines {
            byID[line.id] = line
            let hop = RouteFinder.hopMinutes(line.id)
            for (si, stations) in line.segments.enumerated() {
                for name in stations where !(byStation[name]?.contains(where: { $0.id == line.id }) ?? false) {
                    byStation[name, default: []].append(line)
                }
                guard stations.count >= 2 else { continue }
                for i in 1..<stations.count {
                    link(Node(line: line.id, station: stations[i - 1]), Node(line: line.id, station: stations[i]), hop)
                }
                if line.loop && si == 0, let first = stations.first, let last = stations.last {
                    link(Node(line: line.id, station: last), Node(line: line.id, station: first), hop)
                }
            }
        }

        for (name, passing) in byStation where passing.count > 1 {
            for i in 0..<passing.count {
                for j in (i + 1)..<passing.count {
                    let a = passing[i].id
                    let b = passing[j].id
                    if RouteFinder.notConnected.contains("\(name)|\(a)|\(b)")
                        || RouteFinder.notConnected.contains("\(name)|\(b)|\(a)") { continue }
                    link(Node(line: a, station: name), Node(line: b, station: name), RouteFinder.transferMinutes)
                }
            }
        }
        for alias in RouteFinder.aliases {
            link(Node(line: alias.0, station: alias.1), Node(line: alias.2, station: alias.3), RouteFinder.transferMinutes)
        }

        edges = graph
        linesByID = byID
        stationLines = byStation
        stationNames = byStation.keys.sorted()
    }

    func search(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return stationNames }
        let starts = stationNames.filter { $0.hasPrefix(q) }
        let contains = stationNames.filter { !$0.hasPrefix(q) && $0.contains(q) }
        return starts + contains
    }

    func plan(from: String, to: String) -> RoutePlan? {
        guard from != to, let startLines = stationLines[from], stationLines[to] != nil else { return nil }

        var dist: [Node: Double] = [:]
        var previous: [Node: Node] = [:]
        var frontier: [Node: Double] = [:]
        var done = Set<Node>()
        for line in startLines {
            let node = Node(line: line.id, station: from)
            dist[node] = 0
            frontier[node] = 0
        }

        var goal: Node?
        while let current = frontier.min(by: { $0.value < $1.value }) {
            let node = current.key
            frontier[node] = nil
            done.insert(node)
            if node.station == to {
                goal = node
                break
            }
            for edge in edges[node] ?? [] where !done.contains(edge.node) {
                let next = current.value + edge.cost
                if next < (dist[edge.node] ?? .infinity) {
                    dist[edge.node] = next
                    previous[edge.node] = node
                    frontier[edge.node] = next
                }
            }
        }
        guard let end = goal else { return nil }

        var path: [Node] = [end]
        while let before = previous[path[0]] { path.insert(before, at: 0) }

        var legs: [RouteLeg] = []
        var run: [Node] = []
        func close() {
            guard run.count >= 2, let line = linesByID[run[0].line] else { return }
            let minutes = Double(run.count - 1) * RouteFinder.hopMinutes(line.id)
            legs.append(RouteLeg(
                id: legs.count, line: line, stations: run.map(\.station),
                minutes: Int(minutes.rounded(.up))
            ))
        }
        for node in path {
            if let last = run.last, last.line != node.line {
                close()
                run = []
            }
            run.append(node)
        }
        close()
        guard !legs.isEmpty else { return nil }

        let total = legs.reduce(0) { $0 + $1.minutes } + (legs.count - 1) * Int(RouteFinder.transferMinutes)
        return RoutePlan(legs: legs, totalMinutes: total)
    }
}
