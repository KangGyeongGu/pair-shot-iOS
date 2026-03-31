# F14 - AI Auto Alignment

## Requirements
- Runs automatically after After capture (no user action required)
- Compute homography between before-after using Vision `VNHomographicImageRegistrationRequest`
- Warp the before image with the computed matrix to pixel-align with after
- Use aligned image in comparison views (F07, F11, F16)

## Non-functional Requirements
- Processing within 2 seconds on A14 or later
- Use original image on alignment failure (graceful fallback)

## Edge Cases
- Capture angles too different → Homography fails → Use original + display "Alignment not possible"
- Scene significantly changed (construction completed) → Insufficient matching points → Use original

## Implementation Points
- `VNHomographicImageRegistrationRequest(targetedCGImage: after)`
- `VNImageRequestHandler(cgImage: before).perform([request])`
- `observation.warpTransform` → Warp before using `CIPerspectiveTransform`
- Cache warped image (prevent recomputation)

## Related Files
