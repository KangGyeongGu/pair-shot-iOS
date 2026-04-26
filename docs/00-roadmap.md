# PairShot iOS — Roadmap

작업 진행 단일 추적. Android v1.1.3 MVP와 **사용자 기능 동등**, **iOS 네이티브 구현**.

각 task는 **SCOPE(허용 경로) + Refs(읽을 ref) + Done(검증 기준)** 을 명시. implementer subagent가 그대로 받아 작업 가능.

---

## 작업 워크플로우 (반드시 준수)

- **Branch**: 각 phase는 `feature/ios-mvp/<NN-name>` 별도 브랜치. main/develop 직접 수정 금지.
- **1 task = 1 commit**: roadmap 한 task 끝낼 때만 commit.
- **단일 commit에 묶을 항목**:
  1. 코드·테스트 변경
  2. `docs/00-roadmap.md`의 `[ ]` → `[x]` + "현재 상태" 갱신 + 진행 로그 1줄
  3. 그 task가 만든 doc 변경 (refs 업데이트 등)
- **금지**: doc-only commit · "fix typo" 후속 commit · `Co-authored-by` · `--no-verify` · `git add -A`
- **자투리 변경**: 직전 task commit에 `git commit --amend`
- **Push**: 사용자 명시 지시 시만. 자동 push 절대 금지.
- **Phase 종료 시**: branch에서 main/develop으로 squash merge 여부는 사용자가 직접 결정.

---

## 핵심 원칙 (Phase 0~11 공통)

1. **AVFoundation only**. ARKit / Vision auto-alignment / LiDAR / 자동 색보정 절대 추가 금지
2. **Sensor input은 CoreMotion `roll`만** (수평계 1줄)
3. **Before overlay = 단순 반투명 UIImage + alpha slider** (자동정렬 0)
4. **SwiftData 영속화는 `Project`·`PhotoPair`·`Coupon` 셋만**. 파일은 컨테이너에 저장
5. **Android 구현 방식 모방 금지** — 사용자 결과만 같으면 됨
6. **외부 의존성 = ZIPFoundation + Google Mobile Ads SDK 둘만**. Ed25519/QR은 Apple 표준(CryptoKit/AVFoundation)
7. **AdFree 상태 활성 시 광고 호출 자체를 안 함** (불필요 네트워크/ATT 트리거 회피)

---

## Specification (Ground Truth)

사용자 가시 동작 + 아키텍처의 1차 SoT 는 `docs/10-*.md` ~ `docs/17-*.md`. 본 roadmap 의 Phase Done 조건은 시점별 구현 진행을 기록한 것이며, **현행 코드의 정합성 기준은 항상 다음 spec 문서가 우선**한다 (코드↔spec 충돌 시 코드를 고친다).

| Spec | 영역 | 본 roadmap 매핑 |
|------|------|----------------|
| `docs/10-product-overview.md` | 제품 정의·사용자 시나리오·핵심 entity (페어 / 앨범) | 전체 (특히 Phase 1·핵심 원칙 4) |
| `docs/11-information-architecture.md` | 화면 위계·진입점(시작 화면 = Camera Before)·전이 | Phase 1·Phase 2·Phase 3·Phase 4·전체 navigation |
| `docs/12-screens.md` § 12.1~12.6 | Camera(Before/After)·Home·AlbumDetail·PairPicker·PairPreview | Phase 2 (12.1)·Phase 3 (12.2)·Phase 4 (12.3·12.6)·신규 AlbumDetail/PairPicker (12.4·12.5) |
| `docs/12-screens.md` § 12.7~12.11 | Settings·WatermarkSettings·CombineSettings·ExportSettings·License | Phase 8 (12.7)·신규 12.8/12.9 (워터마크/합성 상세)·Phase 7 (12.10)·신규 12.11 (License) |
| `docs/13-data-model.md` | PhotoPair·Album·Coupon·CameraSettings·AppSettings·파일 명명·EXIF·Stale URI 가드·백업 | Phase 1·Phase 2.6·Phase 3.4·Phase 5.2·Phase 6.3·Phase 8.2·Phase 8.4 |
| `docs/14-functional-requirements.md` | Capture·Composite·Share/Save/Export·Selection·Sort/Filter·Re-capture·위치·동시성·스낵바·권한 | Phase 2·Phase 3·Phase 4·Phase 5·Phase 7 cross-cutting |
| `docs/15-non-functional-requirements.md` | 성능·접근성·보안·프라이버시·i18n·다크모드·테스트·코드 품질·출시 기준 | Phase 9·Phase 10·전체 ops |
| `docs/16-strings.md` | String Catalog·키 컨벤션·하드코딩 금지·검수 grep | Phase 9.3·전체 view 작성 |
| `docs/17-architecture-and-patterns.md` | Clean Architecture·MVVM·Repository·UseCase·디렉토리 구조·Forbidden 패턴·DI | 전체 — 신규/리팩터 코드의 정합 기준 |

### Phase Done 보강

본 roadmap 의 Phase Done 라인은 **구현 시점의 자체 검증** 만 명시한다. **spec 정합성 검증 (`docs/10~17` 대비 사용자 가시 동작·아키텍처 일치 여부) 은 별도 spec-realign 라운드** 에서 수행한다 (cluster 명명 `realign-{영역}`). spec-realign 라운드의 합격 기준:

- explorer 8종이 docs/10~17 영역별로 dispatch 되어 코드↔spec 차이 0건 (Critical/High 0)
- `xcodebuild build` / `xcodebuild test` PASS
- `audit-arch` skill PASS
- 하드코딩 한국어/색/dp grep = 0
- reviewer ≥ 70 점, blocking 0

---

## 현재 상태

- Phase: **R1 완료 — Album entity + PhotoPair restructure + 파일 시스템 분리 + EXIF + SwiftData migration**
- 다음 task: **R2 — `realign-architecture` (Domain/Data/App/Shared 디렉토리 + ViewModel 분리)**
- Branch: `feature/ios-mvp/audit-d-finalize` (R1 누적, 후속 R-Round 동일 브랜치 진행)
- Last commit: refactor(R1) realign-data-model — Album + PhotoPair restructure + photos/thumbnails 디렉토리 분리 + EXIF normalize + SchemaV1→V2 migration

### Audit-C 진행 로그

- 셔터 햅틱 중복 제거 — `BeforeCaptureCoordinator` / `AfterCaptureCoordinator` 가 더 이상 `.heavy` / `.success` 발생시키지 않음. 뷰 레이어가 단일 `.heavy` (press) + 단일 `.success` (완료) 보장.
- 캡처 실패 사용자 알림 — `BeforeCameraView` / `AfterCameraView` 에 한국어 alert 추가 (P9.4 placeholder 코멘트 제거). After 흐름의 stale Before 파일은 transient toast 로 안내.
- ShareSheet ZIP 정리 — 임시 zip URL 추적 + onDisappear 시 unlink. `PhotoLibraryExport.authorize()` 는 ExportPicker 진입 시 1회만 호출.
- 접근성 — `PairThumbnailCell` / `ProjectRow` 단일 VoiceOver utterance, CameraControlBar 터치 영역 36→44pt, ComparisonView/CompositeMenu/QRScannerView 의 `.font(.system(size:))` 고정 → Dynamic Type 친화 textStyle.
- AccentColor — light/dark teal 듀얼 컬러 등록 (`#1D7A8C` / `#4FB1C4`).
- Localized 정합 — Archive 4개 파일 + NewProjectSheet 의 한국어 literal 일괄 `String(localized:)`. ko/en `.strings` 32키 추가. WatermarkOverlay 의 `Locale(identifier: "ko_KR")` → `Locale.current`. AdFreeStatusFormatter / CouponRegistration 의 `yyyy-MM-dd` 포매터에 `en_US_POSIX` 명시.
- AdFreeStore 캐싱 — `activeCoupons` / `pastCoupons` computed → stored snapshot. `refresh()` 가 한 번에 partition 갱신.
- LocationService race guard — 동시 호출 시 두 번째는 즉시 nil 반환.
- 신규 테스트 5종 — HapticDoubleFireTests · AccessibilityLabelTests · AdFreeStoreCachingTests · LocalizationCoverageTests · LocationServiceConcurrencyTests.
- 다이어트 — BeforeCameraView 224→225L, AfterCameraView 240→249L, ShareSheet 223→250L (모두 250L cap 이하). Archive 304L 은 audit-D 로 이월.

✅ PairShot iOS MVP 자율 phase 루프 완주 — P0~P10 모두 구현 완료
✅ Audit-A Critical 6 → 수정 완료 (네비게이션 복구로 전체 사용자 흐름 도달 가능)
✅ Audit-B 9 → 수정 완료 (광고·권한·출시 메타 정합)
✅ Audit-C 15 → 수정 완료 (UX·접근성·concurrency·문구 정합 상위)
✅ Audit-D 11 → 수정 완료 (잔여 polish — view 다이어트·Localized 정합·EXIF·Banner adaptive·HapticContract)

---

## Phase 0 — Legacy Purge & Foundation

폐기된 AR/Vision/LiDAR 코드 제거. 빌드는 계속 통과해야 함.

### P0.1 — Vision/AR/LiDAR Service 9개 제거 — [x]
- SCOPE: `PairShot/PairShot/Services/{ARSessionManager,AlignmentService,AIAnalysisCoordinator,PositionMatchingService,MatchingScoreService,ColorCorrectionService,DepthCaptureService,LowLightManager,QualityCheckService}.swift`
- Refs: `.claude/refs/avfoundation-camera.md` (forbidden 목록)
- Done (vacuous): 현재 코드베이스는 Xcode 템플릿 수준(`PairShot/PairShot/`에 `PairShotApp.swift`·`ContentView.swift`·`Item.swift`·`Assets.xcassets/`만 존재). 폐기 대상 9개 Service 파일은 처음부터 부재. `audit-arch` skill 통과로 검증.

### P0.2 — AR/LiDAR View 5개 제거 — [x]
- SCOPE: `PairShot/PairShot/Views/Camera/{ARCameraView,ARCameraPreviewView,SixDOFGuideView,LiDARMeasureOverlayView}.swift` + 빈 extension 4개 (`CameraView+AR`, `+LiDAR`, `+Quality`, `ARPositionGuideView`)
- Done (vacuous): `Views/Camera/` 디렉터리 자체 부재. `UnifiedCameraView` 등 어떤 카메라 분기 코드도 미존재. `audit-arch` skill 통과.

### P0.3 — Photo @Model entity 제거 + PhotoPair 단순화 — [x]
- SCOPE: `PairShot/PairShot/Models/{Photo,PhotoPair,QualityIssue,CaptureMode}.swift`
- Refs: `.claude/refs/swiftdata-persistence.md`
- Done (vacuous): `Models/` 디렉터리 부재. 기존 `@Model class Photo`/`PhotoPair`/`QualityIssue`/`CaptureMode` 미존재. P1.1에서 `Project` @Model을 새로 도입하는 것이 첫 모델 작업.

### P0.4 — 폐기 테스트 4개 제거 — [x]
- SCOPE: `PairShot/PairShotTests/{AlignmentServiceTests,SensorAlignmentTests,LowLightEnhanceTests,QualityCheckTests}.swift`
- Done (vacuous): 폐기 대상 테스트 파일 4종 모두 부재. 현재는 Xcode 템플릿의 `PairShotTests.swift` 단일 파일만 존재 (P1+에서 본격적으로 테스트 추가).

### P0.5 — Info.plist MinimumOSVersion 정합화 — [x]
- SCOPE: `PairShot/PairShot/Info.plist`, `PairShot/PairShot.xcodeproj/project.pbxproj`
- Refs: `.claude/refs/ios-permissions.md`
- Done: `IPHONEOS_DEPLOYMENT_TARGET = 26.4` → `17.0` 4곳 일괄 수정 (project Debug/Release + PairShot target Debug/Release). `Info.plist`는 `GENERATE_INFOPLIST_FILE = YES`로 빌드 시 자동 생성되므로 별도 파일 없음 — 배포 타겟이 단일 source of truth. `xcodebuild build` 통과.

### P0.6 — Phase 0 종료 검증 — [x]
- SCOPE: (검증만)
- Done: `xcodebuild -scheme PairShot -destination 'iPhone 15 Pro' build` PASS. `xcodebuild test` PASS (PairShotTests 1 case + PairShotUITests 2 case + LaunchTests 4 iter). `audit-arch` skill 7개 forbidden 규칙 모두 zero match (verdict PASS).

---

## Phase 1 — Foundation: Project Management

Android 매핑: 프로젝트 CRUD, GPS 자동 기록, 정렬, 배지.

### P1.1 — Project @Model 정의 + ModelContainer 설정 — [x]
- SCOPE: `PairShot/PairShot/Models/Project.swift`, `PairShot/PairShot/Models/PhotoPair.swift`, `PairShot/PairShot/PairShotApp.swift`, `PairShot/PairShot/ContentView.swift`, `PairShot/PairShot/Item.swift`(삭제), `PairShot/PairShotTests/ProjectModelTests.swift`
- Refs: `.claude/refs/swiftdata-persistence.md`
- Done: `Project`(id·title·createdAt·updatedAt·lat/lon/locationLabel·pairs) 정의, `PhotoPair` 최소 정의(P2.6에서 capture 흐름 보강), ModelContainer에 두 모델 등록. Xcode 템플릿 잔재 `Item` @Model 제거. ContentView를 Project 임시 placeholder로 교체(P1.2에서 ArchiveView로 교체). 단위 테스트 7종(init·GPS·UUID·cascade·한국어 unicode·empty title·기본 status) 모두 PASS.

### P1.2 — ArchiveView (프로젝트 목록 + 정렬 + 배지) — [x]
- SCOPE: `PairShot/PairShot/Features/Archive/ArchiveView.swift`, `PairShot/PairShot/ContentView.swift`(연결), `PairShot/PairShotTests/ArchiveViewQueryTests.swift`
- Refs: `.claude/refs/swiftui-patterns.md`
- Done: `@Query` + 동적 SortDescriptor (updatedAt desc / createdAt desc 토글, Toolbar Menu Picker). 셀 = 제목·갱신일 + 페어/완료/합성 3종 CountBadge. 빈 상태는 ContentUnavailableView. ContentView는 ArchiveView wrapper로 단순화. ArchiveViewQueryTests 5종 PASS (empty fetch · sort updatedAt · sort createdAt · 배지 카운트 · 한국어 라벨).

### P1.3 — NewProjectSheet (생성 + GPS 자동 태그) — [x]
- SCOPE: `PairShot/PairShot/Features/Archive/NewProjectSheet.swift`, `PairShot/PairShot/Services/LocationService.swift`, `PairShot/PairShot/Features/Archive/ArchiveView.swift`(+ 버튼·시트 연결), `PairShot/PairShot.xcodeproj/project.pbxproj`(INFOPLIST_KEY_NSLocationWhenInUseUsageDescription), `PairShot/PairShotTests/NewProjectFactoryTests.swift`
- Refs: `.claude/refs/ios-permissions.md`
- Done: `LocationProviding` protocol + `CoreLocationService` (CLLocationManager `requestLocation()` 단발, continuous 금지). `NewProjectFactory.make` 함수형 인스턴스 생성기 (테스트 가능). `NewProjectSheet` Form: 제목 + GPS 토글 + 한국어 footer 문구. ArchiveView toolbar에 + 버튼 + sheet. 위치 권한 거부/타임아웃 시 lat/lon = nil로 그대로 생성. 7종 테스트 PASS (GPS · GPS off · 권한 거부 · 빈 제목 · whitespacesAndNewlines 트림 · 한국어 unicode · 공백 트림).

### P1.4 — Project 편집 + 다중 선택 일괄 삭제 — [x]
- SCOPE: `PairShot/PairShot/Features/Archive/ArchiveView+Edit.swift`(+EditProjectSheet+ProjectRenameService), `PairShot/PairShot/Features/Archive/ArchiveView+MultiSelect.swift`(+ProjectSelection+MultiSelectBottomBar+ProjectDeletionService), `PairShot/PairShot/Features/Archive/ArchiveView.swift`(통합), `PairShot/PairShotTests/ArchiveMultiSelectTests.swift`
- Done: 길게 누르기(0.4s) → ProjectSelection 진입(첫 row 선택) → 후속 tap으로 토글. `safeAreaInset(.bottom)` 으로 MultiSelectBottomBar 노출(취소·N개 선택·삭제). `ProjectDeletionService.deleteProjects(ids:in:)`로 SwiftData cascade(@Relationship .cascade로 PhotoPair entity 자동 삭제 — 사진 파일 자체 삭제는 P2.6 PhotoStorageService 도입 시 보강 예정). swipe-trailing `이름 변경` → EditProjectSheet → `ProjectRenameService.rename` (트림·동일제목 NoOp·updatedAt 갱신). ArchiveMultiSelectTests 8종 PASS (selection toggle · enter/exit · cascade 6→1 · empty/unknown set NoOp · rename + 트림 + 동일 NoOp).

---

## Phase 2 — Before Camera

