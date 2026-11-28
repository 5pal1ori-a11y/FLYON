import CoreLocation
import MapKit
import SwiftUI

enum RailKind: String, CaseIterable, Identifiable {
    case ktx = "KTX"
    case srt = "SRT"
    case eum = "KTX-이음"
    case itx = "ITX-새마을"
    case mugunghwa = "무궁화호"

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .ktx: return "#1D4E9E"
        case .srt: return "#6B2C73"
        case .eum: return "#0E7F86"
        case .itx: return "#C23A2B"
        case .mugunghwa: return "#C77A1A"
        }
    }

    var color: Color { Color(hex: hex) }

    /// 시간표 API가 주는 열차 종류 이름이 이 종류에 해당하는지.
    func matches(_ gradeName: String) -> Bool {
        let g = gradeName.uppercased()
        switch self {
        case .ktx: return g.hasPrefix("KTX") && !g.contains("이음")
        case .srt: return g.contains("SRT")
        case .eum: return g.contains("이음")
        case .itx: return g.contains("새마을") || g.contains("마음")
        case .mugunghwa: return g.contains("무궁화")
        }
    }
}

struct RailStop: Hashable {
    let name: String
    let lat: Double
    let lon: Double
    /// 출발역에서 걸리는 대략적인 시간(분). 구간 비율을 나누는 데만 쓴다.
    let minute: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct RailRoute: Identifiable, Hashable {
    let id: String
    let kind: RailKind
    let name: String
    let stops: [RailStop]
    /// 미리보기 열차를 만들 때 쓰는 배차 간격·첫차·막차(자정부터의 분)
    let headway: Int
    let first: Int
    let last: Int
    /// 시간표 API에서 역을 찾을 때 쓰는 이름 후보
    let originNames: [String]
    let destinationNames: [String]

    var totalMinutes: Double { stops.last?.minute ?? 1 }
    var coordinates: [CLLocationCoordinate2D] { stops.map(\.coordinate) }
}

struct RailStopTime: Identifiable {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let time: Date

    var id: String { name }
}

struct RailPosition {
    let coordinate: CLLocationCoordinate2D
    let progress: Double
    let previous: String
    let next: String
    let nextTime: Date
}

struct RailTrain: Identifiable, Hashable {
    let id: String
    let routeID: String
    let reversed: Bool
    let number: String
    let kindName: String
    let depart: Date
    let arrive: Date
    /// 실제 시간표에서 온 열차면 true, 배차 간격으로 만든 미리보기면 false
    let scheduled: Bool

    var route: RailRoute { RailCatalog.route(routeID) }
    var kind: RailKind { route.kind }
    var title: String { number.isEmpty ? kindName : "\(kindName) \(number)" }

    var origin: String { (reversed ? route.stops.last : route.stops.first)?.name ?? "" }
    var destination: String { (reversed ? route.stops.first : route.stops.last)?.name ?? "" }

    var stopTimes: [RailStopTime] {
        let r = route
        let total = max(r.totalMinutes, 1)
        let span = arrive.timeIntervalSince(depart)
        let ordered = reversed ? Array(r.stops.reversed()) : r.stops
        return ordered.map { stop in
            let m = reversed ? total - stop.minute : stop.minute
            return RailStopTime(
                name: stop.name,
                coordinate: stop.coordinate,
                time: depart.addingTimeInterval(span * m / total)
            )
        }
    }

