# Phase 2: 데이터 모델 + 프로젝트 관리

## Features
- F01: Project Management + Archive Structure
- F06: Photo Pair List (Project Detail Screen)

## Research Summary
- SwiftData 모델 4개(Project, PhotoPair, Photo, PairStatus) 이미 정의됨
- ModelContainer 설정 완료 (PairShotApp.swift)
- CameraManager.savePhoto가 before.jpg 고정 — after 분기 필요
- CameraView.handleShutterTap에서 UUID() 임의 생성 — 실제 Project/PhotoPair 연결 없음
- NavigationStack 골격 존재, ContentView를 Archive 진입점으로 교체 필요

## Work Items

### W1: Model 보강 + Item.swift 정리
- Objective: Project에 completionRate 헬퍼 추가, Item.swift 삭제
- Owned Paths: PairShot/PairShot/Models/
- Acceptance Criteria: Project.completePairCount/totalPairCount 계산 프로퍼티 동작, Item.swift 삭제 후 빌드 성공
- Test Scope: completePairCount 계산 로직 단위 테스트
- Spec Reference: .claude/specs/F01-project-management.md
- SDK Headers: .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface

### W2: CameraManager Before/After 분기 저장
- Objective: savePhoto/generateThumbnail에 isBefore 파라미터 추가, after.jpg 경로 지원
- Owned Paths: PairShot/PairShot/Services/CameraManager.swift
- Acceptance Criteria: isBefore=true → before.jpg, isBefore=false → after.jpg 저장. 썸네일도 동일 분기
- Test Scope: 파일명 분기 로직 (하드웨어 의존 부분 제외)
- Spec Reference: .claude/specs/F01-project-management.md (File System Storage Structure)
- SDK Headers: .claude/apple-sdk-refs/Foundation/FileManager.h

### W3: PhotoStorageService 구현
- Objective: 파일 저장/삭제/썸네일 관리를 CameraManager에서 분리한 전용 서비스
- Owned Paths: PairShot/PairShot/Services/PhotoStorageService.swift
- Acceptance Criteria: 프로젝트 디렉토리 생성/삭제, 고아 파일 정리, 백그라운드 대량 삭제
- Test Scope: FileManager 기반 저장/삭제/경로 생성 단위 테스트
- Spec Reference: .claude/specs/F01-project-management.md (Non-functional Requirements)
- SDK Headers: .claude/apple-sdk-refs/Foundation/FileManager.h

### W4: Archive(프로젝트 목록) 화면
- Objective: 앱 진입점을 Archive로 변경. 프로젝트 목록/생성/삭제/이름변경 구현
- Owned Paths: PairShot/PairShot/Views/Archive/, PairShot/PairShot/ContentView.swift
- Acceptance Criteria:
  - 앱 시작 = Archive(프로젝트 목록)
  - "새 현장 촬영" 버튼 → 이름 입력 시트 → 프로젝트 생성 + GPS 자동 → Before 카메라 진입
  - 좌 스와이프 삭제(확인 alert), 길게 누르기 이름 변경
  - 빈 이름 → "2026-04-01 09:15 현장" 자동 생성
  - 100+ 프로젝트 스크롤 성능
- Test Scope: 프로젝트 생성 시 기본 이름 생성 로직 테스트
- Spec Reference: .claude/specs/F01-project-management.md
- SDK Headers: .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface, .claude/apple-sdk-refs/SwiftUI/SwiftUI.swiftinterface, .claude/apple-sdk-refs/CoreLocation/CLLocationManager.h

### W5: PairGallery(페어 목록) 화면
- Objective: 프로젝트 내 페어 그리드(2열). 미완료 우선 표시, 필터, 썸네일 캐시
- Owned Paths: PairShot/PairShot/Views/Gallery/
- Acceptance Criteria:
  - LazyVGrid 2열 썸네일 표시
  - 미완료 페어 빨간 테두리 + 상단 우선
  - 필터 세그먼트(전체/미완료/완료)
  - 빈 프로젝트 → 빈 상태 화면
  - 썸네일 NSCache 캐싱
  - 페어 삭제(스와이프 or 편집모드)
- Test Scope: 필터 로직 테스트
- Spec Reference: .claude/specs/F06-pair-gallery.md
- SDK Headers: .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface, .claude/apple-sdk-refs/SwiftUI/SwiftUI.swiftinterface

### W6: CameraView - Project/PhotoPair 연결
- Objective: CameraView가 실제 Project/PhotoPair를 받아 촬영→DB 저장까지 연결
- Owned Paths: PairShot/PairShot/Views/Camera/CameraView.swift
- Acceptance Criteria:
  - CameraView(project:pair:isBefore:) 생성자
  - 셔터 탭 → 실제 pair.id/project.id로 저장
  - 저장 완료 → Photo 객체 생성 + pair.beforePhoto/afterPhoto 할당 + status 업데이트
  - 연속 촬영: 셔터마다 새 PhotoPair 자동 생성
- Test Scope: Photo→PhotoPair 연결 로직 (ModelContext mock)
- Spec Reference: .claude/specs/F01-project-management.md, .claude/specs/F02-camera-basic.md
- SDK Headers: .claude/apple-sdk-refs/SwiftData/SwiftData.swiftinterface

### W7: 단위 테스트
- Objective: P2 순수 로직 테스트 작성
- Owned Paths: PairShot/PairShotTests/
- Acceptance Criteria: Model 헬퍼, PhotoStorageService 파일 I/O, 기본 이름 생성, 필터 로직 테스트 통과
- Test Scope: 하드웨어 비의존 순수 로직만
- Spec Reference: .claude/specs/F01-project-management.md, .claude/specs/F06-pair-gallery.md

## Execution Order
W1 → W2 → W3 → (W4, W5 parallel) → W6 → W7

## Risks
- HIGH: CameraView UUID() 임의 사용 → W6에서 실제 연결로 교체 필수
- HIGH: savePhoto before.jpg 고정 → W2에서 분기 처리 선행 필수
- MEDIUM: @Query predicate에서 relationship 필터링 불안정 → project.pairs 직접 사용 대안 검토
- MEDIUM: 대량 삭제 시 UI 블로킹 → W3에서 백그라운드 처리 구현
