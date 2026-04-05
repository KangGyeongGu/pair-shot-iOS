# Phase 5: 비교 뷰 + AI 분석

**Features**: F07(나란히 비교), F11(슬라이더 비교), F14(AI 자동정렬), F15(매칭 점수), F16(변화 히트맵), F17(색보정), F25(애니메이션 비교)
**Depends on**: P2 (갤러리/PhotoPair 모델)
**Research report**: `.claude/cycles/current/research-report.json`

## Work Items

### W1: PhotoPair 모델 확장 — P5 필드 추가
- **Objective**: SwiftData `@Model` PhotoPair에 비교/분석 결과 저장용 optional 필드 3개 추가
- **Owned Paths**:
  - `PairShot/PairShot/Models/PhotoPair.swift` (MODIFY)
- **필드 추가**:
  - `matchingScore: Float?` (F15)
  - `alignedBeforeImagePath: String?` (F14 캐시)
  - `colorCorrectedBeforeImagePath: String?` (F17 캐시)
- **Acceptance Criteria**:
  - 빌드 성공, 3개 필드 모두 optional이므로 SwiftData 자동 마이그레이션 (명시적 SchemaMigrationPlan 불필요)
  - 기존 PhotoPair 인스턴스 로드 시 크래시 없음
- **Test Scope**: PhotoPair 생성/저장/로드 시 새 필드 nil 기본값 확인
- **Spec**: F14, F15, F17
- **Dependencies**: 없음

### W2: PhotoStorageService 파생 이미지 URL 메서드 추가
- **Objective**: aligned/colorCorrected 이미지용 파일 경로 제공
- **Owned Paths**:
  - `PairShot/PairShot/Services/PhotoStorageService.swift` (MODIFY)
- **추가 메서드**:
  - `alignedPhotoURL(projectId:pairId:) → projects/{id}/pairs/{id}/aligned_before.jpg`
  - `colorCorrectedPhotoURL(projectId:pairId:) → projects/{id}/pairs/{id}/corrected_before.jpg`
  - `deletePair` 경로에 두 파일 삭제 포함
- **Acceptance Criteria**: 메서드가 올바른 URL 반환, 디렉토리 자동 생성, 삭제 시 파생 파일 모두 제거
- **Test Scope**: URL 생성/삭제 경로 확인
- **Spec**: F14, F17
- **Dependencies**: 없음

### W3: 공유 CIContext 싱글톤
- **Objective**: AlignmentService/HeatmapService/ColorCorrectionService 간 공유할 thread-safe CIContext
- **Owned Paths**:
  - `PairShot/PairShot/Services/ImageProcessingContext.swift` (NEW)
- **구현**: `enum ImageProcessingContext { static let shared = CIContext(options:) }` 형태. CIContext는 Sendable/immutable이므로 actor 불필요
- **Acceptance Criteria**: 여러 서비스에서 `ImageProcessingContext.shared` 호출 시 동일 인스턴스 반환
- **Spec**: F14/F16/F17 공통
- **SDK Headers**: `.claude/apple-sdk-refs/CoreImage/CIContext.h`
- **Dependencies**: 없음

### W4: AlignmentService 구현 (F14)
- **Objective**: Vision Homography로 before→after 픽셀 정렬 후 결과 이미지 캐시
- **Owned Paths**:
  - `PairShot/PairShot/Services/AlignmentService.swift` (NEW)
- **핵심 로직**:
  1. before/after CGImage 로드 (1200px 다운스케일 — R3 메모리 대응)
  2. before를 after 해상도로 CGContext resize (**R1**: 해상도 일치 필수)
  3. `VNHomographicImageRegistrationRequest(targetedCGImage: beforeResized)`
  4. `VNImageRequestHandler(cgImage: afterCGImage, options: [.ciContext: ImageProcessingContext.shared]).perform([request])`
  5. `observation.warpTransform` (matrix_float3x3)에서 4 코너 CGPoint 역산 (**R2**)
  6. `CIFilter.perspectiveTransformFilter()` 적용
  7. JPEG로 aligned_before.jpg 저장, `PhotoPair.alignedBeforeImagePath` 업데이트
  8. 실패 시 nil 반환 (원본 사용 — R4 폴백)
- **Concurrency**: `Task.detached(priority: .userInitiated)` 안에서 Vision perform, PhotoPair 업데이트는 `@MainActor`
- **Acceptance Criteria**:
  - 정렬 성공 시 aligned_before.jpg 생성
  - 정렬 실패 시 크래시 없이 nil 반환
  - Swift 6 strict concurrency 빌드 경고 없음
