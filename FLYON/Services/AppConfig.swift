import Foundation

/// Supabase 프로젝트를 만든 뒤 두 값을 채우면 샘플 데이터 대신 실제 서버 데이터를 쓴다.
/// anon 키는 앱에 들어가도 되도록 설계된 공개 키다. 단, service_role 키와
/// Travelpayouts 토큰은 절대 여기에 넣지 않는다.
enum AppConfig {
    static let supabaseProjectRef = ""   // TODO: 예) abcdefghijklmnop
    static let supabaseAnonKey = ""      // TODO: Project Settings > API > anon public

    static func makePriceProvider() -> PriceProvider {
        guard !supabaseProjectRef.isEmpty, !supabaseAnonKey.isEmpty,
              let url = URL(string: "https://\(supabaseProjectRef).supabase.co/functions/v1/prices") else {
            return MockPriceProvider()
        }
        return ServerPriceProvider(baseURL: url, anonKey: supabaseAnonKey)
    }
}
