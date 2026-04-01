# F19 - LiDAR Distance Measurement

## Requirements
- Tap two points on photo → Display actual distance (cm/m)
- Based on ARKit raycasting (activated only when LiDAR is available)
- Save measurement results in photo metadata

## Non-functional Requirements
- Measurement precision ±1~2cm (within 3m)
- Feature is hidden entirely on devices without LiDAR

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
