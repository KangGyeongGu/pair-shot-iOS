# 광고 & 쿠폰

---

## 광고 5종

### Banner (`Data/Ads/BannerAdView.swift`)
- `BannerAdSlot` View — `BannerAdGate.shouldShow(isAdFree:)` 가드 통과 시 표시
- `GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth`
- width 변화 ≥ 1.0pt 일 때만 reload
- 노출 화면: Home / AlbumDetail / PairPreview / Before·After 카메라 / Export / Settings + 일부 서브스크린

### Interstitial (`Data/Ads/InterstitialAdManager.swift`)
- 5초 cooldown
- `runGated(...)` 로 액션 직전에 게이팅
- 사용처: Home/AlbumDetail/Export 의 share / save / delete 액션 전

### Rewarded (`Data/Ads/RewardedAdManager.swift`)
- `UnlockID = .compositionSettings | .watermarkSettings`
- 세션 단위 `sessionUnlocks: Set<UnlockID>` 캐시
- 사용처: Export 의 워터마크·합성 설정 진입 게이트 (`ExportSettingsViewModel+Gate.swift`)

### Native (`Data/Ads/NativeAdLoader.swift`)
- 5개 단위 prefetch (앱 부팅 / 백그라운드 복귀 시)
- dequeue 후 캐시 < 2 면 재 prefetch
- 표시: `NativeAdCard(slotIndex:)` — Home / AlbumDetail 그리드 안
- 슬롯 결정 (`PairListWithAdsBuilder`): 4 페어마다 1 광고, 최소 3 페어부터 노출

### AppOpen (`Data/Ads/AppOpenAdManager.swift`)
- 최소 60초 interval (`AppOpenAdGate.defaultMinimumInterval`)
- 5초 load 폴링
- 트리거 2가지
  1. **콜드스타트** — `BeforeCameraView` 첫 진입 후 카메라 권한 granted 시 1회 (`hasPresentedColdStartAppOpen` 가드)
  2. **백그라운드 복귀** — background dwell ≥ 30초 (`backgroundDwellThreshold`)

---

## SDK 초기화 & 동의 흐름 (`App/PairShotApp.swift`)

순서:
1. 권한 일괄 요청 (Camera → Photo → Location)
2. ATT — `TrackingAuthorizationService.requestIfUndetermined`
3. UMP — `ConsentManager.bootstrap` (`requestConsentInfoUpdate` → `loadAndPresentIfRequired` → `refreshFlags`)
4. `canRequestAds == true` 일 때만 `GADMobileAds.sharedInstance().start()` → `adFreeStore.refresh()` → 모든 매니저 `loadIfNeeded` + Native prefetch
5. `onChange(canRequestAds)` — consent 사후 ack 시점에도 ads 시작

`hasBootstrappedAds` 가드로 SDK 시작 중복 방지.

---

## ATT (`Data/Ads/TrackingAuthorizationService.swift`)

- `ATTrackingManager.requestTrackingAuthorization`
- 결과는 `AdRequestBuilder.build(attStatus:)` 에서 `npa=1` extras 부착 여부 결정
- `shouldAttachNonPersonalised: attStatus != .authorized` — 비허가 시 비개인화 광고 요청

---

## Consent / UMP (`Data/Ads/ConsentManager.swift`)

`@MainActor @Observable`.

- `bootstrap()` — `UMPConsentInformation.sharedInstance().requestConsentInfoUpdate` + `UMPConsentForm.loadAndPresentIfRequired` + `refreshFlags`
- `tagForUnderAgeOfConsent = false` 고정
- 노출 값: `canRequestAds`, `canShowPrivacyOptionsButton`
- `presentPrivacyOptions()` — Settings → Privacy options 행 진입 시 호출
- `canImport(UserMessagingPlatform)` 가드 — SDK 미존재 시 `canRequestAds = true` fallback

---

## AdMob 키 (`Data/Ads/AdsConfig.swift`)

