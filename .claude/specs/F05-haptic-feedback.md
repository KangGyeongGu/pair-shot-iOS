# F05 - Haptic Feedback

## Requirements
- Vibration intensity increases as angle approaches target ("hot/cold" sensation)
- Success vibration pattern when all axes (pitch/roll/yaw) enter tolerance range
- Enables alignment without looking at screen in bright sunlight / glove-wearing situations

## Non-functional Requirements
- Minimize battery drain (continuous haptics consume significant battery)
- Vibration frequency: 1Hz when far from alignment, 5Hz when close, single success pattern on alignment complete

## UI Behavior
- No separate UI — feedback through vibration felt in hand only
- Synchronized with F04 visual guide (simultaneous visual + tactile feedback)

## Edge Cases
- Haptics work even in silent mode (default iOS behavior)
- Core Haptics unsupported on older devices → Fallback to `UIImpactFeedbackGenerator`
- User wants to disable haptics → Toggle in settings

## Implementation Points
- `CHHapticEngine` + `CHHapticEvent(.hapticContinuous)`
- Intensity: `CHHapticEventParameter(.hapticIntensity, value: alignmentScore)`
- alignmentScore: 0.0 (far) ~ 1.0 (aligned) → Weighted average of pitch/roll/yaw
- Success pattern: `UINotificationFeedbackGenerator.notificationOccurred(.success)`
- Battery protection: Stop haptics after alignment complete

## Related Files
