# PairShot iOS — Spec Realign Findings (Round 1)

8 explorer (E1~E8) 가 docs/10~17 영역별 read-only 검수한 결과 압축.
2026-04-26 기준. 코드 ↔ spec 차이 = 코드를 고치는 게 원칙 (docs 우선).

---

## 0. 총 통계

| 영역 | Critical | High | Medium | Low |
|------|----------|------|--------|-----|
| E1 docs/10+11 (제품·IA) | 4 | 2 | 1 | 0 |
| E2 docs/12 §12.1~6 (4 screen) | 3 | 7 | 4 | 1 |
| E3 docs/12 §12.7~11 (Settings 영역) | 3 | 4 | 2 | 0 |
| E4 docs/13 (data model) | 5 | 6 | 2 | 1 |
| E5 docs/14 (functional) | 3 | 4 | 3 | 0 |
| E6 docs/16 (strings) | 1 | 3 | 2 | 1 |
| E7 docs/17+CLAUDE.md (architecture) | 5 | 2 | 3 | 1 |
| E8 docs/15+swift-style (NFR) | 1 | 4 | 4 | 2 |
| **합계** | **25** | **32** | **21** | **6** |

총 84건 (Critical 25 + High 32 = **57건이 자동 수정 대상**).

---

## 1. Critical 25건 (현행 MVP 의 근간 위반)

