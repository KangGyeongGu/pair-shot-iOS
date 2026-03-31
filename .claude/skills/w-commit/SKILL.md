---
name: w-commit
description: Create a git commit following Conventional Commits convention
---

Commit procedure:
1. git status → check changed files
2. git diff --staged (or git diff) → analyze changes
3. Compose commit message in Conventional Commits format:
   - Title: <type>(<scope>): <Korean summary>  (type/scope in English, summary in Korean)
   - Body: Korean, detailed change description in bullet points
4. git add (specific files only, never git add -A)
5. git commit

Type: feat, fix, test, refactor, chore, docs, style, perf
Scope: camera, overlay, sensor, arkit, model, compare, export, haptic, infra

Example:
```
feat(camera): AVCaptureSession 기반 라이브 프리뷰 추가

- AVCaptureSession 기반 카메라 프리뷰 구현
- 후면 카메라 기본 설정
- 세션 시작/정지 라이프사이클 관리
```

Rules:
- NEVER add Co-Authored-By, Contributed-by, or any attribution trailer
- NEVER reference Claude, AI, bot, or assistant in commit messages
- Type and scope in English, summary and body in Korean
- One commit per logical change (atomic commits)
- Present tense ("add" not "added")
- Do NOT commit .env, credentials, or sensitive files
