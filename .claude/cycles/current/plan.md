# Phase 5 확장: 3계층 AI 보정

**추가 스코프**: 기기 capability(ARKit/LiDAR)에 따른 3단계 보정 품질 분기
**기존 P5**: F14(정렬) F15(매칭점수) F17(색보정) F25(비교뷰) — 이미 구현됨
**Research**: `.claude/cycles/current/research-report.json`

## 3계층 구조

| Tier | 조건 | 보정 방법 | 품질 |
|------|------|-----------|------|
| 1 | 일반 모드 (AVFoundation) | Vision Homography (현재) | 2D 근사 |
| 2 | 정밀 모드 (ARSession) + WorldMap relocalize 성공 | 카메라 포즈 기반 평면 근사 Homography | 회전/이동 정밀 |
| 3 | 정밀 모드 + LiDAR + sceneDepth | 깊이맵 + 포즈 기반 그리드 Warp | 3D 정밀 |

자동 폴백: Tier 3 → Tier 2 → Tier 1 (데이터 가용성에 따라)

## Work Items

### W1: Photo/PhotoPair 모델 확장
- **Objective**: 3계층 보정에 필요한 데이터 필드 추가
- **Owned Paths**:
  - `PairShot/PairShot/Models/Photo.swift` (MODIFY)
  - `PairShot/PairShot/Models/PhotoPair.swift` (MODIFY)
- **추가 필드**:
  - Photo: `arIntrinsicsData: Data?` (matrix_float3x3, 36바이트), `depthMapPath: String?`
  - PhotoPair: `alignmentTierRaw: String?` ("tier1"/"tier2"/"tier3")
- **Acceptance Criteria**: 빌드 성공, 기존 데이터 마이그레이션 자동 (optional 필드)
- **Dependencies**: 없음

### W2: ARSessionManager — sceneDepth 활성화 + capturePhoto 확장
- **Objective**: LiDAR 기기에서 깊이맵 캡처 활성화 + capturePhoto 반환에 intrinsics/sceneDepth 추가
- **Owned Paths**:
  - `PairShot/PairShot/Services/ARSessionManager.swift` (MODIFY)
- **변경사항**:
  1. `startSession`에서 `supportsFrameSemantics(.sceneDepth)` 확인 후 `config.frameSemantics = .sceneDepth` 추가
  2. `ARCaptureResult` 구조체 신규: `image: UIImage, transform: simd_float4x4, intrinsics: matrix_float3x3, sceneDepthMap: CVPixelBuffer?`
  3. `capturePhoto() → ARCaptureResult` 반환 타입 변경
- **Acceptance Criteria**: LiDAR 기기에서 sceneDepth != nil, 비-LiDAR 기기에서 nil (graceful)
- **SDK Headers**: `.claude/apple-sdk-refs/ARKit/` (ARFrame.h, ARCamera.h, ARDepthData.h, ARConfiguration.h)
- **Dependencies**: 없음

### W3: ARCameraView — Before 촬영 시 WorldMap + intrinsics + depthMap 저장
- **Objective**: Before 촬영 시점에 3계층 보정에 필요한 모든 데이터 저장
- **Owned Paths**:
  - `PairShot/PairShot/Views/Camera/ARCameraView.swift` (MODIFY)
- **변경사항**:
  1. `savePhotoFiles`에서 `ARCaptureResult` 구조체 활용 (W2에서 변경된 반환 타입)
  2. `intrinsics` → `Data` 변환 후 `photo.arIntrinsicsData` 저장
  3. `sceneDepthMap` → Float32 바이너리 파일 저장 → `photo.depthMapPath` 설정
  4. Before 촬영 시 `captureWorldMap()` → `saveWorldMap(to:)` → `photo.worldMapPath` 설정
     - `worldMappingStatus`가 `.mapped`/`.extending`일 때만 시도, 실패 시 skip
- **Acceptance Criteria**: Before Photo에 worldMapPath/arIntrinsicsData/depthMapPath 저장됨 (LiDAR 기기에서)
- **Dependencies**: W1 (모델 필드), W2 (ARCaptureResult 타입)

### W4: ARCameraView — After 세션에서 Before WorldMap relocalize
- **Objective**: After 촬영 시 Before의 WorldMap을 로드하여 동일 좌표계 확보
- **Owned Paths**:
  - `PairShot/PairShot/Views/Camera/ARCameraView.swift` (MODIFY)
- **변경사항**:
  1. `!isBefore` 분기에서 `existingPair?.beforePhoto?.worldMapPath` 확인
  2. 있으면 `loadWorldMap(from:)` → `startSession(withWorldMap:)` 호출
  3. `trackingState` 모니터링 → relocalize 완료 확인 (`.normal` 도달)
  4. 타임아웃(10초) 후 relocalize 실패 시 WorldMap 없이 세션 계속 (Tier 2 불가 → Tier 1 폴백)
  5. After intrinsics/depthMap도 W3과 동일하게 저장
- **Acceptance Criteria**: After 세션이 Before WorldMap 기반으로 relocalize 시도. 성공 시 동일 좌표계 확보.
- **Dependencies**: W1, W2, W3 (같은 파일이지만 W3 이후 순차)

### W5: AlignmentService — 3-tier 분기 + AlignmentContext
- **Objective**: 데이터 가용성에 따라 Tier 1/2/3 자동 선택
- **Owned Paths**:
  - `PairShot/PairShot/Services/AlignmentService.swift` (MODIFY)
