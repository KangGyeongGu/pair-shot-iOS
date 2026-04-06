# F17 - Color Correction Matching

## Requirements
- Auto-correct lighting differences between before (morning) and after (afternoon)
- **before is the reference; after is corrected to match before's color/lighting**
- Use corrected_after.jpg in comparison view (F25)
- Preserve originals, generate corrected versions separately

## Implementation Points
- Input: after image. Reference: before image.
- `CIImage.autoAdjustmentFilters()` applied to **after**
- Average color extracted from **before** as reference
- `CIFilter.colorMatrix()` applied to **after** to match **before**

## Apple SDK References
- .claude/apple-sdk-refs/CoreImage/CIFilter.h (CITemperatureAndTint, CIColorMatrix)
- .claude/apple-sdk-refs/CoreImage/CIImage.h

## Related Files
