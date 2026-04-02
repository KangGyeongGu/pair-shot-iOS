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

## Edge Cases
- Low-light/night: relax blur threshold (lower Laplacian variance cutoff)
- Intentional bokeh/out-of-focus: blur detection may produce false positive; consider exposure context
- Rapid continuous capture: async analysis must use a serial/concurrent queue to avoid blocking main thread

## Implementation Points
- Blur: `CIFilter(name: "CILaplacian")` → Calculate variance, blur if below threshold
- Exposure: `CIFilter(name: "CIAreaHistogram")` → Analyze histogram distribution
- Analysis runs on background queue, only results delivered to main thread

## Apple SDK References
- .claude/apple-sdk-refs/CoreImage/CIFilter.h (CILaplacian)
- .claude/apple-sdk-refs/CoreImage/CIImage.h
- .claude/apple-sdk-refs/AVFoundation/AVCaptureDevice.h (ISO, exposureDuration)

## Related Files
