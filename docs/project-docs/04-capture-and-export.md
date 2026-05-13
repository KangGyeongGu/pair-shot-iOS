# 촬영 & 합성 & 내보내기

---

## 카메라 세션 (`Data/Camera/CameraSession.swift`)

### 기본 구성
- `AVCaptureSession`, `sessionPreset = .photo`
- 단일 `AVCapturePhotoOutput`, `maxPhotoQualityPrioritization = .quality`
- 모든 mutation 은 `sessionQueue` (`DispatchQueue("com.pairshot.camera.session", qos: .userInitiated)`) 위에서 실행
- 클래스 자체는 `@unchecked Sendable`, 진입점 = `runOnSessionQueue` / `runOnSessionQueueVoid`

### 디바이스 선택 (`+Lens.swift`)
후면 우선 fallback: `TripleCamera` → `DualWide` → `Dual` → `WideAngle`

### Responsive capture
지원 시 모두 활성:
- `isZeroShutterLagEnabled`
- `isResponsiveCaptureEnabled`
- `isFastCapturePrioritizationEnabled`
- `isAutoDeferredPhotoDeliveryEnabled`

### Readiness
`AVCapturePhotoOutputReadinessCoordinator` 로 `captureReadiness` 관찰. `.ready` 상태에서만 셔터 진입.

### Rotation
`AVCaptureDevice.RotationCoordinator` (iOS 17+) 로 preview / capture 각도 KVO 관찰.

### Zoom (iOS 18+ 분기)
- max: `device.activeFormat.systemRecommendedVideoZoomRange.upperBound` (iOS 18+) → `maxAvailableVideoZoomFactor` (fallback)
- 1× 기준: `displayVideoZoomFactorMultiplier` (iOS 18+) → `virtualDeviceSwitchOverVideoZoomFactors.first` 의 역수 (fallback)

### Photo capture 핸들러
- 일반 — `photoOutput(_:didFinishProcessingPhoto:)` → `photo.fileDataRepresentation()` JPEG → PhotoKit `.photo` 리소스
- Deferred proxy — `photoOutput(_:didFinishCapturingDeferredPhotoProxy:)` → `isDeferredProxy = true` 플래그 + PhotoKit `.photoProxy` 리소스

### 인터럽션
`AVCaptureSession.wasInterrupted` / `interruptionEnded` / `runtimeError` 알림 관찰 → 자동 `startRunning` 복구.

---

## 센서

### CoreMotion (`Data/Sensors/MotionService.swift`)
- `CMMotionManager.startDeviceMotionUpdates`, interval 0.05s, utility QoS 큐
- 노출 값 2개
  - `rollDegrees` — `attitude.roll` 도(°) 환산 → 수평계용
  - `orientation` — `CameraOrientation(gravityX:gravityY:)` → After 회전 안내용
- 구독자 수 기반 reference counting — count 0 일 때만 실제 stop

### CoreLocation (`Data/Location/LocationService.swift`)
- `desiredAccuracy = kCLLocationAccuracyHundredMeters`
- 권한 허가 후에만 `startUpdatingLocation`
- 캐시 채택 조건: `horizontalAccuracy > 0 && ≤ 1000`, `timestamp` ≤ 5초
- `fetchOnce()` — 캐시 있으면 즉시 반환, 없으면 start 후 2초 sleep

---

## EXIF GPS (`Domain/Util/ExifGPSBuilder.swift`)

GPS 캐시가 있을 때만 `kCGImagePropertyGPSDictionary` 빌드:
- `Latitude` / `LatitudeRef` (N/S)
- `Longitude` / `LongitudeRef` (E/W)
- `TimeStamp` (ISO8601)

빌드된 dict 는 `AVCapturePhotoSettings.metadata` 에 주입 → JPEG 파일에 자연스럽게 포함되어 PhotoKit 저장.

권한 거부 등으로 GPS 캐시가 없으면 EXIF GPS 만 누락, 촬영 자체는 정상.

---

## 합성 (`Data/Composite/`)

### 엔진
- `UIGraphicsImageRenderer` (CoreImage 미사용, Vision 미사용)
- `UIGraphicsImageRendererFormat.scale = 1`, `opaque = true`
- `Task.detached(priority: .userInitiated)` + `autoreleasepool`

### Layout (`CompositeOptions.swift`)
- `.horizontal` — `min(beforeHeight, afterHeight)` 로 통일 후 가로 결합, border 추가
- `.vertical` — `min(beforeWidth, afterWidth)` 로 통일 후 세로 결합
- 캔버스 = before + after + 3 × border (가운데 + 양쪽)
- `referenceImageWidth = 1024` 기준 border scale = `imageMaxWidth / 1024`
- Canvas background — border 활성 시 border color, 아니면 `.black`

### JPEG quality
- `CompositeOptions.jpegQuality` 기본 0.9
- Export 경로 0.95
- PairPreview 경로 0.95, `includeGPS = appSettings.embedGPSInPhoto`

