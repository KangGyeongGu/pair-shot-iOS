# F17 - Color Correction Matching

## Requirements
- Auto-correct lighting differences between before (morning) and after (afternoon)
- Use corrected images in comparison views and heatmap
- Preserve originals, generate corrected versions separately

## Implementation Points
- `CIFilter.temperatureAndTint()` white balance matching
- Compare average colors → Correct with `CIFilter.colorMatrix()`
- `CIImage.autoAdjustmentFilters()` auto correction

## Apple SDK References
- .claude/apple-sdk-refs/CoreImage/CIFilter.h (CITemperatureAndTint, CIColorMatrix)
- .claude/apple-sdk-refs/CoreImage/CIImage.h

## Related Files
