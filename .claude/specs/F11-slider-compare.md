# F11 - Slider Comparison View

## Requirements
- Overlay before (left) and after (right) on a single screen, drag a vertical divider line to adjust the boundary
- Use AI auto-aligned image (F14) when available

## Non-functional Requirements
- Maintain 60fps during drag

## UI Behavior
- After displayed full screen
- Before overlays from the left up to the divider line
- Drag handle on the divider line (left-right arrow icon)
- Pinch zoom also supported (slider works in zoomed state)

## Edge Cases
- Image size mismatch → Center-aligned crop

## Implementation Points
- `GeometryReader` + `DragGesture` → `sliderX` value
- Before image: `.mask(Rectangle().frame(width: sliderX))`
- After image: Displayed full in background
- Divider line: `Rectangle().frame(width: 2).position(x: sliderX)`

## Apple SDK References
- .claude/apple-sdk-refs/SwiftUI/SwiftUI.swiftinterface
- .claude/apple-sdk-refs/QuartzCore/CALayer.h

## Related Files
