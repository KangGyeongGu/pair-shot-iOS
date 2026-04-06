# F14 - AI Auto Alignment

## Requirements
- Runs automatically after After capture (no user action required)
- Compute homography between before-after using Vision `VNHomographicImageRegistrationRequest`
- Warp the **after** image with the computed matrix to pixel-align with **before** (before = reference)
- Use aligned_after.jpg in comparison view (F25)

## Non-functional Requirements
- Processing within 2 seconds on A14 or later
- Use original image on alignment failure (graceful fallback)

## Edge Cases
- Capture angles too different → Homography fails → Use original + display "Alignment not possible"
- Scene significantly changed (construction completed) → Insufficient matching points → Use original

## Implementation Points
- `VNHomographicImageRegistrationRequest(targetedCGImage: afterResized)`
- `VNImageRequestHandler(cgImage: beforeCG).perform([request])`
- `observation.warpTransform` → Warp afterResized using `CIPerspectiveTransform` → aligned_after.jpg
- Cache warped image (prevent recomputation)

## Apple SDK References
- .claude/apple-sdk-refs/Vision/VNHomographicImageRegistrationRequest.h
- .claude/apple-sdk-refs/Vision/VNImageRequestHandler.h
- .claude/apple-sdk-refs/Vision/VNObservation.h
- .claude/apple-sdk-refs/CoreImage/CIFilter.h (CIPerspectiveTransform)

## Related Files