Android 매핑: 핀치 줌·프리셋·렌즈 전환·플래시 4모드·탭 포커스·EV·그리드·수평계.

### P2.1 — CameraSession actor + AVCaptureSession 셋업 — [x]
- SCOPE: `PairShot/PairShot/Services/CameraSession.swift`, `PairShot/PairShot/Features/CameraBefore/CameraPreview.swift`
- Refs: `.claude/refs/avfoundation-camera.md`
- Done: actor 기반 AVCaptureSession 시작/정지 (`CameraSession.swift` 138줄), `UIViewRepresentable CameraPreview` (43줄), `CameraSessionTests` (100줄, 단위 테스트). 수동 작업분 통합 — autonomous loop 가 P2.2 부터 이어받아 검증·확장 예정. 실 디바이스 프리뷰는 P9 수동 검증 보류.

### P2.2 — 핀치 줌 + 프리셋 (0.5 / 1 / 2 / 5) — [x]
- SCOPE: `PairShot/PairShot/Features/CameraBefore/CameraControlBar.swift`, `PairShot/PairShot/Features/CameraBefore/ZoomControl.swift`
- Refs: `.claude/refs/avfoundation-camera.md` (zoom 섹션)
- Done: `CameraSession.ramp(toZoomFactor:rate:)` 가 `device.ramp(toVideoZoomFactor:withRate:)` 으로 위임 (lockForConfiguration). `setZoomFactor(_:)` 는 진행 중 ramp 를 cancel 후 hard-set. `ZoomControl` 의 4 프리셋(0.5/1/2/5) 버튼은 `isPresetSupported(_:)` 결과로 hide. 줌 범위는 `device.minAvailableVideoZoomFactor` / `maxAvailableVideoZoomFactor` 만 사용 — 하드코딩 0. CameraZoomTests 6종 PASS.

### P2.3 — 렌즈 전환 + 플래시 4모드 — [x]
- SCOPE: `PairShot/PairShot/Features/CameraBefore/CameraControlBar.swift`
- Refs: `.claude/refs/avfoundation-camera.md`
- Done: `switchLens(to:)` 가 `.builtInTripleCamera → .builtInDualWideCamera → .builtInDualCamera → .builtInWideAngleCamera` 우선순위 순환으로 사용 가능한 첫 device 채택(광각/초광각 자동 분기). 4모드 플래시 cycle off → on → auto → torch → off; photo는 `AVCapturePhotoSettings.flashMode`, torch는 `device.torchMode`. CameraControlBar 토글 4종(플래시·그리드·수평계·렌즈). CameraLensFlashTests 6종 PASS.

### P2.4 — 탭 포커스 + EV 드래그 — [x]
- SCOPE: `PairShot/PairShot/Features/CameraBefore/FocusGesture.swift`
- Refs: `.claude/refs/avfoundation-camera.md` (focus 섹션)
- Done: `FocusGestureView` 의 탭 → `FocusGestureMath.devicePoint(forTap:in:)` (`previewLayer.captureDevicePointConverted(fromLayerPoint:)`) → `CameraSession.focus(at:)` (focusPointOfInterest + autoFocus + autoExpose). 세로 DragGesture → `biasForDrag` 가 view-height 기준 `range` mapping → `setExposureTargetBias`. `FocusReticleView` 1 초 fade-out (Task.sleep + animation). FocusGestureTests 6종 PASS.

### P2.5 — 그리드 + 수평계 토글 — [x]
- SCOPE: `PairShot/PairShot/Features/CameraBefore/GridOverlay.swift`, `PairShot/PairShot/Features/CameraBefore/LevelIndicator.swift`, `PairShot/PairShot/Services/MotionService.swift`
- Refs: (없음 — Core Motion 표준)
- Done: `GridOverlay` 가 Canvas + Path 단일 draw 로 3×3 (divisions 파라미터화). `MotionService` (`@MainActor @Observable`) 가 `CMMotionManager.startDeviceMotionUpdates(to: .main)` 1Hz, `attitude.roll` (rad → deg). `LevelIndicator` pill 이 ±X° 표시 + tolerance ≤ 1.5° 시 green tint. `BeforeCameraView` 토글로 grid/level 시작/정지. GridOverlayTests 4종 + MotionServiceTests 7종 PASS.

### P2.6 — Capture + PhotoPair 저장 (Before) — [x]
- SCOPE: `PairShot/PairShot/Features/CameraBefore/CaptureAction.swift`, `PairShot/PairShot/Services/PhotoStorageService.swift`
- Refs: `.claude/refs/swiftdata-persistence.md`
- Done: `CameraSession.capturePhoto()` 가 `AVCapturePhotoOutput.capturePhoto(with:delegate:)` 로 JPEG byte 수집(continuation), zoom·lens 메타 함께 반환. `PhotoStorageService.saveBeforeJPEG(_:fileID:)` 가 `Application Support/photos/<UUID>.jpg` 저장 → 상대 경로 반환. `BeforeCaptureCoordinator.captureBefore(project:into:)` 이 actor → 파일 → `PhotoPair(beforePath, status=.pendingAfter, beforeZoomFactor, beforeLensIdentifier, project:)` 삽입 + `project.updatedAt` 갱신 + `context.save()`. 셔터 햅틱은 `UIImpactFeedbackGenerator(style: .heavy)`. PhotoStorageServiceTests 6종 PASS (저장·resolve·삭제·중복 방지·blank path nil·SwiftData PhotoPair link).

---

## Phase 3 — After Camera with Overlay

Android 매핑: 미완료 pair 자동 순회, Before 반투명 overlay + alpha, 줌 자동 복원.

### P3.1 — 미완료 pair 자동 순회 진입 — [x]
- SCOPE: `PairShot/PairShot/Features/CameraAfter/AfterCameraView.swift`
- Done: `AfterCameraPairLoader.firstPendingPair(in:)` 가 `status == .pendingAfter && afterPath == nil` 인 페어 중 `beforeCapturedAt` 오래된 순으로 첫번째 반환. 진입 시(`task`) 세션 start 후 `loadFirstPendingOrDismiss()`. 캡처 outcome 의 `nextPendingPair` 가 있으면 `adopt(pair:)` 로 전이, 없으면 `dismiss()`. AfterCameraTraversalTests 7종 PASS.

### P3.2 — Before 반투명 overlay + alpha 슬라이더 — [x]
- SCOPE: `PairShot/PairShot/Features/CameraAfter/GhostOverlay.swift`
- Done: `GhostOverlayLoader.loadImage(relativePath:storage:)` 가 PhotoStorageService 경로 → `UIImage(contentsOfFile:)` 동기 디코드. `GhostOverlayView` 가 `Image(uiImage:).resizable().scaledToFill().opacity(GhostOverlayMath.clamp(alpha))`. `GhostOverlayAlphaSlider` 0.0~1.0 + 퍼센트 라벨, 캡슐 배경. `GhostOverlayMath.clamp` 가 음수/1초과 모두 snap. **자동정렬·homography 0** — `.opacity(...)` 단일 호출. GhostOverlayTests 7종 PASS.

### P3.3 — Before zoom factor 자동 복원 — [x]
- SCOPE: `PairShot/PairShot/Features/CameraAfter/AfterCameraView.swift`
- Done: `adopt(pair:)` 직후 `restoreZoom(for:)` 가 `CameraSession.setZoomFactor(pair.beforeZoomFactor)` 호출 → 실제 적용된 `currentZoomFactor` 를 다시 읽어 `pinchBaseFactor` / `activePreset` 동기화. 1회 가드(`hasRestoredZoom`)로 후속 pinch 가 자동복원에 의해 덮어써지지 않음. 사용자는 P2.2 ZoomControl + 핀치로 자유 변경. AfterZoomRestoreTests 6종 PASS.

### P3.4 — Capture → COMPLETE 전이 + cascade — [x]
- SCOPE: `PairShot/PairShot/Features/CameraAfter/AfterCaptureAction.swift`
- Done: `PhotoStorageService.saveAfterJPEG(_:fileID:)` (saveBeforeJPEG 와 동일 디렉터리 정책). `AfterCaptureCoordinator.captureAfter(for:into:)` 가 `pair.status == .pendingAfter && afterPath == nil` 가드 → 액터 캡처 → 파일 저장 → `pair.afterPath = ... ; afterCapturedAt = ... ; status = .complete; project.updatedAt = .now` → `context.save()` → `AfterCaptureOutcome(completedPair:nextPendingPair:)` 반환. View 는 `nextPendingPair` 있으면 `adopt(pair:)`, 없으면 `dismiss()`. AfterCaptureActionTests 6종 PASS.

---

## Phase 4 — Gallery

Android 매핑: 2열 그리드, ALL/합성본 필터, 다중 선택 액션.

### P4.1 — PairGalleryView 2열 그리드 — [x]
- SCOPE: `PairShot/PairShot/Features/Gallery/PairGalleryView.swift`
- Done: `LazyVGrid` 2열(`GridItem.flexible()` × 2, spacing 4) — `PairThumbnailCell` (1:1 aspect, Before JPEG 우선, 상태 배지 = pendingAfter→Before/주황 · complete→완료/녹 · combinedPath→합성/보라). 탭 → `ComparisonPlaceholderView` (`.sheet(item: $preview)`) — P5.1 에서 본격 ComparisonView 로 교체. `task(id:)` 로 thumbnail load detached. 빈 상태 `ContentUnavailableView`.

### P4.2 — ALL / 합성본 필터 — [x]
- SCOPE: `PairShot/PairShot/Features/Gallery/GalleryFilter.swift`
- Done: `enum GalleryFilter: { all, combinedOnly }` (`Identifiable` + `CaseIterable` + `String(localized:)` 라벨). `apply(to:)` 순수 함수 — `combinedOnly` 는 `combinedPath != nil && !isEmpty` 만. View 상단 `Picker(.segmented)`. 다중 선택 모드 진입 시 `.disabled`.

### P4.3 — 다중 선택 + 일괄 액션 (합성·공유·삭제) — [x]
- SCOPE: `PairShot/PairShot/Features/Gallery/MultiSelectBar.swift`
- Done: `@MainActor @Observable PairSelection` (Phase 1.4 ProjectSelection 패턴 적용). Long press(0.4s) → enter selection. `safeAreaInset(.bottom)` 의 `PairMultiSelectBar` = 취소 · N개 선택 · 합성(P5.2 placeholder, `.disabled`) · 공유(P7.3 placeholder, `.disabled`) · 삭제(`PairDeletionService`). `PairDeletionService.deletePairs(ids:in:storage:)` 가 SwiftData row + JPEG 파일(before/after/combined) + ThumbnailCache entry 모두 정리 — 파일 삭제 실패는 best-effort 로 swallow.

### P4.4 — 썸네일 캐시 — [x]
- SCOPE: `PairShot/PairShot/Services/ThumbnailCache.swift`
- Done: `final class ThumbnailCache: @unchecked Sendable` + `NSCache<NSString, UIImage>`. `loadThumbnail(forRelativePath:storage:pixelSize:)` = cache hit → 즉시 반환, miss → `CGImageSourceCreateThumbnailAtIndex` 다운샘플 (`kCGImageSourceCreateThumbnailFromImageAlways` + `ThumbnailMaxPixelSize: 600`) → 캐시 저장(cost = w×h×4). `evict(relativePath:)` 단건 삭제 (deletion 시 호출). 디스크 캐시는 별도 sidecar 없음 — 원본 JPEG 자체를 디스크 레이어로 활용 (WWDC18 패턴). `ThumbnailCache.shared` 싱글톤은 `NSCache` 의 thread-safe 보장에 의존.

---

## Phase 5 — Comparison & Composition

Android 매핑: 풀스크린 비교, 좌우 순회, 합성 생성·저장. **자동정렬·자동 색보정 없음**.

### P5.1 — 풀스크린 비교 모달 + 스와이프 dismiss — [x]
- SCOPE: `PairShot/PairShot/Features/Comparison/ComparisonView.swift`
- Done: `ComparisonView` 가 `.fullScreenCover` 로 표시. `ZStack` + `ComparisonImagePane` 가 split / beforeOnly / afterOnly 3 모드를 토글(사진 탭). DragGesture 로 vertical>120pt → dismiss, horizontal>80pt → `ComparisonPager.next/previous` 인접 페어 순회 (가장자리 clamp). NavigationTitle 에 `n / N` 페이저. 합성 진행 중 ProgressView overlay + 알림. PairGalleryView 의 ComparisonPlaceholder 제거하고 실 ComparisonView 와 wire-up.

### P5.2 — 합성 (Composite) — Before+After horizontal/vertical — [x]
- SCOPE: `PairShot/PairShot/Services/CompositeRenderer.swift`, `PairShot/PairShot/Features/Comparison/CompositeOptions.swift`
- Refs: (UIGraphicsImageRenderer)
- Done: `CompositeLayout {.horizontal, .vertical}` + `CompositeOptions(layout, jpegQuality, watermarkEnabled)`. `CompositeRenderer.composeFrames` 가 공통 변(짧은 쪽) 기준으로 두 이미지를 letterbox 없이 정렬, `renderComposite` 가 `UIGraphicsImageRenderer`(scale=1, opaque) 로 단일 캔버스에 paste. **자동정렬·자동 색보정 0**. `makeComposite(for:options:storage:in:)` 가 디코드 → 렌더 → 워터마크 → JPEG → `PhotoStorageService.saveCombinedJPEG` → `pair.combinedPath` + `project.updatedAt` 갱신. ComparisonView 툴바 메뉴(square.on.square) 에서 좌우/상하 선택 → 호출.

### P5.3 — 워터마크 (옵션) — [x]
- SCOPE: `PairShot/PairShot/Services/WatermarkOverlay.swift`
- Done: `WatermarkOverlay.apply(to:date:)` 가 우하단 라운드 캡슐 위에 `"앱이름 · yyyy-MM-dd HH:mm"` 텍스트를 단일 `NSAttributedString.draw(at:)` 로 stamp. 폰트 크기는 짧은 변의 2.2% 로 스케일(썸네일~고해상도 모두 합리적). 토글은 `UserDefaults.standard.bool(forKey: "watermarkEnabled")`, `register(defaults:)` 로 미설정 시 `true` 기본. Settings UI 는 P8.3 에서 노출.

---

## Phase 6 — Ads & Coupon System (AdMob)

Android 매핑: 광고 5종 + Ed25519 서명 쿠폰 + AdFree 상태. iOS 전용 추가: ATT, Privacy Manifest, SKAdNetwork.

### P6.1 — Mobile Ads SDK 통합 + iOS 광고 정책 — [x]
- SCOPE: `PairShot/PairShot.xcodeproj/project.pbxproj` (SPM 의존성), `PairShot/PairShot/Info.plist`, `PairShot/PairShot/PrivacyInfo.xcprivacy`, `PairShot/PairShot/Services/AdsConfig.swift`
- Refs: `.claude/refs/ios-permissions.md`
- Done:
  - SPM `swift-package-manager-google-mobile-ads` 11.x 추가 (project.pbxproj 직접 편집 — `XCRemoteSwiftPackageReference` + `XCSwiftPackageProductDependency` + `packageReferences` + Frameworks build-file 모두 수동). xcodebuild 가 11.13.0 + GoogleUserMessagingPlatform 2.7.0 자동 fetch.
  - `Info.plist` 신규 생성 + `GENERATE_INFOPLIST_FILE = NO` + `INFOPLIST_FILE = PairShot/Info.plist` 로 전환 (synchronized-group 의 `PBXFileSystemSynchronizedBuildFileExceptionSet` 으로 `Info.plist` 빌드 리소스 중복 방지). 카메라/위치/사진/ATT 사유 + Scene/Launch/Orientation/`GADApplicationIdentifier`(test app id) 모두 명시.
  - `SKAdNetworkItems` 51개 (Google AdMob 공식 목록 — `cstr6suwn9` 외 50종) Info.plist 에 등록.
  - `PrivacyInfo.xcprivacy`: `NSPrivacyTracking=YES` + `NSPrivacyTrackingDomains=[]` (광고 SDK 가 런타임에 추가) + `NSPrivacyAccessedAPITypes` 3종 (UserDefaults `CA92.1` · DiskSpace `E174.1` · SystemBootTime `35F9.1`) + `NSPrivacyCollectedDataTypes=[]`.
  - `AdsConfig` enum: `TestUnitID` (banner/interstitial/rewarded/rewardedInterstitial/native/appOpen — Google 공식 테스트 unit-id 핀) + `InfoPlistKey` (RELEASE 에서 xcconfig 주입할 키 이름). DEBUG 는 항상 테스트 id, RELEASE 는 Bundle lookup → fallback to test id.
  - `PairShotApp.init()` 에서 `#if canImport(GoogleMobileAds)` 가드 + `MobileAds.shared.start(completionHandler: nil)` 호출 (idempotent, fire-and-forget).

