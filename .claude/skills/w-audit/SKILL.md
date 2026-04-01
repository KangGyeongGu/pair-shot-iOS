---
name: w-audit
description: Run mechanical and semantic audit on current changes
---

Audit workflow:
1. Read .claude/status.json → state must be "auditing"

Phase 1 — Mechanical (run all, then gate):
  Run all 4 checks independently (parallel where possible):
  1. xcodebuild build -project PairShot/PairShot.xcodeproj -scheme PairShot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_STRICT_CONCURRENCY=complete -quiet
  2. swiftlint lint PairShot/PairShot --config .swiftlint.yml --strict
  3. swiftformat --lint PairShot/PairShot --config .swiftformat
  4. xcodebuild test -project PairShot/PairShot.xcodeproj -scheme PairShot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_STRICT_CONCURRENCY=complete -quiet
  Report all results, then gate: any failure → verdict NEEDS_WORK, do NOT proceed to Phase 2.

Phase 2 — Semantic (parallel, scoped):
  Orchestrator MUST split review work into small scoped units.
  Each agent receives at most 3-5 files with explicit file paths.

  Splitting strategy:
  - Group files by layer: Services, Views, Protocols/Models
  - Spawn one code-reviewer per group (parallel)
  - Spawn one test-reviewer for test files vs their production counterparts
  - Each agent prompt MUST list exact file paths to review — no open-ended "review everything"

  Example for a phase with Services(3) + Views(6) + Protocols(2):
    Agent 1: code-reviewer → Services/*.swift (3 files) — focus: concurrency, API usage, error handling
    Agent 2: code-reviewer → Views/*.swift (max 5) — focus: architecture, UX, accessibility
    Agent 3: code-reviewer → Protocols + Models — focus: protocol design, spec compliance
    Agent 4: test-reviewer → test files vs production files listed above

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
  "mechanical": { "build": "pass", "lint": "pass", "format": "pass", "test": "pass" },
  "semantic": {
    "code_review": { "verdict": "...", "findings": [...] },
    "test_review": { "verdict": "...", "findings": [...] }
  },
  "device_test_items": [
    "description of manual device test needed (camera, sensor, UX, permissions, etc.)"
  ]
}

Note on test_review scope:
- test_review judges ONLY pure-logic unit test coverage (state, math, data, file I/O)
- Hardware-dependent scenarios (camera, sensor, permissions, background lifecycle) go into device_test_items as a checklist for the user to verify on a real device
