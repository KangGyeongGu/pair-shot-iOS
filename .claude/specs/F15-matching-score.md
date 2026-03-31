# F15 - Matching Score

## Requirements
- Display before-after composition match rate as a numeric value
- Grades: Excellent (distance < 5) / Good (5~15) / Retake recommended (> 15)
- Displayed on comparison view screen

## Implementation Points
- `VNGenerateImageFeaturePrintRequest` → `VNFeaturePrintObservation`
- `fp1.computeDistance(&distance, to: fp2)` → Float distance
- UI: Top badge "92% match" or color code (green/yellow/red)

## Related Files