### P6.2 — ATT (App Tracking Transparency) 권한 흐름 — [x]
- SCOPE: `PairShot/PairShot/Services/TrackingAuthorizationService.swift`
- Refs: `.claude/refs/ios-permissions.md`
- Done: `TrackingAuthorizationProviding` 프로토콜 + `SystemTrackingAuthorizationProvider` (production, `ATTrackingManager.trackingAuthorizationStatus` / `requestTrackingAuthorization` async 래핑) + `@MainActor @Observable TrackingAuthorizationService` (`currentStatus` publish · `requestIfUndetermined()` 가 `.notDetermined` 일 때만 prompt, 이미 결정된 경우 즉시 캐시 반환 · `refresh()` 가 Settings 복귀 후 재조회). `Info.plist` `NSUserTrackingUsageDescription` 한국어 사유 등록. 호출 사이트(첫 광고 표면 직전)는 P6.5/P6c 에서 wire.

### P6.3 — Coupon Ed25519 검증 + AdFree state — [x]
- SCOPE: `PairShot/PairShot/Models/Coupon.swift`, `PairShot/PairShot/Services/CouponVerifier.swift`, `PairShot/PairShot/Services/AdFreeStore.swift`
- Refs: `.claude/refs/swiftdata-persistence.md`
- Done:
  - `@Model Coupon` (id · code · activatedAt · durationDays · signatureBase64 · `Status {.active, .expired, .revoked}`) + `expirationDate` 계산 + `isCurrentlyActive(now:)`. Schema 에 추가 (`PairShotApp.sharedModelContainer`).
  - `CouponVerifier.verify(code:signatureBase64:publicKeyBase64:)` 가 `Curve25519.Signing.PublicKey(rawRepresentation:)` 로 키 복원 → `isValidSignature(_:for: Data(code.utf8))`. 빈 code/sig·malformed base64·잘못된 키 길이 모두 `CouponVerificationError` throws. 공개키는 32-byte 영점 placeholder (real apricity 키는 P6c/P10.5 에서 xcconfig 주입).
  - `@MainActor @Observable AdFreeStore`: SwiftData ModelContext 주입, `refresh()` 가 active 쿠폰 fetch → 만료 지난 row 는 `.expired` 로 rollover + persist → `isAdFree` & `currentExpiration` publish. 빈 store / expired only / revoked only 모두 false. 다중 active 중 가장 늦은 expirationDate 채택.

### P6.4 — Coupon 등록 UI (코드 입력 + QR 스캔) — [x]
- SCOPE: `PairShot/PairShot/Features/Settings/CouponRegistrationView.swift`, `PairShot/PairShot/Features/Settings/QRScannerView.swift`
- Refs: `.claude/refs/avfoundation-camera.md`
- Done: `QRPayloadParser` 가 단일 토큰 `<code>.<signatureBase64>` 형식 파싱(. 0개·≥2개·빈 half 모두 throws). `@MainActor @Observable CouponRegistrationViewModel` 가 verifier/now/context 를 의존성 주입 받아 parse → duplicate-active 체크 → verify → `Coupon` insert → `AdFreeStore.refresh()` → `lastSuccessExpiration` 노출. `CouponRegistrationView` 가 NavigationStack + Form 두 섹션(수동 paste · QR 스캔) + `.fullScreenCover` 로 `QRScannerView` 호출 + 성공 토스트(만료일 yyyy-MM-dd)+자동 dismiss. `QRScannerView` 가 별도 `AVCaptureSession` + `AVCaptureMetadataOutput`(`.qr`) — Before/After CameraSession 액터와 수명 격리, 첫 인식 시 stop+success 햅틱+콜백, 권한 거부 시 Settings 딥링크. CouponRegistrationViewModelTests 8종(happy · scanned · empty · malformed · verify=false · verify throws · duplicate active · 만료된 duplicate 재등록) + QRPayloadParserTests 10종(happy + 한국어 + trim + 모든 throws case).

### P6.5 — Banner ad — [x]
- SCOPE: `PairShot/PairShot/Services/BannerAdView.swift`
- Done: `BannerAdView` (UIViewRepresentable, `GADBannerView` + `GADAdSizeBanner` + `loadRequest`) + `BannerAdSlot` (SwiftUI guard view: `@Environment(AdFreeStore.self)` + `BannerAdGate.shouldShow(isAdFree:)` 가드 → AdFree 시 EmptyView). ArchiveView 하단 `safeAreaInset(.bottom)` 의 VStack 에 multi-select 바와 stack. 분리 순수 함수 `BannerAdGate.shouldShow(isAdFree:)` (테스트 가능).

### P6.6 — Interstitial ad — [x]
- SCOPE: `PairShot/PairShot/Services/InterstitialAdManager.swift`
- Done: `@MainActor @Observable InterstitialAdManager` (`isLoaded` · `isLoading` · `lastShownAt` 게시, `loadIfNeeded` / `presentIfReady` API). `GADInterstitialAd.load(withAdUnitID:request:completionHandler:)` 로 prefetch, `GADFullScreenContentDelegate` shim 으로 dismiss/fail 시 coordinator 슬롯 release. 분리 순수 함수 `InterstitialFrequencyGate.shouldPresent(now:lastShownAt:minimumInterval:)` (default 300 s = 5 분). ComparisonView 의 합성 성공 직후 `presentIfReady(...)` 호출. AdFree 시 manager 자체적으로 skip.

### P6.7 — Rewarded video gate (워터마크·합성 게이트) — [x]
- SCOPE: `PairShot/PairShot/Services/RewardedAdManager.swift`, `PairShot/PairShot/Features/Settings/CompositionSettingsGate.swift`
- Done: `@MainActor @Observable RewardedAdManager` (`UnlockID.compositionSettings` enum + `sessionUnlocks: Set<UnlockID>` + `RewardOutcome` 4-case enum). `loadIfNeeded` / `presentForReward(_ unlockID:from:coordinator:adFreeStore:)` 둘 다 AdFree 시 SDK 호출 자체 skip — `presentForReward` 는 `.skipped(adFree: true)` 로 즉시 unlock insert. 분리 순수 함수 `RewardedSessionGate.shouldShowGate(unlockID:sessionUnlocks:isAdFree:)` (테스트 가능). `GADRewardedAd.load(withAdUnitID:request:completionHandler:)` + `present(fromRootViewController:userDidEarnRewardHandler:)` v11 시그니처. `GADFullScreenContentDelegate` shim 으로 dismiss/fail 시 coordinator release + 다음 prefetch. `CompositionSettingsGate<Content: View>` wrapper view (잠금 화면 + "광고 보고 잠금 해제" 버튼 → `presentForReward` → `.granted`/`.skipped` 시 child render). 본 phase 에서는 wrapper + 단위 테스트만 — 실 wire-up 은 P8.3 `CompositionSettingsView` 도입 시.

### P6.8 — Native ad in lists (Gallery 매 6 pair) — [x]
- SCOPE: `PairShot/PairShot/Services/NativeAdLoader.swift`, `PairShot/PairShot/Features/Gallery/PairGalleryView.swift`, `PairShot/PairShot/Features/Gallery/PairThumbnailCell.swift`
- Done: `@MainActor @Observable NativeAdLoader` (NSObject sub) — `prefetch(count:adUnitID:adFreeStore:)` 가 `GADAdLoader(adUnitID:rootViewController:adTypes:[.native],options:[GADMultipleAdsAdLoaderOptions])` + `loader.load(GADRequest())`. `GADNativeAdLoaderDelegate` 구현으로 `didReceive nativeAd` → `loadedAds.append`. AdFree 시 prefetch 자체 skip. `adFor(index:)` 는 round-robin 풀 (음수 index defensive). 분리 순수 함수 `NativeAdInsertionStrategy.indices(forPairCount:interval:)` 가 0-based ad slot 위치 반환 (default interval 6 → `[5, 11, 17, ...]`). 0/음수/interval ≤ 0 모두 빈 배열. `PairGalleryView` 의 LazyVGrid 데이터를 `enum GalleryItem { case pair(PhotoPair); case nativeAd(id:Int, ad:Any?) }` 기반으로 변경 — AdFree 시 또는 selection mode 활성 시 ad cell 미삽입. `NativeAdCell` (UIViewRepresentable wrapping `GADNativeAdView`) 가 headline / body / icon / CTA 4 자산 표시 (UIButton.Configuration v15+, NSDirectionalEdgeInsets). `PairThumbnailCell` 별도 파일로 분리해 `PairGalleryView` 250 라인 이하 유지.

### P6.9 — App Open ad + FullscreenAdCoordinator — [x]
- SCOPE: `PairShot/PairShot/Services/AppOpenAdManager.swift`, `PairShot/PairShot/Services/FullscreenAdCoordinator.swift`, `PairShot/PairShot/PairShotApp.swift`
- Done:
  - `actor FullscreenAdCoordinator { tryAcquire / release }` — 동시 풀스크린 광고 직렬화. `tryAcquire = false` 시 caller 즉시 skip(재시도 X). 액터 격리로 동시 8 acquirer 중 정확히 1 만 성공(테스트로 검증). 커스텀 `EnvironmentKey` (`\.fullscreenAdCoordinator`) 로 SwiftUI environment 주입(actor 는 Observable 미준수).
  - `@MainActor @Observable AppOpenAdManager` — `loadIfNeeded` + `presentIfReady(coldStart:from:coordinator:adFreeStore:now:)`. 분리 순수 함수 `AppOpenAdGate.shouldPresent(coldStart:lastShownAt:now:minimumInterval:)` (default 240 s = 4 분, cold/foreground 동일 캡으로 빠른 재시작 방어).
  - `PairShotApp` 가 `@State` 로 4 인스턴스(AdFreeStore / FullscreenAdCoordinator / InterstitialAdManager / AppOpenAdManager) 보관, `.environment(_:)` 주입. `WindowGroup` `.task` 에서 첫 frame 후 콜드 스타트 App Open ad 시도(App.init 직후엔 scene 미활성). `@Environment(\.scenePhase) onChange` 로 `.active` 진입 시 `presentIfReady(coldStart: false, ...)` (단 첫 active 는 cold-start 경로가 처리).

---

## Phase 7 — Export & Share

Android 매핑: ZIP 내보내기 / 기기 저장 / 공유 시트. Before/After/Combined 선택.

### P7.1 — ZIP 내보내기 — [x]
- SCOPE: `PairShot/PairShot/Services/ZipExporter.swift`
- Refs: ZIPFoundation README
- Done: ZIPFoundation 0.9.x SPM 추가 (project.pbxproj 직접 편집: `XCRemoteSwiftPackageReference` + `XCSwiftPackageProductDependency` + `packageReferences` + Frameworks build-file). `actor ZipExporter` + `enum ExportMode {.all, .beforeOnly, .afterOnly, .combinedOnly}` + `enum ExportSelection` 순수 함수가 pair 별 (relativeName, sourcePath) entry list 생성 — `<projectTitle>/<pairUUID>_<role>.jpg` 일관 디렉터리. `Archive(url:accessMode: .create)` + `addEntry(with:fileURL:compressionMethod: .none)` (JPEG 재압축 회피). 빈 pairs / sourceMissing / archive open 실패 모두 typed `ExportError` throws.

### P7.2 — 기기 저장 (PhotoKit) — [x]
- SCOPE: `PairShot/PairShot/Services/PhotoLibraryExport.swift`
- Refs: `.claude/refs/ios-permissions.md`
- Done: `protocol PhotoLibraryExporting: Sendable { authorize() async -> PHAuthorizationStatus; saveImageData(_:type:) async throws }` + `final class PhotoLibraryExport: PhotoLibraryExporting`. `authorize()` 가 `PHPhotoLibrary.authorizationStatus(for: .addOnly)` 단락회로 → `notDetermined` 일 때만 `PHPhotoLibrary.requestAuthorization(for: .addOnly)` 호출. `saveImageData` 가 `PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.forAsset().addResource(with: .photo, data:, options: nil) }` 을 `withCheckedThrowingContinuation` 으로 async 래핑. 권한 거부 시 `PhotoLibraryExportError.notAuthorized` throws (UI Settings 딥링크 트리거 가능).

### P7.3 — 공유 시트 (`UIActivityViewController`) — [x]
- SCOPE: `PairShot/PairShot/Features/Export/ShareSheet.swift`, `PairShot/PairShot/Features/Export/ExportPickerSupport.swift`, `PairShot/PairShot/Features/Gallery/MultiSelectBar.swift`(공유 버튼 활성화), `PairShot/PairShot/Features/Gallery/PairGalleryView.swift`(`.sheet(item: $exportPayload)` 트리거)
- Done: `struct ShareSheet: UIViewControllerRepresentable` 가 `UIActivityViewController` 를 wrap, `completionWithItemsHandler` 으로 dismiss 콜백. `struct ExportPicker: View` (NavigationStack + Form + 3 액션) 가 ExportMode segmented picker + 3 action row (ZIP 으로 공유 / 사진 앱에 저장 / 이미지로 공유). 진행 중 ProgressView overlay + 완료 토스트 + 알림(에러). View 250 라인 이하 유지 위해 `ExportPickerSupport.swift` 에 helper 타입 분리(`ExportPickerPayload` · `ExportPickerPhase` · `ExportShareItems` · `ExportPickerError`). `PairMultiSelectBar` 의 공유 버튼이 `disabled(true)` → `disabled(selectedIds.isEmpty)` 활성화. `Info.plist` 의 `NSPhotoLibraryAddUsageDescription` 은 P6.1 부터 등록되어 그대로 사용.

---

## Phase 8 — Settings

Android 매핑: JPEG 품질, 파일명 prefix, overlay 기본 alpha, 워터마크, 합성 레이아웃, 저장 용량.

### P8.1 — Settings 화면 골격 — [x]
- SCOPE: `PairShot/PairShot/Features/Settings/SettingsView.swift`
- Done: `SettingsView` (NavigationStack + List, `.insetGrouped`). 5 섹션 (촬영·합성·내보내기·쿠폰·정보) 골격 — 촬영만 활성, 합성/내보내기/쿠폰은 `DisabledSettingsRow` placeholder (P8b/P8c 에서 활성화). 정보 섹션은 `Bundle.main` 의 `CFBundleShortVersionString`/`CFBundleVersion` 표시. `ArchiveView` toolbar 우측 `gearshape` 아이콘 → `.sheet` 진입. `PairShotApp` 가 `@State private var appSettings = AppSettings()` 보관 + `.environment(appSettings)` 전역 주입.

### P8.2 — JPEG 품질 + 파일명 prefix — [x]
- SCOPE: `PairShot/PairShot/Features/Settings/CaptureSettings.swift`, `PairShot/PairShot/Services/AppSettings.swift`, `PairShot/PairShot/Services/PhotoStorageService.swift`(+ fileNamePrefix 파라미터), `PairShot/PairShot/Services/CompositeRenderer.swift`(+ prefix 전달), `PairShot/PairShot/Features/CameraBefore/CaptureAction.swift` · `PairShot/PairShot/Features/CameraAfter/AfterCaptureAction.swift`(coordinator init 에 prefix), `BeforeCameraView` · `AfterCameraView` · `ComparisonView`(`@Environment(AppSettings.self)` 주입)
- Done: `@MainActor @Observable AppSettings` (UserDefaults wrapper, computed get/set, `register(defaults:)` 로 jpegQuality 0.8 / prefix "" 시드, `static let shared`). `enum CaptureQualityPreset { .low(0.6) / .standard(0.8) / .high(0.95) }` + `nearest(to:)` 라운딩. `enum FileNamePrefixValidator { sanitize / maxLength=32 / forbiddenCharacters }` — 공백 트림 + `/\:?*"<>|` + 제어문자/개행 제거 + 32자 컷. `CaptureSettingsView` Form 2 섹션: Picker `pickerStyle(.segmented)` + TextField `onChange` 디바운싱(prefixDraft → sanitize → AppSettings). Footer 가 현재 품질 백분율 + filename 프리뷰 + 안내. `PhotoStorageService.saveBefore/After/CombinedJPEG` 시그니처에 `fileNamePrefix: String = ""` 추가, 내부 `writeJPEG` 헬퍼가 sanitize 한 prefix 로 `<prefix><UUID>.jpg` 저장. `BeforeCaptureCoordinator/AfterCaptureCoordinator` 생성 시 sanitize 된 prefix 전달; `CompositeRenderer.makeComposite` 가 `appSettings.jpegQuality` 를 `CompositeOptions.jpegQuality` 로 받아 인코딩, prefix 도 saveCombinedJPEG 로 전파. 신규 테스트 18건 (AppSettingsTests 6 · CaptureSettingsValidationTests 8 · PhotoStorageQualityTests 5: prefix 적용·legacy 모양·품질 sizing·금지문자 storage 방어 layer·resolve 라운드트립 — 총 19건). xcodebuild build PASS · xcodebuild test PASS.

