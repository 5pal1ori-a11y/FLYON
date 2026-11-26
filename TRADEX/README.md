# TRADEX — 코인 모의투자 iOS 앱

업비트 실시간 시세로 가상 자산을 사고파는 연습용 앱 (SwiftUI, iOS 17+).

## 빌드·업로드 (FLYON 레포 안의 TRADEX 폴더)

- **빌드 확인**: `main`에 `TRADEX/**` 변경이 푸시되면 Actions의 *TRADEX build check*가 자동 실행 (서명 없이 컴파일만)
- **TestFlight 업로드**: Actions 탭 → *TRADEX TestFlight* → Run workflow
  - FLYON과 같은 App Store Connect 시크릿 사용, 지금은 FLYON 앱 레코드(`com.flight.flyon`)로 올라감
  - 정식 출시 때는 TRADEX 전용 번들 ID와 App Store Connect 앱을 만들어 `project.yml`과 워크플로의 `BUNDLE_ID`를 바꿀 것

## 로컬 실행 (Mac)
```bash
brew install xcodegen
cd TRADEX && xcodegen && open TRADEX.xcodeproj
```
- Debug 빌드에는 "개발용 로그인" 버튼이 있어 Sign in with Apple 없이도 테스트 가능

## 구조
```
TRADEX/Sources/
├─ Sources/App/TRADEXApp.swift        앱 시작, 탭 구성
├─ Services/UpbitService.swift 업비트 REST(마켓·시세·캔들) + WebSocket 실시간
├─ Stores/MarketStore.swift    실시간 시세 상태 (0.3초 단위로 묶어서 화면 갱신, 자동 재연결)
├─ Stores/Wallet.swift         가상 지갑: TRADEX, 모의 원화, 매수·매도, 평가
├─ Stores/Session.swift        로그인 / 첫 로그인 10 TRADEX 지급 / 계정 삭제
├─ Models/…                    데이터 모델, 규칙(TradexRules)
├─ Views/…                     관심 · 거래소 · 코인 상세(차트) · 주문 · 자산 · 설정
└─ Components/…                테마(상승 빨강/하락 파랑), 포맷, 코인 아이콘, 깜빡이는 가격
```

규칙 값은 `Models/WalletModels.swift`의 `TradexRules`에서 바꿔요:
- 1 TRADEX = 10,000원, 첫 로그인 10 TRADEX, 수수료 0.05%, 최소 주문 5,000원

## 출시 전 체크리스트 ⚠️

**법적으로 꼭 지킬 것**
- [ ] TRADEX·모의 원화를 **현금, 기프티콘, 상품, 실제 코인으로 바꿔 주지 않기** (사행성·가상자산 규제 위험)
- [ ] TRADEX를 **돈 받고 팔지 않기**, **사용자끼리 주고받기 기능 만들지 않기**
- [ ] 수익률 랭킹에 **상품·상금 걸지 않기**
- [ ] "이 코인 사세요" 같은 **종목 추천 기능 넣지 않기** (유사투자자문 규제)
- [ ] **업비트 Open API 이용약관 확인** → 제3자 앱에 시세 표시가 허용되는지 업비트(두나무)에 문의하고 답변 보관
- [ ] 업비트·코인 프로젝트 **로고 사용 금지** (지금은 글자 아이콘으로 그림)
- [ ] **"TRADEX" 상표 검색** (KIPRIS, kipris.or.kr) — 같은 이름의 등록 상표가 있으면 이름 변경 고려

**앱스토어 심사**
- [ ] 개인정보처리방침·이용약관 페이지 만들고 `SettingsView.swift`의 example.com 주소 교체
- [ ] App Store Connect의 개인정보 항목(앱이 수집하는 데이터) 작성
- [ ] 개발자 계정은 만 18세 이상 명의로 등록 (미성년자면 보호자 명의)
- [ ] 스크린샷·설명에 "모의투자, 실제 거래 아님" 명시

## 다음에 붙이면 좋은 것
- 서버(Firebase 등): 지금은 지갑이 폰에만 저장돼서 앱 삭제 시 사라지고, 조작도 가능함 → 랭킹·커뮤니티를 하려면 서버 필요
- 서버를 붙이면 계정 삭제 시 Apple 토큰 폐기(revoke)도 구현해야 함
- 지정가 주문, 호가창, 수익률 차트
