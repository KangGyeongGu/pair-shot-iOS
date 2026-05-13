# PairShot iOS — Overview

## 정체성

현장 작업의 Before / After 사진 쌍을 촬영·관리·내보내기 위한 iOS 네이티브 앱.

## 핵심 기능

1. **Before / After 쌍 촬영** — Before 촬영 후 같은 구도로 After 를 촬영할 수 있도록 ghost overlay 와 회전 안내를 제공.
2. **앨범 관리** — 페어를 앨범으로 묶고 이름·위치를 부여, 멤버십 토글로 다대다 관리.
3. **합성 / 내보내기** — Before·After 를 가로 또는 세로로 합성, 워터마크·라벨·테두리 적용 후 사진 앨범 저장 / 공유 / ZIP 출력.
4. **광고 기반 수익화** — Banner / Interstitial / Rewarded / Native / AppOpen 5종 노출, 외부 처리 쿠폰으로 광고 제거 옵션.

## 기술 스택

- Swift 6, strict concurrency `complete`, SE-0466 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- SwiftUI · iOS 17.0+, iPhone 전용, Portrait 고정
- AVFoundation (카메라), CoreMotion (수평계 — roll 한정), CoreLocation (EXIF GPS), PhotoKit (사진 본체 저장)
- SwiftData (모델 영속화), UserDefaults (설정), Keychain (디바이스 UUID 1건)
- UIGraphicsImageRenderer + ImageIO (합성·EXIF 작성), ZIPFoundation (ZIP)
- Google Mobile Ads SDK + Google User Messaging Platform (UMP), App Tracking Transparency
- 외부 의존성은 GoogleMobileAds, UserMessagingPlatform, ZIPFoundation 3종으로 한정 (AR / Vision / Core Image 자동정렬 등 미사용)

## 권한 (Info.plist 사용 설명 5종)

| 권한 | Info.plist Key | 한국어 설명 |
|---|---|---|
| 카메라 | `NSCameraUsageDescription` | 현장 작업의 Before/After 사진을 촬영하기 위해 카메라를 사용합니다. |
| 위치 (사용 중) | `NSLocationWhenInUseUsageDescription` | 새 프로젝트 생성 시 촬영 위치를 자동으로 기록해 같은 현장의 사진을 묶어 보여드리기 위해 위치를 사용합니다. |
| 사진 추가 | `NSPhotoLibraryAddUsageDescription` | 촬영하거나 합성한 Before/After 사진을 기기 사진 앨범에 저장하기 위해 사진 라이브러리 쓰기 권한을 사용합니다. |
| 사진 접근 | `NSPhotoLibraryUsageDescription` | 촬영한 Before/After 사진을 기기 사진 앨범에 저장하고, 사용자가 앨범에서 변경한 사진을 페어 카드에 동기화하기 위해 사진 라이브러리 접근이 필요합니다. |
| 추적 (ATT) | `NSUserTrackingUsageDescription` | 관심사에 맞는 광고를 보여드리기 위해 추적 권한을 요청합니다. 거부하셔도 앱의 모든 기능을 정상적으로 사용하실 수 있습니다. |

## 부팅 순서

1. **ModelContainer 부트스트랩** — Application Support 디렉토리에 SwiftData 컨테이너 생성. 실패 시 `isStoredInMemoryOnly: true` fallback 후 UI alert 노출.
2. **AppEnvironment 생성** — 단일 DI 컨테이너 (Repos / UseCases / Services / Ad managers / ViewModel factories).
3. **AppLanguage 적용** — `AppleLanguages` UserDefaults 에 사용자 설정 언어 주입.
4. **권한 일괄 요청** — `RootView.task` 안에서 Camera → Photo → Location 순차 요청 (`pairshot.permissions.requestedInitialBundle` 표식으로 1회만).
5. **ATT 요청** — `TrackingAuthorizationService.requestIfUndetermined()`.
6. **UMP 동의** — `ConsentManager.bootstrap()` (`requestConsentInfoUpdate` → `loadAndPresentIfRequired` → `refreshFlags`).
7. **광고 SDK 시작** — `canRequestAds == true` 일 때만 `GADMobileAds.start()` → `adFreeStore.refresh()` → 모든 매니저 `loadIfNeeded` + Native 5개 prefetch.
8. **첫 화면** — `BeforeCameraView` (NavigationStack root).

## 문서 인덱스

- `02-screens.md` — 화면별 기능 명세
- `03-data-model.md` — SwiftData 모델 / UserDefaults / Keychain / 파일 저장
- `04-capture-and-export.md` — 카메라 / 센서 / EXIF / 합성 / ZIP
- `05-ads-and-coupon.md` — 광고 5종 / Consent / ATT / AdFree / 쿠폰
- `06-architecture.md` — 레이어 / DI / Navigation / Concurrency / 디자인 시스템 / 로깅
