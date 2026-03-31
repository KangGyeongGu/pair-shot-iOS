---
name: w-audit
description: Run mechanical and semantic audit on current changes
---

Audit workflow:
1. Read .claude/status.json → state must be "auditing"

Phase 1 — Mechanical (fail-stop, sequential):
  1. xcodebuild build -scheme PairShot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet
  2. swiftlint lint --strict
  3. swiftformat --lint .
  4. xcodebuild test -scheme PairShot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet
  (any failure → verdict: FAIL, stop immediately)

Phase 2 — Semantic (parallel):
  1. Spawn code-reviewer agent → architecture/quality/security/App Store compliance
  2. Spawn test-reviewer agent → test quality/coverage

Phase 3 — Aggregate:
  Collect all findings → determine verdict:
  - PASS → write audit-report.json/md, status → "merging"
  - NEEDS_WORK → record fixes needed in audit-report, status → "developing", retry_count++
  - BLOCKED → status → "blocked"

Audit-report.json format:
{
  "verdict": "PASS|NEEDS_WORK|BLOCKED",
  "mechanical": { "build": "pass", "lint": "pass", "format": "pass", "test": "pass" },
  "semantic": {
    "code_review": { "verdict": "...", "findings": [...] },
    "test_review": { "verdict": "...", "findings": [...] }
  }
}
