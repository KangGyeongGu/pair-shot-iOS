# F25 - Animation Comparison

## Requirements
- Before ↔ After crossfade toggle
- 0.3 second fade transition on each tap
- One of the comparison view modes

## Implementation Points
- `withAnimation(.easeInOut(duration: 0.3))` + `opacity` toggle
- Or `UIView.transition(with:duration:options:.transitionCrossDissolve)`

## Related Files
