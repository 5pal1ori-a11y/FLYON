# 구독온 (SUBSCRIPTION ON)
iOS 17+ / SwiftUI. Mac 에서 아래 두 줄이면 열려요.

    brew install xcodegen
    cd SubscriptionOn && xcodegen && open SubscriptionOn.xcodeproj

- 로고: 공식 이미지는 Assets 에 `logo_넷플릭스` 처럼 넣으면 자동 적용 (없으면 브랜드색+이니셜)
- OCR: Apple Vision (온디바이스)

## GitHub Actions → TestFlight
1. Apple Developer Program 가입, App Store Connect 에서 앱(번들 ID `com.subon.app`) 생성
2. App Store Connect > 사용자 및 액세스 > 통합 > API 키 발급 (권한: App 관리 이상 / Admin 권장)
3. GitHub 저장소 Settings > Secrets and variables > Actions 에 등록
   - `APPLE_TEAM_ID` : 개발자 팀 ID
   - `ASC_KEY_ID` : API 키 ID
   - `ASC_ISSUER_ID` : Issuer ID
   - `ASC_KEY_P8` : .p8 파일 내용 전체
   - (선택) Variables 에 `BUNDLE_ID`
4. `git tag v1.0.0 && git push --tags` 또는 Actions 탭에서 수동 실행
