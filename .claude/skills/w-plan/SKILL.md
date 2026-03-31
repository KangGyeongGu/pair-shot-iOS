---
name: w-plan
description: Plan a development phase - research and decompose work items
---

Plan workflow:
1. Read .claude/status.json → state must be "idle"
2. Read .claude/pipeline.json → current phase info (features, depends_on)
3. Read .claude/specs/F{XX}.md → feature specs for this phase
4. Read .claude/known-failures.md → past failure patterns (if any)
5. Spawn researcher agent → investigate current codebase → .claude/cycles/current/research-report.json
6. Orchestrator: decompose into work items → .claude/cycles/current/plan.md
   - Per work item: objective, owned_paths, acceptance_criteria, test_scope
7. Update status.json: state → "developing"

Plan.md format:
```
# Phase {N}: {name}
## Work Items
### W1: {title}
- Objective: ...
- Owned Paths: PairShot/...
- Acceptance Criteria: [...]
- Test Scope: [...]
- Spec Reference: .claude/specs/F{XX}.md
```
