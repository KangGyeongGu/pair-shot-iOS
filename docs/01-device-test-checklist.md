# PairShot iOS — 실 디바이스 스모크 테스트 체크리스트

P10.4. App Store 제출 직전 사용자(=릴리스 매니저)가 실제 iPhone에서
한 번씩 실행하며 체크. 시뮬레이터로는 카메라 / 위치 / 광고 SDK / ATT
프롬프트 일부가 정확히 동작하지 않으므로 반드시 실 기기 1대 이상에서
완주할 것.

각 항목 체크박스 1번 통과 → `[x]` 마킹. 실패 시 GitHub Issue 발행 +
Phase 11 (App Store 출시) 진행 보류.

---

## 1. 권한 흐름

콜드 인스톨 (앱 삭제 후 재설치) 상태에서 시작.

### 1.1 카메라 권한
- [ ] 첫 Before 진입 시 카메라 권한 시스템 프롬프트 표시
- [ ] **허용** → 프리뷰가 즉시 시작됨
- [ ] **거부** → `PermissionDeniedView` 노출, "설정으로 이동" 버튼이 시스템 설정 앱의 PairShot 페이지를 연다
- [ ] 설정에서 토글 ON → 앱 복귀 시 카메라 정상

### 1.2 위치 권한
- [ ] 새 프로젝트 생성 시트의 "GPS 자동 기록" 토글이 기본 ON
- [ ] "사용 중에만 허용" 시 lat/lon이 기록됨 (List에 위치 라벨 표시 — 선택 사항)
- [ ] "거부" 시 lat/lon = nil로 정상 생성 (앱 충돌 없음)

### 1.3 사진 라이브러리 권한
- [ ] Export → "사진 앱에 저장" 첫 호출 시 `Add-only` 권한 프롬프트
- [ ] 허용 후 사진 앱 최근 항목에 저장된 JPEG 확인
- [ ] 거부 시 에러 알림 (앱 충돌 없음)

### 1.4 ATT (App Tracking Transparency)
- [ ] 첫 광고 로드 직전 ATT 프롬프트 표시 (한국어 사유 표시)
- [ ] **허용/거부** 모두 앱 정상 동작
- [ ] 거부 시에도 광고는 표시됨 (개인화만 비활성)

---

## 2. Before 캡처 (`BeforeCameraView`)

- [ ] 핀치 줌 부드러운 ramp (디바이스 줌 limit 안에서)
- [ ] 4 프리셋 버튼 (0.5× / 1× / 2× / 5×) — 디바이스가 지원하지 않는 프리셋은 hide
- [ ] 4 렌즈 우선순위 자동 선택 (triple → dualWide → dual → wideAngle)
- [ ] 4 플래시 모드 cycle (off → on → auto → torch → off) — torch 모드는 즉시 LED 점등
- [ ] 탭 포커스 — reticle 1초 페이드 아웃
- [ ] EV 드래그 (세로 드래그) — 노출이 시각적으로 변함
- [ ] 그리드 토글 — 3×3 격자 표시/숨김
- [ ] 수평계 토글 — `±X°` pill, ≤ 1.5°에서 녹색
- [ ] 셔터 → 햅틱 (heavy) → 썸네일 well에 즉시 반영
- [ ] 캡처 후 `PhotoPair`가 `pendingAfter` 상태로 추가됨 (Gallery에서 확인)

---

## 3. After 캡처 (`AfterCameraView`)

- [ ] Before 페어 1개 이상 있을 때만 진입 가능
- [ ] 진입 시 가장 오래된 `pendingAfter` 페어 자동 로드
- [ ] Before 사진이 반투명 overlay로 노출 (자동 정렬 0 — 단순 `.opacity()`)
- [ ] Alpha 슬라이더 0.0~1.0 변경 시 즉시 반영
- [ ] Before zoom factor 자동 복원 (1회 가드 — 핀치 override 가능)
- [ ] 셔터 → status `.complete` 전이 → 다음 `pendingAfter` 페어로 자동 전이
- [ ] 마지막 페어 완료 후 자동 dismiss

---

## 4. Gallery (`PairGalleryView`)

- [ ] 2열 그리드 (정사각 셀)
- [ ] 상태 배지 — Before(주황) / 완료(녹) / 합성(보라) 분기
- [ ] **ALL** / **합성본** 필터 segmented Picker
- [ ] 길게 누르기(0.4s) → 다중 선택 모드 진입
- [ ] 다중 선택 바 — 취소 / N개 선택 / 합성(disabled placeholder) / 공유 / 삭제
- [ ] 일괄 삭제 — JPEG 파일 + DB row + 썸네일 캐시 모두 정리됨
- [ ] 일괄 공유 → ExportPicker 4 모드 시트 → ZIP 또는 사진앱 저장 또는 이미지 공유
- [ ] 썸네일 캐시 — 스크롤 후 재진입 시 즉시 로드 (다운샘플 600px)
- [ ] AdFree 비활성 시 매 6 페어마다 NativeAdCell 삽입
- [ ] AdFree 활성 또는 selection mode 시 NativeAd 미삽입

---

## 5. Comparison (`ComparisonView`)

- [ ] Gallery 셀 탭 → 풀스크린 모달 진입 (`.fullScreenCover`)
- [ ] 좌우 스와이프 — 같은 프로젝트 내 인접 페어 순회 (가장자리 clamp)
- [ ] 아래로 스와이프 (>120pt) — 모달 dismiss
- [ ] 사진 탭 — split / before-only / after-only 토글
- [ ] 합성 메뉴 (square.on.square) — 가로 / 세로 + "(기본)" 라벨
- [ ] 합성 결과 → `pair.combinedPath` 갱신 → Gallery 배지 합성으로 변경
- [ ] 워터마크 토글 — 우하단 캡슐 (앱이름 · yyyy-MM-dd HH:mm)