- **Test Scope**: 동일 이미지 정렬 시 near-identity warp 확인, 실패 케이스 폴백 확인
- **Spec**: F14
- **SDK Headers**: `Vision/VNHomographicImageRegistrationRequest.h`, `VNImageRequestHandler.h`, `VNObservation.h`, `CoreImage/CIFilterBuiltins.h`
- **Dependencies**: W1, W2, W3

### W5: MatchingScoreService 구현 (F15)
- **Objective**: VNFeaturePrint 거리값으로 매칭 점수 계산
- **Owned Paths**:
  - `PairShot/PairShot/Services/MatchingScoreService.swift` (NEW)
- **핵심 로직**:
  1. `VNGenerateImageFeaturePrintRequest` 2개 (revision: `VNGenerateImageFeaturePrintRequestRevision2` — iOS 17+)
  2. before/after 각각 `VNImageRequestHandler.perform`
  3. `try fp1.computeDistance(&dist, to: fp2)` → Float
  4. `PhotoPair.matchingScore`에 저장
  5. 등급 변환 helper: `<5: excellent(green), 5~15: good(yellow), >15: retake(red)`
  6. 퍼센트 변환: `max(0, Int((1 - min(score/20, 1)) * 100))`
- **Acceptance Criteria**:
  - 동일 이미지 distance ≈ 0
  - 크게 다른 이미지 distance > 15
  - 등급/퍼센트 helper 경계값 테스트 통과
- **Test Scope**: 등급 변환, 퍼센트 변환 경계값
- **Spec**: F15
- **SDK Headers**: `Vision/VNGenerateImageFeaturePrintRequest.h`, `VNFeaturePrintObservation.h`
- **Dependencies**: W1, W3

### W6: ColorCorrectionService 구현 (F17)
- **Objective**: before 이미지의 조명/색온도를 after 기준으로 보정
- **Owned Paths**:
  - `PairShot/PairShot/Services/ColorCorrectionService.swift` (NEW)
- **핵심 로직**:
  - 방법: `CIImage.autoAdjustmentFilters(options:)` 체인 적용 (단순) 또는 `CIAreaAverage`로 after 평균 색 추출 후 `CITemperatureAndTint` 매칭
  - 결과를 corrected_before.jpg로 저장
  - `PhotoPair.colorCorrectedBeforeImagePath` 업데이트
- **Acceptance Criteria**: 보정 파일 생성, 원본 before 보존
- **Test Scope**: 보정 결과가 원본과 다른 해시인지 확인
- **Spec**: F17
- **SDK Headers**: `CoreImage/CIFilterBuiltins.h`, `CIImage.h`
- **Dependencies**: W1, W2, W3

### W7: HeatmapService 구현 (F16)
- **Objective**: before-after 차이 이미지 생성 + 변화율 계산
- **Owned Paths**:
  - `PairShot/PairShot/Services/HeatmapService.swift` (NEW)
- **핵심 로직**:
  1. `CIFilter.colorAbsoluteDifferenceFilter()` (iOS 14+) — CIDifferenceBlendMode보다 직접적
  2. `CIFilter.falseColorFilter()` — 휘도→레드 매핑 (color0: clear, color1: red)
  3. `CIFilter.sourceOverCompositingFilter()` — after 위에 오버레이
  4. 변화율: 512px 다운스케일 차이 이미지에서 임계값(0.1) 초과 픽셀 비율 (**R6**)
  5. 반환: `(heatmapImage: CIImage, changeRatio: Double)`
- **Acceptance Criteria**:
  - 동일 이미지 입력 시 changeRatio ≈ 0
  - 완전 다른 이미지 입력 시 changeRatio > 0.5
- **Test Scope**: 동일/상이 이미지 케이스
- **Spec**: F16
- **SDK Headers**: `CoreImage/CIFilterBuiltins.h`
- **Dependencies**: W3

### W9: ComparisonContainerView — 탭바 + 모드 전환 컨테이너
- **Objective**: 4개 비교 모드(Side/Slider/Heatmap/Animation) + 매칭 스코어 배지 + 뒤로가기/공유
- **Owned Paths**:
  - `PairShot/PairShot/Views/Comparison/ComparisonContainerView.swift` (NEW)
- **구성**:
  - 하단 세그먼트 컨트롤: 나란히 / 슬라이더 / 히트맵 / 애니메이션
  - 상단: 뒤로가기 + 공유 + 매칭 스코어 배지 (W14)
  - AI 정렬 결과(alignedBeforeImagePath) 로드하여 자식 뷰에 전달
  - 정렬 처리 중 상태 표시 ("AI 정렬 중...")
  - alignedBeforeImagePath가 nil이면 원본 사용 (폴백)
- **Acceptance Criteria**:
  - **F006 재발 방지**: 4개 자식 뷰(W10~W13)가 반드시 body ZStack/TabView 안에 삽입됨
  - 모드 전환 시 상태(줌/슬라이더 위치) 유지 불필요 (각 모드 독립)
