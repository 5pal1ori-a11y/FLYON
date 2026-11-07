import Foundation
import Observation

enum AppTab: Hashable {
    case home, pricing, settings
}

struct RecentSearch: Identifiable, Hashable, Codable {
    let originCode: String
    let destinationCode: String
    let date: Date
    var id: String { "\(originCode)-\(destinationCode)" }
}

@Observable
final class AppState {
    /// AppConfig에 Supabase 값이 있으면 실제 서버, 없으면 샘플 데이터
    let provider: PriceProvider = AppConfig.makePriceProvider()

    var selectedTab: AppTab = .home
    /// 홈에서 노선을 누르면 책정 탭에 미리 채워 줄 값
    var pendingRoute: FavoriteRoute?

    private(set) var favorites: [FavoriteRoute] = []
    private(set) var recents: [RecentSearch] = []

    private let favoritesKey = "flyon.favorites"
    private let recentsKey = "flyon.recents"

    init() {
        favorites = Self.load([FavoriteRoute].self, key: favoritesKey) ?? []
        recents = Self.load([RecentSearch].self, key: recentsKey) ?? []
    }

    func isFavorite(_ route: FavoriteRoute) -> Bool { favorites.contains(route) }

    func toggleFavorite(_ route: FavoriteRoute) {
        if let i = favorites.firstIndex(of: route) {
            favorites.remove(at: i)
        } else {
            favorites.insert(route, at: 0)
        }
        Self.save(favorites, key: favoritesKey)
    }

    func addRecent(origin: Airport, destination: Airport) {
        let item = RecentSearch(originCode: origin.code, destinationCode: destination.code, date: .now)
        recents.removeAll { $0.id == item.id }
        recents.insert(item, at: 0)
        recents = Array(recents.prefix(5))
        Self.save(recents, key: recentsKey)
    }

    func clearAllLocalData() {
        favorites = []
        recents = []
        UserDefaults.standard.removeObject(forKey: favoritesKey)
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
