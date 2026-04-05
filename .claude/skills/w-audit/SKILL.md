---
name: w-audit
description: Run mechanical and semantic audit on current changes
---

Audit workflow:
1. Read .claude/status.json → state must be "auditing"
2. Read .claude/skills/w-audit/project-versions.md → exact tool/framework versions to constrain semantic review references

Phase 1 — Mechanical (run all, then gate):

### 1A. 기본 검사 (build/lint/format/test)
  1. `xcodebuild build -project PairShot/PairShot.xcodeproj -scheme PairShot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_STRICT_CONCURRENCY=complete -quiet`
  2. `swiftlint lint PairShot/PairShot --config .swiftlint.yml --strict`
  3. `swiftformat --lint PairShot/PairShot --config .swiftformat`
  4. `xcodebuild test -project PairShot/PairShot.xcodeproj -scheme PairShot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_STRICT_CONCURRENCY=complete -quiet`

### 1B. 성능 병목 정적 분석 — Build flags
SwiftUI body의 타입 추론 병목 및 긴 함수 검출 (Xcode/Swift 컴파일러 기능, 설치 불필요):
```
xcodebuild build -project PairShot/PairShot.xcodeproj -scheme PairShot \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  OTHER_SWIFT_FLAGS='-Xfrontend -warn-long-function-bodies=100 -Xfrontend -warn-long-expression-type-checking=100' \
  2>&1 | grep -E "warning:.*(took [0-9]+ms|expression|function body)"
```
- `-warn-long-function-bodies=100`: 100ms 이상 걸리는 함수 본문 경고
- `-warn-long-expression-type-checking=100`: 100ms 이상 걸리는 단일 표현 타입 체크 경고
- 목표: SwiftUI body 타입 추론 병목은 런타임 UI 버벅거림의 주요 원인. 200ms 이상은 major, 500ms 이상은 critical로 분류.

### 1C. Dead code 검출 — periphery
설치: `brew install peripheryapp/periphery/periphery` (최초 1회). `which periphery` 로 설치 확인.
실행:
```
periphery scan --project PairShot/PairShot.xcodeproj --schemes PairShot --targets PairShot --quiet \
  -- -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -sdk iphonesimulator
```
- `-- ` 이후는 xcodebuild로 패스스루되는 인자. macOS 데스티네이션 충돌을 피하기 위해 반드시 iOS Simulator 명시.
- 출력 `* No unused code detected.` 가 통과. 파일별 경고가 있으면 dead code 수정 필요 목록에 기록.

### 1D. 런타임 프로파일링 — xctrace (Instruments CLI, Xcode 내장)
**선택적**: 성능 병목 심층 분석이 필요한 경우에만 실행. 시간 5-10분 소요.

시뮬레이터 부팅 + 앱 설치:
```
xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/PairShot-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "PairShot.app" | head -1)
xcrun simctl install booted "$APP_PATH"
BUNDLE_ID=$(defaults read "$APP_PATH/Info" CFBundleIdentifier)
```

프로파일 수집 (템플릿별):
```
mkdir -p /tmp/pairshot-traces
# 1. Time Profiler: CPU 핫스팟 + 구동 시간
xcrun xctrace record --template 'Time Profiler' --device "iPhone 15 Pro" \
  --launch -- "$BUNDLE_ID" --output /tmp/pairshot-traces/launch.trace --time-limit 30s

# 2. Allocations: 메모리 할당 피크
xcrun xctrace record --template 'Allocations' --device "iPhone 15 Pro" \
  --launch -- "$BUNDLE_ID" --output /tmp/pairshot-traces/alloc.trace --time-limit 30s

# 3. Animation Hitches: 프레임 드롭
xcrun xctrace record --template 'Animation Hitches' --device "iPhone 15 Pro" \
  --launch -- "$BUNDLE_ID" --output /tmp/pairshot-traces/hitches.trace --time-limit 30s
```

내보내기 (xml/csv 분석):
```
xcrun xctrace export --input /tmp/pairshot-traces/launch.trace --xpath '/trace-toc/run/data/table[@schema="time-sample"]'
```

**적용 기준**: xctrace는 CI 자동화보다는 심층 분석용. 보통 audit 시 1회 수집 후 finding이 있을 때만 재수집. 결과는 `/tmp/pairshot-traces/` 에 남김. 프로세스가 오래 실행되므로 `timeout` 파라미터 충분히 주기 (5-10분).