### P8.3 — Overlay 기본 alpha + 합성 레이아웃 기본값 — [x]
- SCOPE: `PairShot/PairShot/Features/Settings/CompositionSettings.swift`, `PairShot/PairShot/Services/AppSettings.swift`(+ defaultOverlayAlpha · defaultCompositeLayout · watermarkEnabled), `PairShot/PairShot/Features/Settings/SettingsView.swift`(NavigationLink 활성화 + summary 행), `PairShot/PairShot/Features/CameraAfter/AfterCameraView.swift`(진입 시 alpha seed), `PairShot/PairShot/Features/Comparison/ComparisonView.swift`(메뉴 default highlight), `PairShot/PairShotTests/{CompositionDefaultsTests,AppSettingsCompositionTests}.swift`
- Done: `AppSettings` 에 `defaultOverlayAlpha`(UserDefaults `pairshot.defaultOverlayAlpha`, clamp 0~1) + `defaultCompositeLayout`(`pairshot.defaultCompositeLayout`, raw String) + `watermarkEnabled`(`WatermarkOverlay.userDefaultsKey` 공유) 3종 추가, `register(defaults:)` 시드 확장. `enum CompositionDefaults`(alphaRange · fallbackAlpha 0.5 · fallbackLayout .horizontal · clampAlpha NaN/Inf → fallback · layout(forRawValue:) 미지값 fallback) 순수 헬퍼 분리. `CompositionSettingsView` Form 3 섹션(슬라이더 + 퍼센트 라벨 + 푸터 / 합성 레이아웃 segmented Picker / 워터마크 Toggle). `SettingsView` 합성 섹션 NavigationLink 활성화 + 요약 row(투명도·레이아웃·워터마크 상태). `AfterCameraView` `.task` 진입 시 + `adopt(pair:)` 시 `appSettings.defaultOverlayAlpha` 클램프 → `alpha` State 시드. `ComparisonView` 합성 메뉴를 default layout 우선 정렬 + "(기본)" 라벨링. CompositionDefaultsTests 9건(clamp happy/edge/NaN-Inf · layout known/round-trip/unknown · alphaRange · fallback 일치) + AppSettingsCompositionTests 7건(register defaults · 3 setter persist · clamp · 공유 key · 두 인스턴스 라운드트립 · corrupted raw fallback).

### P8.4 — 저장 용량 표시 + 캐시 정리 — [x]
- SCOPE: `PairShot/PairShot/Features/Settings/StorageInfo.swift`, `PairShot/PairShot/Services/PhotoStorageService.swift`(+ directorySize · enumerateAllFiles · orphanFiles · deleteOrphanFiles · filename(from:)), `PairShot/PairShot/Features/Settings/SettingsView.swift`(저장 섹션 NavigationLink), `PairShot/PairShotTests/StorageInfoTests.swift`
- Done: `PhotoStorageService` 에 `directorySize() throws -> Int64`(URL `.totalFileAllocatedSizeKey` 권장 경로) · `enumerateAllFiles() throws -> [URL]`(`.skipsHiddenFiles + .skipsPackageDescendants`) · `orphanFiles(referencedRelativePaths:)` · `deleteOrphanFiles(referencedRelativePaths:) -> (deletedCount, freedBytes)` 추가, 정규화 헬퍼 `static func filename(from:)` 분리. `StorageInfoView` Form 2 섹션: "저장 공간"(폴더 크기 ByteCountFormatter `.file` style + 페어 수 `@Query`) + "캐시 정리"(Button → confirmation alert → detached Task → 결과 라벨). 디렉터리 크기 계산은 `.task` 에서 detached priority 로 백그라운드 수행. `SettingsView` 에 "저장 공간" 섹션(internaldrive SF Symbol) NavigationLink. `enum StorageInfoMath`(referencedRelativePaths 합집합 + 빈 path 스킵 · formatBytes ByteCountFormatter 래핑 + negative clamp) 순수 헬퍼. StorageInfoTests 11건(directorySize 빈/파일 합산 · enumerateAllFiles · orphanFiles 비참조/전체참조/빈 · deleteOrphanFiles count+bytes · referenced union 3-role · empty/nil 스킵 · formatBytes 0/1MB/negative · filename 정규화).

### P8.5 — 쿠폰·AdFree 상태 섹션 — [x]
- SCOPE: `PairShot/PairShot/Features/Settings/AdFreeStatusView.swift`, `PairShot/PairShot/Features/Settings/SettingsView.swift`(쿠폰 NavigationLink 활성화 + 다이어트), `PairShot/PairShot/Features/Settings/SettingsView+Helpers.swift`(SettingsRow/DisabledSettingsRow + AppSettings.captureSummary/compositionSummary 분리), `PairShot/PairShot/Services/AdFreeStore.swift`(activeCoupons/pastCoupons computed + AdFreeCouponSorter), `PairShot/PairShotTests/AdFreeStatusFormatterTests.swift`, `PairShot/PairShotTests/AdFreeStoreSortingTests.swift`
- Done: `AdFreeStatusView` Form 4 섹션 — 현재 상태(headline) / 쿠폰 등록(`.sheet` → P6.4 CouponRegistrationView) / 활성 쿠폰(non-empty 시) / 과거 쿠폰(non-empty 시). 분리 순수 함수 `enum AdFreeStatusFormatter`(remainingDays clamp · headline 활성/비활성 양분기 · maskCode `****-LAST4` · pastStatusLabel `만료`/`취소`). 분리 순수 함수 `enum AdFreeCouponSorter`(active = `status==.active && expirationDate > now` desc, past = inverse desc by activatedAt). 등록 sheet onDismiss 도 `adFreeStore.refresh()` 한 번 더 호출 (CouponRegistrationView 가 이미 처리하지만 cancel 경로 방어). SettingsView 의 `couponSection` placeholder 제거 → `NavigationLink { AdFreeStatusView() }` 활성화. SettingsView 250 라인 cap 다이어트 — `SettingsRow`/`DisabledSettingsRow`/`captureSummary`/`compositionSummary` 4종을 `SettingsView+Helpers.swift` 로 이전 (SettingsView 251L → 176L). 신규 테스트 18건 (AdFreeStatusFormatterTests 10 · AdFreeStoreSortingTests 8). xcodebuild build PASS · xcodebuild test PASS.

---

## Phase 9 — Polish

### P9.1 — 햅틱 피드백 (셔터·토글·완료) — [x]
- SCOPE: `PairShot/PairShot/Services/HapticService.swift`
- Done: `protocol HapticServicing` + `final class HapticService: @MainActor` (UIImpactFeedbackGenerator + UINotificationFeedbackGenerator wrapper, prepare() 호출). `HapticImpactStyle` 5종 / `HapticNotificationKind` 3종 enum 으로 UIKit 의존성 격리. `HapticService.shared` 싱글톤 + `init()` 로 테스트용 인스턴스 가능. 호출자 통일: `CaptureAction.CaptureHaptics`(셔터=heavy/완료=success) → HapticService.shared 위임 / `CameraControlBar.iconButton` 토글 4종 → impact(.light) / `ComparisonView.runComposite` 합성 성공 → notify(.success) / `StorageInfo.runOrphanPurge` 캐시 정리 성공 → notify(.success) / `CouponRegistrationView.handlePostSubmit` 등록 성공 → notify(.success) / `QRScannerView.handleScan` QR 인식 성공 → HapticService.shared.notify(.success) (기존 직접 호출 제거).

### P9.2 — Liquid Glass UI 조건 분기 (iOS 26+) — [x]
- SCOPE: `PairShot/PairShot/DesignSystem/Materials.swift`
- Refs: `.claude/refs/swiftui-patterns.md`
- Done: `enum AppMaterial: CaseIterable { case panel, accent, sheet }` 시맨틱 토큰 + `extension View.appMaterialBackground(_:)` View modifier. iOS 17 baseline 매핑 (panel→regularMaterial, accent→thinMaterial, sheet→thickMaterial); `swiftUIMaterial` computed property 가 향후 iOS 26 Liquid Glass API 명 확정 시 한 곳에서 분기 지점이 되도록 격리. `identifier` round-trip + `init?(identifier:)` 로 토큰 surface 안정성 테스트. 보수적 적용: `CameraControlBar` 의 background 1곳에 `.appMaterialBackground(.panel)` (기존 LinearGradient 는 overlay 로 보존 — 밝은 프리뷰 위에서 가독성 유지).

### P9.3 — Localizable.strings 추출 — [x]
- SCOPE: `PairShot/PairShot/Resources/ko.lproj/Localizable.strings`, `PairShot/PairShot/Resources/en.lproj/Localizable.strings`, `PairShot/PairShot.xcodeproj/project.pbxproj` (developmentRegion = ko + knownRegions += ko)
- Done: 코드베이스에서 `String(localized: "...")` 호출 117 종 추출 → ko.lproj 에 키=값 1:1, en.lproj 에 영문 1차 번역. PBXFileSystemSynchronizedRootGroup 패턴이라 `.lproj/` 디렉터리는 자동 인식 (별도 build phase 등록 불필요). 프로젝트 `developmentRegion = en` → `ko` 전환 + `knownRegions` 에 `ko` 추가. `LocalizableKeysAuditTests` 가 ko/en 키 set 일치 + 각 파일 ≥50개 보장. 정식 영문 번역 polish 는 P10 직전.

### P9.4 — 빈 상태 / 오류 상태 UI — [x]
- SCOPE: `PairShot/PairShot/DesignSystem/PermissionDeniedView.swift`, `PairShot/PairShot/Features/CameraBefore/BeforeCameraView.swift`, `PairShot/PairShot/Features/CameraAfter/AfterCameraView.swift`
- Done: 신규 `PermissionDeniedView` (ContentUnavailableView wrapper + Settings 딥링크 버튼) + 편의 init `init(forCamera:)`/`init(forPhotoLibrary:)`. 분리 helper `enum PermissionDeniedSettingsURL.makeURL/openSystemSettings` 로 URL 구성을 테스트 가능하게 분리. BeforeCameraView/AfterCameraView 모두 진입 시 `AVCaptureDevice.authorizationStatus(for: .video)` 체크 → `notDetermined` 만 `requestAccess` → `.denied`/`.restricted` 면 `cameraPermissionGranted = false` 로 PermissionDeniedView 노출 (AVFoundation 세션 시작 자체 skip → 무한 검은 프리뷰 회피). ArchiveView/PairGalleryView 의 ContentUnavailableView 빈 상태는 P1.2/P4.1 부터 정합 — 별도 변경 없음 (스코프 외).

---

## Phase 10 — TestFlight Prep

### P10.1 — 앱 아이콘 + 스플래시 — [x]
- SCOPE: `PairShot/PairShot/Assets.xcassets/AppIcon.appiconset/`, LaunchScreen
- Done: AppIcon.appiconset Contents.json 을 iOS 17+ single-size 1024×1024 + light/dark/tinted 3 variant 으로 정합. 1024×1024 sRGB placeholder PNG (브랜드 teal `#1D7A8C` + 흰색 "PS") 를 `swift /tmp/make_app_icon.swift` (NSBitmapImageRep 단발 스크립트) 로 생성해 commit. 실 디자인 PNG 는 P10.6 사용자 후속 교체. LaunchScreen 은 Info.plist `UILaunchScreen` empty dict (iOS 14+ 기본 흰 배경) — storyboard 불필요. INFOPLIST_FILE 직접 편집(GENERATE_INFOPLIST_FILE = NO 는 P6a 에서 전환 완료).

### P10.2 — 권한 description 검토 — [x]
- SCOPE: `PairShot/PairShot/Info.plist`
- Refs: `.claude/refs/ios-permissions.md`
- Done: 4 키 (NSCameraUsageDescription / NSLocationWhenInUseUsageDescription / NSPhotoLibraryAddUsageDescription / NSUserTrackingUsageDescription) 모두 한국어 + ≥12자 + 사용 목적 명시 + 사용자 가치 강조 (ATT 는 거부 시 정상 사용 가능 명시 — App Store 5.1.1 가이드라인). Carrier copy: 카메라(현장 작업 + QR 인식) · 위치(프로젝트 자동 묶음) · 사진(앨범 저장) · ATT(관심사 광고 + 거부 무영향).

### P10.3 — Privacy Manifest 최종 검토 — [x]
- SCOPE: `PairShot/PairShot/PrivacyInfo.xcprivacy`
- Done: 4 top-level key 모두 정의. NSPrivacyTracking=YES (광고 personalization 가능). NSPrivacyTrackingDomains=[] (Google Mobile Ads SDK 가 자동 보충). NSPrivacyAccessedAPITypes 4 reasons (UserDefaults `CA92.1` · DiskSpace `E174.1` · SystemBootTime `35F9.1` · FileTimestamp `C617.1`). NSPrivacyCollectedDataTypes 2종 (PreciseLocation + PhotosorVideos), 둘 다 Linked=NO · Tracking=NO · Purposes=[AppFunctionality]. 신규 테스트 PrivacyManifestAuditTests 5건 + InfoPlistPermissionAuditTests 7건 = 12건이 매 빌드에서 plist 구조 회귀 차단.

### P10.4 — 실 디바이스 스모크 테스트 체크리스트 — [x]
- SCOPE: `docs/01-device-test-checklist.md`, `PairShot/PairShotTests/DeviceChecklistAuditTests.swift`
- Done: 12 섹션(권한·Before·After·Gallery·Comparison·Export·Settings·Coupon·광고·AdFree·빈 상태·오류 상태) 체크리스트 한국어 markdown 작성. `DeviceChecklistAuditTests` 5건이 매 빌드마다 (1) 파일 존재 (2) 12 필수 헤딩 모두 존재 (3) 각 섹션 ≥ 1 `[ ]` 체크박스 (4) TestFlight 가이드 cross-link (5) 5 광고 surface 모두 명시 — 회귀 차단.

### P10.5 — Release configuration 빌드 — [x]
- SCOPE: `PairShot/PairShot/Config/{Debug,Release}.xcconfig`, `PairShot/PairShot.xcodeproj/project.pbxproj`(BASE_CONFIGURATION_REFERENCE), `PairShot/PairShot/Info.plist`(`AdUnitID_*` 5종 빌드 변수 노출), `PairShot/PairShot/Services/AdsConfig.swift`(placeholder 감지 fallback), `PairShot/PairShotTests/AdsConfigReleaseLookupTests.swift`
- Done: `Release.xcconfig` 가 5 AdUnit 키(`ADUNIT_ID_BANNER`/`INTERSTITIAL`/`REWARDED`/`NATIVE`/`APP_OPEN`)를 placeholder `INSERT_PRODUCTION_ID_HERE` 로 정의 — 사용자 가 production ID 발급 후 직접 교체. Info.plist 가 `$(ADUNIT_ID_*)` 로 5 키 surface, `AdsConfig.resolve` 가 RELEASE bundle lookup 시 placeholder 검출 → Google 공식 테스트 ID 로 자동 fallback (잘못 업로드해도 잘못된 광고 흐름 0). 분리 순수 함수 `resolveRelease(testID:bundleValue:)` 가 DEBUG 빌드에서도 placeholder/nil/empty/실 ID 4 케이스 모두 검증 가능. AdsConfigReleaseLookupTests 5건 PASS.

### P10.6 — TestFlight 업로드 — [x] (사용자 수행 항목 — `docs/02-testflight-upload-guide.md` 가이드 참조)
- SCOPE: `docs/02-testflight-upload-guide.md`
- Done: 5 섹션 한국어 가이드 — (1) 사전 교체 항목(AppIcon production / AdMob 5 unit ID / GADApplicationIdentifier 실 ID) (2) Build & Archive (3) Distribute App → App Store Connect (4) TestFlight 빌드 정보 / 그룹 / 외부 검토 (5) 디바이스 검증 + Phase 11 안내. 사용자가 Xcode Organizer 로 archive → 업로드 직접 수행.

### P10b reviewer advisory 흡수 (P9 cumulative polish) — [x]
- SCOPE: 5 view 다이어트 + Materials.swift Liquid Glass 분기
  - `BeforeCameraView.swift` 316 → 228L (`CameraStack.swift` 신규 148L)
  - `AfterCameraView.swift` 327 → 218L (`AfterCameraStack.swift` 신규 154L)
  - `ComparisonView.swift` 452 → 244L (`CompositeMenu.swift` 신규 — Menu + ImagePane + Loader + Pager 추출)
  - `CouponRegistrationView.swift` 398 → 150L (`CouponRegistrationSections.swift` 신규 — ViewModel + Parser + 두 Section 추출)
  - `QRScannerView.swift` 299 → 207L (`QRScannerViewController.swift` 신규 — UIViewController 분리)
  - `Materials.swift` 가 `if #available(iOS 26.0, *)` 분기로 `liquidGlassMaterial` (placeholder, TODO P11) / `legacyMaterial` 양분리. 단일 변경 지점 단일 책임 유지.
- Done: 5 파일 모두 ≤ 250 줄 cap 통과. ViewLineCountAuditTests 6건이 staticly 매 빌드 회귀 차단(파일별 cap + 추출 파일 5개 존재 sanity). 행위 변경 0 — 기존 테스트 (FocusGesture · CameraSession · Comparison · CouponRegistration · QR 등) 모두 그대로 PASS.

---

## Phase 11 — App Store 출시 (정식 출시 시점)

이 단계는 **본인 결정 후 별도로 진행**. 이 roadmap에는 task 미정의.

- 스토어 등록 정보 (스크린샷·설명·그래픽)
- 개인정보처리방침 URL
- 앱 콘텐츠 양식
- 출시 국가
- 검수 제출

