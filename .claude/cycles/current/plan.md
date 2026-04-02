# Phase 4: 촬영 고도화 (ARKit + LiDAR + 재설계 반영)

## Features
- F03: Ghost Overlay 고도화 (임계값 활성화, 슬라이더, 탭 토글)
- F04: Sensor Guide 3D 재설계 (3D 구체 + 회전 링 + GuidanceStage)
- F05: Haptic 방향 반전 (맞을수록 약해짐)
- F10: ARKit 정밀 재위치 (ARWorldMap 저장/로드 + 3D 화살표 안내)
- F13: 촬영 품질 검사 (블러/노출 분석)
- F19: LiDAR 거리 측정

## Architecture Decision: ARKit-AVFoundation 공존

### 핵심 제약
ARSession과 AVCaptureSession은 동시 실행 불가 (카메라 리소스 독점)

### 전략
- **Before 모드**: AVCaptureSession(현행) → 촬영 완료 후 잠시 ARSession 시작 → worldMap 저장 → ARSession 종료
- **After 모드 (worldMap 있음)**: ARSession 기반 프리뷰 사용 → 재위치 안내 → captureHighResolutionFrame(iOS 16+)으로 촬영
- **After 모드 (worldMap 없음/실패)**: AVCaptureSession 폴백 (현행 동작 + 센서 가이드만)
- **LiDAR 분기**: `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` 런타임 체크

## Work Items

### W1: GuidanceStage 상태 머신 + alignmentScore 통일 + 햅틱 반전
- Objective: GuidanceStage(.locating → .positioning → .aligning) 추가, CameraView의 중복 alignmentScore 제거 후 SensorAlignment 사용으로 통일, 햅틱 강도 반전(1.0 - score)
- Owned Paths:
  - PairShot/PairShot/Views/Camera/SensorGuideView.swift (MODIFY)
  - PairShot/PairShot/Services/HapticService.swift (MODIFY)
  - PairShot/PairShot/Views/Camera/CameraView.swift (MODIFY)
- Spec Reference: .claude/specs/F04-sensor-guide.md, .claude/specs/F05-haptic-feedback.md

### W2: Ghost Overlay 임계값 활성화 + 슬라이더 + 탭 토글
- Objective: 오버레이 초기 숨김, positioning 단계(±10°) 진입 시 자동 활성화, 불투명도 슬라이더(0-70%), 탭 토글(0% ↔ 25%)
- Owned Paths:
  - PairShot/PairShot/Views/Camera/GhostOverlayView.swift (MODIFY)
  - PairShot/PairShot/Views/Camera/CameraView.swift (MODIFY)
- Spec Reference: .claude/specs/F03-ghost-overlay.md

### W3: Sensor Guide 3D 재설계
- Objective: 2D Canvas → 3D 구체(pitch/roll) + 회전 링(yaw) 시각화로 교체
- Owned Paths:
  - PairShot/PairShot/Views/Camera/SensorGuideView.swift (MODIFY — body 전면 재설계)
- Spec Reference: .claude/specs/F04-sensor-guide.md

### W4: ARSessionManager 서비스 + Photo 모델 확장
- Objective: ARKit 세션 라이프사이클 관리 서비스 생성, Photo 모델에 worldMapPath 필드 추가
- Owned Paths:
  - PairShot/PairShot/Services/ARSessionManager.swift (NEW)
  - PairShot/PairShot/Models/Photo.swift (MODIFY)
- Spec Reference: .claude/specs/F10-arkit-reposition.md
- SDK Headers: .claude/apple-sdk-refs/ARKit/ARSession.h, ARWorldTrackingConfiguration.h, ARWorldMap.h, ARFrame.h, ARCamera.h

### W5: ARKit 통합 — Before worldMap 저장 + After 재위치 + 3D 화살표
- Objective: Before 촬영 후 ARWorldMap 자동 저장, After 모드에서 ARSession 기반 재위치, X/Y/Z 축별 3D 화살표 가이드
- Owned Paths:
  - PairShot/PairShot/Views/Camera/ARPositionGuideView.swift (NEW)
  - PairShot/PairShot/Views/Camera/CameraView.swift (MODIFY)
- Spec Reference: .claude/specs/F10-arkit-reposition.md

### W6: 촬영 품질 검사 (F13)
- Objective: 촬영 직후 블러/노출 자동 분석, 품질 불량 시 재촬영 다이얼로그
- Owned Paths:
  - PairShot/PairShot/Services/QualityCheckService.swift (NEW)
  - PairShot/PairShot/Views/Camera/CameraView.swift (MODIFY)
- Spec Reference: .claude/specs/F13-quality-check.md
- SDK Headers: .claude/apple-sdk-refs/CoreImage/CIFilter.h

### W7: LiDAR 거리 측정 (F19)
- Objective: LiDAR 기기에서 두 점 탭 → 실제 거리 표시, 측정 결과 메타데이터 저장
- Owned Paths:
  - PairShot/PairShot/Views/Camera/LiDARMeasureOverlayView.swift (NEW)
  - PairShot/PairShot/Views/Camera/CameraView.swift (MODIFY)
- Spec Reference: .claude/specs/F19-lidar-measure.md
- SDK Headers: .claude/apple-sdk-refs/ARKit/ARSession.h, ARRaycastQuery.h, ARRaycastResult.h

### W8: 단위 테스트
- Objective: 핵심 로직 테스트 — GuidanceStage 전환, alignmentScore 계산, 햅틱 반전, 품질 검사 임계값
- Owned Paths: PairShot/PairShotTests/

## Execution Order
W1 → W2 → W3 (sequential: SensorGuideView.swift + CameraView.swift 공유)
W3 → W4 (sequential: W4의 Photo.swift 변경이 이후 W5에 필요)
W4 → W5 → W6 → W7 (sequential: CameraView.swift 순차 수정)
W7 → W8 (테스트는 마지막)

## File Dependency Matrix
| Work Item | Creates | Modifies |
|-----------|---------|----------|
| W1 | — | SensorGuideView.swift, HapticService.swift, CameraView.swift |
| W2 | — | GhostOverlayView.swift, CameraView.swift |
| W3 | — | SensorGuideView.swift |
| W4 | ARSessionManager.swift | Photo.swift |
| W5 | ARPositionGuideView.swift | CameraView.swift |
| W6 | QualityCheckService.swift | CameraView.swift |
| W7 | LiDARMeasureOverlayView.swift | CameraView.swift |
| W8 | Tests | — |
