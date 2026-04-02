# F03 - After Capture + Ghost Overlay

## Requirements
- When selecting an incomplete pair → Camera launches with the corresponding before photo displayed as a semi-transparent overlay
- Overlay starts HIDDEN on After capture entry
- Auto-activates when F04 sensor guide detects angle within ±10° threshold
- Default opacity 25% on activation, adjustable 0-70% via slider
- Tap toggle: Tap anywhere on screen → Instantly switch overlay between 0% ↔ default (25%)
- Overlay image is NOT included in the capture (only the original photo is saved)
- Pair status transitions to `.complete` upon capture completion

## Non-functional Requirements
- Overlay rendering maintains 60fps (no frame drops)
- Overlay image memory: Use 1080p downscaled version (do NOT load original 12MP)

## UI Behavior
- Full-screen camera preview + semi-transparent before photo overlaid
- Overlay is hidden on entry; appears automatically when F04 sensor guide angle is within ±10°
- Bottom: Opacity slider (left=transparent, right=opaque), range 0-70%
- Top: "View Before" toggle icon
- Overlay and preview aspect ratio/position must match exactly

## Edge Cases
- Before photo aspect ratio differs from current camera ratio → Center crop alignment
- Before photo is portrait but camera is landscape → Detect device orientation and rotate
- On memory warning → Further reduce overlay resolution

## Implementation Points
- `UIImageView` + `alpha` property overlaid on camera preview
- Separate UIView layer on top of `AVCaptureVideoPreviewLayer`
- Opacity slider: SwiftUI `Slider` → `ghostImageView.alpha` binding
- Tap toggle: `UITapGestureRecognizer` → Toggle alpha between 0 ↔ 0.25
- 1080p downscale: `UIImage` → `CGImage` → `CGContext.draw` resize

## Apple SDK References
- .claude/apple-sdk-refs/AVFoundation/AVCaptureVideoPreviewLayer.h
- .claude/apple-sdk-refs/UIKit/UIImageView.h
- .claude/apple-sdk-refs/QuartzCore/CALayer.h

## Related Files
