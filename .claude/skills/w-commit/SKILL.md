---
name: w-commit
description: Create a git commit following Conventional Commits convention
---

Commit procedure:
1. git status → check changed files
2. git diff --staged (or git diff) → analyze changes
3. Compose commit message in Conventional Commits format:
   - Title: English, <type>(<scope>): <summary>
   - Body: Korean, detailed change description in bullet points
4. git add (specific files only, never git add -A)
5. git commit

Type: feat, fix, test, refactor, chore, docs, style, perf
Scope: camera, overlay, sensor, arkit, model, compare, export, haptic, infra

Example:
```
feat(camera): add live preview with AVCaptureSession

- AVCaptureSession 기반 카메라 프리뷰 구현
- 후면 카메라 기본 설정
- 세션 시작/정지 라이프사이클 관리
```

Rules:
- NEVER add Co-Authored-By, Contributed-by, or any attribution trailer
- NEVER reference Claude, AI, bot, or assistant in commit messages
- Title in English, body in Korean
- One commit per logical change (atomic commits)
- Present tense ("add" not "added")
- Do NOT commit .env, credentials, or sensitive files
