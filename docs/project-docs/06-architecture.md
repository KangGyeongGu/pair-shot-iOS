# 아키텍처

---

## 레이어 구조

```
PairShot/
├── App/              앱 부팅, AppEnvironment (DI), RootView
├── Features/         화면 + ViewModel (SwiftUI Views, @Observable)
│   ├── Home/  AlbumDetail/  PairPreview/
│   ├── CameraBefore/  CameraAfter/
│   ├── Export/  Settings/  Permissions/
├── Domain/
│   ├── Models/       값 객체 (PhotoPair, Album, CameraSettings, WatermarkSettings, CombineSettings, ExportHistory 등)
│   ├── Repositories/ protocol 만
│   ├── UseCases/     비즈니스 흐름 9종
│   ├── Services/     도메인 서비스
│   └── Util/         ExifGPSBuilder, validators (대부분 nonisolated)
├── Data/
│   ├── Models/       SwiftData @Model + Schema
│   ├── Repositories/ SwiftData impl (`@MainActor`)
│   ├── Storage/      PhotoLibraryService, AppSettingsKeys
│   ├── Camera/       AVFoundation 래퍼
│   ├── Sensors/      CoreMotion
│   ├── Location/     CoreLocation
│   ├── Composite/    UIGraphicsImageRenderer 합성
│   ├── Export/       ZIP + 임시 파일 + DocumentExporter
│   ├── Ads/          GoogleMobileAds 통합
│   ├── Coupon/       AdFreeStore + Keychain + 외부 redeem
│   └── Network/      CouponApiConfig
├── Shared/
│   ├── DesignSystem/ Color / Typography / Spacing / Materials / StripDesign
│   ├── Navigation/   Route enum, SettingsRedirectCoordinator
│   ├── Permissions/  PermissionDeniedView
│   ├── Ads/          NativeAdCard, PairListWithAdsBuilder
│   ├── UI/           SnackbarBanner, ActionBar, HighlightableCard 등
│   └── Util/         AppLogger, HapticService
├── Resources/        Localizable.strings (ko, en)
├── Assets.xcassets/  Colors / AppIcon (light + dark)
└── Config/           xcconfig (Debug / Release / Sample)
```

---

## 의존성 주입 (`App/AppEnvironment.swift`)

`@MainActor @Observable final class AppEnvironment` 단일 컨테이너.

### 보유 의존성

| 카테고리 | 항목 |
|---|---|
| Repos (2) | `pairRepo`, `albumRepo` |
| Data services (5) | `location`, `couponApiConfig`, `deviceHashProvider`, `photoLibraryExporter`, `photoLibrary` |
| UseCases (9) | `createPair`, `captureAfter`, `recaptureAfter`, `deletePairs`, `deleteCombinedExports`, `deletePairsKeepingCombined`, `exportPairs`, `toggleAlbumMembership`, `immediateExport` |
| Settings | `appSettings`, `appSettingsRepo` |
| Ads / Coupon (8) | `adFreeStore`, `trackingService`, `interstitialAdManager`, `rewardedAdManager`, `nativeAdLoader`, `appOpenAdManager`, `fullscreenAdCoordinator`, `consentManager` |
| Shared services (6) | `snackbarQueue`, `settingsRedirectCoordinator`, `permissionStatusService`, `thumbnailCache`, `hapticService`, `motionService` |
| ViewModel factories | `makeBeforeCameraViewModel`, `makeAfterCameraViewModel`, `makePairPreviewViewModel`, `makeAlbumDetailViewModel`, `makePairPickerViewModel`, `makeHomeViewModel`, `makeSettingsViewModel`, `makeWatermarkSettingsViewModel`, `makeCombineSettingsViewModel`, `makeExportSettingsViewModel` |

### Factory 분리
`AppEnvironment+Factories.swift` 에서 `makeFoundation` / `makeDataServices` / `makeAdServices` / `makeUseCases` 로 구성 단계 분리. Tests / Previews 에서 override 가능.

### 사용
뷰는 `@Environment(AppEnvironment.self)` 로 주입받음.

---

## 라우팅

### NavigationStack
- 단일 `NavigationStack(path: $path)` (`App/RootView.swift`)
- root = `BeforeCameraView`
- `path` 는 RootView 의 `@State [Route]`, 자식 뷰에 `$path` 전달

### Route enum (`Shared/Navigation/Route.swift`)
`Hashable, Codable`:

`home`, `albumDetail(UUID)`, `pairPreview(UUID)`, `settings`, `watermarkSettings`, `combineSettings`, `license`, `exportSettings([UUID])`, `languagePicker`, `themePicker`, `imageQualityPicker`, `filenamePrefixEditor`

`navigationDestination(for: Route.self)` 단일 switch.

### Deep link
없음 (`.onOpenURL` 미사용).

### SettingsRedirectCoordinator (`Shared/Navigation/SettingsRedirectCoordinator.swift`)
- `pendingPulse: SettingsPulseTarget?` (`.watermark` / `.combine`)
- Settings 진입 시 `consume` → 해당 행 pulse 애니메이션 (`HighlightableCard`)
- Export 의 "User settings" 진입 흐름에서 사용

### 권한 게이트
`PermissionGateView` 는 NavigationStack 외부 ZStack 분기. 차단 시 nav 진입 자체 불가.

