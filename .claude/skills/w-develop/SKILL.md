---
name: w-develop
description: Execute development work items with build verification
---

Development workflow:
1. Read .claude/status.json → state must be "developing"
2. Read .claude/cycles/current/plan.md → work items
3. Orchestrator: git checkout -b feature/{phase-name} develop
4. For each work item, spawn develop-worker agent (worktree isolation):
   - Worker reads .claude/specs/F{XX}.md + implements
   - Worker runs: xcodebuild build (with SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_STRICT_CONCURRENCY=complete) + swiftlint --strict + swiftformat --lint
   - Worker returns results
5. If worker fails → Fresh Retry (max 3, each with fresh context + previous error summary)
6. If all items succeed:
   a. Run /w-commit to create commit
   b. Write .claude/cycles/current/develop-report.json + develop-report.md
   c. Update status.json: state → "auditing"
7. If still failing after 3 retries → status.json: state → "blocked"

Develop-report.json format:
{
  "phase": "P1",
  "work_items": [...],
  "build_status": "pass/fail",
  "lint_status": "pass/fail",
  "retry_count": 0
}
