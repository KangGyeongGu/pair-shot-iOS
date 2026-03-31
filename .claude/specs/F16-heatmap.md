# F16 - Change Detection Heatmap

## Requirements
- Display changed areas as a red overlay on aligned before-after images
- Show change percentage (e.g., "42% area changed")
- Displayed as one of the comparison view modes

## Implementation Points
- `CIFilter.differenceBlendMode()` → Difference image
- `CIFilter.falseColor()` → Convert to red overlay
- `CIFilter.sourceOverCompositing()` → Composite over after image
- Change percentage: Calculate ratio of pixels exceeding threshold in difference image

## Related Files
