# 등불지기 TestFlight 배포

이 저장소(FLYON)에 이미 있는 TestFlight 방식을 그대로 씁니다.
**새로 등록할 비밀값은 없습니다.** 기존 Secrets `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`를 함께 씁니다.

## 어떻게 동작하나

워크플로: `.github/workflows/testflight-lanternkeeper.yml`

1. macOS 서버에 Godot 4.5.1과 iOS 내보내기 템플릿을 받습니다 (한 번 받으면 캐시).
2. 게임 테스트를 돌립니다. 실패하면 업로드하지 않습니다.
3. `ci/apple_signing.py`가 App Store Connect API로 **임시 배포 인증서와 프로필**을 만듭니다.
4. Godot가 Xcode 프로젝트를 만들고, `xcodebuild`가 서명·아카이브한 뒤 App Store Connect로 바로 업로드합니다.
5. 끝나면 임시 인증서·프로필·키체인을 지웁니다.

- 버전: `1.0.0` (`Lanternkeeper/project.godot`의 `config/version`)
- 빌드 번호: `30000 + 실행 번호` (구독온 10000번대, TRADEX 20000번대와 겹치지 않게)

## 실행 방법

| 방법 | 언제 |
|---|---|
| `claude/lanternkeeper-game` 브랜치에 `Lanternkeeper/` 변경을 푸시 | 자동 실행 |
| Actions 탭 → **등불지기 TestFlight** → **Run workflow** | 워크플로 파일이 **main에 합쳐진 뒤**부터 버튼이 보입니다 |

## 지금은 FLYON 앱 레코드로 올라갑니다

TRADEX·구독온과 같은 방식으로, 기본 번들 ID는 `com.flight.flyon`입니다.
그래서 App Store Connect에서는 **FLYON 앱의 TestFlight 빌드(버전 1.0.0)**로 보이고, 아이폰에 설치하면 이름은 "등불지기"로 나옵니다.
테스트용으로는 문제가 없지만, **정식 출시 전에는 반드시 전용 앱으로 분리**하세요.

### 전용 앱으로 분리하는 법
1. developer.apple.com → Identifiers → **+** → App ID: `com.flight.lanternkeeper` (기능은 아무것도 켜지 않음)
2. App Store Connect → 앱 → **+** → 이름 `등불지기`, 번들 ID `com.flight.lanternkeeper`, SKU `lanternkeeper`
3. Run workflow에서 `bundle_id`에 `com.flight.lanternkeeper` 입력 (또는 워크플로의 기본값 변경)

## 출시 전 체크리스트

- [ ] **개발자 계정 명의**: Apple Developer Program은 성인 본인 명의만 가입할 수 있습니다. 미성년자는 보호자 명의 계정에 App Store Connect 사용자로 초대받아 쓰세요. 유료 판매 수익·세금도 계정 명의자에게 귀속됩니다.
- [ ] **연령 등급 설문**: 판타지 폭력 "드물게/경미", 도박·뽑기·사용자 간 소통 없음. 한국 게임 등급은 앱스토어 자체등급분류로 처리됩니다.
- [ ] **개인정보 라벨**: "데이터를 수집하지 않음" (광고·분석·로그인 없음)
- [ ] **개인정보 처리방침 URL**: `Lanternkeeper/PRIVACY.md` 링크 (공개 저장소라 그대로 쓸 수 있습니다)
- [ ] **수출 규정**: 빌드에 "암호화 사용 안 함"이 들어가 있어 따로 답할 필요 없음
- [ ] **이름 확인**: "등불지기"가 이미 쓰이는 이름인지 App Store와 KIPRIS(상표)에서 검색
- [ ] **스크린샷**: 6.9인치 아이폰 세로

## 문제 해결

| 증상 | 해결 |
|---|---|
| `Missing App Store Connect secrets` | 저장소 Secrets 3개가 있는지 확인 |
| `Bundle ID not found in this team` | 입력한 번들 ID의 App ID를 먼저 만들 것 |
| 업로드 시 앱 레코드를 찾을 수 없다는 오류 | 그 번들 ID로 App Store Connect 앱을 먼저 만들 것 |
| `Godot did not create the Xcode project` | Actions의 `lanternkeeper-godot-export-log` 파일 확인 |
| 서명 정리 실패 경고 | developer.apple.com에서 이름이 `FLYON CI`로 시작하는 인증서·프로필 삭제 |
