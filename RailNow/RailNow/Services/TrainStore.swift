import Foundation
import SwiftUI

enum AppTab: Hashable {
    case home, subway, rail, settings
}

enum DataSource: Equatable {
    case live              // 실제 수신 데이터 (지하철 위치 / 열차 시간표)
    case preview           // 인증키 없음: 운행 간격으로 만든 미리보기
    case failed(String)    // 요청 실패: 미리보기로 대신 표시

    var isLive: Bool { self == .live }
}

/// 인증키와 즐겨찾기. 키는 무료 공공데이터 키라 기기 설정에 그대로 저장한다.
final class AppSettings: ObservableObject {
    @Published var seoulKey: String {
        didSet { UserDefaults.standard.set(seoulKey, forKey: "seoulKey") }
    }
    @Published var railKey: String {
        didSet { UserDefaults.standard.set(railKey, forKey: "railKey") }
    }
    @Published var favorites: [String] {
        didSet { UserDefaults.standard.set(favorites, forKey: "favoriteLines") }
    }

    init() {
        let defaults = UserDefaults.standard
        seoulKey = defaults.string(forKey: "seoulKey") ?? ""
        railKey = defaults.string(forKey: "railKey") ?? ""
        favorites = defaults.stringArray(forKey: "favoriteLines") ?? ["2", "1", "shinbundang"]
    }

    private func bundled(_ name: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: name) as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 설정 화면에 넣은 키가 우선이고, 없으면 빌드할 때 넣은 키를 쓴다.
    var effectiveSeoulKey: String {
        let typed = seoulKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? bundled("SeoulSubwayKey") : typed
    }

    var effectiveRailKey: String {
        let typed = railKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? bundled("DataGoKrKey") : typed
    }

    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) {
            favorites.remove(at: i)
        } else {
            favorites.append(id)
        }
    }
}

@MainActor
final class TrainStore: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var selectedLineID: String = "2"
    @Published var focusedRailID: String?

    @Published private(set) var subway: [String: [SubwayTrain]] = [:]
    @Published private(set) var subwaySource: [String: DataSource] = [:]
    @Published private(set) var subwayUpdated: [String: Date] = [:]

    @Published private(set) var rail: [RailTrain] = []
    @Published private(set) var railSource: DataSource = .preview
    @Published private(set) var railLoading = false

    let catalog = SubwayCatalog.shared
    let settings: AppSettings
    private var railLoadedFor = ""

    init(settings: AppSettings) {
        self.settings = settings
        rail = RailCatalog.previewTrains(day: Date())
        #if DEBUG
        // 시뮬레이터 스크린샷용 실행 인자: -screenshotTab subway|rail|settings -screenshotLine 1 -screenshotSheet rail
        let args = UserDefaults.standard
        switch args.string(forKey: "screenshotTab") {
        case "subway": tab = .subway
        case "rail": tab = .rail
        case "settings": tab = .settings
        default: break
        }
        if let line = args.string(forKey: "screenshotLine") { selectedLineID = line }
        if args.string(forKey: "screenshotSheet") == "rail" {
            let now = Date()
            focusedRailID = rail.first { $0.kind == .ktx && ($0.position(at: now)?.progress ?? 0) > 0.4 }?.id
        }
        #endif
    }

    func refreshSubway(_ line: SubwayLine) async {
        let key = settings.effectiveSeoulKey
        let now = Date()
        if let liveName = line.live, !key.isEmpty {
            do {
                let list = try await SubwayLiveService.fetch(lineName: liveName, key: key)
                subway[line.id] = list
                subwaySource[line.id] = .live
            } catch is CancellationError {
                return
            } catch {
                if (error as? URLError)?.code == .cancelled { return }
                subway[line.id] = SubwayEstimator.trains(line: line, at: now)
                subwaySource[line.id] = .failed(error.localizedDescription)
            }
        } else {
            subway[line.id] = SubwayEstimator.trains(line: line, at: now)
            subwaySource[line.id] = .preview
        }
        subwayUpdated[line.id] = now
    }

    func loadRail(force: Bool = false) async {
        let key = settings.effectiveRailKey
        let today = Date()
        let stamp = "\(KST.ymd(today))|\(key)"
        if !force && stamp == railLoadedFor { return }
        if railLoading { return }
        railLoading = true
        defer { railLoading = false }

        // 자정을 넘겨 달리는 열차가 빠지지 않도록 어제 출발분도 함께 둔다.
        let yesterday = today.addingTimeInterval(-86400)
        let preview = RailCatalog.previewTrains(day: yesterday) + RailCatalog.previewTrains(day: today)
        guard !key.isEmpty else {
            rail = preview
            railSource = .preview
            railLoadedFor = stamp
            return
        }
        do {
            rail = try await RailScheduleService.trains(day: today, key: key)
            railSource = .live
            railLoadedFor = stamp
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            rail = preview
            railSource = .failed(error.localizedDescription)
            railLoadedFor = stamp
        }
    }

    func placed(_ line: SubwayLine) -> [PlacedTrain] {
        (subway[line.id] ?? []).compactMap { line.place($0) }
    }

    func openLine(_ id: String) {
        selectedLineID = id
        tab = .subway
    }

    func openRail(_ id: String) {
        focusedRailID = id
        tab = .rail
    }
}