| # | 영역 | 사항 | 주요 파일 |
|---|------|------|----------|
| C-01 | IA | 시작 화면 = Camera Before 인데 코드는 ArchiveView | `ContentView.swift:17`, `ArchiveView.swift` |
| C-02 | IA / Data | `Project` entity 존재 (docs 가 명시 금지한 안티 패턴) | `Models/Project.swift`, `PhotoPair.project` FK |
| C-03 | IA | "프로젝트 → 갤러리 → 카메라" 3-depth (spec 0-depth 카메라 시작) | `ArchiveView` → `PairGalleryView` → `BeforeCameraView` |
| C-04 | Data | `Album` entity 부재 (페어 그룹핑의 SoT) | (파일 자체 부재) |
| C-05 | Data | `PhotoPair.albums` many-to-many 관계 부재 | `Models/PhotoPair.swift` |
| C-06 | Screens | AlbumDetail 화면 부재 | `Features/AlbumDetail/` 부재 |
| C-07 | Screens | PairPicker 화면 부재 | `Features/AlbumDetail/PairPickerView.swift` 부재 |
| C-08 | Screens | PairPreview 화면 부재 (Comparison sheet 가 대체 중이나 single-step 토글·재촬영·BottomBar 4 액션 모두 없음) | `Features/PairPreview/` 부재 |
| C-09 | Screens | WatermarkSettings 화면 전체 부재 (3×3 위치, 줄수, 반복수, 텍스트/로고 분기, 미리보기) | `Features/Settings/WatermarkSettingsView.swift` 부재 |
| C-10 | Screens | CombineSettings 부분만 (테두리·레이블·레이블배경·미리보기 없음) | `Features/Settings/CompositionSettings.swift` |
| C-11 | Screens | License 화면 부재 | `Features/Settings/LicenseView.swift` 부재 |
| C-12 | Data | 파일 디렉토리 = `Application Support/photos/<flat>/` (spec: `Documents/PairShot/photos/{before,after,combined}/`) | `Services/PhotoStorageService.swift` |
| C-13 | Data | 파일명 패턴 = `<prefix><UUID>.jpg` (spec: `{prefix}{type}_{timestamp}_{shortId}.jpg`) | `PhotoStorageService.writeJPEG` |
| C-14 | Data | iCloud 백업 정책 정반대 (`photos/` excluded vs spec include, `thumbnails/` 부재) | `PhotoStorageService.ensureDirectoryExists` |
| C-15 | Functional | 합성 자동 트리거 부재 (After 채워지면 자동 — spec 14.2). 현 코드는 ComparisonView 메뉴에서 사용자 트리거 | `AfterCaptureAction.swift` |
| C-16 | Functional | 페어 삭제 다이얼로그 "합성본만" 분기 부재 (spec 14.4) | `PairDeletionService` |
| C-17 | Functional | 재촬영 플로우 부재 (PairPreview "재촬영" 메뉴 → After 만 다시 → 합성 재생성 → popBack) | (PairPreview 자체 부재) |
| C-18 | Strings | 모든 ~212 `String(localized:)` 호출이 raw 한국어를 키로 사용 (spec 컨벤션 `{section}_{type}_{name}` 0건) | 전체 코드베이스 |
| C-19 | Architecture | Domain layer 부재 (`Domain/Models/Repositories/Services/UseCases/`) | 디렉토리 자체 부재 |
| C-20 | Architecture | UseCase 패턴 완전 부재 (CreatePairUseCase 등) | (디렉토리 부재) |
| C-21 | Architecture | ViewModel layer 부재 — View 가 Service/actor 직접 호출 | 모든 Features |
| C-22 | Architecture | Repository 패턴 부재 (PhotoStorageService struct 가 직접 SwiftData/FileManager) | `Services/PhotoStorageService.swift` |
| C-23 | Architecture | View 가 AVCaptureSession 직접 보유 (Forbidden #1) | `CameraPreview.swift:8`, `CameraStack.swift:14`, `AfterCameraStack.swift:14`, `QRScannerViewController.swift:24` |
| C-24 | Code style | 신규 코드 주석 금지 위반 — `//` ~2335줄, `///` ~1900줄 (CouponVerifier 전체 DocC 등) | 전 코드베이스 |
| C-25 | Settings | 워터마크 "사용자 설정" Rewarded Ad 게이트 미적용 (CompositionSettingsGate 는 합성 only) | `SettingsView.swift` |

---

## 2. High 32건 (출시 기준 미달)

(주요 항목만 압축; 완전 목록은 explorer 결과 본문 참조.)

- Camera Before: 야간모드 chip (E2-C5/E5-H-02), Before Strip 썸네일 가로 스크롤 (E2-C6), TopBar 홈 아이콘 (E2-C4)
- Camera After: 회전 가이드 (E2-C7/E5-H-04), overlay chip + opacity slider (E2-C13)
- Home: 단일 Pair 그리드 + Album 필터 토글 구조 (E2-C8/C9), BottomBar 4 액션 완전체 (E2-C10), 정렬 최신순/오래된순 토글 (E5-M-02)
- 합성: in-flight `beginBackgroundTask` (E5-H-01)
- Snackbar: 큐잉·debounce (E5-H-03)
- Data: PhotoPair 필드 rename (`beforeFileName` 등, E4-D6), `updatedAt`/`latitude`/`longitude`/`locationLabel` (D7~D8), CameraSettings embedded struct (D9), PairStatus 3-case computed (D10), 디스크 thumbnail 디렉토리 (D11), EXIF 정규화 (D12)
- Strings: `Localizable.xcstrings` 마이그레이션 (E6-S1), docs/16.5 핵심 200+ 키 등록 (E6-S3), 하드코딩 한국어 9건 (E6-S4)
- Architecture: AppEnvironment composition root (E7-A6), Ads protocol Strategy/Adapter (E7-A7), 하드코딩 Color literal (E7-A8)
- Settings: 6 섹션 정합 (촬영및파일·워터마크·합성·일반·쿠폰·저장공간및앱정보 — E3-A4), 일반 섹션 (언어 3-radio, 테마 3-radio — E3-A9), 개인정보처리방침 외부 브라우저 (E3-A7)
- Code style: `@unchecked Sendable` DocC 블록 → 1줄 `//` 교체 (E8-NF-02), Info.plist landscape 제거 (E8-NF-03), Coupon JSON payload format `{code,kind,issuedAt,version}` 전환 (E8-NF-04), OSLog 5 카테고리 (E8-NF-05)
- Export: ExportSettings 전용 화면 + BottomBar 진입 (E1-H-01)
- 광고: WatermarkSettingsGate (E1-H-02 = E3-A6)

---

## 3. Cluster 제안 (12종)

의존 관계 + working tree 충돌 회피 + cluster 명명 `realign-{영역}`. 직렬 순서.

| # | Cluster | 묶음 | 근사 공수 |
|---|---------|------|----------|
| 1 | `realign-data-model` | C-04, C-05, C-12, C-13, C-14, C-15(연관), High D6~D12 | XL (SwiftData VersionedSchema 마이그레이션) |
| 2 | `realign-architecture` | C-19, C-20, C-21, C-22, C-23, High A6, A7 | XL (Domain/Data/Features 폴더 재편 + UseCase/Repository/ViewModel 도입) |
| 3 | `realign-ia` | C-01, C-02, C-03 (root navigation 전환) | L (Project 제거 + Camera root 전환) |
| 4 | `realign-screens-album` | C-06, C-07 (AlbumDetail + PairPicker) | L |
| 5 | `realign-screens-pair-preview` | C-08, C-17 (PairPreview + 재촬영) | L |
| 6 | `realign-screens-settings-detail` | C-09, C-10, C-11 (Watermark/Combine/License 상세) | XL |
| 7 | `realign-settings-structure` | C-25, High Settings 6 섹션 정합, A4, A7, A9 | M |
| 8 | `realign-camera` | High 야간모드, Before Strip, 회전 가이드, overlay chip | L |
| 9 | `realign-functional-polish` | C-15 (자동 합성 트리거), C-16 (합성본만 삭제), High beginBackgroundTask, snackbar queue, 정렬 토글 | L |
| 10 | `realign-export` | E1-H-01 (ExportSettings 화면 분리 + BottomBar 진입) | M |
| 11 | `realign-strings` | C-18, High xcstrings 마이그레이션, 200+ 키 등록, 9 하드코딩 제거, error LocalizedStringResource | XL |
| 12 | `realign-style-misc` | C-24 (주석 제거 ~4000줄), High Info.plist landscape, OSLog, Coupon JSON payload, 하드코딩 Color | L |

근사 총 공수: **L 4개 + M 2개 + XL 6개**. 5 라운드 budget 으로 cluster 1개/라운드 페이스만 가능 → **루프 1회 (5 라운드) 로 12 cluster 모두 완료 불가능**.

---

## 4. 루프 결정 (Round 1 abort)

본 라운드는 다음 사유로 implementer dispatch 없이 **findings 정리·docs commit·사용자 보고**로 종결:

1. **scope vs budget mismatch**: 12 cluster (XL 다수) ≫ 5 라운드 budget. 1 cluster 라도 부분 dispatch 시 working tree 가 다른 cluster 의존성과 충돌해 후속 라운드 직렬화 비용 폭증.
2. **architecture 재편 + entity 마이그레이션**: 시스템 root (Project → Album, file path/naming, root navigation, Domain layer) 가 동시 변경되어야 의미 있음. 하나만 먼저 commit 시 중간 상태가 build 통과는 해도 사용자에게 깨진 앱.
3. **사용자 결정 필요**: 출시본 (Audit-D 까지 완료) 의 scope 를 재정의할지, docs 를 현 구현에 맞춰 갱신할지, 아니면 spec 우선 rewrite 할지 — 자체 결정 범위 초과.

---

## 5. 사용자 선택 옵션

| 옵션 | 의미 | 후속 작업 |
|------|------|----------|
| **A. 스펙 우선 rewrite** | docs/10~17 = SoT 그대로. 현 P0~P10 구현은 재배치 / 재작성. v1.0 출시 일정 reset. | 새 roadmap (R1~Rn) 작성. cluster 1~12 를 phase 로 재구성. 라운드 당 1 cluster, 12+ 라운드. |
| **B. 현 구현 우선 docs 정합** | 출시본 구현 (Project entity, Application Support, 단순 워터마크 등) 을 SoT 로 docs/10~17 갱신. Critical 대부분 사라짐. | docs 12 파일 갱신 단일 commit. spec-realign 라운드는 그 다음 H/M Polish 만. 1~2 라운드로 종료 가능. |
| **C. 하이브리드** | 출시 가능한 핵심 (강제 안전·접근성·strings 정합) 만 spec 따라가고, 정보 아키텍처 (Project/Album) 와 Domain layer 등은 v1.x 로 미룸. | docs 12 파일 partial 갱신 + 명시적 v1.x 스코프 분리 + 1~2 cluster (strings, comments, polish) 만 진행. 2~3 라운드로 종료. |

권장: **C** (현실적). v1.0 출시본은 audit-D 까지 polish 완료 + TestFlight 단계. spec 의 Project 부재·Album 도입·Domain layer 재편은 v1.1 이상에서 SwiftData 마이그레이션과 함께 다루는 게 안전.

---

## 6. 본 commit 의 행위

- `docs/03-spec-realign-findings.md` 신규 생성 (본 파일)
- `docs/00-roadmap.md` 변경 없음 (Phase 0 commit 에서 spec 보강 완료)
- 코드 변경 없음
- 1 commit: `docs(spec-fix): R1 spec realign 차이 정리·cluster 12종 도출·사용자 결정 옵션 A/B/C 제시`

다음 라운드는 사용자 옵션 선택 후 재진입.
