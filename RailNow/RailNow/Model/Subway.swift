import Foundation

/// 지하철 노선. `segments[0]`이 본선이고 나머지는 지선이다. (Resources/subway.json)
struct SubwayLine: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let short: String
    let color: String
    /// 서울시 실시간 위치 API가 받는 노선 이름. nil이면 실시간을 제공하지 않는 노선.
    let live: String?
    let loop: Bool
    let segments: [[String]]
    /// 역 이름 → [위도, 경도]. 노선도 지도에 쓴다.
    let coords: [String: [Double]]

    func segmentTitle(_ index: Int) -> String {
        let s = segments[index]
        if loop && index == 0 { return "순환" }
        return "\(s.first ?? "") – \(s.last ?? "")"
    }
}

struct SubwayData: Decodable {
    let attribution: String
    let generatedAt: String
    let lines: [SubwayLine]
}

final class SubwayCatalog {
    static let shared = SubwayCatalog()

    let lines: [SubwayLine]
    let attribution: String
    private let byID: [String: SubwayLine]

    private init() {
        var loaded: SubwayData?
        if let url = Bundle.main.url(forResource: "subway", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            loaded = try? JSONDecoder().decode(SubwayData.self, from: data)
        }
        lines = loaded?.lines ?? []
        attribution = loaded?.attribution ?? ""
        var map: [String: SubwayLine] = [:]
        for line in lines { map[line.id] = line }
        byID = map
    }

    func line(_ id: String) -> SubwayLine? {
        byID[id] ?? lines.first
    }
}

struct SubwayTrain: Identifiable, Hashable {
    enum Status: Int {
        case approaching = 0   // 진입
        case arrived = 1       // 도착
        case departed = 2      // 출발
        case leftPrevious = 3  // 전역 출발
    }

    let id: String
    let number: String
    let station: String
    let destination: String
    /// 상행·내선이면 true (API의 updnLine == 0)
    let upbound: Bool
    let status: Status
    let express: Bool
    let lastCar: Bool
    let receivedAt: Date?
    /// 실제 수신 위치가 아니라 운행 간격으로 만든 미리보기 열차
    let estimated: Bool
    /// 미리보기 열차는 구간과 방향을 미리 안다.
    var segment: Int? = nil
    var towardStart: Bool? = nil

    var statusText: String {
        switch status {
        case .approaching: return "\(station) 진입 중"
        case .arrived: return "\(station) 도착"
        case .departed: return "\(station) 출발"
        case .leftPrevious: return "\(station) 방면 이동 중"
        }
    }
}

/// 노선도 위에 놓인 열차. `row`는 역 순서(0부터)에 구간 내 위치를 더한 값이다.
struct PlacedTrain: Identifiable {
    let train: SubwayTrain
    let segment: Int
    let towardStart: Bool
    let row: Double

    var id: String { train.id }
}

extension SubwayLine {
    /// API가 주는 역 이름과 자료의 역 이름을 맞추기 위한 정리. 괄호 부기와 '역', '종착', '지선'을 뗀다.
    static func normalize(_ raw: String) -> String {
        var s = raw
        if let open = s.firstIndex(of: "(") { s = String(s[..<open]) }
        s = s.trimmingCharacters(in: .whitespaces)
        for suffix in ["종착", "지선", "급행"] where s.hasSuffix(suffix) && s.count > suffix.count + 1 {
            s = String(s.dropLast(suffix.count))
        }
        if s.hasSuffix("역") && s.count > 2 { s = String(s.dropLast()) }
        return s
    }

