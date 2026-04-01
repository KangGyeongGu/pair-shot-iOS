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
