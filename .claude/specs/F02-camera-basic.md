# F02 - Before Capture

## Requirements
- Launch camera immediately after project creation in F01 or after entering an existing project
- Automatically create a new pair + save before.jpg on photo capture
- Record sensor data (pitch/roll/yaw/heading/GPS) simultaneously with capture
- Continuous shooting: Camera stays active after capture, each shutter tap auto-creates a new pair
- Auto-generate thumbnail after capture (300x300)
- Background save ARWorldMap (when available)
- **Capture count display:** "3 photos taken" (current session capture count)

## Non-functional Requirements
- Capture → pair creation → save completed within 1 second (no user waiting)
- Memory usage stays under 200MB (during continuous shooting)

## UI Behavior
- Full-screen camera preview
- Bottom shutter button (large and clear, tappable with gloves)
- Top: Flash / aspect ratio / grid line toggles
- Bottom-left thumbnail stack on capture (most recent capture, tap to open gallery)
- Top or bottom: "N photos taken" count
- Back: Return to Archive (project gallery)

## Edge Cases
- Camera permission denied → Guidance screen directing to Settings app
- Insufficient storage → Warning dialog
- App goes to background → Pause camera session, auto-resume on return
- ARWorldMap save failure (insufficient environment features) → Ignore, save sensor data only
- Additional shooting when project already has befores → Append new pairs after existing ones

## Implementation Points
- `AVCaptureSession` + `AVCapturePhotoOutput`
- On capture: Create `PhotoPair(status: .pendingAfter)` → Create `Photo` → Save file
- Sensors: `CMMotionManager.deviceMotionUpdateInterval = 1/60`, snapshot at capture moment
- Thumbnail: `CGImageSourceCreateThumbnailAtPixelSize` (memory efficient)
- ARWorldMap: `arSession.getCurrentWorldMap` → `NSKeyedArchiver` → File save
- File saving / thumbnail generation processed on background queue

## Apple SDK References
- .claude/apple-sdk-refs/AVFoundation/AVCaptureDevice.h
- .claude/apple-sdk-refs/AVFoundation/AVCaptureSession.h
- .claude/apple-sdk-refs/AVFoundation/AVCapturePhotoOutput.h
- .claude/apple-sdk-refs/AVFoundation/AVCaptureVideoPreviewLayer.h
- .claude/apple-sdk-refs/AVFoundation/AVCaptureInput.h
- .claude/apple-sdk-refs/Photos/PHPhotoLibrary.h
- .claude/apple-sdk-refs/Photos/PHAssetChangeRequest.h
- .claude/apple-sdk-refs/ImageIO/CGImageSource.h

## Related Files
