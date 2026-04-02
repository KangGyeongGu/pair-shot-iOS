---
name: w-plan
description: Plan a development phase - research and decompose work items
---

Plan workflow:
1. Read .claude/status.json → state must be "idle"
2. Read .claude/pipeline.json → current phase info (features, depends_on)
3. Read .claude/specs/F{XX}.md → feature specs for this phase
4. Read Apple SDK headers listed in each spec's "Apple SDK References" section
5. Read .claude/known-failures.md → past failure patterns
6. Spawn researcher agent → investigate codebase + SDK APIs → research-report
7. Orchestrator: decompose into work items with dependency analysis

Work item decomposition rules:
- Identify owned_paths (files to create/modify) for each work item
- Analyze file overlap between work items:
  - Same file modified by multiple items → MUST be sequential
  - No file overlap → CAN be parallel
- Mark execution order explicitly: sequential dependencies and parallel groups
- Each work item must be independently committable (buildable after commit)
- Smaller, focused work items preferred over large multi-file items

8. Write .claude/cycles/current/plan.md
9. Update status.json: state → "developing"

Plan.md format:
```
# Phase {N}: {name}

## Work Items

### W1: {title}
- Objective: ...
- Owned Paths: PairShot/PairShot/Services/NewService.swift (NEW), PairShot/PairShot/Views/Camera/CameraView.swift (MODIFY)
- Acceptance Criteria: [concrete, verifiable conditions]
- Test Scope: [what to unit test]
- Spec Reference: .claude/specs/F{XX}.md
- SDK Headers: .claude/apple-sdk-refs/...

## Execution Order
W1 → W2 (sequential: both modify CameraView.swift)
W3 ∥ W4 (parallel: no file overlap)
(W3, W4) → W5 (sequential: W5 depends on W3+W4 outputs)
W6 (test: after all implementation)

## File Dependency Matrix
| Work Item | Creates | Modifies |
|-----------|---------|----------|
| W1 | NewService.swift | — |
| W2 | — | CameraView.swift |
| W3 | GuideView.swift | CameraView.swift |
→ W2, W3 must be sequential (both modify CameraView.swift)
```