---

## R-Phases — Spec Realign Rewrite (옵션 A 선택)

2026-04-26 spec realign R1 검수 결과 (`docs/03-spec-realign-findings.md` 84건) 에서 사용자 옵션 A "스펙 우선 rewrite" 선택. 출시본 (P0~P10 audit-D) 은 동결, 본 R-phase 시퀀스로 docs/10~17 spec 정합 v2.0 구축. 각 phase 단일 commit, 직렬 진행 (working tree 공유). cluster 명명 `realign-{영역}`, 본 roadmap 의 R# 번호와 1:1 매핑.

### R1 — `realign-data-model` — [x]
- SCOPE: `PairShot/PairShot/Models/{PhotoPair,Coupon,Project}.swift`(Project 삭제), `Models/Album.swift`(신규), `Models/CameraSettings.swift`(신규), `Models/PairStatus.swift`(신규), `Services/PhotoStorageService.swift`, `PairShotApp.swift`(Schema 갱신 + MigrationPlan), `PairShotTests/{ProjectModelTests,PhotoStorageServiceTests,...}`(갱신·신규)
- Refs: `docs/13-data-model.md` (전체), `.claude/refs/swiftdata-persistence.md`
- Done:
  - `Album` @Model 신규 (id·name·createdAt·updatedAt·latitude·longitude·locationLabel·pairs many-to-many)
  - `PhotoPair` 필드 spec 정합: `beforeFileName`/`afterFileName`/`combinedFileName`(rename), `updatedAt`/`latitude`/`longitude`/`locationLabel` 추가, `albums: [Album]` many-to-many, `cameraSettings: CameraSettings?` embedded
  - `Project` @Model + `PhotoPair.project` FK 제거 (Schema migration 으로 데이터 보존: 기존 Project.title 은 새 Album 으로 1:1 변환, 페어는 모두 그 Album 에 속하도록 마이그레이션)
  - `enum CameraSettings`(zoomFactor·lensPosition·flashMode·useGrid·useNightMode) Codable struct
  - `enum PairStatus { .scheduled, .captured, .combined }` + `PhotoPair.status` computed
  - `PhotoStorageService` 디렉토리 변경: `Application Support/photos/<flat>/` → `~/Documents/PairShot/photos/{before,after,combined}/`
  - 파일명 패턴: `<prefix><UUID>.jpg` → `{prefix}{type}_{timestamp}_{shortId}.jpg` (`FileNameBuilder` enum static func 분리)
  - 백업 정책 반전: `photos/` 백업 **포함** (isExcludedFromBackup 제거), `thumbnails/` 디렉토리 신규 생성 + 백업 제외
  - EXIF 회전 정규화: 캡처 콜백에서 `UIImage(cgImage:scale:orientation:)` → JPEG 재인코딩 → orientation=1 명시
  - SwiftData VersionedSchema (`SchemaV1`/`SchemaV2`) + MigrationPlan (Project → Album 1:1 변환 + 페어 필드 rename + lat/lon backfill)
  - 신규 테스트: AlbumModelTests · CameraSettingsTests · PairStatusComputedTests · FileNameBuilderTests · PhotoStorageDirectoryMigrationTests · PhotoStorageBackupTests (현 PhotoStorageBackupExclusionTests 정반대 시그니처) · ExifNormalizationTests
  - 기존 테스트 갱신: ProjectDeletionFileCleanupTests → AlbumDeletion(... 페어 유지) Tests, PhotoStorageQualityTests 의 `<prefix><UUID>.jpg` 가정 갱신

### R2 — `realign-architecture` — [ ]
- SCOPE: `PairShot/PairShot/{Domain,Data,App,Shared}/`(신규 디렉토리), `Features/`(ViewModel 분리), `PairShotApp.swift`
- Refs: `docs/17-architecture-and-patterns.md` (전체), `docs/15-non-functional-requirements.md` § 15.9
- Done:
  - 4 신규 디렉토리: `Domain/{Models,Repositories,Services,UseCases}/`, `Data/{Repositories,Storage,Ads,Composite,Location,Network,Util}/`, `App/{PairShotApp,AppEnvironment,RootView}.swift`, `Shared/{DesignSystem,Navigation,Permissions,Util}/`
  - 기존 파일 `git mv` 매핑 (`docs/03-spec-realign-findings.md` § Architecture 디렉토리 매핑 표 적용)
  - `Domain/Repositories/` 에 PhotoPair·Album·Coupon·AppSettings repository protocol 4종
  - `Data/Repositories/` 에 SwiftData/UserDefaults 구현체 4종
  - `Domain/UseCases/` 에 CreatePair·CaptureAfter·DeletePairs·ExportPairs·ToggleAlbumMembership·ActivateCoupon·CheckAdFreeState 7종 (callAsFunction)
  - 각 Feature 에 `*ViewModel.swift` (`@MainActor @Observable`) — View 가 ViewModel 만 호출하도록 정합
  - `App/AppEnvironment.swift` Composition Root — 모든 의존성 인스턴스화 + `.environment(env)` 주입
  - View 가 직접 보유하던 `AVCaptureSession` 을 `Features/Camera/CameraSession/CameraSessionActor.swift` (Data layer 격리) 로 이동, View 는 actor 참조만
  - `AdsCoordinator` protocol → Production `GoogleMobileAdsCoordinator` + Test `NoOpAdsCoordinator` 분리
  - 신규 테스트: 각 UseCase ≥ 1 happy + 1 edge + Mock 의존성 (~14 cases). Mock 들은 `Tests/Domain/Mocks/` 에

### R3 — `realign-ia` — [ ]
- SCOPE: `App/RootView.swift`, `Features/Camera/BeforeCameraView.swift`, `ContentView.swift`(삭제 또는 simple wrapper), `Features/Archive/`(전체 삭제 — Project 기반)
- Refs: `docs/11-information-architecture.md` § 0~3
- Done:
  - 앱 startDestination = `BeforeCameraView` (Project 의존 없음, optional `albumId` 파라미터)
  - TopBar 홈 아이콘 → Home(페어 그리드) push
  - `ArchiveView` / `ProjectRow` / `NewProjectSheet` / `EditProjectSheet` / `ProjectRenameService` / `ProjectDeletionService` 전부 삭제 (R1 에서 Project entity 제거 후속)
  - Camera (Before) 시스템 back → 앱 종료
  - 다중 선택 모드 시 시스템 back → 선택 해제 (popBack 아님)
  - 신규 테스트: RootViewStartDestinationTests · CameraBackBehaviorTests

### R4 — `realign-screens-album` — [ ]
- SCOPE: `Features/Home/`(신규 — HomeView + ViewModel + PairCardView + AlbumCardView + HomeFilterRow + HomeSelectionBottomBar + CreateAlbumDialog + HomeEmptyState), `Features/AlbumDetail/`(신규 — AlbumDetailView + ViewModel + PairPickerView + ViewModel + AlbumDialogs)
- Refs: `docs/12-screens.md` § 12.3·12.4·12.5
- Done:
  - `HomeView` = TopBar(selection 모드 토글) + Banner Ad + Filter Row(전체/앨범 SegmentedControl) + Pair/Album LazyVGrid + BottomBar(촬영/앨범생성/페어 다중선택 4 액션/앨범 다중선택 2 액션)
  - `AlbumDetailView` = TopBar back + 제목 + more menu(이름수정/앨범삭제) + 페어 그리드 + PrimaryActionBar(촬영 albumId/페어 추가) + 다중선택 BottomBar 의 "앨범에서 제거"
  - `PairPickerView` = 전체 페어 그리드 + 이미 속한 페어 dimmed + 다중 선택 + 추가 버튼
  - 신규 테스트: HomeViewModelTests (filter·selection·sort) · AlbumDetailViewModelTests (멤버십 관리) · PairPickerViewModelTests

### R5 — `realign-screens-pair-preview` — [ ]
- SCOPE: `Features/PairPreview/`(신규 — PairPreviewView + ViewModel), `Features/CameraAfter/`(retakeMode 분기 추가), `Domain/UseCases/CaptureAfterUseCase.swift`(retake 옵션)
- Refs: `docs/12-screens.md` § 12.6, `docs/14-functional-requirements.md` § 14.6
- Done:
  - `PairPreviewView` = TopBar back/more menu(재촬영) + 큰 미리보기 영역(합성본 우선/없으면 Before+After 분할) + 단계 토글(Before/After/합성본) + BottomBar(공유·기기저장·내보내기설정·삭제)
  - 재촬영 진입: `Camera (After, initialPairId, retakeMode=true)` — strip 비표시·자동 진행 X·완료 후 PairPreview 로 popBack + 합성 재생성(기존 combined 파일 덮어쓰기)
  - 신규 테스트: PairPreviewViewModelTests (단계 토글·재촬영 라우팅) · CaptureAfterRetakeFlowTests

### R6 — `realign-screens-settings-detail` — [ ]
- SCOPE: `Features/Settings/{WatermarkSettingsView,WatermarkSettingsViewModel,CombineSettingsView,CombineSettingsViewModel,LicenseView}.swift`(신규)
- Refs: `docs/12-screens.md` § 12.8·12.9·12.11, `docs/13-data-model.md` § AppSettings(WatermarkSettings/CombineSettings struct)
- Done:
  - `WatermarkSettingsView` = 기본 설정(유형 텍스트/로고 + 텍스트 입력 + 위치 3×3 + 크기 + 투명도 + 줄수 + 반복수) + 미리보기
  - `CombineSettingsView` = 정렬(좌우/상하) + 테두리(사용·두께·색) + 레이블(BEFORE/AFTER 텍스트·크기·색·위치·방식) + 레이블 배경(사용·색·투명도·곡률) + 미리보기
  - `LicenseView` = OSS 라이선스 목록 (`Pretendard` 등 + GoogleMobileAds + ZIPFoundation 등)
  - `WatermarkSettings` / `CombineSettings` Codable struct (R2 의 AppSettings 안에 nested)
  - 광고 게이트: `WatermarkSettingsGate` 추가 (R2 의 `RewardedAdManager.UnlockID.watermarkSettings` enum case 추가). AdFree 자동 통과
  - 신규 테스트: WatermarkSettingsViewModelTests · CombineSettingsViewModelTests · LicenseViewTests

### R7 — `realign-settings-structure` — [ ]
- SCOPE: `Features/Settings/SettingsView.swift`, `Features/Settings/SettingsView+Helpers.swift`, `Domain/Models/AppSettings.swift`
- Refs: `docs/12-screens.md` § 12.7
- Done:
  - 6 섹션 구조 정합: 촬영및파일 / 워터마크 / 합성 / 일반 / 쿠폰 / 저장공간및앱정보 (현 5 섹션 + 내보내기/저장공간 분리/일반 신규)
  - 촬영및파일: 이미지 품질(다이얼로그 75/85/95) + 파일명 접두어(다이얼로그 + 초기화) + 오버레이 투명도(다이얼로그 슬라이더) — 현 코드의 segmented Picker 대신 다이얼로그
  - 일반(신규): 언어(시스템/ko/en 라디오) + 시스템 테마(시스템/light/dark 라디오)
  - 저장공간및앱정보: 사진용량(표시) + 캐시(용량+초기화) + 앱버전 + 라이선스(R6 LicenseView 진입) + 개인정보처리방침(외부 브라우저)
  - 내보내기 섹션 제거 (BottomBar 액션으로만 진입 — R10)
  - 신규 테스트: SettingsSectionStructureTests (6 섹션 + 항목 라벨 키 정합)

### R8 — `realign-camera` — [ ]
- SCOPE: `Features/Camera/{Before,After}/...`, `Services/CameraSession.swift`(R2 후 actor)
- Refs: `docs/12-screens.md` § 12.1·12.2, `docs/14-functional-requirements.md` § 14.1
- Done:
  - 야간모드 chip 추가 (`CMTAVCaptureDevice.isLowLightBoostSupported` + `isLowLightBoostEnabled`)
  - Camera Before Strip 영역 신규 (After 미촬영 페어만 가로 스크롤, 64×64pt + 우상단 "After 필요" 배지, 빈 상태 텍스트)
  - 마지막 촬영 썸네일 갱신 (캡처 성공 후 `capturedThumbnail` 할당)
  - Camera After 회전 가이드 (CoreMotion roll vs 저장된 EXIF orientation 비교 → "왼쪽으로 눕혀 주세요" / "오른쪽으로 눕혀 주세요")
  - Camera After overlay chip 영역 (toggle + opacity slider 통합)
  - Camera Before 셔터 버튼 80pt 정합 (현 72pt)
  - TopBar 홈 아이콘 = `house.fill` (현 "닫기" 텍스트 버튼)
  - 신규 테스트: NightModeToggleTests · BeforeStripPopulationTests · RotationGuideTests

### R9 — `realign-functional-polish` — [ ]
- SCOPE: `Features/CameraAfter/AfterCaptureAction.swift`, `Domain/UseCases/CaptureAfterUseCase.swift`(R2 후), `Features/Gallery/MultiSelectBar.swift` → `Features/Home/HomeSelectionBottomBar.swift`(R4 후), `Services/SnackbarQueue.swift`(신규), `Shared/Util/BackgroundTaskGuard.swift`(신규)
- Refs: `docs/14-functional-requirements.md` § 14.2·14.4·14.8·14.9
- Done:
  - **자동 합성 트리거** (14.2): After 채워질 때 `AfterCaptureCoordinator` 가 `CompositeRenderer.makeComposite` 자동 호출 (사용자 트리거 X, ComparisonView 의 합성 메뉴 제거)
  - **"합성본만" 삭제 분기** (14.4): `PairDeletionService` 에 `deleteCombinedOnly(ids:in:storage:)` 추가 — combined 파일만 unlink + `pair.combinedFileName = nil` + `status` 회귀 (`.combined` → `.captured`)
  - **삭제 다이얼로그**: "일괄 삭제" / "합성본만" 2 버튼 분기
  - **백그라운드 in-flight 합성 보장** (14.8): `BackgroundTaskGuard.run { ... }` wrapper 가 `UIApplication.shared.beginBackgroundTask` ↔ `endBackgroundTask` 정합
  - **스낵바 큐잉/디바운스** (14.9): `@MainActor @Observable SnackbarQueue` (큐 + variant 색 + 동일 메시지 1초 debounce + 액션 가능 메시지 5초)
  - 신규 테스트: AutoCompositeTriggerTests · DeleteCombinedOnlyTests · BackgroundTaskGuardTests · SnackbarQueueTests (큐 순서·debounce·dismiss)

### R10 — `realign-export` — [ ]
- SCOPE: `Features/Export/ExportSettingsView.swift`(신규 — 별도 화면), `Features/Export/ExportSettingsViewModel.swift`(신규), `Features/Export/ShareCoordinator.swift`(신규 — 워터마크/합성 옵션 적용 시 재합성 처리), `Features/Home/HomeSelectionBottomBar.swift`(R4 후 — "내보내기설정" 진입점), `Features/Export/ShareSheet.swift`(현 ExportPicker 제거)
- Refs: `docs/12-screens.md` § 12.10, `docs/14-functional-requirements.md` § 14.3
- Done:
  - `ExportSettingsView` = 포함 항목 라디오(합성본만/Before만/After만) + 워터마크옵션 적용 toggle + 합성옵션 적용 toggle + 저장 형식 라디오(이미지/ZIP) + Bottom 2 버튼(공유/기기저장)
  - 워터마크/합성 옵션 적용 ON 시 재합성 후 export (진행 spinner)
  - ZIP 형식 저장 시 `UIDocumentPickerViewController` (현 `UIActivityViewController` ZIP 만)
  - "기기저장" PhotoKit 저장 시 albumName "PairShot" 자동 부착 (없으면 생성)
  - `ExportSettings` 마지막 사용 옵션 캐시 (UserDefaults, default 합성본만/이미지)
  - 신규 테스트: ExportSettingsViewModelTests · ShareCoordinatorReCompositeTests · DocumentPickerZipSaveTests

### R11 — `realign-strings` — [ ]
- SCOPE: `PairShot/PairShot/Resources/Localizable.xcstrings`(신규 String Catalog), `Resources/{ko,en}.lproj/Localizable.strings`(삭제 또는 transition), 모든 `Features/`·`Services/`·`Models/` 의 `String(localized: "...")` 호출, 코드의 raw 한국어 literal 9건
- Refs: `docs/16-strings.md` (전체)
- Done:
  - `Localizable.xcstrings` 신규 (Xcode String Catalog, ko/en 양쪽 등록)
  - 코드의 모든 `String(localized:)` 호출이 raw 한국어 키 → spec 컨벤션 키 (`{section}_{type}_{name}`) 로 일괄 교체
  - `docs/16.5` 의 200+ 핵심 키 등록 (xcstrings 에)
  - 하드코딩 한국어 9건 (CaptureSettings·CompositionSettings·StorageInfo·AfterCameraView·ContentView·PairGalleryView Preview) → `String(localized:)` 라우팅
  - error enum 들이 `var message: LocalizedStringResource` 패턴 적용 (raw String 반환 금지)
  - `LocalizableKeysAuditTests` 강화: `{section}_{type}_{name}` 컨벤션 grep + `String(localized:)` 호출 키가 xcstrings 에 모두 정의됐는지 + dead key 0
  - SwiftLint custom rule 또는 별도 audit script: `.swift` 파일에서 raw 한국어 literal 검출 시 fail
  - `developmentRegion = en` 또는 `ko` 결정 (현 `ko`)

