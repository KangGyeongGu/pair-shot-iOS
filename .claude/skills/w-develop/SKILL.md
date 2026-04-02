---
name: w-develop
description: Execute development work items with build verification
---

Development workflow:
1. Read .claude/status.json → state must be "developing"
2. Read .claude/cycles/current/plan.md → work items + execution order + file dependency matrix
3. Orchestrator: git checkout -b feature/{phase-name} develop (if not already on feature branch)
4. Follow execution order from plan.md:
   - Sequential items: run one at a time, commit after each
   - Parallel items (no file overlap): run concurrently, commit each on completion
5. For each work item:
   a. Spawn develop-worker agent (works directly on feature branch, NO worktree)
   b. Worker reads .claude/specs/F{XX}.md + implements
   c. Worker runs: xcodebuild build + swiftlint --strict + swiftformat --lint
   d. Worker returns results
   e. If success → orchestrator commits: "feat(scope): W{N} description"
   f. If fail → Fresh Retry (max 3, fresh context + previous error summary)
6. After all work items:
   a. Write .claude/cycles/current/develop-report.json
   b. Update status.json: state → "auditing"
7. If still failing after 3 retries → status.json: state → "blocked"

Key rules:
- Workers operate directly on feature branch (no worktree isolation)
- Each work item gets its own commit on the feature branch
- Workers must NOT commit — orchestrator handles all git operations
- Commit message per work item: "feat(scope): W{N} description"
- NEVER run parallel workers that modify the same file — check file dependency matrix
- Each commit must be independently buildable (no broken intermediate states)
