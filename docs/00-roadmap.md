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

## 현재 상태

- Phase: **P8b 종료 (합성 설정 + 저장 용량/캐시 정리)**
- 다음 task: **P8c — 쿠폰·AdFree 섹션 (P8.5)**
- Branch: `feature/ios-mvp/p8b-composition-storage`
- Last commit: feat(P8b) 합성 설정 + 저장 용량/캐시 정리

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

### P8.5 — 쿠폰·AdFree 상태 섹션
- SCOPE: `PairShot/PairShot/Features/Settings/AdFreeStatusView.swift`
- Done: 현재 AdFree 활성/비활성·만료일 표시. "쿠폰 등록" 버튼 → P6.4 CouponRegistrationView 진입. 활성 쿠폰 목록 (사용 중·과거).

---

## Phase 9 — Polish

### P9.1 — 햅틱 피드백 (셔터·토글·완료)
- SCOPE: `PairShot/PairShot/Services/HapticService.swift`
- Done: UIImpactFeedbackGenerator 또는 Core Haptics. 셔터=heavy, 토글=light, 완료=success.

### P9.2 — Liquid Glass UI 조건 분기 (iOS 26+)
- SCOPE: `PairShot/PairShot/DesignSystem/Materials.swift`
- Refs: `.claude/refs/swiftui-patterns.md`
- Done: `if #available(iOS 26.0, *)` 분기로 Liquid Glass material 사용. 미만은 .regularMaterial.

### P9.3 — Localizable.strings 추출
- SCOPE: `PairShot/PairShot/Resources/Localizable.strings` (ko, en)
- Done: 모든 한국어 하드코딩 문자열 추출. ko 1차, en 자동 영문 (대충 OK, 정식 번역은 출시 직전).

### P9.4 — 빈 상태 / 오류 상태 UI
- SCOPE: 각 Feature의 EmptyState / ErrorState View
- Done: 프로젝트 0개 / 페어 0개 / 권한 거부 / 카메라 사용 불가 등 모든 시나리오 표시 메시지 + 액션 버튼.

---

## Phase 10 — TestFlight Prep

### P10.1 — 앱 아이콘 + 스플래시
- SCOPE: `PairShot/PairShot/Assets.xcassets/AppIcon.appiconset/`, LaunchScreen
- Done: 모든 사이즈 아이콘 (1024 마스터 + iOS 자동 변환). LaunchScreen storyboard 또는 Info.plist UILaunchScreen.

### P10.2 — 권한 description 검토
- SCOPE: `PairShot/PairShot/Info.plist`
- Refs: `.claude/refs/ios-permissions.md`
- Done: 카메라·위치·사진·ATT description 한국어로 적절. App Store 검수 가이드 기준.

### P10.3 — Privacy Manifest 최종 검토
- SCOPE: `PairShot/PairShot/PrivacyInfo.xcprivacy`
- Done: NSPrivacyTracking, NSPrivacyAccessedAPITypes (UserDefaults·DiskSpace·SystemBootTime 등 reasons), NSPrivacyCollectedDataTypes 항목 정확히 신고.

### P10.4 — 실 디바이스 스모크 테스트 체크리스트
- SCOPE: `docs/01-device-test-checklist.md` (이번 task에서 생성)
- Done: Before 촬영·After 촬영·overlay·합성·공유·설정·광고·쿠폰 등록 all paths 수동 체크리스트 작성. 사용자가 실제 디바이스에서 한 번씩 실행 후 체크.

### P10.5 — Release configuration 빌드
- SCOPE: Xcode build settings, AdMob production unit ID 주입
- Done: Release 빌드로 archive 생성. 앱 크기 확인. AdMob test → production unit ID 전환 (xcconfig 변수).

### P10.6 — TestFlight 업로드 (선택)
- SCOPE: 사용자 직접
- Done: Xcode Organizer로 archive 업로드. 사용자가 직접 진행 — 자동화 X.

---

## Phase 11 — App Store 출시 (정식 출시 시점)

이 단계는 **본인 결정 후 별도로 진행**. 이 roadmap에는 task 미정의.

- 스토어 등록 정보 (스크린샷·설명·그래픽)
- 개인정보처리방침 URL
- 앱 콘텐츠 양식
- 출시 국가
- 검수 제출

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