- **변경사항**:
  1. `AlignmentContext` 구조체 신규:
     ```swift
     struct AlignmentContext {
         let beforeTransform: simd_float4x4?
         let afterTransform: simd_float4x4?
         let beforeIntrinsics: matrix_float3x3?
         let afterIntrinsics: matrix_float3x3?
         let beforeDepthMapURL: URL?
         let depthAtCenter: Double?
         let worldMapRelocalized: Bool
     }
     ```
  2. `align(beforeURL:afterURL:outputURL:context:)` 시그니처 확장
  3. 내부에서 tier 판정:
     - context.beforeDepthMapURL != nil && worldMapRelocalized → Tier 3
     - context.beforeTransform != nil && context.afterTransform != nil && worldMapRelocalized && beforeIntrinsics != nil → Tier 2
     - else → Tier 1
  4. 선택된 tier 반환 (AIAnalysisCoordinator가 PhotoPair.alignmentTierRaw에 기록)
- **Acceptance Criteria**: 빌드 성공, 기존 Tier 1 동작 유지 (context 없이 호출 시 fallback)
- **Dependencies**: W1 (AlignmentContext에 사용할 타입)

### W6: Tier 2 구현 — 포즈 기반 평면 근사 Homography
- **Objective**: 카메라 포즈(6DOF)에서 homography 행렬을 직접 계산
- **Owned Paths**:
  - `PairShot/PairShot/Services/AlignmentService.swift` (MODIFY)
- **알고리즘**:
  1. `T_relative = T_after * inverse(T_before)` → R, t 분리
  2. `H = K * (R - t * n^T / d) * K_inv` (n=[0,0,1] 평면 가정, d=depthAtCenter 또는 추정값)
  3. H 행렬을 기존 applyWarp 파이프라인에 전달 (CIPerspectiveTransform)
- **Acceptance Criteria**: 정밀 모드 + WorldMap relocalize 성공 시 Tier 2 적용, homography보다 정밀한 결과
- **Dependencies**: W5 (tier 분기 구조)

### W7: Tier 3 구현 — LiDAR 깊이 기반 그리드 Warp
- **Objective**: 깊이맵 + 포즈로 per-grid-point 3D reprojection 수행
- **Owned Paths**:
  - `PairShot/PairShot/Services/AlignmentService.swift` (MODIFY)
- **알고리즘**:
  1. Before 깊이맵 로드 (256×192 Float32)
  2. 이미지를 32×24 그리드로 분할
  3. 각 그리드 교점: depth → 3D → T_relative 적용 → 재투영 → displacement
  4. 그리드 displacement를 사진 해상도로 보간
  5. CIFilter 타일 분할 warp 또는 Metal compute shader
- **대안 (간소화)**: `VNGenerateOpticalFlowRequest`로 displacement map 직접 계산 → Metal warp. AR 데이터 불요.
- **Acceptance Criteria**: LiDAR + 정밀 모드에서 3D 시차까지 보정된 결과. 비-LiDAR에서 Tier 2 폴백.
- **Dependencies**: W6 (같은 파일 순차)

### W8: AIAnalysisCoordinator — AR 데이터 수집 + tier 기록
- **Objective**: Coordinator가 Photo에서 AR 데이터를 추출해 AlignmentService에 전달
- **Owned Paths**:
  - `PairShot/PairShot/Services/AIAnalysisCoordinator.swift` (MODIFY)
- **변경사항**:
  1. `pair.beforePhoto`/`afterPhoto`에서 arTransformData, arIntrinsicsData, depthMapPath, worldMapPath 추출
  2. `AlignmentContext` 구성
  3. `AlignmentService.align(... context:)` 호출
  4. 반환된 tier를 `pair.alignmentTierRaw`에 기록
- **Acceptance Criteria**: 비교 뷰에서 사용된 tier가 PhotoPair에 기록됨
- **Dependencies**: W1, W5

## Execution Order

```
Layer 0 (병렬):
  W1 (Photo/PhotoPair 모델)
  W2 (ARSessionManager)

Layer 1 (W1+W2 완료 후, 순차 — ARCameraView 동일 파일):
  W3 (Before 저장) → W4 (After relocalize)

Layer 2 (W1 완료 후):
  W5 (AlignmentService tier 분기)

Layer 3 (W5 완료 후, 순차 — AlignmentService 동일 파일):
  W6 (Tier 2) → W7 (Tier 3)

Layer 4 (W5 완료 후):
  W8 (Coordinator) — W6/W7과 병렬 가능 (다른 파일)
  단, W8은 W5의 align 시그니처를 사용하므로 W5 이후
```

## File Dependency Matrix

| WI | Creates | Modifies |
|----|---------|----------|
| W1 | — | Photo.swift, PhotoPair.swift |
| W2 | — | ARSessionManager.swift |
| W3 | — | ARCameraView.swift |
| W4 | — | ARCameraView.swift |
| W5 | — | AlignmentService.swift |
| W6 | — | AlignmentService.swift |
| W7 | — | AlignmentService.swift |
| W8 | — | AIAnalysisCoordinator.swift |

**겹침**: W3↔W4 (ARCameraView), W5↔W6↔W7 (AlignmentService) — 각 그룹 내 순차 필수

## 주요 리스크
- **R1 (High)**: WorldMap relocalize 실패 가능성 → 타임아웃 + Tier 1 폴백
- **R2 (Medium)**: sceneDepth 해상도(256×192) vs 사진(4032×3024) → 그리드 보간으로 완화
- **R3 (Medium)**: zoom factor 변경 시 intrinsics 변동 → Before/After 각각 저장
- **R5 (Medium)**: 평면 근사 한계 (Tier 2) → Tier 3에서 해결
- **R6 (Medium)**: Tier 3 Metal 커널 구현 비용 → VNGenerateOpticalFlowRequest 대안 검토
