# Known Failures

반복 실패 패턴 기록. 3회 이상 반복 시 .claude/rules/로 승격.

## F001 — Hardcoded device values instead of API queries
- **Phase**: P1 Camera
- **Pattern**: Zoom factors, exposure limits, focal lengths were hardcoded (e.g., maxZoom * 15, exposureBiasLimit = 3.0)
- **Root Cause**: SDK headers not read before implementation. Unaware of systemRecommendedVideoZoomRange, systemRecommendedExposureBiasRange, displayVideoZoomFactorMultiplier
- **Prevention**: MUST read SDK headers first. Use device.activeFormat.systemRecommended* APIs. Never hardcode device-specific values.
- **Recurrence**: 3+ (zoom, exposure, focal length — promoted to CLAUDE.md rule)

## F002 — Wrong coordinate system for focus/exposure
- **Phase**: P1 Camera
- **Pattern**: Touch coordinates normalized by simple division (x/width) instead of using AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)
- **Root Cause**: SDK header for AVCaptureVideoPreviewLayer not read
- **Prevention**: Always use previewLayer.captureDevicePointConverted(fromLayerPoint:) for focus/exposure point conversion
- **Recurrence**: 1

## F003 — SwiftUI view swap breaks DragGesture context
- **Phase**: P1 Camera (zoom dial)
- **Pattern**: Using if/else to swap views (ZoomButtonRow ↔ ZoomDialView) caused DragGesture to reset mid-drag, resulting in 0.5x starting position bug
- **Root Cause**: SwiftUI recreates gesture state when view tree changes
- **Prevention**: Keep both views in ZStack, use .opacity to toggle visibility instead of conditional rendering
- **Recurrence**: 1

## F004 — API name guessing without SDK verification
- **Phase**: P1 Camera
- **Pattern**: Used rampToVideoZoomFactor (wrong) instead of ramp(toVideoZoomFactor:withRate:) (correct). Used deprecated APIs.
- **Root Cause**: Guessed API names from memory instead of reading SDK headers
- **Prevention**: Always grep SDK headers for exact method signatures before writing code
- **Recurrence**: 2

## F005 — Empty closures and disconnected navigation (P2)
- **Phase**: P2 Data Model
- **Pattern**: PairGalleryView had 4 buttons with empty action closures (Button {}). ArchiveView used navigationDestination instead of fullScreenCover for camera, causing duplicate back buttons.
- **Root Cause**: develop-worker created UI elements without implementing action logic. No verification step for UI-logic connection completeness.
- **Prevention**: develop-worker must verify every button action is connected. code-reviewer must flag empty closures as critical.
- **Recurrence**: 1

## F006 — View created but not inserted into parent (P3)
- **Phase**: P3 Ghost Overlay
- **Pattern**: GhostOverlayView.swift and SensorGuideView.swift were created as files but never inserted into CameraView body ZStack. beforeImage loading logic was also missing entirely.
- **Root Cause**: develop-worker created separate View files but did not add them to the parent view hierarchy. No spec-vs-implementation completeness check.
- **Prevention**: develop-worker must verify all new Views appear in their parent body. Creating a file ≠ using it.
- **Recurrence**: 1
