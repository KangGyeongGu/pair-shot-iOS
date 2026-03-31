# F04 - Sensor Angle Guide

## Requirements
- During After capture, visually display the difference between the current device angle and the pitch/roll/yaw values recorded during Before capture
- Crosshair circular indicator: Current angle = dot, target angle = circle → Alignment complete when dot is inside circle
- On entering the circle → Turn green + success haptic feedback
- Tolerance: pitch/roll ±2 degrees, yaw ±5 degrees

## Non-functional Requirements
- Sensor updates at 60Hz → Smooth UI updates
- Minimize CPU usage (runs simultaneously with camera)

## UI Behavior
- Displayed as semi-transparent HUD over camera preview
- Center: Circular target (fixed) + current position dot (moving)
- When dot enters circle: Both circle and dot turn green
- When dot is outside circle: Red, with arrows showing movement direction
- No complex numeric values (angle numbers) displayed — operate by visual intuition only

## Edge Cases
- Magnetic interference environment (rebar structures, etc.) → Yaw precision degraded → Auto-expand yaw guide range
- Legacy pairs without sensor data from Before capture → Disable guide, provide overlay only
- Rapid device shaking causes noise → Apply low-pass filter

## Implementation Points
- `CMMotionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)`
- `CMDeviceMotion.attitude` → pitch/roll/yaw (radians)
- Calculate difference between before values and current values: `deltaP = current.pitch - saved.pitch`
- Indicator position: `CGPoint(x: deltaRoll * scale, y: deltaPitch * scale)`
- Low-pass filter: `filtered = alpha * new + (1-alpha) * filtered` (alpha=0.15)

## Related Files
