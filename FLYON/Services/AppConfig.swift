import Foundation

/// Supabase 접속 값은 소스에 적지 않고, 빌드할 때 주입된다.
///   project.yml 의 Info.plist 키(SupabaseProjectRef / SupabaseAnonKey)
///   <- 빌드 설정(SUPABASE_PROJECT_REF / SUPABASE_ANON_KEY) <- GitHub Actions Secrets
/// 값이 비어 있으면(로컬 개발, 빌드 점검) 샘플 데이터를 쓴다.
/// anon(공개) 키만 쓴다. service_role 키와 Travelpayouts 토큰은 절대 넣지 않는다.
enum AppConfig {
    private static func infoString(_ key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.hasPrefix("$(") ? "" : value
    }

    static var supabaseProjectRef: String { infoString("SupabaseProjectRef") }
    static var supabaseAnonKey: String { infoString("SupabaseAnonKey") }

    static var functionsBaseURL: URL? {
        guard !supabaseProjectRef.isEmpty, !supabaseAnonKey.isEmpty else { return nil }
        return URL(string: "https://\(supabaseProjectRef).supabase.co/functions/v1")
    }

    static func makePriceProvider() -> PriceProvider {
        guard let base = functionsBaseURL else { return MockPriceProvider() }
        return ServerPriceProvider(baseURL: base.appendingPathComponent("prices"), anonKey: supabaseAnonKey)
    }

    static func makeAlertsClient() -> AlertsClient? {
        guard let base = functionsBaseURL else { return nil }
        return AlertsClient(baseURL: base.appendingPathComponent("alerts"), anonKey: supabaseAnonKey)
    }
}
