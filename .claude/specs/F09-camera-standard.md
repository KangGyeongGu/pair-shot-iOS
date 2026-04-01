# F09 - Standard Camera Features

## Requirements
- Aspect ratio switch: 4:3 (default), 16:9, 1:1
- Zoom: 0.5x / 1x / 2x / 3x(5x) — Auto lens switching
- Flash: Auto / On / Off
- Grid lines: Rule of thirds overlay toggle
- Timer: Off / 3 sec / 10 sec
- Front/rear camera switch

## Non-functional Requirements
- Preview changes immediately on aspect ratio switch (no delay)
- Pinch gesture zoom also supported

## UI Behavior
- Top bar: Flash / Timer / Aspect ratio icons
- Zoom: Bottom zoom buttons (0.5x, 1x, 2x) + Pinch gesture
- Grid lines: Settings or top bar icon
- Front/rear switch: Bottom-right rotation icon

## Implementation Points
- Aspect ratio: Sensor always captures at 4:3, `CGRect` crop on preview/save
- Zoom: `AVCaptureDevice.videoZoomFactor` + `rampToVideoZoomFactor` (animated)
- Lens switching: Reference `virtualDeviceSwitchOverVideoZoomFactors`
- Flash: `AVCapturePhotoSettings.flashMode`
- Grid: Draw 2 vertical lines + 2 horizontal lines on `UIView`

## Apple SDK References
- .claude/apple-sdk-refs/AVFoundation/AVCaptureDevice.h (videoZoomFactor, virtualDeviceSwitchOverVideoZoomFactors, displayVideoZoomFactorMultiplier, flashMode, focusMode, whiteBalanceMode)
- .claude/apple-sdk-refs/AVFoundation/AVCapturePhotoOutput.h (flashMode, supportedFlashModes)
- .claude/apple-sdk-refs/AVFoundation/AVCaptureSession.h

## Related Files