### R12 — `realign-style-misc` — [ ]
- SCOPE: 전 코드베이스 (주석 제거), `PairShot/PairShot/Info.plist`(orientation), `Models/Coupon.swift` + `Services/CouponVerifier.swift`(JSON payload), 각 Service 파일(OSLog), `Shared/DesignSystem/Colors.swift`(신규 토큰), 하드코딩 Color literal grep 결과 전부
- Refs: `docs/15-non-functional-requirements.md` § 15.3·15.7·15.9·15.11, `.claude/refs/swift-style.md` § Comments
- Done:
  - 신규 추가된 `//` ~2335줄 + `///` ~1900줄 제거 (allow list: `// MARK: -`, `@unchecked Sendable` 정당화 1줄, framework-bug workaround 1줄). 자동 제거 후 수동 검토.
  - `Info.plist` `UISupportedInterfaceOrientations` = `UIInterfaceOrientationPortrait` 단독 (landscape 제거)
  - **Coupon JSON payload format** (15.3): `Coupon` 에 `kind: CouponKind`/`payloadVersion: Int`/`issuedAt: Date` 필드 + `CouponVerifier` 가 `{code,kind,issuedAt,version:1}` JSON Codable 디코딩 후 `version == 1` 검증 + 서명 검증
  - OSLog 5 카테고리 도입 (`Camera`/`Storage`/`Ads`/`Coupon`/`Network`) — 각 Service 에 `private let log = Logger(subsystem:category:)` + 기존 분기·에러 로그 `log.info`/`log.error` 라우팅. `print()` 사용 0 유지
  - `Shared/DesignSystem/Colors.swift` 시맨틱 색 토큰 신규 + 하드코딩 `Color.black/.white/.gray/.yellow/.green` 등 grep 결과 전부 토큰 교체 (Asset Catalog Color Set + Light/Dark 양쪽 정의)
  - Asset Catalog Color Set 의 Dark Appearance 누락 색 채움
  - 폰트 사이즈 하드코딩(`size: 18`, `size: 14`) → `.body`, `.caption` 등 의미 토큰
  - `accessibilityReduceMotion` 분기: 화면 전환 fade 만, blackout minimum
  - 터치 영역 < 44pt 1건 (CameraControlBar) `contentShape(Rectangle())` 또는 outer frame 보강
  - 신규 테스트: CouponJSONPayloadTests · OSLogCategoryTests · ColorTokenAuditTests · OrientationAuditTests · ReduceMotionTests

---

### R-Round 종료 기준

전 R1~R12 완료 후 1회 sweep:
- `xcodebuild -scheme PairShot build` PASS
- `xcodebuild -scheme PairShot test` PASS
- `audit-arch` skill PASS
- 하드코딩 한국어 grep = 0
- 하드코딩 색·dp grep = 0
- 신규 코드 주석 grep = 0 (allow list 외)
- explorer 8종 dispatch 결과 새 Critical/High = 0
- reviewer ≥ 70 점, blocking 0
- 사용자 manual 검수 (`docs/01-device-test-checklist.md`)

상기 모두 만족 시 v2.0 (spec 정합 v1.0) 출시 준비 완료.

---

## 진행 로그

