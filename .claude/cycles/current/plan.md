# Phase 1: Camera Basic

## Features
- F02: Before Capture
- F08: Low-Light Auto Correction
- F09: Standard Camera Features

## Work Items

### W1: SwiftData Domain Models
- Objective: Create core data models (Project, PhotoPair, Photo, SensorSnapshot), replace template Item.swift
- Owned Paths: PairShot/PairShot/Models/
- Acceptance Criteria: Models compile, relationships defined, PairShotApp.swift updated with modelContainer
- Test Scope: Model creation, relationship integrity
- Spec Reference: .claude/specs/F02-camera-basic.md (data model section)

### W2: CameraManager (AVFoundation)
- Objective: Camera session, photo capture, file save, thumbnail generation
- Owned Paths: PairShot/PairShot/Services/CameraManager.swift
- Acceptance Criteria: Session start/stop, photo capture, HEIC save to Documents, 300x300 thumbnail
- Test Scope: Mock protocol tests for capture logic
- Spec Reference: .claude/specs/F02-camera-basic.md

### W3: SensorManager (Core Motion + Core Location)
- Objective: Gyro/compass/GPS collection, snapshot at capture moment
- Owned Paths: PairShot/PairShot/Services/SensorManager.swift
- Acceptance Criteria: 60Hz sensor updates, snapshot creation, GPS recording
- Test Scope: Mock protocol tests
- Spec Reference: .claude/specs/F02-camera-basic.md (sensor data section)

### W4: LowLightManager (F08)
- Objective: Auto detect dark environment, adjust exposure/torch, post-capture enhancement
- Owned Paths: PairShot/PairShot/Services/LowLightManager.swift
- Acceptance Criteria: ISO monitoring, exposureTargetBias auto, torch auto, CIHighlightShadowAdjust post-process
- Test Scope: Threshold logic tests with mock ISO values
- Spec Reference: .claude/specs/F08-low-light.md

### W5: Camera Standard Features (F09)
- Objective: Aspect ratio (4:3/16:9/1:1), zoom (0.5x-5x), flash, grid, timer, front/rear switch
- Owned Paths: PairShot/PairShot/Services/CameraSettings.swift
- Acceptance Criteria: All standard features functional
- Test Scope: Settings state management tests
- Spec Reference: .claude/specs/F09-camera-standard.md

### W6: Camera UI Views
- Objective: Full camera UI - preview, shutter button, controls, grid overlay, zoom buttons
- Owned Paths: PairShot/PairShot/Views/Camera/
- Acceptance Criteria: Full-screen preview, large shutter button (44pt+), all controls accessible
- Test Scope: UI preview verification
- Spec Reference: .claude/specs/F02-camera-basic.md (UI section)

### W7: Permission Denial Handling
- Objective: Graceful UI when camera/location/motion permissions denied
- Owned Paths: PairShot/PairShot/Views/Camera/PermissionDeniedView.swift
- Acceptance Criteria: No crash on denial, settings redirect button, fallback UI
- Test Scope: Permission state simulation
- Spec Reference: App Store compliance (section 16 of architecture.md)

## Execution Order
W1 → (W2, W3 parallel) → (W4, W5 parallel) → W6 → W7