---

## Concurrency

### Default isolation
- 빌드 설정: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (SE-0466)
- 모든 struct / enum / class 의 default = `@MainActor`
- `nonisolated` 표기는 명시적 격리 분리

### MainActor isolated
거의 모든 ViewModel · Service · `AppEnvironment` 가 `@MainActor @Observable final class`.

### Nonisolated (의도된 분리)

| 컴포넌트 | 이유 |
|---|---|
| `AppLogger` | OSLog facade |
| `AppSettingsKeys` | 상수 모음 |
| `KeychainDeviceUUID` | Keychain I/O |
| `DeviceHashProvider` | SHA256 |
| `AdFreeStatusFetcher` | URLSession 호출 |
| `CouponApiConfig` | 값 객체 |
| `ExifGPSBuilder` | 메타데이터 빌더 |
| `UserDefaultsAppSettingsRepository` | `@unchecked Sendable` snapshot |
| `AppLanguage` enum | 값 enum |

### Actor 사용

| Actor | 역할 |
|---|---|
| `FullscreenAdCoordinator` | 전면 광고 동시 노출 mutex |
| `ZipExporter` | ZIP I/O 직렬화 (`ZipExporterAdapter` nonisolated wrapper 제공) |

### Delegate 가교
AdMob (Interstitial / Rewarded / AppOpen / Native) 과 `PermissionStatusService` 의 delegate 콜백은 `nonisolated func` → `Task { @MainActor [weak self] }` 로 hop.

### Sendable 처리
- `@preconcurrency import GoogleMobileAds`, `@preconcurrency import AVFoundation`, `@preconcurrency import CoreMotion`
- `final nonisolated class XxxBox: @unchecked Sendable` — AdMob completion 결과를 MainActor 로 안전 hop (Interstitial / Rewarded / AppOpen)
- `CameraSession: @unchecked Sendable` + `sessionQueue` 패턴

---

## 디자인 시스템 (`Shared/DesignSystem/`)

### Color (Asset Catalog)
`Assets.xcassets/Colors/` 에 라이트 / 다크 페어:
- `appSurfaceContainer`, `appOnSurfaceVariant`
- `appCameraBackground`, `appLetterbox`
- `appSnackbarSuccess` / `Error` / `Warning` / `Info`
- 별도: `AccentColor`

`ColorRGBA ↔ SwiftUI.Color ↔ UIKit.UIColor` 변환 helper.

### Typography (`Typography.swift`)
`appBody` / `appCaption` / `appCaptionBold` / `appLabel` — 시스템 Font wrapper, Dynamic Type 위임.

### Spacing (`Spacing.swift`)
`AppSpacing.sm = 8`, `md = 12`, `lg = 16`, `xxl = 32` (4개만 정의).

### Strip (`StripDesign.swift`)
카드 100×134, cornerRadius 10, spacing 8, padding V17 H20, activeScale 1.0 / inactiveScale 0.85, activeBorder yellow 3pt / inactive white@0.3 1pt.

### 다크모드
- `AppTheme.preferredColorScheme: ColorScheme?` 매핑 — `system → nil`, `light → .light`, `dark → .dark`
- `PairShotApp.body` 가 `.preferredColorScheme(env.appSettings.resolvedColorScheme)` 전역 적용
- 네비게이션 바도 `toolbarColorScheme(colorScheme, for: .navigationBar)` 동기화

### iOS 26+ Liquid Glass (`Materials.swift`)
- `View.adaptiveGlass(in:kind:)` modifier
- iOS 26+ — `.glassEffect(.regular, in: shape)` (`#available(iOS 26.0, *)`)
- 이전 버전 — `.regularMaterial` / `.thinMaterial` / `.thickMaterial` 또는 사용자 지정 fill
- `AdaptiveGlassKind = .regular | .thin | .thick`
- 사용처: `SnackbarBanner`, `PairShotActionBar`

---

## 로깅

`AppLogger` (`Shared/Util/AppLogger.swift`) — `nonisolated enum`.

- subsystem = `Bundle.main.bundleIdentifier ?? "com.pairshot"`
- 카테고리 3종
  - `camera` — CameraSession / interruption / zoom / focus / MotionService / LocationService
  - `storage` — PhotoLibraryExport
  - `ads` — 모든 광고 매니저, Banner, FullscreenAdCoordinator
- 모든 메시지는 `privacy: .public`
- 별도 분석 / telemetry SDK 없음 (OSLog 만)

---

## 빌드 설정

| 설정 | 값 |
|---|---|
| Deployment Target | iOS 17.0 |
| Swift Version | 6.0 |
| `SWIFT_STRICT_CONCURRENCY` | `complete` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` |
| `TARGETED_DEVICE_FAMILY` | 1 (iPhone only) |
| `UISupportedInterfaceOrientations` | Portrait only |
| Bundle ID | `com.pairshot.PairShot` |
| Marketing Version | 1.0.0 |
| `ITSAppUsesNonExemptEncryption` | `false` |

## 외부 의존성 (3종)

| 패키지 | 용도 |
|---|---|
| Google Mobile Ads SDK | Banner / Interstitial / Rewarded / Native / AppOpen |
| Google User Messaging Platform (UMP) | GDPR / 동의 |
| ZIPFoundation | Export ZIP 출력 |