- 2026-04-25: `feature/ios-mvp/00-bootstrap` 분기. 기존 `.claude/` `_legacy/`로 이동, 신규 자산(영문 5-Layer + 5 refs + audit-arch skill + hooks) + `docs/00-roadmap.md` 작성.
- 2026-04-25: Phase 6 (AdMob & Coupon) 추가. iOS 전용 항목 명시 (ATT·Privacy Manifest·SKAdNetwork·CryptoKit Ed25519·AVCaptureMetadataOutput QR). 후속 Phase 번호 +1 shift. Phase 0 진입 대기.
- 2026-04-25: Phase 0 완료 (`feature/ios-mvp/p0-purge`). P0.1~P0.4는 폐기 대상 코드가 처음부터 부재해 vacuous 처리. P0.5는 `IPHONEOS_DEPLOYMENT_TARGET` 26.4 → 17.0 정합화 (4 spots). P0.6 검증으로 build/test/audit-arch 모두 PASS. Phase 1 진입 대기.
- 2026-04-25: P1.1 완료 (`feature/ios-mvp/p1-foundation`). `Project` @Model + `PhotoPair` 최소 골격 + ModelContainer 등록. Xcode 템플릿 `Item` 제거. ContentView placeholder. ProjectModelTests 7종 PASS.
- 2026-04-25: P1.2 완료. `Features/Archive/ArchiveView` + 정렬 토글(updatedAt/createdAt desc Menu Picker) + 페어·완료·합성 CountBadge. ContentView를 ArchiveView wrapper로 정리. ArchiveViewQueryTests 5종 PASS.
- 2026-04-25: P1.3 완료. `LocationProviding` 프로토콜 + `CoreLocationService`(`requestLocation()` 단발), `NewProjectFactory` 순수 함수, `NewProjectSheet` Form. ArchiveView toolbar `+`. INFOPLIST_KEY_NSLocationWhenInUseUsageDescription 한국어 사유 등록. NewProjectFactoryTests 7종 PASS.
- 2026-04-25: P1.4 완료. ProjectSelection (@Observable) + MultiSelectBottomBar + ProjectDeletionService(cascade) + ProjectRenameService + EditProjectSheet. ArchiveView에 long-press(0.4s) 다중 선택 + safeAreaInset 하단 액션 바 + swipe-trailing `이름 변경`. ArchiveMultiSelectTests 8종 PASS. Phase 1 종료.
- 2026-04-26: P2.1 통합. `CameraSession.swift`(138L) + `CameraPreview.swift`(43L) + `CameraSessionTests.swift`(100L) — 수동 작업분을 commit 으로 정리해 dirty tree 해소. 자율 루프가 다음 fire 부터 P2.2~P2.7 일괄 진행. (xcodebuild 정합 검증은 P2 phase 종료 시 implementer 가 수행.)
- 2026-04-26: P2.2~P2.6 일괄 완료. CameraSession actor 를 zoom(ramp/setZoomFactor/preset)·렌즈(switchLens 4-tier 우선순위)·flash 4-mode (off/on/auto/torch)·focus(focusPointOfInterest)·EV(setExposureTargetBias)·capturePhoto(JPEG 반환) 로 확장. 신규 SwiftUI 컴포넌트: `CameraControlBar` (토글 4종) · `ZoomControl` (프리셋 4 버튼) · `FocusGestureView`+`FocusReticleView` (탭/드래그) · `GridOverlay` (3×3) · `LevelIndicator` (roll ±°) · `BeforeCameraView` (조립) · `CaptureShutterButton`+`BeforeCaptureCoordinator` (캡처→저장→`PhotoPair`). 신규 서비스: `MotionService` (CoreMotion roll 1Hz) · `PhotoStorageService` (`Application Support/photos/<UUID>.jpg`). 신규 테스트 35건 (CameraZoomTests 6 · CameraLensFlashTests 6 · FocusGestureTests 6 · MotionServiceTests 7 · GridOverlayTests 4 · PhotoStorageServiceTests 6). xcodebuild build PASS · xcodebuild test PASS (PairShotTests 70 / 0 failure). 통합(ArchiveView → BeforeCamera 진입)은 P5 UI gate 에서 처리.
- 2026-04-26: Phase 3 (After Camera with Overlay) 완료. `AfterCameraView` (272L) + `GhostOverlay`(GhostOverlayMath/Loader/View/AlphaSlider) + `AfterCaptureAction`(AfterCaptureCoordinator + AfterCameraPairLoader pure helpers). `PhotoStorageService.saveAfterJPEG` 추가 (saveBeforeJPEG 와 동일 디렉터리). 진입 시 `pendingPairs` 오래된 순 첫 페어 로드 → Before JPEG 를 `.opacity(alpha)` 로 단일 overlay (자동정렬 0) → `setZoomFactor(beforeZoomFactor)` 자동 복원(1회 가드, 핀치 override 가능) → 셔터 시 status=.complete + afterPath/afterCapturedAt + project.updatedAt 갱신 → 다음 pendingAfter 로 자동 전이, 없으면 dismiss. 신규 테스트 26건 (AfterCameraTraversalTests 7 · GhostOverlayTests 7 · AfterCaptureActionTests 6 · AfterZoomRestoreTests 6).
- 2026-04-26: Phase 4 (Gallery) 완료. `Features/Gallery/PairGalleryView`(LazyVGrid 2열 + PairThumbnailCell + ComparisonPlaceholder) · `GalleryFilter`(.all / .combinedOnly 순수 predicate) · `MultiSelectBar`(`PairSelection` @Observable + `PairMultiSelectBar` + `PairDeletionService`) · `Services/ThumbnailCache`(NSCache + ImageIO 다운샘플, evict on delete). 합성/공유 버튼은 `.disabled` placeholder (P5.2 / P7.3 활성화). 신규 테스트 28건 (GalleryFilterTests 6 · PairGalleryViewTests 6 · PairMultiSelectTests 7 · ThumbnailCacheTests 9). xcodebuild build PASS · xcodebuild test PASS (전체 131 case).
- 2026-04-26: Phase 5 (Comparison & Composition) 완료. `Features/Comparison/ComparisonView`(NavigationStack + 3-mode 토글 + DragGesture 인접 페어 순회 + 합성 메뉴 + 진행 ProgressView + 에러 알림) + `CompositeOptions`(CompositeLayout {.horizontal, .vertical}). `Services/CompositeRenderer`(composeFrames 공통-변 letterbox-zero 정렬 + UIGraphicsImageRenderer paste, makeComposite 디코드→렌더→워터마크→JPEG→`saveCombinedJPEG`→`pair.combinedPath` & `project.updatedAt` 갱신). `Services/WatermarkOverlay`(우하단 라운드 캡슐 위 단일 텍스트, UserDefaults `watermarkEnabled` 토글, default true via `register(defaults:)`). PhotoStorageService 에 `saveCombinedJPEG` 추가. PairGalleryView 의 ComparisonPlaceholder 제거하고 `.fullScreenCover` → 실 ComparisonView 로 교체. **자동정렬·자동 색보정 0** 원칙 그대로. 신규 테스트 30건 (ComparisonViewTests 11 · CompositeRendererTests 10 · WatermarkOverlayTests 8 + 기존 인프라 보강). xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: P6b 완료 (P6.4 단일 commit). 신규 `Features/Settings/CouponRegistrationView`(NavigationStack + Form 수동 paste + QR 스캔 fullScreenCover + 성공 토스트 → dismiss) · `Features/Settings/QRScannerView`(`UIViewControllerRepresentable` + 격리된 `AVCaptureSession` + `AVCaptureMetadataOutput(.qr)` 단일 인식 stop, 권한 거부 시 Settings 딥링크, 가운데 사각 가이드 + 햅틱). 분리 테스트 컴포넌트: `QRPayloadParser`(점-구분 단일 토큰 → `CouponPayload`, 빈/잘못된 separator/half 모두 typed throws) · `@MainActor @Observable CouponRegistrationViewModel`(verifier/now DI, parse → duplicate-active guard → verify → `Coupon` insert → `AdFreeStore.refresh` → `lastSuccessExpiration`). 신규 테스트 18건 (CouponRegistrationViewModelTests 8 · QRPayloadParserTests 10). xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: P6a 완료 (P6.1~P6.3 묶음 단일 commit). P6.1 — Google-Mobile-Ads-SDK 11.13.0 SPM 추가(project.pbxproj 직접 편집: `XCRemoteSwiftPackageReference` + `XCSwiftPackageProductDependency` + `packageReferences` + `packageProductDependencies` + Frameworks build-file). Info.plist 신규 + `GENERATE_INFOPLIST_FILE = NO` + synchronized-group `Info.plist` 빌드 리소스 예외(`PBXFileSystemSynchronizedBuildFileExceptionSet`). SKAdNetworkItems 51개 + 권한 사유 4종 + `GADApplicationIdentifier`(test app id). PrivacyInfo.xcprivacy(NSPrivacyTracking + 3종 API reasons). `AdsConfig` enum(DEBUG=test id 핀, RELEASE=Bundle lookup with fallback). `MobileAds.shared.start(completionHandler: nil)` `PairShotApp.init` 에서 호출(`#if canImport(GoogleMobileAds)` 가드). P6.2 — `TrackingAuthorizationProviding` 프로토콜 + `SystemTrackingAuthorizationProvider` + `@MainActor @Observable TrackingAuthorizationService`(`requestIfUndetermined()` 캐시 단락회로 + `refresh()`). P6.3 — `@Model Coupon` (status enum + `isCurrentlyActive(now:)`) ModelContainer 등록. `CouponVerifier.verify` (`Curve25519.Signing.PublicKey(rawRepresentation:)` + `isValidSignature(_:for:)`, 32-byte 영점 placeholder 키, malformed/empty 입력 throws). `@MainActor @Observable AdFreeStore`(active fetch → 만료 rollover persist → publish). 신규 테스트 35건 (CouponVerifierTests 10 · AdFreeStoreTests 7 · AdsConfigTests 4 · TrackingAuthorizationServiceTests 8). xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: P6c 완료 (P6.5·P6.6·P6.9 묶음 단일 commit). P6.5 — `BannerAdView` (UIViewRepresentable, `GADBannerView(adSize: GADAdSizeBanner)`) + `BannerAdSlot` (SwiftUI guard view, `BannerAdGate.shouldShow(isAdFree:)` → AdFree 시 EmptyView, ad request 자체 미발생). ArchiveView 하단 safeAreaInset VStack 에 multi-select 바와 stack. P6.6 — `@MainActor @Observable InterstitialAdManager` (`loadIfNeeded`/`presentIfReady` async API, `GADFullScreenContentDelegate` shim 으로 dismiss 시 coordinator release + 다음 ad prefetch). 분리 순수 함수 `InterstitialFrequencyGate.shouldPresent(now:lastShownAt:minimumInterval:)` (default 300 s). ComparisonView 합성 성공 직후 `presentIfReady(...)` 호출 — 실패 시는 호출 X. P6.9 — `actor FullscreenAdCoordinator { tryAcquire/release }` 액터 격리로 동시 풀스크린 광고 직렬화. SwiftUI 주입 위한 `\.fullscreenAdCoordinator` `EnvironmentKey` 추가(actor 는 Observable 미준수). `@MainActor @Observable AppOpenAdManager` 가 cold-start(`.task` 에서 첫 frame 후) + foreground 복귀(`.onChange(of: scenePhase)`) 양쪽에서 `presentIfReady(coldStart:)` 호출. 분리 순수 함수 `AppOpenAdGate.shouldPresent` (default 240 s, cold/foreground 동일 캡). PairShotApp 가 4 ad surface 인스턴스 `@State` 보관 + environment 주입, AdFreeStore 도 sharedModelContainer.mainContext 로 init. 신규 테스트 25건 (FullscreenAdCoordinatorTests 7 · InterstitialFrequencyCapTests 7 · AppOpenAdGateTests 8 · BannerAdGateTests 3). xcodebuild build PASS · xcodebuild test PASS (Simulator 87.7 s 1-shot).
- 2026-04-26: P6d 완료 (P6.7·P6.8 묶음 단일 commit). P6.7 — `@MainActor @Observable RewardedAdManager` (`UnlockID.compositionSettings` enum + `sessionUnlocks: Set<UnlockID>`); `presentForReward` 가 AdFree 시 `.skipped(adFree: true)` 즉시 unlock, 이미 unlock 시 `.granted` 즉시 반환, 그 외 `GADRewardedAd.present(fromRootViewController:userDidEarnRewardHandler:)` + 단일 continuation 으로 dismiss/fail/earn 신호를 `.granted` / `.userClosed` / `.failed(reason)` 4 outcome 으로 funnels. 분리 순수 함수 `RewardedSessionGate.shouldShowGate`. `CompositionSettingsGate<Content: View>` wrapper — 본 phase 는 wrapper + 단위 테스트만, 실 wire-up 은 P8.3. P6.8 — `@MainActor @Observable NativeAdLoader: NSObject` 가 `GADAdLoader` + `GADNativeAdLoaderDelegate` 구현, `prefetch(count:)` 로 풀 prebuild. 분리 순수 함수 `NativeAdInsertionStrategy.indices(forPairCount:interval:)` (default 6 → `[5, 11, 17, ...]`, 0/음수/interval ≤ 0 모두 empty). `PairGalleryView` LazyVGrid 데이터 모델을 `enum GalleryItem { .pair / .nativeAd }` 기반으로 전환 — AdFree 또는 selection mode 시 ad cell 미삽입. `NativeAdCell` (UIViewRepresentable wrapping `GADNativeAdView`, headline/body/icon/CTA 4 자산). `PairThumbnailCell` 별도 파일로 분리해 PairGalleryView 250 라인 이하 유지. ATT — `BootstrapAdsCoordinator.bootstrap(adFreeStore:tracking:ifNotAdFree:)` 순수 함수 (PairShotApp 에서 분리) 가 AdFreeStore.refresh → AdFree guard → ATT requestIfUndetermined → 4 manager + native loader load 순으로 직렬화. PairShotApp `.task { await bootstrapAds() }` 첫 프레임 1회. 신규 테스트 23건 (RewardedAdGateTests 7 · NativeAdInsertionTests 11 · ATTWiringTests 5). xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: **P6d 부터 docs/00-roadmap.md 가 git tracked.** P0~P6c 는 `/docs/` `.gitignore` 룰로 untracked 운영되어 phase 진행 상태가 git history 에 미반영 (각 phase 의 commit body 와 별도). 본 commit 의 roadmap 스냅샷이 P0~P6 전체의 정확한 상태이며, 후속 phase 는 동 파일을 갱신/commit 으로 단일 source of truth 유지. `.gitignore` 에 `!/docs/00-roadmap.md` 부정 룰 추가.
- 2026-04-26: **P6 묶음 종료 — 4 그룹 commit (P6a c3df1de · P6b 186f092 · P6c 6a1bc7d · P6d 3218f5f).** Phase 7 (Export & Share) 진입 대기.
- 2026-04-26: Phase 7 (Export & Share) 완료 (P7.1·P7.2·P7.3 단일 commit). ZIPFoundation 0.9.x SPM 추가(project.pbxproj 직접 편집). `Services/ZipExporter`(actor + `ExportMode` 4 case + `ExportSelection` 순수 함수가 `<projectTitle>/<pairUUID>_<role>.jpg` entry 생성, `Archive.addEntry(compressionMethod: .none)` 으로 JPEG 재압축 회피, typed `ExportError` throws). `Services/PhotoLibraryExport`(`protocol PhotoLibraryExporting` + production wrapper, `PHPhotoLibrary.requestAuthorization(for: .addOnly)` async + `performChanges { PHAssetCreationRequest.forAsset().addResource(with: .photo, data:, options: nil) }` continuation 래핑). `Features/Export/ShareSheet`(`UIViewControllerRepresentable` UIActivityViewController + `ExportPicker` Form/Picker/3 액션). View 250 라인 cap 유지를 위해 `ExportPickerSupport.swift` 로 helper 타입 분리. `MultiSelectBar` 의 공유 버튼 `.disabled(true)` → `.disabled(selectedIds.isEmpty)` 활성화 + `PairGalleryView` 가 `.sheet(item: $exportPayload)` 으로 ExportPicker 트리거. 신규 테스트 19건(ZipExporterTests 7 · PhotoLibraryExportTests 5 + FakePhotoLibraryExporter · ExportSelectionTests 8). xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: P8a 완료 (P8.1·P8.2 묶음 단일 commit). P8.1 — `Features/Settings/SettingsView`(NavigationStack + List `.insetGrouped`) 5 섹션 골격 (촬영·합성·내보내기·쿠폰·정보). 촬영만 NavigationLink 활성, 합성/내보내기/쿠폰은 `DisabledSettingsRow` placeholder (P8b/P8c). 정보 섹션에 `Bundle.main` 버전·빌드 표시. ArchiveView toolbar `gearshape` 아이콘 → `.sheet(SettingsView)`. PairShotApp 가 `@State private var appSettings = AppSettings()` 보관 + `.environment(appSettings)`. P8.2 — `Services/AppSettings.swift`(`@MainActor @Observable` UserDefaults wrapper, computed get/set, `register(defaults:)` 시드, `static let shared`) + `enum CaptureQualityPreset`(.low 0.6 · .standard 0.8 · .high 0.95 + `nearest(to:)`) + `enum FileNamePrefixValidator`(sanitize: 트림 → 금지문자(`/\:?*"<>|` + 제어/개행) 제거 → 32자 컷). `Features/Settings/CaptureSettingsView` Form 2 섹션: 품질 segmented Picker + prefix TextField `onChange` 디바운싱. `PhotoStorageService.save{Before,After,Combined}JPEG` 에 `fileNamePrefix: String = ""` 파라미터 추가, 내부 `writeJPEG` 헬퍼가 sanitize 한 prefix 로 `<prefix><UUID>.jpg` 저장. `BeforeCaptureCoordinator`/`AfterCaptureCoordinator` 생성자에 prefix 전달; `CompositeRenderer.makeComposite` 가 `CompositeOptions.jpegQuality` 를 AppSettings 의 값으로 인코딩 + prefix 도 saveCombinedJPEG 로 전파. ComparisonView/BeforeCameraView/AfterCameraView 가 `@Environment(AppSettings.self)` 주입. 신규 테스트 19건 (AppSettingsTests 6 · CaptureSettingsValidationTests 8 · PhotoStorageQualityTests 5). xcodebuild build PASS · xcodebuild test PASS (전체 ~250 case green).
- 2026-04-26: P8b 완료 (P8.3·P8.4 묶음 단일 commit). P8.3 — `AppSettings` 에 `defaultOverlayAlpha` / `defaultCompositeLayout` / `watermarkEnabled` 3종 + `register(defaults:)` 시드 확장(WatermarkOverlay 키 공유). 순수 헬퍼 `enum CompositionDefaults`(alphaRange · fallbackAlpha 0.5 · fallbackLayout .horizontal · clampAlpha NaN/Inf safe · layout(forRawValue:) unknown fallback). `Features/Settings/CompositionSettingsView` Form 3 섹션(슬라이더+퍼센트+푸터 / segmented 레이아웃 Picker / 워터마크 Toggle). `SettingsView` 합성 섹션 NavigationLink 활성화 + 요약 row(투명도·레이아웃·워터마크). `AfterCameraView` `.task` + `adopt(pair:)` 두 지점에서 `appSettings.defaultOverlayAlpha` 클램프 → `alpha` State 시드. `ComparisonView` 합성 메뉴를 default layout 우선 정렬 + "(기본)" 라벨로 surface. P8.4 — `PhotoStorageService` 에 `directorySize`(URL `.totalFileAllocatedSizeKey`) · `enumerateAllFiles`(`.skipsHiddenFiles + .skipsPackageDescendants`) · `orphanFiles(referencedRelativePaths:)` · `deleteOrphanFiles → (deletedCount, freedBytes)` · `static func filename(from:)` 추가. `Features/Settings/StorageInfoView` Form 2 섹션(폴더 크기 ByteCountFormatter `.file` + 페어 수 `@Query` / "고아 파일 삭제" 버튼 → confirmation alert → detached Task → 결과 라벨). `enum StorageInfoMath`(referencedRelativePaths 합집합·empty/nil 스킵 · formatBytes negative clamp). `SettingsView` "저장 공간" 섹션 NavigationLink 활성화. 신규 테스트 27건 (CompositionDefaultsTests 9 · AppSettingsCompositionTests 7 · StorageInfoTests 11). xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: P10a 완료 (P10.1·P10.2·P10.3 묶음 단일 commit). P10.1 — `AppIcon.appiconset/Contents.json` 을 1024 single-size + light/dark/tinted variant 3종으로 정합화, `AppIcon-1024.png` 1024×1024 sRGB placeholder (브랜드 teal `#1D7A8C` + 흰색 "PS") 를 `NSBitmapImageRep` 단발 Swift 스크립트(repo 외 `/tmp`)로 생성해 commit. LaunchScreen 은 기존 `Info.plist UILaunchScreen` empty dict 활용 (iOS 14+ 기본 흰 배경, storyboard 불필요). P10.2 — 4 권한 키 한국어 사유 강화 (≥12자 + 사용 목적 + 사용자 가치): 카메라(현장 작업 + 무광고 쿠폰 QR), 위치(프로젝트 자동 묶음), 사진(앨범 쓰기), ATT(거부 시 정상 사용 가능 명시 — App Store 5.1.1). P10.3 — `PrivacyInfo.xcprivacy` 4 top-level key 모두 정의: NSPrivacyTracking=YES, NSPrivacyTrackingDomains=[] (GMA SDK 자동 보충), NSPrivacyAccessedAPITypes 4 reasons (UserDefaults CA92.1 · DiskSpace E174.1 · SystemBootTime 35F9.1 · FileTimestamp C617.1), NSPrivacyCollectedDataTypes 2종 (PreciseLocation + PhotosorVideos, 둘 다 Linked=NO · Tracking=NO · Purposes=[AppFunctionality]). 신규 테스트 12건 (PrivacyManifestAuditTests 5 · InfoPlistPermissionAuditTests 7) — 매 빌드마다 plist 구조 회귀 차단. AppIcon PNG 는 placeholder, 실 디자인 교체는 P10.6 사용자 직접 작업. xcodebuild build PASS · xcodebuild test PASS.
- 2026-04-26: P9 완료 (P9.1·P9.2·P9.3·P9.4 묶음 단일 commit, Phase 9 종료). P9.1 — `Services/HapticService` (`protocol HapticServicing` + `@MainActor final class HapticService` UIKit wrapper, `HapticImpactStyle`/`HapticNotificationKind` enum, prepare() 호출, shared 싱글톤). 호출 6곳 통일 (CameraControlBar 토글 .light · CaptureAction shutter .heavy/success .success · ComparisonView 합성 success · StorageInfo 캐시정리 success · CouponRegistrationView 등록 success · QRScannerView 스캔 success). P9.2 — `DesignSystem/Materials` (`enum AppMaterial { panel, accent, sheet }` + `extension View.appMaterialBackground(_:)`). iOS 17 baseline 은 regular/thin/thickMaterial 매핑, iOS 26 Liquid Glass 분기 진입점은 한 파일로 격리. 보수적 적용 — CameraControlBar background 1곳. P9.3 — ko/en `Localizable.strings` 117 키 추출 + `developmentRegion = ko` + `knownRegions += ko` (project.pbxproj). PBXFileSystemSynchronizedRootGroup 가 lproj 디렉터리 자동 인식. P9.4 — `DesignSystem/PermissionDeniedView`(ContentUnavailableView + Settings 딥링크) + `enum PermissionDeniedSettingsURL` 순수 helper. BeforeCameraView/AfterCameraView 진입 시 `AVCaptureDevice.authorizationStatus(for: .video)` 가드 → 거부 시 PermissionDeniedView 노출 (세션 시작 skip). 신규 테스트 17건 (HapticServiceTests 5 · MaterialResolverTests 4 · PermissionDeniedViewTests 5 · LocalizableKeysAuditTests 3). xcodebuild build PASS · xcodebuild test PASS. Phase 10 (TestFlight Prep) 진입 대기.
- 2026-04-26: P8c 완료 (P8.5 단일 sub-step 단일 commit, Phase 8 종료). 신규 `Features/Settings/AdFreeStatusView`(Form 4 섹션 — 현재 상태 headline / "쿠폰 코드 등록" 버튼 → `.sheet(CouponRegistrationView)` / 활성 쿠폰(`activeCoupons` non-empty 시 표시) / 과거 쿠폰(`pastCoupons` non-empty 시, `만료`/`취소` 캡슐 라벨)). 분리 순수 함수 `enum AdFreeStatusFormatter`(remainingDays clamp negative-to-zero · headline isAdFree==false 또는 expiration==nil 모두 비활성 단락 · `maskCode "****-LAST4"` · `pastStatusLabel`). `Services/AdFreeStore` 에 `var activeCoupons` / `var pastCoupons` computed 노출 + 분리 순수 함수 `enum AdFreeCouponSorter`(active = `.active && expirationDate > now` desc by expiration, past = inverse desc by activatedAt). 등록 sheet `onDismiss` 도 `adFreeStore.refresh()` 한 번 더 호출(cancel 경로 방어). P8b reviewer advisory 흡수 — `SettingsView` 의 `SettingsRow`/`DisabledSettingsRow`/`compositionSummary`/`captureSummary` 4종을 `Features/Settings/SettingsView+Helpers.swift` 로 분리(captureSummary/compositionSummary 는 `extension AppSettings` 의 computed prop). SettingsView 251L → 176L. `couponSection` placeholder 제거 → `NavigationLink { AdFreeStatusView() }` 활성화. 신규 테스트 18건 (AdFreeStatusFormatterTests 10: remainingDays 3 · headline 3 · maskCode 3 · pastStatusLabel 1 / AdFreeStoreSortingTests 8: active sorting+filter, past sorting+stale-active 포함, 양분리 disjoint, store integration 2). xcodebuild build PASS · xcodebuild test PASS. Phase 8 종료 → Phase 9 (Polish) 진입 대기.
- 2026-04-26: **P10b 완료 (P10.4·P10.5·P10.6 + P9 reviewer advisory 흡수 단일 commit, Phase 10 종료, MVP 자율 루프 완주).** P10.4 — `docs/01-device-test-checklist.md` 12 섹션 한국어 체크리스트 + `DeviceChecklistAuditTests` 5건 (파일 존재 · 12 헤딩 · ≥ 12 체크박스 · TestFlight cross-link · 5 광고 surface). P10.5 — `Config/{Debug,Release}.xcconfig` 신규 + project.pbxproj `BASE_CONFIGURATION_REFERENCE` 등록 + Info.plist `AdUnitID_*` 5종 빌드 변수 노출 + `AdsConfig.resolve` placeholder 검출 fallback (`INSERT_PRODUCTION_ID_HERE` 시 테스트 ID 로 자동 fallback) + `AdsConfigReleaseLookupTests` 5건. P10.6 — `docs/02-testflight-upload-guide.md` 5 섹션 사용자 수행 가이드 (사전 교체 / Archive / Distribute / TestFlight 빌드 정보 / 디바이스 검증). P9 advisory — 5 view 다이어트 (BeforeCameraView 316 → 228 / AfterCameraView 327 → 218 / ComparisonView 452 → 244 / CouponRegistrationView 398 → 150 / QRScannerView 299 → 207, 5 신규 subview 파일 추출, 행위 변경 0) + Materials.swift 의 `swiftUIMaterial` 가 `if #available(iOS 26.0, *)` 분기로 `liquidGlassMaterial` placeholder / `legacyMaterial` 양분리 + `ViewLineCountAuditTests` 6건 (5 파일 cap + 5 추출 파일 sanity). xcodebuild build PASS · xcodebuild test PASS. ✅ PairShot iOS MVP 자율 phase 루프 완주 — P0~P10 모두 구현 완료. 다음 단계 = Phase 11 (App Store 출시) 사용자 직접 수행.
- 2026-04-26: **Audit-B 완료 (광고·권한·출시 메타 정합 9건 단일 commit).** 6 explorer 정밀 검수에서 식별된 광고/권한/출시 메타 영역의 High 발견사항을 일괄 수정. (1) **GADApplicationIdentifier xcconfig 변수화** — Info.plist 의 GAD app id 값을 `$(GAD_APPLICATION_ID)` 로 surface, Debug.xcconfig 가 Google 공식 sample app id (`ca-app-pub-3940256099942544~1458002511`), Release.xcconfig 가 placeholder `INSERT_PRODUCTION_APP_ID_HERE` 로 정의 (사용자 P10.6 가이드 따라 교체). (2) **AdUnitID_RewardedInterstitial 키 추가** — Info.plist 에 `AdUnitID_RewardedInterstitial` = `$(ADUNIT_ID_REWARDED_INTERSTITIAL)` 추가, Debug 는 Google 공식 test rewarded interstitial id, Release 는 placeholder. AdsConfig 의 기존 `rewardedInterstitial` 가 정합. (3) **CouponPublicKeyBase64 Info.plist 주입** — Info.plist 신규 키 + Release.xcconfig `COUPON_PUBLIC_KEY = INSERT_COUPON_PUBLIC_KEY_BASE64_HERE`, Debug 는 빈 값. `CouponVerifier.resolvedPublicKeyBase64(bundle:)` static helper 가 Bundle.main 또는 주입 bundle 에서 lookup → 비어있/공백/누락 시 placeholder zero key fallback. `verify(...)` 의 default 파라미터가 resolved key 사용. (4) **PrivacyInfo.xcprivacy 정합** — `NSPrivacyTrackingDomains` 에 Google Mobile Ads 4 도메인 (googleads.g.doubleclick.net · googlesyndication.com · googleadservices.com · doubleclick.net) 추가, `NSPrivacyCollectedDataTypes` 에 `AdvertisingData` (Tracking=YES · Purpose=ThirdPartyAdvertising) 추가. 기존 PrivacyManifestAuditTests 의 "모든 entry tracking=NO" 테스트는 PhotoVideos/Location 만 검증하도록 분리 갱신. (5) **CompositionSettingsGate wire-up** — SettingsView 의 합성 NavigationLink 가 `CompositionSettingsGate { CompositionSettingsView() }` 으로 wrap. AdFree 시 자동 통과, 비-AdFree 시 P6.7 rewarded ad 시청 후 진입. (6) **카메라 ScenePhase 처리** — Before/After CameraView 가 `@Environment(\.scenePhase)` + `.onChange(of:)` → `.background` 시 session.stop + motion.stop, `.active` 시 session.start + (Before) 수평계 켜졌으면 motion.start. 분리 순수 함수 `CameraScenePhaseGate.action(for:) → CameraSessionAction?` (.background → .stop · .active → .start · .inactive → nil). BeforeCameraView 가 250L cap 초과로 `CameraSessionHolder` 를 별도 파일 (`CameraSessionHolder.swift`) 로 추출. (7) **AppOpenAdGate dead branch 단순화** — `shouldPresent(coldStart:lastShownAt:now:minimumInterval:)` 의 if/else 분기 제거 (`coldStart` 인자는 시그니처 유지하되 `_` 로 무시). 기존 `AppOpenAdGateTests` 8 case 모두 PASS 그대로. (8) **AppOpen .inactive→.active 미트리거** — PairShotApp 에 `lastScenePhase` State 추가, 분리 순수 함수 `AppOpenScenePhaseGate.shouldPresent(previous:current:)` 가 `previous == .background && current == .active` 일 때만 true. `.inactive→.active` (전화/control center 복귀) 는 skip. (9) **ATT deny npa fallback** — 신규 `Services/AdRequestBuilder.swift` (`build(isAdFree:attStatus:) → GADRequest?` + 순수 `shouldAttachNonPersonalised(attStatus:)`). Banner / Interstitial / Rewarded / AppOpen / Native 5 manager 모두 `GADRequest()` 직접 생성 대신 AdRequestBuilder 통과 — `.authorized` 외 모든 ATT status 에서 `GADExtras` 의 `["npa": "1"]` 자동 부착. AdFree 시 nil 반환 → SDK 호출 자체 차단 (CLAUDE.md 핵심 원칙 7 강화). 신규 테스트 25건 (AdsConfigRewardedInterstitialTests 7 · CouponPublicKeyInjectionTests 7 · PrivacyManifestDomainTests 4 · CameraScenePhaseTests 6 · AppOpenScenePhaseGateTests 6 · AdRequestBuilderTests 4). xcodebuild build PASS · xcodebuild test PASS. Audit-C (Critical/High 외 잔여 notes) 는 후속 dispatch.

