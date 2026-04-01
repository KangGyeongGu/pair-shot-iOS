---
name: w-plan
description: Plan a development phase - research and decompose work items
---

Plan workflow:
1. Read .claude/status.json → state must be "idle"
2. Read .claude/pipeline.json → current phase info (features, depends_on)
3. Read .claude/specs/F{XX}.md → feature specs for this phase
4. Read Apple SDK headers listed in each spec's "Apple SDK References" section
5. Read .claude/known-failures.md → past failure patterns (if any)
6. Spawn researcher agent → investigate codebase + SDK APIs → .claude/cycles/current/research-report.json
7. Orchestrator: decompose into work items → .claude/cycles/current/plan.md
   - Per work item: objective, owned_paths, acceptance_criteria, test_scope, required_sdk_headers
8. Update status.json: state → "developing"

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
- SDK Headers: .claude/apple-sdk-refs/AVFoundation/AVCaptureDevice.h, ...
```