- **Spec**: F07/F11/F16/F25 통합
- **Dependencies**: W1, W4, W5

### W10: SideBySideView 구현 (F07)
- **Objective**: 좌(Before)/우(After) HStack + 동기 줌/패닝
- **Owned Paths**:
  - `PairShot/PairShot/Views/Comparison/SideBySideView.swift` (NEW)
- **핵심 로직**:
  - 공유 `@State zoomScale`, `offset`
  - `.simultaneousGesture(MagnificationGesture())` 양쪽 동시 줌
  - `DragGesture` 동기 패닝 (**R7**: ZStack 최상위 단일 제스처)
  - 더블탭 리셋
  - 대용량 이미지: `CGImageSourceCreateThumbnailAtPixelSize(maxPixelSize: 1200)` 다운스케일
  - 종횡비 불일치: 작은 쪽에 맞춰 크롭
- **Acceptance Criteria**: 한쪽 줌/드래그 시 반대쪽 동기 이동, 더블탭 리셋 동작
- **Spec**: F07
- **SDK Headers**: `SwiftUI/SwiftUI.swiftinterface`
- **Dependencies**: W9

### W11: SliderCompareView 구현 (F11)
- **Objective**: 세로 분할선 드래그로 Before/After 경계 조정
- **Owned Paths**:
  - `PairShot/PairShot/Views/Comparison/SliderCompareView.swift` (NEW)
- **핵심 로직**:
  - After full screen 배경
  - Before를 `.mask(alignment: .leading) { Rectangle().frame(width: sliderX) }`
  - 분할선 `Rectangle().frame(width: 2).position(x: sliderX)`, 핸들 `arrow.left.and.right`
  - F14 정렬 이미지 우선 사용
  - **R8**: sliderX는 GeometryReader 좌표계, 이미지 변환과 분리
- **Acceptance Criteria**: 60fps 드래그, 분할선이 뷰 범위 내 유지
- **Spec**: F11
- **Dependencies**: W9

### W12: HeatmapView 구현 (F16)
- **Objective**: HeatmapService 결과 표시 + 변화율 텍스트
- **Owned Paths**:
  - `PairShot/PairShot/Views/Comparison/HeatmapView.swift` (NEW)
- **핵심 로직**:
  - `.task(id: pair.id)`로 뷰 진입 시 HeatmapService 호출
  - 생성 중 ProgressView
  - 결과 이미지 + 하단 "42% 면적 변화" 텍스트
- **Acceptance Criteria**: 히트맵 이미지 표시, changeRatio 포맷팅 정확
- **Spec**: F16
- **Dependencies**: W7, W9

### W13: AnimationCompareView 구현 (F25)
- **Objective**: Before↔After 0.3초 크로스페이드 토글
- **Owned Paths**:
  - `PairShot/PairShot/Views/Comparison/AnimationCompareView.swift` (NEW)
- **핵심 로직**:
  - `@State showingAfter = true`
  - 탭 시 `withAnimation(.easeInOut(duration: 0.3)) { showingAfter.toggle() }`
  - 두 이미지 opacity 토글
- **Acceptance Criteria**: 탭 시 0.3초 크로스페이드 동작
- **Spec**: F25
- **Dependencies**: W9

### W14: MatchingScoreBadge 컴포넌트 (F15 UI)
- **Objective**: ComparisonContainerView 상단 배지
- **Owned Paths**:
  - `PairShot/PairShot/Views/Comparison/MatchingScoreBadge.swift` (NEW)
- **핵심 로직**:
  - `matchingScore: Float?` 입력
  - nil → "분석 중..."
  - 등급별 색상(green/yellow/red) + "{percent}% 일치" 텍스트
- **Acceptance Criteria**: 각 등급 경계값(4.9/5.0/14.9/15.0)에서 올바른 색상/텍스트
- **Spec**: F15
- **Dependencies**: W9 (컨테이너에서 사용)

### W8: 비교 뷰 진입 연결 — PairGalleryView + PairCellView
- **Objective**: complete 상태 페어 탭 시 ComparisonContainerView로 이동
- **Owned Paths**:
  - `PairShot/PairShot/Views/Gallery/PairCellView.swift` (MODIFY)
  - `PairShot/PairShot/Views/Gallery/PairGalleryView.swift` (MODIFY)
- **핵심 로직**:
  - PairCellView `onTapGesture`에 complete 분기 추가 → `onTapCompare?(pair)` 콜백
  - PairGalleryView `@State comparisonPair: PhotoPair?` + `.sheet(item:)` 또는 `navigationDestination`
  - **F005 교훈**: 빈 closure 금지, 실제 액션 연결 필수
