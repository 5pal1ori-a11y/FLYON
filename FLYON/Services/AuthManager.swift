import AuthenticationServices
import Observation
import Security

@Observable
final class AuthManager {
    private(set) var userID: String?
    private(set) var displayName: String?
    var errorMessage: String?

    var isSignedIn: Bool { userID != nil }

    private let nameKey = "flyon.displayName"

    init() {
        userID = Keychain.read("appleUserID")
        displayName = UserDefaults.standard.string(forKey: nameKey)
    }

    /// 앱 실행 시 Apple 측에서 로그인이 취소(해지)됐는지 확인
    func checkCredentialState() async {
        guard let id = userID, id != Self.debugUserID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: id)
        if state == .revoked || state == .notFound { signOut() }
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Keychain.save(cred.user, for: "appleUserID")
            userID = cred.user
            // 이름은 최초 로그인 때만 내려온다
            if let name = cred.fullName {
                let full = [name.familyName, name.givenName].compactMap { $0 }.joined()
                if !full.isEmpty {
                    UserDefaults.standard.set(full, forKey: nameKey)
                    displayName = full
                }
            }
            errorMessage = nil
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func signOut() {
        Keychain.delete("appleUserID")
        userID = nil
    }

    /// 로컬 데이터 삭제. 서버에 사용자 데이터를 저장하게 되면 서버 삭제 요청과
    /// Apple 토큰 해지(revoke) 호출을 여기에 추가해야 한다.
    func deleteAccount() {
        signOut()
        UserDefaults.standard.removeObject(forKey: nameKey)
        displayName = nil
    }

    #if DEBUG
    static let debugUserID = "debug-user"
    func signInForDebug() {
        Keychain.save(Self.debugUserID, for: "appleUserID")
        userID = Self.debugUserID
        displayName = "테스터"
    }
    #else
    static let debugUserID = ""
    #endif
}

enum Keychain {
    private static let service = "app.flyon"

    private static func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    static func save(_ value: String, for key: String) {
        SecItemDelete(query(key) as CFDictionary)
        var q = query(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