### EXIF 작성 (`ExifEmbedder`)
합성물에는 원본 EXIF 를 복사하지 않고 새로 작성:
- `ExifDateTimeOriginal` / `Digitized` = `capturedAt`
- GPS — `includeGPS = true` 일 때 `pair.latitude/longitude` (N/S/E/W ref + 절대값)
- 그 외 필드 (orientation, ISO, focal length 등) 는 비포함

### Watermark (`WatermarkOverlay.swift`)

**Text 모드**
- 회전 `-π/4` 대각선 반복 텍스트
- `lineCount` 1..20
- `repeatCount` 0.1..3.0
- `textSizeRatio` 기반 폰트 크기 = `max(14, canvas.width × ratio)`
- white text + opacity
- 캔버스를 1.5배 확장해 대각선 영역 채움

**Logo 모드**
- `widthRatio` 0.1..0.9
- 9 위치 anchor (`LogoPosition`: topLeft..bottomRight + center 등)
- `alpha` 클램프
- `padding = canvas.width × 0.02`

### Label (`CompositeLabelDrawer.swift`)
- `CombineSettings.label.isEnabled` 시 BEFORE/AFTER 텍스트 표시
- 모드 `.fullWidth` — 이미지 너비 폭 배경 바
- 모드 `.free` — `LabelPosition` anchor + rounded corner
- 메트릭: `rectHeight = fontSize × 1.6`, `horizontalPadding = fontSize × 0.75`, `margin = fontSize × 0.4`

---

## Export 실행 (`Features/Export/ExportSettingsViewModel+Execute.swift`)

### Individual + Save to device
각 entry → `ExportEntryRenderer.render` → `photoLibraryExporter.saveImageData(_, type: .photo)` → `ExportHistoryEntity` 기록 (kind: `combined` / `watermarkedBefore` / `watermarkedAfter`)

### Individual + Share
각 entry → `tempDir/pairshot-share/<sanitized-name>` 임시 파일 → `UIActivityViewController`

### ZIP + Save to device
ZIP 생성 → `UIDocumentPickerViewController(forExporting:asCopy:)` 로 사용자 선택 위치 → 임시 zip 삭제

### ZIP + Share
ZIP 생성 → `UIActivityViewController`

### ZIP 구조 (`Data/Export/ZipExporter.swift`)
```
<album-name-or-PairShot>/
├── COMBINED/<file>.jpg
├── BEFORE/<file>.jpg
└── AFTER/<file>.jpg
```

- 폴더명 sanitize (`ExportSelection.sanitizeFolderName`): alphanumerics + `_-` + Hangul (`U+AC00..U+D7A3`) + 나머지 `_` 치환
- 파일명 (`FileNameBuilder`): `{prefix}_{BEFORE|AFTER|PAIR}_{seq3}_{yyyyMMdd}_{HHmmss}.jpg`
- prefix sanitize: 32자, `/\:?*"<>|` + 제어문자 / 개행 제거
- ZIP 파일명: `PairShot_{yyyyMMdd_HHmmss}.zip`
- `ZIPFoundation.Archive(accessMode: .create)`, `compressionMethod: .none`
- `actor ZipExporter` + `nonisolated struct ZipExporterAdapter` wrapper

### 진행 표시
- `SnackbarQueue.enqueueProgress` / `updateProgress` / `completeProgress` / `cancelProgress`
- 토큰 prefix: `export-share-` / `export-save-` / `share-` / `save-`
- Individual 은 entry 처리 비례 (`Double(processed) / Double(total)`)

### Interstitial gate
share / save 액션 진행 전 `InterstitialAdManager.runGated` — Home / AlbumDetail / Export 모두 동일.

### ImmediateExportService
Home / AlbumDetail 의 단축 share / save 진입점 (Export 화면 우회). 동일한 `ExportPreferences` 적용.

---

## UseCase 카탈로그 (`Domain/UseCases/`)

| UseCase | 역할 |
|---|---|
| `CreatePairUseCase` | Before JPEG 저장 + 새 Pair insert, 또는 `refillBefore(pairId:)` 로 기존 Pair 의 before 갱신 |
| `CaptureAfterUseCase` | Pair fetch → after JPEG 저장 → Pair 업데이트 |
| `RecaptureAfterUseCase` | 기존 after + combined export 자산 정리 → 새 after 기록 |
| `DeletePairsUseCase` | before / after / 모든 export history 자산을 Photo Library 에서 삭제 → DB 삭제 |
| `DeleteCombinedExportsUseCase` | combined export 자산만 Photo Library 삭제 + 레코드 삭제 |
| `DeletePairsKeepingCombinedUseCase` | before / after 원본만 Photo Library 삭제, Pair entity 삭제 (combined export 는 Photo Library 에 남음) |
| `ExportPairsUseCase` | `ZipExporterAdapter.exportPairsToZip` 위임 |
| `ToggleAlbumMembershipUseCase` | `addPair` / `removePair` 분기 |
| `ImmediateExportUseCase` | 현재 ExportPreferences 그대로 즉시 share / save 실행 |
