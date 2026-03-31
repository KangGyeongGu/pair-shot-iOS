---
name: w-merge
description: Create PR, merge to develop, archive cycle
---

Merge workflow:
1. Read .claude/status.json → state must be "merging"
2. git push origin feature/{name}
3. gh pr create --title "{type}({scope}): {summary}" --body (audit-report summary)
4. gh pr merge --squash --delete-branch
5. git checkout develop && git pull origin develop
6. mv .claude/cycles/current/* .claude/cycles/archive/{date}_{phase-name}/
7. Update status.json:
   - state → "device_testing" (if device_test=true) or "idle" (if false)
   - current_phase → next phase
   - last_completed_phase → current phase
   - retry_count → 0
8. Update known-failures.md if any findings from this cycle

Rules:
- NEVER include Co-Authored-By or Claude-related text in PR body
- Use squash merge to keep history clean
- PR body in Korean (summary of changes and audit results)
