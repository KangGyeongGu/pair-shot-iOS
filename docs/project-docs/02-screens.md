# 화면별 기능 명세

단일 `NavigationStack(path: $path)`, root = Before 카메라. 모든 라우팅은 `Route` enum (`Shared/Navigation/Route.swift`, `Hashable, Codable`) 으로 typesafe.

---

## 1. Before 카메라 (root · `Features/CameraBefore/`)

화면을 4:3 (가로:세로 3:4) 카메라 프리뷰 + 대기 페어 가로 캐러셀(strip) + 116pt 하단 바로 구성. 비-AdFree 시 상단에 `BannerAdSlot` 오버레이.

### 프리뷰 영역 오버레이
- 3×3 그리드 (토글)
- 수평계 — `LevelIndicator`, CoreMotion roll 을 도(°) 단위로 표시
- 포커스 reticle — 탭한 위치 70×70 노란 사각, 1초 페이드
- 줌 컨트롤 — 프리셋 칩 + 다이얼
- 렌즈 플립 버튼 — 전·후면

### 인터랙션
- **핀치** — `AVCaptureSession.ramp(toZoomFactor:rate:6.0)`
- **탭** — 포커스 + 노출 reticle, `setExposureTargetBias` 초기화
- **수직 드래그** — 노출 보정 (EV bias)
- **줌 다이얼 드래그** — 600pt 가동 범위, minor/major tick 햅틱
- **프리셋 칩 탭** — ramp rate 32 로 빠르게 이동
- **셔터** — heavy 햅틱, EXIF GPS 부여, PhotoKit 저장, 페어 생성

### 설정 시트 (톱니 아이콘)
- 그리드 on/off
- 플래시 — off → on → auto → torch 순환
- 야간 모드 — `automaticallyEnablesLowLightBoostWhenAvailable`
- 수평계 on/off

### 셔터 동작
- `captureReadiness == .ready` 확인 (`AVCapturePhotoOutputReadinessCoordinator`)
- `ExifGPSBuilder` 가 현재 캐시된 위치로 GPS 메타데이터 빌드 → photo settings 의 `metadata` 에 주입
- Deferred photo proxy 지원 — `isAutoDeferredPhotoDeliveryEnabled` 활성 시 `.photoProxy` 리소스 타입으로 PhotoKit 저장
- 일반 캡처는 `.photo` 리소스 타입, `uniformTypeIdentifier = "public.jpeg"`
- `refillPairId` 있으면 기존 페어의 before 만 교체 (`CreatePairUseCase.refillBefore`), 아니면 새 페어 생성 (`CreatePairUseCase`)
- 앨범 컨텍스트에서 진입한 경우 자동으로 `albumRepo.addPair`

### 하단 바
- 좌측: 마지막 썸네일 또는 홈 아이콘 → 탭 시 홈으로 이동
- 중앙: 셔터
- 우측: After 모드 진입 또는 설정 시트

---

## 2. After 카메라 (`Features/CameraAfter/`)

Before 와 동일 골격에 다음 추가:

- **Ghost overlay** — 선택된 페어의 Before 사진을 alpha 0.0~1.0 (기본 0.35) 로 90° 회전 표시 (`scaledToFit`). PhotoKit `requestImageData` → `Task.detached(.userInitiated)` 로 디코딩 후 `.up` 방향으로 재포장.
- **회전 안내** (`RotationGuideOverlay`) — 촬영 당시 orientation 과 현재 device orientation 차이가 있으면 1초 펄스 화살표 (`arrow.counterclockwise` / `clockwise`).
- **Strip** — 대기 페어 가로 캐러셀, 탭 시 페어 전환 (light 햅틱).
- **줌 복원** — 페어 전환 시 해당 페어의 `cameraSettings.zoomFactor` 자동 복원, 실제 적용된 ratio 를 UI 에 반영.
- **수평계 / 포커스 인디케이터 없음** (Before 전용).
- **설정 시트 추가 항목** — overlay on/off + alpha 슬라이더.