- **Acceptance Criteria**:
  - complete 페어 탭 → ComparisonContainerView 풀스크린 진입
  - pendingAfter 페어 탭 동작은 변경 없음 (기존 After 카메라 진입 유지)
- **Spec**: F07 진입점
- **Dependencies**: W9

### W15: After 저장 후 AI 분석 백그라운드 트리거
- **Objective**: After 캡처 완료 후 정렬/스코어/색보정을 백그라운드 비동기 실행
- **Owned Paths**:
  - `PairShot/PairShot/Views/Camera/UnifiedCameraView.swift` (MODIFY)
- **핵심 로직**:
  - After 저장 완료 콜백에서 `Task.detached { async let align = ...; async let score = ...; async let correct = ... }`
  - PhotoPair 업데이트는 `@MainActor` 컨텍스트
  - 비교 뷰 진입을 차단하지 않음 — 진입 시 nil이면 원본 사용, 완료 시 자동 반영
- **Acceptance Criteria**:
  - After 저장 후 카메라 dismiss가 지연되지 않음
  - 백그라운드 작업 실패 시 크래시 없음 (에러 로그만)
- **Spec**: F14/F15/F17 자동 실행
- **Dependencies**: W4, W5, W6

---

## Execution Order

```
Layer 0 (병렬, 파일 겹침 없음):
  W1 (PhotoPair.swift)
  W2 (PhotoStorageService.swift)
  W3 (ImageProcessingContext.swift NEW)

Layer 1 (병렬, W1/W2/W3 완료 후):
  W4 (AlignmentService.swift NEW)        ← W1, W2, W3
  W5 (MatchingScoreService.swift NEW)    ← W1, W3
  W6 (ColorCorrectionService.swift NEW)  ← W1, W2, W3
  W7 (HeatmapService.swift NEW)          ← W3

Layer 2 (W4, W5 완료 후):
  W9 (ComparisonContainerView.swift NEW) ← W1, W4, W5

Layer 3 (병렬, W9 완료 후 — 자식 뷰 & 컴포넌트):
  W10 (SideBySideView.swift NEW)         ← W9
  W11 (SliderCompareView.swift NEW)      ← W9
  W12 (HeatmapView.swift NEW)            ← W7, W9
  W13 (AnimationCompareView.swift NEW)   ← W9
  W14 (MatchingScoreBadge.swift NEW)     ← W9

Layer 4 (병렬, Layer 3 완료 후 — 통합):
  W8  (PairGalleryView + PairCellView MODIFY) ← W9
  W15 (UnifiedCameraView MODIFY)              ← W4, W5, W6
```

## File Dependency Matrix

| WI  | Creates | Modifies |
|-----|---------|----------|
| W1  | — | PhotoPair.swift |
| W2  | — | PhotoStorageService.swift |
| W3  | ImageProcessingContext.swift | — |
| W4  | AlignmentService.swift | — |
| W5  | MatchingScoreService.swift | — |
| W6  | ColorCorrectionService.swift | — |
| W7  | HeatmapService.swift | — |
| W8  | — | PairGalleryView.swift, PairCellView.swift |
| W9  | ComparisonContainerView.swift | — |
| W10 | SideBySideView.swift | — |
| W11 | SliderCompareView.swift | — |
| W12 | HeatmapView.swift | — |
| W13 | AnimationCompareView.swift | — |
| W14 | MatchingScoreBadge.swift | — |
| W15 | — | UnifiedCameraView.swift |

**파일 겹침 분석**: 동일 파일을 수정하는 작업이 없음 — 모든 Layer 내 작업은 병렬 실행 가능. PhotoPair.swift는 W1만 구조 수정 (W4/W5/W6는 ModelContext 통한 필드 값 갱신이므로 파일 수정 없음).

## Known Failures 대응
- **F001/F004**: Vision/CoreImage API는 SDK 헤더 검증 완료 (research-report.json `sdk_api_verification` 15개 항목)
- **F005**: W8에서 빈 closure 금지, 실제 네비게이션 연결 필수
- **F006**: W9 ComparisonContainerView에 W10~W14 자식 뷰 4+1개가 반드시 body에 삽입되었는지 코드리뷰 확인

## 주요 리스크 요약
- **R1 (HIGH, F14)**: VNHomographicImageRegistrationRequest는 before/after 해상도 정확 일치 필수 → W4에서 before 리사이즈 선행
- **R2 (HIGH, F14)**: warpTransform(matrix_float3x3) → 4코너 CGPoint 수학 역산 로직 필요
- **R3 (HIGH, F14/F15/F16)**: 48MP 메모리 압박 → 1200px 다운스케일로 AI 처리
- **R5 (MEDIUM, 전체)**: Vision perform은 동기 블로킹 → `Task.detached`, SwiftData 업데이트는 `@MainActor`
