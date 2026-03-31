---
name: w-run-all
description: Run full MVP development pipeline from current phase to completion
---

Full pipeline orchestration. Current session acts as orchestrator.

Procedure:
1. Read .claude/status.json → check current state/phase
2. Read .claude/pipeline.json → phase list + dependencies + device_test flag
3. For each phase (sequential):
   a. /w-plan → plan the phase
   b. /w-develop → implement
   c. /w-audit → verify
   d. PASS → /w-merge → create PR + merge
   e. NEEDS_WORK → re-run /w-develop (max 3 retries)
   f. BLOCKED → report to user, wait for resolution
4. After merge:
   a. Check device_test in pipeline.json
   b. device_test = true → show test items to user, wait for result
   c. device_test = false → proceed to next phase automatically
5. Phases with parallel: true → run in concurrent worktrees
6. All phases complete → report "MVP complete"

Rules:
- Orchestrator stays on develop branch (never switches branches)
- All implementation runs in develop-worker worktree
- Git commits via /w-commit skill (Conventional Commits)
- NEVER add Co-Authored-By or Claude-related trailers