### 셔터 동작
- `currentPair` 필수
- PhotoKit 저장 → 즉시 strip 에서 해당 페어 제거 + 다음 페어로 advance (`contractPairsAndAdvance`)
- `recapture` 모드 → `RecaptureAfterUseCase` (기존 after + combined export 자산 정리 후 신규 기록)
- 일반 → `CaptureAfterUseCase`
- 실패 시 `rollbackOnPersistFailure`
- 모든 페어 완료 시 `allCompleted=true` + 2초 후 dismiss

---

## 3. 홈 (`Features/Home/`)

**상단**: 배너 + 필터 (Pairs / Albums) + 정렬 (newest / oldest)

### Pairs 모드
- 2 컬럼 `LazyVGrid`, aspect 1.8 카드 (`HomePairCardView`)
- 카드: before/after split, `hasCombinedExport` 시 `square.on.square` 배지
- 날짜 시작일 그룹 헤더
- 4 페어마다 `NativeAdCard` 1개 삽입 (최소 3 페어부터 광고 노출, `PairListWithAdsBuilder`)
- 빈 상태: `camera.viewfinder` SF Symbol + 로컬라이즈 헤드라인

### Albums 모드
- `List(.insetGrouped)` + 날짜 헤더 + `HomeAlbumCardView`
- 빈 상태: `rectangle.stack` SF Symbol

### 페어 탭 동작 (`HomeViewModel.tapPair`)
- `.afterOnly` → Before 카메라 refill 모드
- `.scheduled` → After 카메라
- `.captured` → PairPreview 시트

### 컨텍스트 메뉴 / 스와이프 (페어)
- 재촬영(after) / Share / Save to device / Delete

### 선택 모드
- 상단 좌측 체크 아이콘으로 진입
- 하단 바: Share / Save to device / Delete / Export settings 4 버튼
- 삭제 다이얼로그: All / Original only / Combined only / Cancel (combined-only 는 `hasCombinedExport` 시만)

### 하단 액션 (비선택)
- Pairs 모드: "Start capture" → Before 카메라
- Albums 모드: "Create album" → 위치 reverse geocode 시도 후 이름 입력 다이얼로그

---

## 4. 앨범 상세 (`Features/AlbumDetail/`)

홈 페어 모드와 동일한 그리드. NavigationTitle = 앨범 이름. `@Query` filter `id == albumId`.

### 툴바 (비선택)
- Select / Rename / Delete album

### Long-press
즉시 선택 모드 진입 + 해당 페어 선택 (`AlbumDetailViewModel.longPressPair`).

### 하단 바
- 비선택: Start capture + Add pair (PairPicker 시트 → 기존 페어 다중 선택해 멤버십 토글)
- 선택: Share / Save / Delete / Export settings

### 이름 변경
alert + textfield, trim 후 `albumRepo.update`.

### 앨범 삭제 다이얼로그
- "Album only" — 페어는 보존, 관계만 nullify
- "Album with pairs" → 2차 다이얼로그: All / Original only / Combined only

---

## 5. 페어 프리뷰 (`Features/PairPreview/`)

홈에서 `captured` 페어 탭 시 시트로 표시 (`.presentationDetents([.medium, .large])`, drag indicator).

- 사용자 설정대로 합성된 단일 이미지 (`CompositeRenderer`) 를 표시 — 슬라이드/오버레이 비교 UI 없음
- 핀치 줌 1.0 ~ 4.0, 더블탭 reset
- 하단 배너
- 합성 옵션: `appSettings.combineSettings` direction, JPEG quality 0.95, `includeGPS = appSettings.embedGPSInPhoto`

---

## 6. Export 설정 (`Features/Export/`)

페어/앨범 선택 후 "Export settings" 진입 시 표시.

### 4 섹션
1. **Includes** — Combined / Before / After 3 토글 + Photos 권한 limited 시 access 버튼
2. **Format** — Individual images / ZIP 인라인 picker
3. **Watermark** — 적용 토글 + "User settings" 행 (Rewarded gate 통과 후 WatermarkSettings 진입)
4. **Combine** — 적용 토글 + "User settings" 행 (Rewarded gate 통과 후 CombineSettings 진입)

### Rewarded gate
`RewardedSessionGate` 가 unlockID 별로 세션 단위 캐시 (`.watermarkSettings`, `.compositionSettings`). 첫 진입 시 보상형 광고 후 unlock.

