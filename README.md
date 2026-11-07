# FLYON (iOS, SwiftUI)

항공권 가격 흐름 분석 앱. iOS 17+, SwiftUI, Swift Charts.

## 실행 방법 (Mac + Xcode 필요)

```bash
brew install xcodegen
cd FLYON
xcodegen            # project.yml -> FLYON.xcodeproj 생성
open FLYON.xcodeproj
```

1. `project.yml`의 `bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`을 본인 값으로 바꾼 뒤 `xcodegen`을 다시 실행
2. Xcode > Signing & Capabilities에서 **Sign in with Apple** 이 켜져 있는지 확인 (유료 Apple Developer 계정 필요)
3. 시뮬레이터 실행. 디버그 빌드에는 "개발용 둘러보기" 버튼이 있어 로그인 없이 화면을 볼 수 있음

## 구조

- `FLYONApp.swift` : 진입점, 스플래시와 로그인/메인 전환
- `Views/SplashView.swift` : "FLY ON" 네온 점등 오프닝
- `Views/LoginView.swift` : Apple로 로그인
- `Views/HomeView.swift`, `PricingView.swift`(책정), `ResultView.swift`, `SettingsView.swift`
- `Services/PriceProvider.swift` : 가격 데이터 소스 추상화 (지금은 샘플 데이터)
- `Services/AuthManager.swift` : Apple 로그인, Keychain 저장

## 실제 데이터로 전환

앱에는 API 토큰을 넣지 않는다. 서버가 Travelpayouts Data API를 호출해 DB에 이력을 쌓고,
앱은 `ServerPriceProvider`로 그 서버만 호출한다. `AppState.provider`를 교체하면 된다.

## 출시 전 TODO

- [ ] 개인정보처리방침/이용약관 URL (`SettingsView.swift`의 `LegalLinks`)
- [ ] Travelpayouts 약관: 가격 데이터 저장·가공·표시 허용 범위 확인
- [ ] 서버에 사용자 데이터를 저장하게 되면 계정 삭제 시 서버 삭제와 Apple 토큰 해지(revoke) 구현
- [ ] "FLYON" 상표 검색(KIPRIS)
- [ ] 이 코드는 Linux 환경에서 작성되어 한 번도 컴파일하지 못함. 첫 빌드에서 오류가 나올 수 있음
