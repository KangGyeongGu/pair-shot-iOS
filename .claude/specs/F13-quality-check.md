# F13 - Capture Quality Check

## Requirements
- Automatic quality analysis immediately after capture
- Blur detection: Laplacian filter-based blur score
- Exposure check: Histogram analysis (over/under exposure)
- On poor quality: "Blurry photo detected. Retake?" dialog

## Non-functional Requirements
- Analysis completed within 0.5 seconds
- Minimize false positives (flagging normal photos as poor quality)

## UI Behavior
- Automatic operation, saved without any indication when quality is good
- Dialog only on poor quality: "Retake" / "Save anyway"

## Implementation Points
- Blur: `CIFilter(name: "CILaplacian")` → Calculate variance, blur if below threshold
- Exposure: `CIFilter(name: "CIAreaHistogram")` → Analyze histogram distribution
- Analysis runs on background queue, only results delivered to main thread

## Related Files