    func place(_ train: SubwayTrain) -> PlacedTrain? {
        let name = SubwayLine.normalize(train.station)
        let dest = SubwayLine.normalize(train.destination)

        var found: (segment: Int, index: Int)?
        if let hint = train.segment, hint < segments.count,
           let i = segments[hint].firstIndex(of: name) {
            found = (hint, i)
        } else {
            // 본선과 지선이 만나는 역은 행선지가 있는 쪽 구간에 놓는다.
            for (si, stations) in segments.enumerated() {
                guard let i = stations.firstIndex(of: name) else { continue }
                if found == nil { found = (si, i) }
                if stations.contains(dest) {
                    found = (si, i)
                    break
                }
            }
        }
        guard let spot = found else { return nil }
        let stations = segments[spot.segment]

        let toward: Bool
        if let known = train.towardStart {
            toward = known
        } else if loop && spot.segment == 0 {
            // 2호선 본선은 내선순환(상행 취급)이 역 목록의 아래쪽으로 간다.
            toward = !train.upbound
        } else if let di = stations.firstIndex(of: dest) {
            toward = di == spot.index ? spot.index == 0 : di < spot.index
        } else {
            toward = train.upbound
        }

        // 진행 방향 기준으로 역에 못 미친 만큼(양수) 또는 지난 만큼(음수)
        let before: Double
        switch train.status {
        case .approaching: before = 0.3
        case .arrived: before = 0
        case .departed: before = -0.3
        case .leftPrevious: before = 0.6
        }
        var row = Double(spot.index) + (toward ? before : -before)
        row = min(max(row, -0.3), Double(stations.count - 1) + 0.3)
        return PlacedTrain(train: train, segment: spot.segment, towardStart: toward, row: row)
    }
}

/// 인증키가 없을 때 화면을 채우는 미리보기 열차. 운행 간격만으로 만든 것이라 실제 위치가 아니다.
enum SubwayEstimator {
    static func trains(line: SubwayLine, at date: Date) -> [SubwayTrain] {
        var t = KST.secondsOfDay(date)
        if t < 5400 { t += 86400 }   // 새벽 1시 반까지는 전날 운행으로 본다
        let start = 5.5 * 3600
        let lastDeparture = 23.75 * 3600
        guard t >= start else { return [] }

        let hop: Double = line.id == "gtx-a" ? 300 : 130
        let hour = t / 3600
        let peak = (hour >= 7 && hour < 9.5) || (hour >= 17.5 && hour < 20)
        var out: [SubwayTrain] = []

        for (si, stations) in line.segments.enumerated() where stations.count >= 2 {
            let n = stations.count
            let headway: Double = (peak ? 300 : 480) * (si == 0 ? 1 : 2)

            if line.loop && si == 0 {
                guard t <= lastDeparture + 3600 else { continue }
                let count = max(1, Int(Double(n) * hop / headway))
                let gap = Double(n) / Double(count)
                for k in 0..<count {
                    for down in [true, false] {
                        let shift = Double(k) * gap + (down ? 0 : gap / 2)
                        let q = ((t - start) / hop + shift).truncatingRemainder(dividingBy: Double(n))
                        let step = stepState(q)
                        let j = step.index % n
                        let index = down ? j : (n - j) % n
                        out.append(SubwayTrain(
                            id: "\(line.id)-\(si)-\(down ? "d" : "u")-\(k)",
                            number: "", station: stations[index],
                            destination: down ? "내선순환" : "외선순환",
                            upbound: down, status: step.status, express: false, lastCar: false,
                            receivedAt: nil, estimated: true, segment: si, towardStart: !down
                        ))
                    }
                }
                continue
            }

            let duration = Double(n - 1) * hop
            let kMin = max(0, Int(((t - duration - start) / headway).rounded(.up)))
            let kMax = Int(((min(t, lastDeparture) - start) / headway).rounded(.down))
            guard kMin <= kMax else { continue }
            for k in kMin...kMax {
                for down in [true, false] {
                    let departure = start + Double(k) * headway + (down ? 0 : headway / 2)
                    let q = (t - departure) / hop
                    guard q >= 0, q <= Double(n - 1) else { continue }
                    let step = stepState(q)
                    let j = min(step.index, n - 1)
                    let index = down ? j : n - 1 - j
                    out.append(SubwayTrain(
                        id: "\(line.id)-\(si)-\(down ? "d" : "u")-\(k)",
                        number: "", station: stations[index],
                        destination: down ? stations[n - 1] : stations[0],
                        upbound: !down, status: step.status, express: false, lastCar: false,
                        receivedAt: nil, estimated: true, segment: si, towardStart: !down
                    ))
                }
            }
        }
        return out
    }

    /// 진행 방향으로 q정거장만큼 간 열차가 어느 역에 어떤 상태로 있는지.
    private static func stepState(_ q: Double) -> (index: Int, status: SubwayTrain.Status) {
        let i = Int(q.rounded(.down))
        let f = q - Double(i)
        if f < 0.25 { return (i, .arrived) }
        if f < 0.55 { return (i, .departed) }
        return (i + 1, .approaching)
    }
}
