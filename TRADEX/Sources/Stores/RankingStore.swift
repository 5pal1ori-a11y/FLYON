import Foundation
import Observation

/// 시즌 랭킹 상태: 참가 여부, 순위표, 내 순위. 로그인한 사용자별로 세션을 따로 보관한다.
@MainActor
@Observable
final class RankingStore {
    private(set) var board: RankingAPI.Board?
    private(set) var loading = false
    private(set) var nickname: String?
    var errorText: String?

    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var lastSubmit = Date.distantPast

    var isConfigured: Bool { RankingAPI.isConfigured }
    var isJoined: Bool { session != nil }

    private var session: String? { userID.flatMap { RankingKeychain.get($0) } }
    private var nickKey: String { "ranking-nickname-\(userID ?? "")" }

    func bind(userID: String?) {
        guard self.userID != userID else { return }
        self.userID = userID
        board = nil
        nickname = userID.flatMap { UserDefaults.standard.string(forKey: "ranking-nickname-\($0)") }
    }

    func join(identityToken: String, nickname: String) async throws {
        guard let userID else { return }
        let r = try await RankingAPI.join(identityToken: identityToken, nickname: nickname)
        RankingKeychain.set(r.session, userID)
        self.nickname = r.nickname
        UserDefaults.standard.set(r.nickname, forKey: nickKey)
    }

    /// 내 AP를 서버에 보내고(최대 1분에 한 번) 순위표를 새로 받는다
    func sync(season: Season, ap: Int, force: Bool = false) async {
        guard isConfigured else { return }
        loading = true
        defer { loading = false }
        if let session, force || Date().timeIntervalSince(lastSubmit) > 60 {
            lastSubmit = Date()
            _ = try? await RankingAPI.submit(season: season.id, ap: ap, session: session)
        }
        do {
            board = try await RankingAPI.leaderboard(season: season.id, session: session)
            errorText = nil
            if let me = board?.me, me.nickname != nickname {
                nickname = me.nickname
                UserDefaults.standard.set(me.nickname, forKey: nickKey)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// 지난 시즌 최종 순위 (랭킹 참가자만, 서버에 기록이 있을 때)
    func finalRank(seasonID: String) async -> Int? {
        guard isConfigured, let session else { return nil }
        return try? await RankingAPI.leaderboard(season: seasonID, session: session).me?.rank
    }

    func rename(_ newName: String) async throws {
        guard let session else { return }
        try await RankingAPI.rename(newName, session: session)
        nickname = newName
        UserDefaults.standard.set(newName, forKey: nickKey)
    }

    /// 랭킹 참가 해제 (서버 기록 삭제)
    func leave() async {
        guard let userID, let session else { return }
        try? await RankingAPI.leave(session: session)
        RankingKeychain.delete(userID)
        UserDefaults.standard.removeObject(forKey: nickKey)
        nickname = nil
        board = nil
    }
}
