# F19 - LiDAR Distance Measurement

## Requirements
- Tap two points on photo → Display actual distance (cm/m)
- Based on ARKit raycasting (activated only when LiDAR is available)
- Save measurement results in photo metadata

## Non-functional Requirements
- Measurement precision ±1~2cm (within 3m)
- Feature is hidden entirely on devices without LiDAR

## UI Behavior
- First tap → place start point marker on surface
- Second tap → place end point marker + draw connecting line + display distance label (cm when <1m, m when ≥1m)
- Third tap → reset all markers and start over

## Edge Cases
- No surface detected at tap point (raycast returns no result) → ignore tap silently
- Distance >3m → show accuracy warning alongside distance label
- Oblique surface angle → reduced precision note shown near distance label

## Implementation Points
- `ARSession.raycast(_:)` → `ARRaycastResult.worldTransform`
- Calculate `simd_distance` between two points
- Runtime check: `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`

## Apple SDK References
- .claude/apple-sdk-refs/ARKit/ARSession.h
- .claude/apple-sdk-refs/ARKit/ARRaycastQuery.h
- .claude/apple-sdk-refs/ARKit/ARRaycastResult.h
- .claude/apple-sdk-refs/ARKit/ARWorldTrackingConfiguration.h (supportsSceneReconstruction)

## Related Files
