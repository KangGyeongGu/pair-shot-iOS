# F10 - ARKit Precision Repositioning

## Requirements
- During Before capture: Background save ARWorldMap (without user awareness)
- During After capture: Load ARWorldMap → Environment recognition → AR arrow position guidance
- On successful repositioning: Display "Position matched" + success haptic
- Devices without LiDAR: Operates with ARKit camera tracking only (~10cm precision)
- Devices with LiDAR: Auto-enhanced (1~3cm precision)

## Non-functional Requirements
- ARWorldMap save: Background, within 2~5 seconds
- ARWorldMap file size: 5~20MB
- Repositioning time: 2~10 seconds while moving camera
- AR session must not affect camera preview FPS

## UI Behavior
- ARWorldMap auto-loads on entering After capture mode (no separate guidance text)
- Position guidance: Display only semi-transparent arrows (visual representation of direction + distance)
- Arrow shrinks as user gets closer + haptic intensity increases
- Arrow disappears on position match + success haptic
- No text guidance ("Recognizing environment", etc.) — visual + tactile feedback is sufficient

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

## Related Files