---

## 6. Export & Share (`ExportPicker`)

- [ ] ExportMode 4종 (.all / .beforeOnly / .afterOnly / .combinedOnly) segmented Picker
- [ ] **ZIP 으로 공유** — ZIP 파일 생성 → 시스템 공유 시트 → 카톡/메일 첨부 OK
- [ ] **사진 앱에 저장** — 권한 OK 시 사진앱에 1장씩 저장 (PhotoKit `addOnly`)
- [ ] **이미지로 공유** — UIActivityViewController로 이미지 공유 시트
- [ ] 진행 중 ProgressView overlay → 완료 토스트 / 에러 알림

---

## 7. Settings (`SettingsView`)

- [ ] 5 섹션 (촬영·합성·내보내기·쿠폰·정보)
- [ ] 정보 섹션에 `CFBundleShortVersionString` / `CFBundleVersion` 표시
- [ ] **JPEG 품질** Picker — Low(0.6) / Standard(0.8) / High(0.95) 변경 즉시 반영
- [ ] **파일명 prefix** TextField — 32자 컷 + 금지문자(`/\:?*"<>|` + 제어문자) 제거
- [ ] **overlay alpha 기본값** 슬라이더 — 변경 후 After 진입 시 슬라이더 시작값 일치
- [ ] **합성 레이아웃 기본값** Picker — Comparison의 합성 메뉴에서 "(기본)" 라벨
- [ ] **워터마크 토글** — 합성 결과에 영향
- [ ] **저장 공간** NavigationLink — 폴더 크기 (ByteCountFormatter) + 페어 수
- [ ] **고아 파일 삭제** — confirmation alert → detached Task → 결과 라벨

---

## 8. Coupon (`CouponRegistrationView`)

- [ ] **수동 입력** — `<code>.<signatureBase64>` 토큰 paste → 등록 → 만료일 toast → 자동 dismiss
- [ ] **QR 스캔** — 권한 prompt → 사각 가이드 박스 → QR 인식 → 햅틱 → 등록 흐름
- [ ] **잘못된 토큰** — "코드 형식이 올바르지 않습니다" alert
- [ ] **검증 실패** — "쿠폰 검증 실패" alert (verifier returns false)
- [ ] **중복 활성** — "이미 등록된 쿠폰입니다" alert
- [ ] 등록 성공 시 `AdFreeStore.refresh()` → AdFree 배너 / 인터스티셜 / NativeAd 모두 즉시 사라짐
- [ ] **만료된 쿠폰** — 자동으로 status `.expired` rollover → AdFree 비활성 → 광고 다시 표시

---

## 9. 광고

### 9.1 Banner (ArchiveView 하단)
- [ ] AdFree 비활성 시 ArchiveView 하단에 GADBannerView 노출
- [ ] AdFree 활성 시 EmptyView (request 자체 미발생)

### 9.2 Interstitial (합성 결과)
- [ ] AdFree 비활성 + 5분 cap 만료 → 합성 성공 직후 풀스크린 광고
- [ ] AdFree 활성 시 호출 자체 skip

### 9.3 AppOpen (콜드 / 포그라운드)
- [ ] 첫 콜드 스타트 직후 (4분 cap 만료 시) 풀스크린 광고
- [ ] 백그라운드 → 포그라운드 복귀 시 (4분 cap 만료 시) 풀스크린 광고
- [ ] AdFree 활성 시 모두 skip

### 9.4 Rewarded (P8.3 게이트)
- [ ] CompositionSettingsGate 잠금 화면 → "광고 보고 잠금 해제"
- [ ] 광고 시청 완료 → `.granted` → 본 콘텐츠 노출
- [ ] AdFree 활성 시 즉시 unlock + skip

### 9.5 Native (Gallery 매 6 pair)
- [ ] PairGalleryView 의 LazyVGrid 에 매 6 페어마다 NativeAdCell 삽입
- [ ] AdFree 활성 또는 selection mode 시 미삽입

---

## 10. AdFree 상태

- [ ] 쿠폰 활성 직후 모든 광고 surface (Banner/Interstitial/AppOpen/Rewarded/Native) 가 1번의 화면 전환 안에 사라짐
- [ ] AdFreeStatusView 의 헤드라인이 "광고 제거 활성 (만료일: …)" 으로 갱신
- [ ] 만료 후 자동 rollover → 모든 광고 surface 다시 활성화

---

## 11. 빈 상태

- [ ] 프로젝트 0개 → ArchiveView ContentUnavailableView "프로젝트가 없습니다"
- [ ] 페어 0개 → PairGalleryView ContentUnavailableView "페어가 없습니다"

---

## 12. 오류 상태

- [ ] 카메라 권한 거부 → BeforeCameraView/AfterCameraView 진입 시 PermissionDeniedView
- [ ] 위치 권한 거부 → 새 프로젝트 생성 정상 진행 (lat/lon = nil)
- [ ] 사진 저장 권한 거부 → Export "사진 앱에 저장" 시 에러 알림
- [ ] AppStorage 손상된 raw value → fallback (`CompositionDefaults.layout(forRawValue:)` 등)

---

## 13. 회귀 방지

- [ ] App 강제 종료 후 재실행 — 마지막으로 본 ArchiveView 상태 (정렬·필터) 유지
- [ ] 디바이스 회전 (가로/세로) — 카메라 프리뷰 + Comparison 모두 깨지지 않음 (포트레이트 우선)
- [ ] 한국어 / English 시스템 언어 전환 — 모든 String이 자연스럽게 번역됨

---

체크리스트 완료 후 `docs/02-testflight-upload-guide.md` 단계로 진행.