---

**Gating**: 1A-1C 중 하나라도 실패 → verdict NEEDS_WORK, do NOT proceed to Phase 2.
1B(성능 경고)와 1D(xctrace 결과)는 정보성 — critical로 분류된 경우만 gating.

---

Phase 2 — Semantic (parallel, scoped):
  **버전 제약 레퍼런스**: 모든 code-reviewer 에이전트 프롬프트에 `.claude/skills/w-audit/project-versions.md` 의 정확한 iOS/Swift/프레임워크 버전을 삽입하고, "인용 없는 주장 금지 / 이 버전 이상/이하의 API를 다루는 문서는 무시" 지시.

  Orchestrator MUST split review work into small scoped units.
  Each agent receives at most 3-5 files with explicit file paths.

  Splitting strategy:
  - Group files by layer: Services, Views, Protocols/Models
  - Spawn one code-reviewer per group (parallel — 리뷰 에이전트는 읽기 전용이므로 xcodebuild를 돌리지 않아 병렬 안전)
  - Spawn one test-reviewer for test files vs their production counterparts
  - Each agent prompt MUST list exact file paths to review — no open-ended "review everything"
  - Each agent prompt MUST embed project version snapshot (from project-versions.md) and require reference-backed findings

  Example for a phase with Services(3) + Views(6) + Protocols(2):
    Agent 1: code-reviewer → Services/*.swift (3 files) — focus: concurrency, API usage, error handling
    Agent 2: code-reviewer → Views/*.swift (max 5) — focus: architecture, UX, accessibility
    Agent 3: code-reviewer → Protocols + Models — focus: protocol design, spec compliance
    Agent 4: test-reviewer → test files vs production files listed above

  **Performance-focused review (성능 병목 전용 패스)**:
  사용자가 성능 검증을 요청한 경우, 추가로 아래 전용 에이전트 실행:
    Agent P1: code-reviewer → 앱 구동 경로 (PairShotApp.swift, ContentView.swift, 초기 @State/@Query)
    Agent P2: code-reviewer → 비교 뷰 파이프라인 (ComparisonContainerView + 4 모드 뷰) — 이미지 로드/제스처
    Agent P3: code-reviewer → AI 서비스 파이프라인 (AIAnalysisCoordinator + Vision/CoreImage 서비스) — 메인 스레드 블로킹, CIContext 재사용
    Agent P4: code-reviewer → 갤러리/카메라 전환 경로 — fullScreenCover, SwiftData @Query 효율
  각 성능 리뷰 에이전트는 project-versions.md에 명시된 프레임워크 버전의 WWDC 세션/Apple 공식 문서만 인용. 다음 레퍼런스 우선:
    - WWDC "Demystify SwiftUI performance" (버전 매칭 연도)
    - Apple "Improving app responsiveness"
    - Core Image performance best practices
    - SwiftData performance guide
    - Vision framework revision guide

  Each agent MUST return a structured verdict in its final message.

Phase 3 — Aggregate:
  Collect all findings → determine verdict:
  - PASS → write audit-report.json/md, status → "merging"
  - NEEDS_WORK → record fixes needed in audit-report, status → "developing", retry_count++
    → Next step: run /w-auto-fix to resolve violations
  - BLOCKED → status → "blocked"

Audit-report.json format:
{
  "verdict": "PASS|NEEDS_WORK|BLOCKED",
  "mechanical": {
    "build": "pass",
    "lint": "pass",
    "format": "pass",
    "test": "pass",
    "build_flags_perf": { "warnings": [...], "status": "info|needs_work" },
    "periphery": { "unused": [...], "status": "pass|needs_work" },
    "xctrace": { "traces": ["path/to/.trace"], "findings": [...], "status": "info|needs_work" }
  },
  "semantic": {
    "code_review": { "verdict": "...", "findings": [...] },
    "test_review": { "verdict": "...", "findings": [...] },
    "performance_review": { "verdict": "...", "findings": [...] }
  },
  "device_test_items": [...]
}

Note on test_review scope:
- test_review judges ONLY pure-logic unit test coverage (state, math, data, file I/O)
- Hardware-dependent scenarios (camera, sensor, permissions, background lifecycle) go into device_test_items as a checklist for the user to verify on a real device
