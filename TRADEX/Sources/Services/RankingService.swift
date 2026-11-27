import Foundation
import Security

/// 시즌 랭킹 서버 (Supabase Edge Function: tradex-ranking)
enum RankingAPI {
    struct Entry: Decodable, Identifiable, Equatable {
        let rank: Int
        let nickname: String
        let ap: Int
        var id: Int { rank }
    }
    struct Me: Decodable, Equatable {
        let nickname: String
        let ap: Int
        let rank: Int?
    }
    struct Board: Decodable, Equatable {
        let season: String
        let total: Int
        let top: [Entry]
        let me: Me?
    }
    struct JoinResult: Decodable { let session: String; let nickname: String }
    struct ScoreResult: Decodable { let ap: Int; let rank: Int? }

    enum RankingError: LocalizedError {
        case notConfigured, server(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "랭킹 서버가 아직 연결되지 않았어요."
            case .server(let m): return m
            }
        }
    }

    private static let ref = (Bundle.main.object(forInfoDictionaryKey: "SupabaseProjectRef") as? String) ?? ""
    private static let anon = (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String) ?? ""

    /// 빌드에 서버 정보가 들어 있는지 (값이 비었거나 치환되지 않았으면 비활성)
    static var isConfigured: Bool { !ref.isEmpty && !anon.isEmpty && !ref.hasPrefix("$(") }

    private static func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: Any]? = nil,
                                session: String? = nil) async throws -> Data {
        guard isConfigured, var comps = URLComponents(string: "https://\(ref).supabase.co/functions/v1/tradex-ranking\(path)") else {
            throw RankingError.notConfigured
        }
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        if let session { req.setValue(session, forHTTPHeaderField: "x-tradex-session") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw RankingError.server(msg ?? "랭킹 서버 오류 (\(http.statusCode))")
        }
        return data
    }

    static func join(identityToken: String, nickname: String) async throws -> JoinResult {
        let data = try await request("POST", "/join", body: ["identity_token": identityToken, "nickname": nickname, "age_confirmed": true])
        return try JSONDecoder().decode(JoinResult.self, from: data)
    }

    static func submit(season: String, ap: Int, session: String) async throws -> ScoreResult {
        let data = try await request("POST", "/score", body: ["season": season, "ap": ap], session: session)
        return try JSONDecoder().decode(ScoreResult.self, from: data)
    }

    static func leaderboard(season: String, session: String?) async throws -> Board {
        let data = try await request("GET", "/leaderboard", query: [URLQueryItem(name: "season", value: season)], session: session)
        return try JSONDecoder().decode(Board.self, from: data)
    }

    static func rename(_ nickname: String, session: String) async throws {
        _ = try await request("POST", "/nickname", body: ["nickname": nickname], session: session)
    }

    static func leave(session: String) async throws {
        _ = try await request("DELETE", "/me", session: session)
    }
}

/// 랭킹 세션 토큰은 키체인에 보관 (기기 밖으로 나가지 않음)
enum RankingKeychain {
    private static let service = "tradex.ranking.session"

    static func get(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func set(_ value: String, _ account: String) {
        delete(account)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8),
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete(_ account: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }
}