- 2026-04-26: **Audit-D 완료 (잔여 polish 11건 단일 commit, MVP 정밀 audit 종료).** (1) **View 다이어트** — `ArchiveView` 327→246L (`ArchiveProjectRow.swift` 신규 — `ProjectRow` + `CountBadge` 추출), `PairGalleryView` 265→231L (`PairGallery+Cameras.swift` 신규 — `GalleryItem` enum + `GalleryItemBuilder` 순수 빌더 + `PairGalleryToolbar` ToolbarContent + `PairGalleryCameraCovers` ViewModifier 추출), `ShareSheet` 251→37L (`ExportPicker.swift` 신규 — `ExportPicker` View 분리, ShareSheet 는 UIActivityViewController representable 만 보유). (2) **Localized 잔여** — Settings/Comparison/CameraBefore/CameraAfter 의 모든 한국어 literal 이미 `String(localized:)` 라우팅 확인. (3) **TestRepoLocator** (신규 helper) — `#filePath` 컴파일 시간 상수로 repo root 결정. `LocalizationCoverageTests` / `ViewLineCountAuditTests` 가 `Bundle.bundleURL` 기반 walk-up `XCTSkip` 제거하고 시뮬레이터에서도 PASS. ViewLineCountAuditTests 는 신규 분리 파일(Archive/Gallery/Export 3종) 도 cap 검증 + `testExtractedSubviewFilesExist` 가 8 파일 sanity. (4) **AppOpenAdGate API breaking** — `shouldPresent(coldStart:lastShownAt:now:minimumInterval:)` 의 `coldStart` 파라미터 제거 (Audit-B 에서 dead 처리, 본 phase 에서 시그니처 정리). 호출자 PairShotApp 2 곳, `presentIfReady(coldStart:from:...)` → `presentIfReady(from:...)` 도 시그니처 변경. AppOpenAdGateTests 8 cases / AppOpenScenePhaseGateTests 1 case 갱신. (5) **AfterCameraView+Lifecycle.swift** unused `import UIKit` 제거. (6) **`%d개 선택` / `%d개 페어` / `%d장 저장됨`** — string concatenation `"\(count)\(String(localized: "개 선택"))"` → `String(format: String(localized: "%d개 선택"), count)`. ko/en `.strings` 키 교체 (3 키 삭제 + 3 키 추가 — net 0). (7) **HapticDoubleFireTests CoordinatorContract 강화** — 기존 `_ = coordinator` 컴파일 가드를 source-level grep 검증으로 대체. `BeforeCaptureCoordinator` / `AfterCaptureCoordinator` 의 type body 가 `HapticService` / `CaptureHaptics` / `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` 4 심볼 모두 미참조 보장. (8) **Banner adaptive size** — `GADAdSizeBanner` (320×50 고정) → `GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)`. 분리 순수 helper `enum BannerAdSize`(`fallbackWidth=320` · `reloadThreshold=1.0` · `shouldReload(previous:current:)` hysteresis · `adaptive(width:)`). `Coordinator.lastWidth` 로 width 변화 시에만 adSize 재적용. BannerAdGateTests 에 6 cases 추가. (9) **CompositeRenderer EXIF + autoreleasepool + 재합성 cleanup** — `makeComposite` 시그니처 `throws` → `async throws`. 디코드/렌더/워터마크/JPEG 인코드 전체를 `Task.detached(priority: .userInitiated) { autoreleasepool { ... } }.value` 으로 오프로드 (메인 액터 풀에 두 UIImage 가 누적되지 않음). 분리 순수 enum `ExifEmbedder` (CGImageDestination + ImageIO 로 원본 픽셀 재인코딩 없이 EXIF `DateTimeOriginal` + GPS lat/lon/ref 적용, embed 실패 시 untagged JPEG fallback). `pair.combinedPath` 기존 값 있으면 `storage.deletePhoto` + `ThumbnailCache.evict` 후 새 파일 작성 (재합성 시 orphan 0). 신규 `CompositeRendererPerformanceTests` 8 cases — 재합성 cleanup · EXIF DateTimeOriginal round-trip · GPS N/E ref · GPS S/W ref · GPS skip when nil · ExifEmbedder 순수 helper 4 cases. ComparisonView.runComposite + 기존 CompositeRendererTests 4 cases 도 async 시그니처 적용. (10) **잔여 advisory** — `LocationService.locationManagerDidChangeAuthorization` 의 `finish(with: nil)` 호출에 `self.` prefix (actor 격리 명시). `RootNavigationTests:108` 의 tautology `flag == true || flag == false` → bootstrap idempotency round-trip. (11) **docs** — `docs/00-roadmap.md` Audit-D 진행 로그 + 현재 상태 갱신 ("PairShot iOS 완전 정밀 audit 종료"). xcodebuild build PASS · xcodebuild test PASS. Phase 11 (사용자 수행) 만 남음.

- 2026-04-26: **R1 완료 (realign-data-model 단일 commit, 옵션 A 첫 cluster).** (1) **Album @Model 신규** — id/name/createdAt/updatedAt/lat/lng/locationLabel + many-to-many `pairs: [PhotoPair]` (`@Relationship(.nullify, inverse: \PhotoPair.albums)`). 앨범 삭제 시 페어 유지(spec 13.1 — "앨범을 삭제하시겠습니까? 페어는 유지됩니다."). (2) **PhotoPair restructure** — `beforePath/afterPath/combinedPath` → `beforeFileName/afterFileName/combinedFileName` (path → 순수 파일명). 신규 필드 `updatedAt/latitude/longitude/locationLabel` + `cameraSettings: CameraSettings?` (JSON encoded `@Attribute(.externalStorage) Data?`). 신규 관계 `albums: [Album]`. **Project.project FK 제거**. 기존 `enum Status` (.pendingAfter/.complete) → `PairStatus` computed (.scheduled/.captured/.combined). (3) **CameraSettings struct** (Codable, value type) — zoomFactor/lensPosition/flashMode/useGrid/useNightMode + `LensPosition` (front/backWide/backUltraWide/backTele/backTriple/backDualWide) + `FlashMode` (off/on/auto/torch). (4) **PairStatus computed** — `extension PhotoPair { var status: PairStatus }` (combined 파일명 우선, 그 다음 after, 그 다음 scheduled). (5) **PhotoStorageService 디렉토리 분리** — `Application Support/photos/<UUID>.jpg` → `~/Documents/PairShot/{photos,thumbnails}/{before,after,combined}/`. **백업 정책 반전** — `photos/` 백업 포함 (사용자 데이터, restore 대상), `thumbnails/` 백업 제외 (재생성 가능). 신규 API: `saveBeforeJPEG/saveAfterJPEG/saveCombinedJPEG` 가 `fileName: String` 받음, `resolve(kind:fileName:)` / `deletePhoto(kind:fileName:)` / `clearAllThumbnails()` / `enumerateAllFiles()` per-kind. (6) **FileNameBuilder enum** — spec 13.2 패턴 `{prefix}{type}_{timestamp:yyyyMMdd_HHmmss}_{shortId:6자hex}.jpg`. 같은 페어 before/after/combined 가 같은 `shortId` 공유 (pairId 의 첫 6자). 한국어 prefix 허용 + `FileNamePrefixValidator.sanitize` 통과. 썸네일은 `{baseName}_thumb.jpg`. (7) **ExifNormalizer enum** — spec 13.4 회전 보정. UIImage(data:) → redrawWithUprightOrientation(`UIGraphicsImageRenderer.image(...)`) → `image.jpegData(compressionQuality:)` → CGImageDestination 으로 EXIF orientation=1 명시. 실패 시 입력 그대로 (graceful degrade). `ExifNormalizationTask.normalize` 가 detached + autoreleasepool 으로 호출. (8) **Capture EXIF wire** — `BeforeCaptureCoordinator.captureBefore` / `AfterCaptureCoordinator.captureAfter` 가 `captured.jpegData` 를 `ExifNormalizationTask.normalize` 통과 후 저장. (9) **SwiftData V1→V2 migration** — `SchemaV1`(LegacyProject + LegacyPhotoPair + LegacyCoupon, 옛 필드 그대로), `SchemaV2`(Album + PhotoPair + Coupon, 신 필드), `PairShotMigrationPlan: SchemaMigrationPlan` 가 `MigrationStage.custom` 로 V1.LegacyProject → V2.Album 1:1 변환 (lat/lng backfill 포함) + 페어 필드 rename + `cameraSettings = CameraSettings(zoomFactor: .beforeZoomFactor, lensPosition: lensPositionFromIdentifier, flashMode: .off, useGrid/useNightMode: false)`. `PairShotApp.bootstrap` 이 `Schema(versionedSchema: SchemaV2.self)` + `migrationPlan: PairShotMigrationPlan.self` 로 컨테이너 생성. (10) **Project entity 완전 제거** — `Models/Project.swift` 삭제. **Archive 디렉토리 5 파일 삭제** (`ArchiveView/ArchiveProjectRow/ArchiveView+Edit/ArchiveView+MultiSelect/NewProjectSheet`) — Project 의존이라 R1 시점에 필수 정리. (11) **임시 ContentView** — ArchiveView wrapper → `NavigationStack { PairGalleryView() }` 임시 패치 (R3 의 RootView 로 교체 예정). (12) **AlbumDeletionService** — `deleteAlbums(ids:in:)` 신규 (`Album` 만 삭제, 페어 유지). (13) **ThumbnailCache disk layer** — NSCache 메모리 우선, miss 시 disk thumbnail (`thumbnails/{kind}/{baseName}_thumb.jpg`) → 재생성 시 disk persist. API: `cached(kind:fileName:)` / `loadThumbnail(kind:fileName:storage:)` / `evict(beforeFileName:)` etc. (14) **CompositeRenderer/ComparisonView/PairGalleryView/PairThumbnailCell/MultiSelectBar/GalleryFilter/StorageInfo/ZipExporter/ExportPicker/ExportSelection/AdFreeStatusView/SettingsView 모두 새 필드명/디렉토리 적응**. PairGalleryView 가 `albumId: UUID?` 받음 (nil = 모든 페어, R3 에서 album 진입 추가 예정). BeforeCameraView/AfterCameraView 도 `albumId: UUID?`. CameraSettings 의 lensPosition 매핑은 `V1ToV2Migrator.lensPosition(for:)` 재사용. (15) **신규 테스트 7종** (총 ≥ 50 cases): AlbumModelTests · CameraSettingsTests · PairStatusComputedTests · FileNameBuilderTests · PhotoStorageDirectoryMigrationTests · ExifNormalizationTests · SchemaMigrationPlanTests. **삭제된 테스트 5종**: ProjectModelTests · ProjectDeletionFileCleanupTests · ArchiveMultiSelectTests · ArchiveViewQueryTests · NewProjectFactoryTests. **갱신된 테스트 ~15종**: PhotoStorageServiceTests/PhotoStorageBackupExclusionTests (백업 정책 반전 검증) / PhotoStorageQualityTests / GalleryFilterTests / PairGalleryViewTests / PairMultiSelectTests / AfterCaptureActionTests / AfterCameraTraversalTests / AfterZoomRestoreTests / GhostOverlayTests / ComparisonViewTests / CompositeRendererTests / CompositeRendererPerformanceTests / AccessibilityLabelTests / ZipExporterTests / ExportSelectionTests / RootNavigationTests / StorageInfoTests / ThumbnailCacheTests / ATTWiringTests / AdFreeStore tests / CouponRegistrationViewModelTests / LocalizationCoverageTests / ViewLineCountAuditTests. xcodebuild 검증은 R12 sweep 까지 미룸 (loop 정책).
- 2026-04-26: **Audit-A 완료 (출시 차단 Critical 6건 단일 commit).** 6 explorer 정밀 검수에서 식별된 출시 차단 Critical 만 묶어 일괄 수정. (1) **MVP 내비게이션 복구** — `ArchiveView` 의 `ProjectRow` 를 `NavigationLink(value: project)` + `navigationDestination(for: Project.self) { PairGalleryView(project:) }` 으로 wire-up (selection mode 시 NavigationLink 비활성화 → tap 으로 토글). `PairGalleryView` 의 toolbar `+camera` 버튼 → `.fullScreenCover BeforeCameraView`, `pendingAfter` cell tap → `.fullScreenCover AfterCameraView` (P3.1 의 자동 순회로 첫 미완료 페어 로드, P3.4 에서 dismiss). 이전 상태 = ArchiveView 가 dead-end 였으므로 전체 사용자 흐름 비도달. (2) **PhotoStorageService Backup 안전성** — `documents fallback` 제거 (Application Support 실패 시 `preconditionFailure` — 디스크 완전 고장 시에만 발생, iCloud Backup 누수 차단). `ensureDirectoryExists()` 가 photos 디렉터리에 `URLResourceValues.isExcludedFromBackup = true` 마킹 (idempotent). (3) **ProjectDeletionService 사진 파일 cascade** — `ProjectDeletionService.deleteProjects(ids:in:storage:)` 시그니처 확장 → 각 project.pairs 의 beforePath/afterPath/combinedPath JPEG 를 `PhotoStorageService.deletePhoto` 로 unlink + `ThumbnailCache.shared.evict`, 그 후 SwiftData entity delete + save (best-effort: 파일 누락 시도 SwiftData 삭제 진행). ArchiveView 의 호출 사이트도 `storage:` 주입. (4) **ModelContainer fallback** — `PairShotApp.sharedModelContainer` 의 `fatalError` 제거 → `ModelContainerBootstrap.bootstrap()` 이 디스크 store 시도 → 실패 시 `isStoredInMemoryOnly: true` fallback → 그것도 실패 시 `fatalError` 보존 (정말 시스템 문제). `ContentView(showFallbackAlert:)` 가 binding 받아 `.alert` 로 사용자 고지 ("일시 모드로 동작합니다. 데이터가 보존되지 않습니다."). App Store Review crash-on-launch reject 위험 회피. (5) **AppIcon Alpha 채널 제거** — Swift `CGContext(bitmapInfo: .noneSkipLast)` 단발 스크립트로 `AppIcon-1024.png` RGBA → RGB 변환, `sips -g hasAlpha` = no 검증. App Store Connect Upload Validation 통과 가능. (6) **ShareSheet Cancel 처리** — `UIActivityViewController.completionWithItemsHandler` 의 `completed: Bool` 두 번째 파라미터를 검사 → false (사용자 cancel) 인 경우 `onComplete?()` skip → ExportPicker 가 안 닫혀서 다른 목적지 재선택 가능. 신규 테스트 14건 (ProjectDeletionFileCleanupTests 5 — 디스크 파일 cascade 4 + 썸네일 evict 1 / PhotoStorageBackupExclusionTests 3 — 첫 save 후 flag · 멀티 save idempotent · helper round-trip / RootNavigationTests 7 — Project Hashable · 3 view init · ContentView binding 2 · bootstrap API). xcodebuild build PASS · xcodebuild test PASS. AppIcon hasAlpha=no 검증 완료. Audit-B/C (Critical 외 review notes) → orchestrator 후속 dispatch.
