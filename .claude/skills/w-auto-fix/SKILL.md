---
name: w-auto-fix
description: Auto-fix audit violations — mechanical tools first, then agent for structural issues
---

Auto-fix workflow:
1. Read .claude/status.json → state must be "developing" with retry_count > 0
2. Read .claude/audit-report.json → get violation list

Phase 1 — Mechanical auto-fix (no AI needed):
  1. `swiftformat PairShot/PairShot --config .swiftformat`
  2. `swiftlint lint --fix PairShot/PairShot --config .swiftlint.yml`

Phase 2 — Verify remaining violations:
  Run lint + format in lint-only mode (parallel):
  1. `swiftlint lint PairShot/PairShot --config .swiftlint.yml --strict`
  2. `swiftformat --lint PairShot/PairShot --config .swiftformat`
  If 0 violations → skip Phase 3.

Phase 3 — Structural fix (agent needed):
  Update audit-report.json with remaining violations only.
  Spawn fix-worker agent (worktree isolation) → reads audit-report.json, fixes structural issues.

Phase 4 — Final verification:
  Run all mechanical checks (build, lint, format) in parallel.
  If all pass → run /w-commit, update status.json: state → "auditing"
  If still failing → status.json: state → "blocked"
