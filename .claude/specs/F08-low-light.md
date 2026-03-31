# F08 - Low-Light Auto Correction

## Requirements
- Automatically detect brightness on camera entry
- Auto-respond when dark environment detected:
  - Exposure compensation (`exposureTargetBias` +1~2 EV)
  - If very dark, auto-activate torch (continuous lighting) (level 0.3~0.5)
- Post-capture auto correction: Shadow recovery (`CIHighlightShadowAdjust`), high-ISO noise reduction
- Fully automatic with no user intervention required

## Non-functional Requirements
- Brightness detection → correction applied within 0.5 seconds
- Auto torch activation should feel natural to the user (prevent sudden brightness changes)

## UI Behavior
- No separate UI (automatic operation)
- Torch icon displayed at top when torch is active (manual off available)
- Manual brightness slider: Shown on long press (for advanced users)

## Edge Cases
- Moving from bright to dark area → Real-time adaptation
- Torch + flash simultaneous use → Prevent overexposure
- Low battery → Auto-disable torch with warning

## Implementation Points
- Monitor `AVCaptureDevice.iso` → Determine low-light if above 800
- `device.setExposureTargetBias(min(device.maxExposureTargetBias, 2.0))`
- `device.setTorchModeOn(level: 0.4)` — Continuous lighting
- Post-processing: `CIHighlightShadowAdjust(shadowAmount: 1.5)` + `CINoiseReduction`
- `photoQualityPrioritization = .quality` → Auto-activate Deep Fusion/Smart HDR

## Related Files
