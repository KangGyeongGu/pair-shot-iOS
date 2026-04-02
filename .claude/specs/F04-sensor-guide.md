# F04 - Sensor Angle Guide

## Requirements
- During After capture, visually display the difference between the current device angle and the pitch/roll/yaw values recorded during Before capture
- 3D Icon Guide:
  - pitch/roll: 3D 구체 (구가 회전하여 현재 각도를 표현)
  - yaw: 회전 링 (링이 회전하여 현재 각도를 표현)
- On entering the alignment tolerance zone → Turn green + success haptic feedback
- Tolerance: pitch/roll ±2 degrees, yaw ±5 degrees
- On entering angle tolerance (±10° threshold) → Ghost overlay (F03) auto-activates
- GuidanceStage progression: `.locating` → `.positioning` → `.aligning`

## Non-functional Requirements
- Sensor updates at 60Hz → Smooth UI updates
- Minimize CPU usage (runs simultaneously with camera)

## UI Behavior
- Displayed as semi-transparent HUD over camera preview
- 3D 구체와 회전 링을 통한 각도 표현 (pitch/roll/yaw 축 분리 표시)
- When aligned: Both icon and indicator turn green
- When misaligned: Red color + 3D visual feedback only
- 텍스트 안내 지양, 아이콘/시각 요소만으로 방향 전달
- Synchronized with F03 ghost overlay (±10° entry triggers overlay auto-activation)

## Edge Cases
- Magnetic interference environment (rebar structures, etc.) → Yaw precision degraded → Auto-expand yaw guide range
- Legacy pairs without sensor data from Before capture → Disable guide, provide overlay only
- Rapid device shaking causes noise → Apply low-pass filter

## Implementation Points
- `CMMotionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)`
- `CMDeviceMotion.attitude` → pitch/roll/yaw (radians)
- Calculate difference between before values and current values: `deltaP = current.pitch - saved.pitch`
- GuidanceStage state machine:
  - `.locating`: Initial phase, waiting for motion data
  - `.positioning`: Within ±10° of target, ghost overlay active
  - `.aligning`: Within ±2° (pitch/roll) / ±5° (yaw), ready to capture
- Low-pass filter: `filtered = alpha * new + (1-alpha) * filtered` (alpha=0.15)
- 3D icon visualization: pitch/roll rotation mapping to 3D sphere, yaw rotation mapping to ring rotation

## Apple SDK References
- .claude/apple-sdk-refs/CoreMotion/CMMotionManager.h
- .claude/apple-sdk-refs/CoreMotion/CMDeviceMotion.h
- .claude/apple-sdk-refs/CoreMotion/CMAttitude.h
- .claude/apple-sdk-refs/CoreLocation/CLLocationManager.h
- .claude/apple-sdk-refs/CoreLocation/CLHeading.h

## Related Files
