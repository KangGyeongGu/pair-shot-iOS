# Phase 3: 고스트 오버레이 + 센서 가이드

## Features
- F03: After 촬영 + 고스트 오버레이
- F04: 센서 각도 가이드
- F05: 햅틱 피드백

## Work Items

### W1: 센서 저장 파이프라인 연결
- Objective: CameraView에 SensorManager 주입, Before 촬영 시 센서 스냅샷을 Photo에 저장
- Owned Paths: PairShot/PairShot/Views/Camera/CameraView.swift
- Spec Reference: .claude/specs/F04-sensor-guide.md
- SDK Headers: .claude/apple-sdk-refs/CoreMotion/CMAttitude.h

### W2: 고스트 오버레이 (F03)
- Objective: After 촬영 시 Before 사진을 반투명으로 카메라 프리뷰 위에 겹침
- Owned Paths: PairShot/PairShot/Views/Camera/GhostOverlayView.swift (신규), CameraView.swift
- Spec Reference: .claude/specs/F03-ghost-overlay.md

### W3: 센서 각도 가이드 (F04)
- Objective: After 촬영 시 Before 각도와의 차이를 크로스헤어 인디케이터로 안내
- Owned Paths: PairShot/PairShot/Views/Camera/SensorGuideView.swift (신규), CameraView.swift
- Spec Reference: .claude/specs/F04-sensor-guide.md

### W4: 햅틱 피드백 (F05)
- Objective: 각도 맞아갈수록 진동 강화, 정렬 완료 시 성공 진동
- Owned Paths: PairShot/PairShot/Services/HapticService.swift (신규), CameraView.swift
- Spec Reference: .claude/specs/F05-haptic-feedback.md
- SDK Headers: .claude/apple-sdk-refs/CoreHaptics/CHHapticEngine.h

### W5: After 촬영 통합
- Objective: 오버레이 + 가이드 + 햅틱을 CameraView After 모드에 통합
- Owned Paths: PairShot/PairShot/Views/Camera/CameraView.swift

### W6: 단위 테스트
- Objective: alignmentScore, delta 계산, 범위 판정, 이미지 다운스케일 테스트
- Owned Paths: PairShot/PairShotTests/

## Execution Order
W1 → W2 → W3 → W4 → W5 → W6
