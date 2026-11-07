import Foundation

/// Supabase 접속 값은 소스에 적지 않고, 빌드할 때 주입된다.
///   project.yml 의 Info.plist 키(SupabaseProjectRef / SupabaseAnonKey)
///   <- 빌드 설정(SUPABASE_PROJECT_REF / SUPABASE_ANON_KEY)
///   <- GitHub Actions Secrets
/// 값이 비어 있으면(로컬 개발, 빌드 점검) 샘플 데이터를 쓴다.
///
/// 주의: 이 값들은 결국 앱 안에 들어가므로 앱을 분석하면 볼 수 있다. 그래서 공개해도 되는
/// anon(공개) 키만 쓴다. service_role 키와 Travelpayouts 토큰은 절대 넣지 않는다.
enum AppConfig {
    private static func infoString(_ key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.hasPrefix("$(") ? "" : value   // 치환되지 않은 자리표시는 빈 값으로 취급
    }

    static var supabaseProjectRef: String { infoString("SupabaseProjectRef") }
    static var supabaseAnonKey: String { infoString("SupabaseAnonKey") }

    static func makePriceProvider() -> PriceProvider {
        guard !supabaseProjectRef.isEmpty, !supabaseAnonKey.isEmpty,
              let url = URL(string: "https://\(supabaseProjectRef).supabase.co/functions/v1/prices") else {
            return MockPriceProvider()
        }
        return ServerPriceProvider(baseURL: url, anonKey: supabaseAnonKey)
    }
}
