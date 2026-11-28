import ActivityKit
import CoreLocation
import SwiftUI
import UserNotifications

/// 탑승 안내에서 지나가는 역 하나.
struct RideStop: Identifiable {
    enum Kind {
        case board      // 타는 역
        case pass       // 지나가는 역
        case transfer   // 내려서 갈아타는 역
        case arrive     // 도착역
    }

    let id: Int
    let name: String
    /// 이 역에 올 때 타고 있는 노선
    let line: SubwayLine
    /// 환승역이면 갈아탈 노선
    let nextLine: SubwayLine?
    let kind: Kind
    let coordinate: CLLocationCoordinate2D?
    /// 출발부터 걸리는 시간(분, 추정)
    let minute: Double
}

/// "안내 시작" 이후의 진행 상태.
/// 위치는 GPS로 확인하고, 지하라서 GPS가 안 잡히면 역 사이 평균 시간으로 추정한다.
/// 위치는 기기 안에서 가장 가까운 역을 찾는 데만 쓰고 저장하거나 밖으로 보내지 않는다.
@MainActor
final class RideGuide: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Phase {
        case idle, waiting, riding, finished
    }

    enum Source {
        case time, gps, manual
    }

    @Published private(set) var stops: [RideStop] = []
    @Published private(set) var index = 0
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var source: Source = .time
    @Published private(set) var locationDenied = false

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var confirmedAt = Date()
    private var confirmedMinute = 0.0
    private var activity: Activity<RideActivityAttributes>?

    var isActive: Bool { phase != .idle }
    var current: RideStop? { stops.indices.contains(index) ? stops[index] : nil }
    var next: RideStop? { stops.indices.contains(index + 1) ? stops[index + 1] : nil }
    var destination: String { stops.last?.name ?? "" }

    /// 다음에 내리거나 갈아탈 역
    var target: RideStop? {
        stops.first { $0.id > index && ($0.kind == .transfer || $0.kind == .arrive) } ?? stops.last
    }

    var stopsToTarget: Int { max((target?.id ?? index) - index, 0) }

    var minutesLeft: Int {
        guard let last = stops.last else { return 0 }
        let now = phase == .riding ? confirmedMinute + Date().timeIntervalSince(confirmedAt) / 60 : confirmedMinute
        return max(0, Int((last.minute - now).rounded(.up)))
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 30
    }

    // MARK: 시작과 끝

    /// `quiet`는 스크린샷용: 권한 요청·위치·잠금화면 표시 없이 화면 상태만 만든다.
    func start(_ plan: RoutePlan, quiet: Bool = false) {
        stop()
        var list: [RideStop] = []
        var minute = 0.0
        for (li, leg) in plan.legs.enumerated() {
            let hop = RouteFinder.hopMinutes(leg.line.id)
            let lastLeg = li == plan.legs.count - 1
            for (si, name) in leg.stations.enumerated() {
                if si == 0 {
                    if li > 0 { continue }   // 환승역은 앞 구간의 마지막 역으로 이미 넣었다
                } else {
                    minute += hop
                }
                let kind: RideStop.Kind
                if si == 0 {
                    kind = .board
                } else if si == leg.stations.count - 1 {
                    kind = lastLeg ? .arrive : .transfer
                } else {
                    kind = .pass
                }
                var coordinate: CLLocationCoordinate2D?
                if let c = leg.line.coords[name], c.count == 2 {
                    coordinate = CLLocationCoordinate2D(latitude: c[0], longitude: c[1])
                }
                list.append(RideStop(
                    id: list.count, name: name, line: leg.line,
                    nextLine: kind == .transfer ? plan.legs[li + 1].line : nil,
                    kind: kind, coordinate: coordinate, minute: minute
                ))
                if kind == .transfer { minute += RouteFinder.transferMinutes }
            }
        }
        guard list.count >= 2 else { return }

        stops = list
        index = 0
        phase = .waiting
        source = .time
        confirmedAt = Date()
        confirmedMinute = 0

        if quiet { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        manager.requestWhenInUseAuthorization()
        startLocation()
        startActivity()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        if let activity {
            let last = activityState()
            Task { await activity.end(ActivityContent(state: last, staleDate: nil), dismissalPolicy: .immediate) }
        }
        activity = nil
        stops = []
        index = 0
        phase = .idle
    }

    /// 열차에 탔을 때 누른다. 이때부터 시간 추정이 흐른다.
    func boarded() {
        guard phase == .waiting else { return }
        phase = .riding
        confirmedAt = Date()
        confirmedMinute = stops[index].minute
        pushActivity()
    }

    /// 목록에서 "지금 여기"를 직접 고른다.
    func setCurrent(_ id: Int) {
        guard stops.indices.contains(id), phase != .finished else { return }
        source = .manual
        move(to: id, confirmed: true)
    }

    // MARK: 위치 판단

    private func tick() {
        guard phase == .riding, let last = stops.last else { return }
        let estimate = confirmedMinute + Date().timeIntervalSince(confirmedAt) / 60
        // 환승역에서는 갈아타는 시간이 지나야 다음 역으로 넘어간다.
        var byTime = index
        for stop in stops where stop.id > index && stop.minute <= min(estimate, last.minute) {
            byTime = stop.id
        }
        if byTime > index {
            source = .time
            move(to: byTime, confirmed: false)
        }
        objectWillChange.send()   // 남은 시간 갱신
    }

    private func handle(_ location: CLLocation) {
        guard phase == .waiting || phase == .riding else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 250 else { return }
        // 지금 역의 한 정거장 앞부터 네 정거장 뒤까지만 본다. 엉뚱한 역으로 튀지 않게 하기 위해서다.
        let low = max(0, index - 1)
        let high = min(stops.count - 1, index + 4)
        var best: Int?
        var bestDistance = 450.0
        for i in low...high {
            guard let c = stops[i].coordinate else { continue }
            let d = location.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
            if d < bestDistance {
                bestDistance = d
                best = i
            }
        }
        guard let found = best else { return }
        if found == index {
            if phase == .riding {
                source = .gps
                confirmedAt = Date()
                confirmedMinute = stops[index].minute
            }
            return
        }
        source = .gps
        if phase == .waiting { phase = .riding }
        move(to: found, confirmed: true)
    }

    private func move(to id: Int, confirmed: Bool) {
        let previous = index
        index = id
        if phase == .waiting && id > 0 { phase = .riding }
        if confirmed {
            confirmedAt = Date()
            confirmedMinute = stops[id].minute
        }
        let stop = stops[id]
        if stop.kind == .arrive {
            phase = .finished
            timer?.invalidate()
            timer = nil
            manager.stopUpdatingLocation()
            notify(title: "\(stop.name) 도착", body: "목적지에 도착했어요.")
        } else if id > previous {
            if stop.kind == .transfer, let nextLine = stop.nextLine {
                notify(title: "\(stop.name) · 환승역이에요", body: "내려서 \(nextLine.name)으로 갈아타세요.")
            } else if let upcoming = next, upcoming.kind == .transfer || upcoming.kind == .arrive {
                let word = upcoming.kind == .arrive ? "도착역" : "환승역"
                notify(title: "다음 역은 \(upcoming.name)", body: "\(word)이에요. 내릴 준비를 하세요.")
            }
        }
        pushActivity()
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: 위치 권한

    private func startLocation() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationDenied = false
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            manager.pausesLocationUpdatesAutomatically = false
            manager.startUpdatingLocation()
        case .denied, .restricted:
            locationDenied = true
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if self.isActive && self.phase != .finished { self.startLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.handle(last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: 잠금화면·다이내믹 아일랜드

    private func activityState() -> RideActivityAttributes.ContentState {
        let stop = current
        let goal = target
        let label: String
        switch phase {
        case .waiting: label = "출발역"
        case .finished: label = "도착"
        default: label = "이번 역"
        }
        return RideActivityAttributes.ContentState(
            label: label,
            station: stop?.name ?? "",
            lineShort: stop?.line.short ?? "",
            colorHex: stop?.line.color ?? "#1A6DFF",
            remaining: stopsToTarget,
            target: goal?.name ?? "",
            action: goal?.kind == .transfer ? "환승" : "도착"
        )
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RideActivityAttributes(destination: destination)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: activityState(), staleDate: nil),
            pushType: nil
        )
    }

    private func pushActivity() {
        guard let activity else { return }
        let state = activityState()
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }
}
