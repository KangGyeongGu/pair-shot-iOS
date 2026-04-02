# F10 - ARKit Precision Repositioning

## Requirements
- During Before capture: Background save ARWorldMap (without user awareness)
- During After capture: Load ARWorldMap → Environment recognition → AR arrow position guidance
- On successful repositioning: Display "Position matched" + success haptic
- Devices without LiDAR: Operates with ARKit camera tracking only (~10cm precision)
- Devices with LiDAR: Auto-enhanced (1~3cm precision)
- Position match threshold: LiDAR device: ±10cm, non-LiDAR: ±20cm
- Height(Y) correction: up/down arrow using ARCamera.transform[3].y
- Distance(Z) correction: forward/back arrow using ARCamera.transform[3].z
- No text guidance — 3D icons only for direction communication
- Stage transition: worldMappingStatus == .mapped activates Stage 2 (position guide)

## Non-functional Requirements
- ARWorldMap save: Background, within 2~5 seconds
- ARWorldMap file size: 5~20MB
- Repositioning time: 2~10 seconds while moving camera
- AR session must not affect camera preview FPS

## UI Behavior
- ARWorldMap auto-loads on entering After capture mode (no separate guidance text)
- Position guidance: Display 3D arrow icons for X(lateral)/Y(height)/Z(distance) axis-separated guidance
- Each axis has an independent 3D arrow; arrows shrink as user gets closer on that axis
- Arrow disappears per axis on position match; all arrows gone + success haptic when fully matched
- No text guidance ("Recognizing environment", etc.) — 3D icons only for direction communication
- worldMappingStatus == .mapped activates Stage 2 (position guide)

## Edge Cases
- ARWorldMap file missing (previous version before, or save failure) → Ignore, use sensor + overlay only
- Environment significantly changed (after construction) → Repositioning fails → Timeout then fallback to sensor guide
- Dark environment → Tracking unstable without LiDAR → Abandon repositioning, sensor fallback

## Implementation Points
- `ARWorldTrackingConfiguration` + `initialWorldMap`
- `ARSessionDelegate.session(_:didUpdate:)` → `frame.worldMappingStatus`
- `.mapped` → Repositioning successful
- Arrow: `SCNNode` or SwiftUI overlay showing direction/distance
- Sensor tier: Check `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`

## Apple SDK References
- .claude/apple-sdk-refs/ARKit/ARSession.h
- .claude/apple-sdk-refs/ARKit/ARWorldTrackingConfiguration.h
- .claude/apple-sdk-refs/ARKit/ARWorldMap.h
- .claude/apple-sdk-refs/ARKit/ARFrame.h
- .claude/apple-sdk-refs/ARKit/ARCamera.h
- .claude/apple-sdk-refs/ARKit/ARAnchor.h

## Related Files
