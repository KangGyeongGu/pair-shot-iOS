# PairShot iOS — TestFlight 업로드 가이드

P10.6. roadmap 의 자동화 스코프를 벗어난 **사용자 직접 수행** 단계.
이 문서는 "Xcode Organizer 로 archive → TestFlight 업로드" 까지의
체크리스트와 주요 함정을 정리한다.

선결 조건:

- `docs/01-device-test-checklist.md` 의 모든 항목 통과
- App Store Connect 에서 PairShot 앱 레코드 생성 (Bundle ID = `com.pairshot.PairShot`)
- Apple Developer 멤버십 활성 + 팀 ID `RFS7L9397N` 액세스

---

## 1. 사전 교체 항목

### 1.1 AppIcon (P10.1 placeholder → 실 디자인)

`PairShot/PairShot/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
는 P10.1 에서 자동 생성된 brand-teal placeholder. 출시용 디자인 PNG 로
교체:

- 1024×1024, sRGB, no alpha
- single-size + light/dark/tinted 3 variant 유지 (Contents.json 그대로)
- 교체만 하고 commit (코드 변경 없음)

### 1.2 AdMob production unit ID (P10.5 placeholder → 실 ID)

`PairShot/PairShot/Config/Release.xcconfig` 의 5 키 모두
`INSERT_PRODUCTION_ID_HERE` 가 들어 있다.

1. AdMob 콘솔 → 앱 → 광고 단위 → 다음 5종 ID 발급:
   - Banner (`ADUNIT_ID_BANNER`)
   - Interstitial (`ADUNIT_ID_INTERSTITIAL`)
   - Rewarded (`ADUNIT_ID_REWARDED`)
   - Native (`ADUNIT_ID_NATIVE`)
   - App Open (`ADUNIT_ID_APP_OPEN`)
2. 각 placeholder 를 실제 `ca-app-pub-…/…` 형식 ID 로 교체
3. **commit 하지 말 것** (production ID 는 publish 직전 일회성 교체).
   `Release.xcconfig` 에 `*.local.xcconfig` include 패턴을 적용해 secret
   을 분리해도 되지만, MVP 단계는 단순화 위해 직접 교체로 진행
4. 교체 후 `xcodebuild -configuration Release build` 로 컴파일 통과 확인

> AdsConfig 안전망: placeholder 가 교체 안 되어 있으면 `AdsConfig.resolve(...)`
> 가 자동으로 Google 공식 테스트 ID 로 fallback 한다 (P10.5). 즉 잘못
> 업로드해도 production 광고가 잘못된 계정으로 흐르지 않고 테스트 ID
> 배너가 노출되어 즉시 발견 가능.

### 1.3 GADApplicationIdentifier 교체

`PairShot/PairShot/Info.plist` 의

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

은 Google 의 **테스트 앱 ID**. 출시 직전 AdMob 콘솔의 실 앱 ID
(`ca-app-pub-<publisher>~<app>`) 로 교체. 잘못된 ID 로 업로드 시 SDK
초기화 단계에서 크래시.

---

## 2. Build & Archive

### 2.1 Xcode 에서 archive

```
Product → Scheme → Edit Scheme → Run → Build Configuration: Release
Product → Destination: Any iOS Device (arm64)
Product → Archive
```

성공 시 Xcode Organizer 가 자동으로 열림.

### 2.2 Archive validation

Organizer → Archives → 가장 최신 → **Validate App**

- App Store Connect 자격 / Provisioning Profile 자동 매칭 (Automatic)
- Privacy Manifest 검증 (P10.3 의 `PrivacyInfo.xcprivacy`)
- ATT description 검증 (P10.2 의 `NSUserTrackingUsageDescription`)
- SKAdNetworkItems 51개 검증 (P6.1 / P10.3)

실패 시 보통 다음 중 하나:

- **Missing Compliance** — App Store Connect 의 "수출 규정 준수"
  항목을 채워야 함 (PairShot 은 표준 암호화만 사용, "비표준 알고리즘
  없음")
- **Missing Privacy Manifest entry** — Bundle 에 `PrivacyInfo.xcprivacy`
  가 포함되어 있는지, 누락된 NSPrivacyAccessedAPIType 이 있는지 확인
- **Bundle ID 불일치** — App Store Connect 에 `com.pairshot.PairShot`
  앱 레코드가 존재해야 함

### 2.3 Distribute App → App Store Connect

Organizer → Archives → 가장 최신 → **Distribute App** → **App Store Connect**
→ Upload → 자동 sign → 업로드.

업로드 후 App Store Connect → TestFlight 페이지에서 "처리 중" 상태가
약 5-30분 후 "테스트 준비 완료" 로 전환.

---

## 3. TestFlight 설정

### 3.1 빌드 정보

App Store Connect → TestFlight → iOS 빌드 → **빌드 정보**

- **베타 앱 설명** — 한국어 1-2 문단 (앱이 무엇을 하는지)
- **베타 앱 검토 정보** — 검토자가 사용할 데모 계정 (PairShot 은 계정
  불필요, "데모 계정 없음" 선택)
- **베타 앱 검토 메모** — 카메라/위치/사진 권한이 모두 정상 사유 임을
  명시 (`docs/01-device-test-checklist.md` 핵심 시나리오 요약)

### 3.2 그룹 / 테스터 추가

- 내부 그룹 (App Store Connect 사용자) — 검토 없이 즉시 배포
- 외부 그룹 — Apple 의 베타 검토 1-2 일 통과 후 배포

### 3.3 자동 업데이트 알림

- 새 빌드 업로드 시 기존 테스터에게 자동 알림 ON 권장

---

## 4. 검증 (TestFlight 빌드 → 디바이스)

기존 디바이스 체크리스트 (`docs/01-device-test-checklist.md`) 를
TestFlight 설치 빌드로 한 번 더 통과.

추가 확인:

- [ ] 광고 SDK 가 production ID 로 정상 로드 (배너/인터스티셜/네이티브 모두 실 광고가 표시되거나 Google "no fill" 스킵)
- [ ] 충돌 없음 — 1시간 사용 + 백/포그라운드 5회 + 카메라 50회 캡처
- [ ] 사진 앨범 권한 흐름 정상 (TestFlight 빌드는 sandboxed)

---

## 5. 다음 단계 (Phase 11)

이 가이드를 완주하면 PairShot iOS MVP 의 자율 phase 루프가 끝난다.
정식 App Store 출시는 별도 phase (roadmap P11) 로 분리:

- 스토어 등록 정보 (스크린샷 6.5"/6.7"/iPad / 설명 / 키워드)
- 개인정보처리방침 URL
- 앱 콘텐츠 양식 (연령 등급 / 데이터 수집 답변)
- 출시 국가
- App Store 검수 제출

이 단계는 사용자 결정 후 별도 진행.