    /// 운행 중이면 현재 추정 위치, 아니면 nil.
    func position(at now: Date) -> RailPosition? {
        guard now >= depart, now <= arrive else { return nil }
        let stops = stopTimes
        guard stops.count >= 2 else { return nil }
        let span = max(arrive.timeIntervalSince(depart), 1)
        for i in 1..<stops.count where now <= stops[i].time {
            let a = stops[i - 1]
            let b = stops[i]
            let leg = max(b.time.timeIntervalSince(a.time), 1)
            let f = min(max(now.timeIntervalSince(a.time) / leg, 0), 1)
            let coordinate = CLLocationCoordinate2D(
                latitude: a.coordinate.latitude + (b.coordinate.latitude - a.coordinate.latitude) * f,
                longitude: a.coordinate.longitude + (b.coordinate.longitude - a.coordinate.longitude) * f
            )
            return RailPosition(
                coordinate: coordinate,
                progress: now.timeIntervalSince(depart) / span,
                previous: a.name,
                next: b.name,
                nextTime: b.time
            )
        }
        return nil
    }
}

/// 간선 열차 노선. 역 좌표는 지도에 선을 긋기 위한 근삿값이고, 역 사이는 직선으로 잇는다.
enum RailCatalog {
    static let koreaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.25, longitude: 127.75),
        span: MKCoordinateSpan(latitudeDelta: 4.4, longitudeDelta: 3.4)
    )

    private static let coordinates: [String: (Double, Double)] = [
        "서울": (37.5547, 126.9707), "용산": (37.5299, 126.9648), "영등포": (37.5157, 126.9073),
        "광명": (37.4165, 126.8849), "수원": (37.2659, 127.0001), "평택": (36.9909, 127.0852),
        "천안": (36.8090, 127.1467), "천안아산": (36.7946, 127.1045), "조치원": (36.6010, 127.2960),
        "오송": (36.6200, 127.3276), "대전": (36.3324, 127.4347), "서대전": (36.3225, 127.4039),
        "김천구미": (36.1132, 128.1811), "김천": (36.1240, 128.1140), "구미": (36.1282, 128.3309),
        "대구": (35.8760, 128.5962), "동대구": (35.8794, 128.6286), "경주": (35.7985, 129.1391),
        "울산": (35.5514, 129.1386), "밀양": (35.4745, 128.7711), "구포": (35.2054, 128.9972),
        "부산": (35.1151, 129.0414), "공주": (36.3330, 127.0980), "익산": (35.9403, 126.9462),
        "정읍": (35.5757, 126.8430), "광주송정": (35.1378, 126.7909), "나주": (35.0144, 126.7172),
        "목포": (34.7911, 126.3867), "전주": (35.8497, 127.1617), "남원": (35.4130, 127.3610),
        "순천": (34.9456, 127.5035), "여수엑스포": (34.7531, 127.7486), "수서": (37.4873, 127.1012),
        "동탄": (37.2002, 127.0958), "평택지제": (37.0188, 127.0702), "청량리": (37.5805, 127.0469),
        "양평": (37.4927, 127.4918), "만종": (37.3530, 127.8930), "횡성": (37.4690, 127.9830),
        "둔내": (37.5080, 128.2160), "평창": (37.5620, 128.4300), "진부": (37.6430, 128.5750),
        "강릉": (37.7641, 128.8994), "원주": (37.3160, 127.9203), "제천": (37.1278, 128.2052),
        "단양": (36.9440, 128.3240), "영주": (36.8105, 128.6243), "안동": (36.5665, 128.6780),
    ]

    private static func stops(_ list: [(String, Double)]) -> [RailStop] {
        list.map { item in
            let c = coordinates[item.0] ?? (36.5, 127.8)
            return RailStop(name: item.0, lat: c.0, lon: c.1, minute: item.1)
        }
    }

    static let routes: [RailRoute] = [
        RailRoute(
            id: "ktx-gyeongbu", kind: .ktx, name: "경부선",
            stops: stops([("서울", 0), ("광명", 15), ("천안아산", 37), ("오송", 50), ("대전", 62),
                          ("김천구미", 88), ("동대구", 108), ("경주", 127), ("울산", 140), ("부산", 162)]),
            headway: 20, first: 310, last: 1350,
            originNames: ["서울"], destinationNames: ["부산"]
        ),
        RailRoute(
            id: "ktx-honam", kind: .ktx, name: "호남선",
            stops: stops([("용산", 0), ("광명", 14), ("천안아산", 36), ("오송", 48), ("공주", 60),
                          ("익산", 75), ("정읍", 90), ("광주송정", 108), ("나주", 118), ("목포", 145)]),
            headway: 40, first: 310, last: 1320,
            originNames: ["용산"], destinationNames: ["목포"]
        ),
        RailRoute(
            id: "ktx-jeolla", kind: .ktx, name: "전라선",
            stops: stops([("용산", 0), ("광명", 14), ("천안아산", 36), ("오송", 48), ("익산", 75),
                          ("전주", 90), ("남원", 115), ("순천", 145), ("여수엑스포", 172)]),
            headway: 70, first: 310, last: 1290,
            originNames: ["용산"], destinationNames: ["여수EXPO", "여수엑스포", "여수"]
        ),
        RailRoute(
            id: "ktx-gangneung", kind: .ktx, name: "강릉선",
            stops: stops([("서울", 0), ("청량리", 18), ("양평", 42), ("만종", 65), ("횡성", 75),
                          ("둔내", 85), ("평창", 95), ("진부", 105), ("강릉", 122)]),
            headway: 70, first: 330, last: 1320,
            originNames: ["서울"], destinationNames: ["강릉"]
        ),
        RailRoute(
            id: "eum-jungang", kind: .eum, name: "중앙선",
            stops: stops([("청량리", 0), ("양평", 25), ("원주", 50), ("제천", 72), ("단양", 88),
                          ("영주", 110), ("안동", 127)]),
            headway: 120, first: 360, last: 1200,
            originNames: ["청량리"], destinationNames: ["안동"]
        ),
        RailRoute(
            id: "srt-gyeongbu", kind: .srt, name: "경부선",
            stops: stops([("수서", 0), ("동탄", 17), ("평택지제", 27), ("천안아산", 40), ("오송", 52),
                          ("대전", 64), ("김천구미", 90), ("동대구", 108), ("경주", 127), ("울산", 140),
                          ("부산", 160)]),
            headway: 30, first: 330, last: 1360,
            originNames: ["수서"], destinationNames: ["부산"]
        ),
        RailRoute(
            id: "srt-honam", kind: .srt, name: "호남선",
            stops: stops([("수서", 0), ("동탄", 17), ("평택지제", 27), ("천안아산", 40), ("오송", 52),
                          ("공주", 64), ("익산", 78), ("정읍", 92), ("광주송정", 108), ("나주", 118),
                          ("목포", 142)]),
            headway: 60, first: 310, last: 1360,
            originNames: ["수서"], destinationNames: ["목포"]
        ),
        RailRoute(
            id: "itx-gyeongbu", kind: .itx, name: "경부선",
            stops: stops([("서울", 0), ("영등포", 9), ("수원", 30), ("평택", 52), ("천안", 68),
                          ("조치원", 88), ("대전", 110), ("김천", 165), ("구미", 180), ("대구", 210),
                          ("동대구", 216), ("밀양", 250), ("구포", 275), ("부산", 290)]),
            headway: 120, first: 360, last: 1170,
            originNames: ["서울"], destinationNames: ["부산"]
        ),
        RailRoute(
            id: "mug-gyeongbu", kind: .mugunghwa, name: "경부선",
            stops: stops([("서울", 0), ("영등포", 10), ("수원", 34), ("평택", 58), ("천안", 76),
                          ("조치원", 98), ("대전", 124), ("김천", 186), ("구미", 204), ("대구", 238),
                          ("동대구", 245), ("밀양", 284), ("구포", 314), ("부산", 330)]),
            headway: 90, first: 330, last: 1230,
            originNames: ["서울"], destinationNames: ["부산"]
        ),
        RailRoute(
            id: "itx-honam", kind: .itx, name: "호남선",
            stops: stops([("용산", 0), ("영등포", 7), ("수원", 28), ("평택", 50), ("천안", 66),
                          ("조치원", 86), ("서대전", 115), ("익산", 170), ("정읍", 200),
                          ("광주송정", 235), ("목포", 290)]),
            headway: 180, first: 390, last: 1140,
            originNames: ["용산"], destinationNames: ["목포"]
        ),
    ]

    private static let byID: [String: RailRoute] = {
        var map: [String: RailRoute] = [:]
        for r in routes { map[r.id] = r }
        return map
    }()

    static func route(_ id: String) -> RailRoute {
        byID[id] ?? routes[0]
    }

    /// 인증키가 없을 때 쓰는 미리보기 열차. 배차 간격만으로 만든 것이라 실제 시간표가 아니다.
    static func previewTrains(day: Date) -> [RailTrain] {
        let midnight = KST.startOfDay(day)
        var out: [RailTrain] = []
        for route in routes {
            var minute = route.first
            while minute <= route.last {
                for reversed in [false, true] {
                    let offset = reversed ? route.headway / 2 : 0
                    let depart = midnight.addingTimeInterval(Double(minute + offset) * 60)
                    out.append(RailTrain(
                        id: "\(route.id)-\(reversed ? "r" : "f")-\(minute)",
                        routeID: route.id, reversed: reversed, number: "",
                        kindName: route.kind.rawValue,
                        depart: depart,
                        arrive: depart.addingTimeInterval(route.totalMinutes * 60),
                        scheduled: false
                    ))
                }
                minute += route.headway
            }
        }
        return out
    }
}