### 진입점
`AdsConfig.banner / .interstitial / .rewarded / .native / .appOpen` — 광고 ID 가 필요한 모든 곳의 단일 진입점.

### Resolution 로직
- `#if DEBUG` — Google 공식 테스트 ID (5종 하드코딩)
- Release — Info.plist 의 `AdUnitID_*` 값을 읽고, 비어있거나 `INSERT_PRODUCTION_ID_HERE` 면 테스트 ID 로 fallback

### Info.plist ↔ xcconfig 매핑

| Info.plist Key | xcconfig 변수 |
|---|---|
| `GADApplicationIdentifier` | `$(GAD_APPLICATION_ID)` |
| `AdUnitID_Banner` | `$(ADUNIT_ID_BANNER)` |
| `AdUnitID_Interstitial` | `$(ADUNIT_ID_INTERSTITIAL)` |
| `AdUnitID_Rewarded` | `$(ADUNIT_ID_REWARDED)` |
| `AdUnitID_Native` | `$(ADUNIT_ID_NATIVE)` |
| `AdUnitID_AppOpen` | `$(ADUNIT_ID_APP_OPEN)` |

실제 값은 `Config/Release.xcconfig` (production), `Config/Debug.xcconfig` (테스트 App ID 만 — ad unit 은 코드 fallback) 에 보관. 두 파일은 `.gitignore` 대상이며 `Config/Sample.xcconfig` 가 git 추적 템플릿.

---

## FullscreenAdCoordinator (`Data/Ads/FullscreenAdCoordinator.swift`)

`actor` — 동시에 둘 이상의 전면 / 보상형 / 앱오프닝 광고 노출 방지.

- `tryAcquire()` → 이미 표시 중이면 `false`, 이번 노출 skip
- `release()` 호출 후 다시 acquire 가능
- EnvironmentValues `@Entry var fullscreenAdCoordinator` 로 주입
- Interstitial / Rewarded / AppOpen 모두 present 전 `await coordinator.tryAcquire()` 통과 필요

---

## AdFreeStore (`Data/Coupon/AdFreeStore.swift`)

### 상태
- `isAdFree: Bool`
- `expiresAt: Date?`
- `remainingDays: Int?`
- `couponCount: Int`

### 스냅샷
- UserDefaults `pairshot.adFreeStore.snapshot` JSON (ISO8601)
- 오프라인에서도 마지막 상태 유지

### 갱신 시점
- 앱 부팅 시 `adFreeStore.refresh()`
- 백그라운드 → 활성 복귀 시 매번

### 광고 차단
모든 광고 매니저의 `loadIfNeeded` / `showIfAvailable` / `presentIfReady` / `prefetch` 첫 줄에서 `if adFreeStore.isAdFree { return }` 로 단락. Banner 는 `BannerAdGate.shouldShow(isAdFree:)`.

---

## 쿠폰 (외부 처리)

앱은 쿠폰 검증 로직을 가지지 않음. `SFSafariViewController` 로 외부 페이지를 열어 사용자가 처리.

### 진입
- Settings → Promotion code 행
- `CouponRedemptionLink.open(config:deviceHashProvider:)`
- URL: `{baseUrl}/redeem?d={deviceHash}` (deviceHash = SHA256(Keychain UUID).hex)

### 광고 제거 상태 조회
- GET `{baseUrl}/api/pairshot/ad-free?d={deviceHash}`
- Timeout: 10초
- Response DTO (snake_case → camelCase)

| 필드 | 타입 |
|---|---|
| `active` | `Bool` |
| `expires_at` | `Date?` (ISO8601) |
| `remaining_days` | `Int?` |
| `coupon_count` | `Int` |

### baseUrl 설정
- Info.plist `CouponApiBaseUrl = https://$(COUPON_API_HOST)`
- `$(COUPON_API_HOST)` 는 xcconfig (`Debug.xcconfig`, `Release.xcconfig`) 에서 주입
- `CouponApiConfig.isEnabled = !baseUrl.isEmpty` — 호스트가 비어있으면 쿠폰 기능 자체가 disabled