### 툴바
- **Share** — `UIActivityViewController`
- **Save to device** — Individual 은 PhotoKit, ZIP 은 `UIDocumentPickerViewController(forExporting:asCopy:)` 로 사용자 선택 폴더
- 두 액션 모두 진행 전 Interstitial gate

### 기본값 (UserDefaults `pairshot.export*`)
combined=true, before=false, after=false, format=individualImages, applyWatermark=false, applyCombine=true.

### 진행 표시
`SnackbarQueue.enqueueProgress / updateProgress / completeProgress / cancelProgress`, individual 은 entry 처리 비례.

---

## 7. 설정 (`Features/Settings/`)

### 8 섹션
1. **General** — Language / Theme
2. **Capture & File** — Image quality / Ghost overlay opacity toggle+slider / Filename prefix
3. **Watermark** — 적용 토글 + 진입
4. **Combine** — 진입
5. **Privacy** — Embed GPS in photo
6. **Promotion code** — 쿠폰 페이지 (SFSafariViewController) + 활성 시 만료/잔여일 footer
7. **Privacy options** — UMP 동의 재선택
8. **Storage info** — 사진 용량 / 캐시 + 비우기 / 앱 버전 / License / Privacy Policy URL

### 서브스크린 7개 (Route enum 으로 push)

| Route | 화면 | 설정 항목 |
|---|---|---|
| `.combineSettings` | CombineSettingsView | direction (horizontal/vertical), border (toggle/thickness/color), label (toggle/before·after 텍스트/사이즈/색상/mode·position), label background (toggle/matchBorder/color/opacity/cornerRadius) |
| `.filenamePrefixEditor` | FilenamePrefixView | TextField, `FileNamePrefixValidator.sanitize` 적용 (32자, `/\:?*"<>|` + 제어/개행 제거) |
| `.imageQualityPicker` | ImageQualityPickerView | `CaptureQualityPreset.allCases` 라디오 |
| `.languagePicker` | LanguagePickerView | System / Korean / English (`AppLanguage`). 변경 시 `AppLanguageBundleSync.apply` + 재시작 안내 alert |
| `.license` | LicenseView | Google Mobile Ads SDK / Google UMP / ZIPFoundation 3건 — 외부 URL 오픈 |
| `.themePicker` | ThemePickerView | System / Light / Dark (`AppTheme`) |
| `.watermarkSettings` | WatermarkSettingsView | type (text/logo) — 텍스트는 (text, opacity, textSizeRatio, lineCount, repeatCount), 로고는 (PhotosPicker 선택, alpha, widthRatio, 3×3 position). 로고는 PNG 정규화 max 1024px |

### SettingsRedirectCoordinator
Export 의 watermark/combine "User settings" 진입 시 Settings 화면의 해당 행을 pulse 애니메이션으로 강조.

---

## 8. 권한 게이트 (`Features/Permissions/`)

카메라 또는 사진 라이브러리가 denied/restricted 면 `PermissionGateView` 가 NavigationStack 외부에서 전체 화면으로 표시:
- `lock.shield.fill` SF Symbol
- 차단된 권한 목록
- "설정 열기" 버튼 → `UIApplication.shared.open(.settingsURL)`

카메라만 거부된 상태에서 카메라 화면 직접 진입 시: 인라인 `PermissionDeniedView` (`ContentUnavailableView` + 설정 열기 버튼).

위치 거부 시: 촬영은 정상, EXIF GPS 만 누락.

---

## 광고 노출 요약

| 광고 | 노출 위치 |
|---|---|
| Banner | Home / AlbumDetail / PairPreview / Before·After 카메라 / Export / Settings + 일부 서브스크린 |
| Native | Home·AlbumDetail 그리드 안 (4 페어당 1, 최소 3 페어부터) |
| Interstitial | share / save / delete 등 굵직한 액션 직전 (Home / AlbumDetail / Export) |
| Rewarded | Export 의 Watermark·Combine 설정 진입 게이트 |
| AppOpen | 콜드스타트 (Before 카메라 첫 진입, 카메라 권한 granted 시 1회) / 백그라운드 dwell ≥ 30초 복귀 시 |

AdFree 상태에서는 모든 광고와 Rewarded gate 가 우회됨.
