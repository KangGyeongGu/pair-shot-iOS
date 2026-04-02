---
name: w-run-all
description: Run full MVP development pipeline from current phase to completion
---

Full pipeline orchestration. Current session acts as orchestrator.

Procedure:
1. Read .claude/status.json → check current state/phase
2. Read .claude/pipeline.json → phase list + dependencies + device_test flag
3. For each phase (sequential):
   a. /w-plan → plan the phase (create feature branch per architecture.md 4.1)
   b. /w-develop → implement all work items
   d. /w-audit → verify (mechanical + semantic)
   e. NEEDS_WORK → /w-auto-fix first (mechanical auto-fix + structural fix-worker)
      → re-audit. If still failing → retry /w-develop (max 3 retries)
   f. PASS → /w-merge → create PR + merge to develop
   g. BLOCKED → report to user, wait for resolution
4. After merge:
   a. Check device_test in pipeline.json
   b. device_test = true → show test items to user, wait for result
   c. device_test = false → proceed to next phase automatically
5. Phases with parallel: true → run in concurrent worktrees
6. All phases complete → report "MVP complete"

IMPORTANT: Between steps, do NOT pause to ask user unless:
- Plan approval gate (3b)
- device_test = true (4b)
- BLOCKED state (3g)
All other transitions (develop → audit → auto-fix → merge) run automatically.
Never create pr or merge to git, it must be activated by User's permission. 

Rules:
- Orchestrator stays on develop branch (never switches branches)
- All implementation runs in develop-worker worktree
- Git commits via /w-commit skill (Conventional Commits)
- NEVER add Co-Authored-By or Claude-related trailers
