import Foundation
import Observation
import AuthenticationServices

@MainActor
@Observable
final class Session {
    private(set) var user: AppUser?
    private(set) var wallet: Wallet?
    var showWelcome = false
    var errorMessage: String?

    private let userKey = "currentUser"

    init() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let saved = try? JSONDecoder().decode(AppUser.self, from: data) {
            activate(saved)
            Task { await self.verifyAppleCredential() }
        }
    }

    /// Sign in with Apple 결과 처리
    func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            // 이름은 최초 로그인 때만 전달되므로 저장해 둔다.
            let name = [cred.fullName?.familyName, cred.fullName?.givenName]
                .compactMap { $0 }.joined()
            let existingName = UserDefaults.standard.string(forKey: "name-\(cred.user)")
            if !name.isEmpty { UserDefaults.standard.set(name, forKey: "name-\(cred.user)") }
            let user = AppUser(id: "apple-\(cred.user)", displayName: name.isEmpty ? (existingName ?? "트레이더") : name, provider: "apple")
            signIn(user)
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "로그인에 실패했어요. 다시 시도해 주세요."
            }
        }
    }

    #if DEBUG
    /// 개발용 로그인 (시뮬레이터·무료 개발자 계정에서 Sign in with Apple을 못 쓸 때)
    func signInAsDeveloper() {
        signIn(AppUser(id: "guest-dev", displayName: "개발자", provider: "guest"))
    }
    #endif

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userKey)
        user = nil
        wallet = nil
    }

    /// 계정 삭제 (앱스토어 심사 가이드라인 5.1.1(v): 계정 생성 기능이 있으면 삭제 기능 필수)
    /// 서버를 붙이면 여기서 서버 데이터 삭제와 Apple 토큰 폐기(revoke)도 함께 해야 한다.
    func deleteAccount() {
        wallet?.deleteFile()
        if let id = user?.id { UserDefaults.standard.removeObject(forKey: "name-\(id.replacingOccurrences(of: "apple-", with: ""))") }
        signOut()
    }

    private func signIn(_ user: AppUser) {
        if let data = try? JSONEncoder().encode(user) { UserDefaults.standard.set(data, forKey: userKey) }
        activate(user)
        if wallet?.grantSignupBonusIfNeeded() == true {
            showWelcome = true
        }
    }

    private func activate(_ user: AppUser) {
        self.user = user
        self.wallet = Wallet(userID: user.id)
    }

    /// Apple ID 연동이 해제됐으면 로그아웃
    private func verifyAppleCredential() async {
        guard let user, user.provider == "apple" else { return }
        let appleID = String(user.id.dropFirst("apple-".count))
        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { cont in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleID) { state, _ in
                cont.resume(returning: state)
            }
        }
        if state == .revoked || state == .notFound { signOut() }
    }
}
