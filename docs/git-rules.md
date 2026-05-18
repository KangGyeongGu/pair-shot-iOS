# PairShot iOS Git 운영 규칙

이 문서는 PairShot iOS 프로젝트의 git 브랜치 · 태그 · 릴리즈 운영 표준을 정의합니다. 모든 인간 협업자와 AI 에이전트가 이 규칙을 따라 작업합니다.

---

## 1. 브랜치 전략

### 핵심 모델 — 단일 라인 (`release/v1.x`)

```
feature/<scope>/<name>
   │ push
   │ gh pr create --base release/v1.x
   ▼
PR ─ CI 통과 ─ 머지 ─► release/v1.x  (모든 새 commit 의 통합 지점)
                          │
                          │ ff only
                          ▼
                        main  (현재 버전의 미러)
```

- **`release/v1.x`** = v1.x 라인의 통합 브랜치. 새 commit 은 모두 여기로 PR 머지됨.
- **`main`** = `release/v1.x` 의 미러. fast-forward 만 받음. 직접 push 금지.
- **`feature/<scope>/<name>`** = 작업 브랜치. 머지 후 즉시 삭제.
- **`develop` 은 사용하지 않음.** 첫 출시 시점에 모든 잔존 develop 브랜치 (로컬 + origin) 폐기.

### 브랜치 명명

| 종류 | 패턴 | 예시 |
|---|---|---|
| 첫 출시 전 MVP 빌드업 | `feature/ios-mvp/<NN-phase-name>` | `feature/ios-mvp/p3-camera-ui` |
| 일반 기능 | `feature/<short-topic>` | `feature/before-overlay-alpha-slider` |
| 버그 수정 | `fix/<short-topic>` | `fix/swiftdata-migration-crash` |
| 출시 후 핫픽스 | `hotfix/v<patch>/<short-topic>` | `hotfix/v1.0.1/ad-free-race` |
| 리팩토링 | `refactor/<short-topic>` | `refactor/camera-session-actor` |
| 인프라·설정 | `chore/<short-topic>` | `chore/swiftlint-rule-update` |

핫픽스는 `release/v1.x` 에서 분기, 일반 `fix/*` 와 구분해 추적 가능하도록 별도 네임스페이스를 둠.

### PR target 규칙

**모든 시점에서 `release/v1.x` 가 유일한 머지 타겟.**

- `--base main` 으로 PR 만들지 말 것. 어떤 경우에도 안 함.
- `--base develop` 도 안 됨 (develop 폐기).
- 첫 출시 전이라도 `release/v1.x` 를 먼저 만들고 거기로 PR.

### 첫 출시 시점의 `release/v1.x` 생성

첫 출시 직전 1회만:

```bash
git checkout <현재 작업 브랜치>
git checkout -b release/v1.x
git push -u origin release/v1.x
```

이후 모든 PR target = `release/v1.x`. 기존 `develop` 브랜치는 로컬·origin 모두 삭제.

### 정리

PR 머지 후 source 브랜치 즉시 삭제 — GitHub UI "Delete branch" 또는:
```bash
git branch -d <branch>
git push origin --delete <branch>
```

---

## 2. 태그 운용

### 형식

`v<major>.<minor>.<patch>` — Semantic Versioning. 예: `v1.0.0`, `v1.1.0`, `v1.0.1`.

bump 기준:
- `MAJOR` — 사용자 경험 / 데이터 호환성에 breaking 변경
- `MINOR` — `feat` 신기능 추가, 기존 동작 보존
- `PATCH` — `fix` 버그 수정, 기존 동작 보존

### 언제 만드나

`/cut-release` 스킬 (§4) 의 마지막 단계에서 release notes commit 에 annotated tag 자동 생성. 사람·AI 가 수동으로 태깅하지 않음.

### 불변성

- 태그는 한 번 생성 후 **절대 이동·삭제·덮어쓰기 금지**
- 핫픽스 필요 시 다음 패치 버전 (예: `v1.0.0` → `v1.0.1`) 으로 진행
- iOS 의 build number (`CFBundleVersion`) 는 별개 — 같은 `v1.0.0` 이라도 빌드 재업로드 시 build number 증가

### Push

```bash
git push origin v<version>
```

태그 push 도 사용자 명시 지시 후에만.

---

## 3. 릴리즈 노트 운용

### 위치

`docs/releases/v<version>.md` — git 추적.

새 릴리즈 작성 시 `docs/releases/_template.md` 복사 후 채움. `/cut-release` 스킬이 자동으로 초안 생성.

### 양식

`docs/releases/_template.md` 참조 — Keep a Changelog 1.1.0 + Conventional Commits 분류 기반. 섹션:

- `Added` — `feat`
- `Changed` — 기능 변경 / `refactor` 중 사용자 가시
- `Fixed` — `fix`
- `Removed` — 기능 제거
- `Internal` — `chore` / `refactor` 내부 / `perf` / `build` / `test`

### GitHub Release 등록

```bash
gh release create v<version> \
  --title "v<version>" \
  --notes-file docs/releases/v<version>.md \
  --latest
```

- `--latest` — "Latest" 배지 (가장 최근 출시 1개)
- `--notes-file` — `docs/releases/v<version>.md` 본문이 그대로 release body

### README 표 갱신

`README.md` 의 "출시 이력" 표 맨 위에 한 줄 추가:

```markdown
| v1.0.0 | 2026-MM-DD | 1 | <한 줄 요약> | [→](docs/releases/v1.0.0.md) |
```

---

## 4. 새 버전 릴리즈 절차

### 4.1 일상 작업 흐름

1. `release/v1.x` 에서 feature 브랜치 분기:
   ```bash
   git checkout release/v1.x
   git pull
   git checkout -b feature/<scope>/<name>
   ```

2. 작업 + commit (Korean Conventional Commits, no Co-authored-by):
   ```
   feat(scope): "한국어 설명"
   fix(scope): "한국어 설명"
   refactor(scope): "한국어 설명"
   ```
   타입: `feat` `fix` `chore` `refactor` `docs` `test` `perf` 7종만 허용.

3. push 후 PR 생성:
   ```bash
   git push -u origin feature/<scope>/<name>
   gh pr create --base release/v1.x --head feature/<scope>/<name>
   ```

4. 로컬 검증 (`/verify-static` + 필요 시 `/verify-dynamic`) 통과 확인 후 머지 (GitHub UI).

5. 로컬 정리:
   ```bash
   git checkout release/v1.x
   git pull
   git branch -d feature/<scope>/<name>
   git push origin --delete feature/<scope>/<name>
   ```

### 4.2 새 버전 릴리즈 — `/cut-release` 스킬 단일 진입

복수 feature 가 `release/v1.x` 에 누적되어 새 버전을 출시할 시점, `/cut-release` 스킬을 호출하면 아래 표의 단계를 순차 자동 실행. 첫 실패에서 중단.

| 단계 | 카테고리 | 도구·스킬 |
|---|---|---|
| 1 | Git preflight (working tree clean / Conventional Commits / Co-authored-by 0건 / 이전 태그 존재) | `Bash(git *)` |
| 2 | 정적 검증 | `/verify-static` |
| 3 | 동적 검증 | `/verify-dynamic` |
| 4 | 배포 정합 검증 | `/verify-release` |
| 5 | `docs/releases/v<version>.md` 초안 생성 | `git log` 분석 |
| 6 | `README.md` 출시 이력 표 갱신 | Edit |
| 7 | 사용자 검토 대기 | (수동 승인) |
| 8 | Commit (`docs(release): v<version>`) + annotated tag `v<version>` | `Bash(git *)` |
| 9 | push / PR / GitHub Release 명령 안내 | (스킬은 실행 안 함) |

자세한 단계 정의는 `.claude/skills/cut-release/SKILL.md` 참조.

### 4.3 출시 단계 (사용자 명시 지시 후)

`/cut-release` 가 step 9 에서 안내하는 명령을 사용자가 직접 실행:

```bash
# 1. push (작업 브랜치 + tag)
git push origin feature/<scope>/<name>
git push origin v<version>

# 2. PR (feature → release/v1.x) 생성, 로컬 검증 통과 후 머지 (GitHub UI)

# 3. main ff
git checkout main
git pull
git merge --ff-only origin/release/v1.x
git push origin main

# 4. GitHub Release 등록
gh release create v<version> --title "v<version>" \
  --notes-file docs/releases/v<version>.md --latest
```

이후 App Store Connect 측 절차 (Archive, TestFlight, 심사 제출, phased release) 는 사용자가 별도 진행. 이 문서에서는 다루지 않음.

---

## 5. 검증 — 로컬 전용 (CI 미운용)

GitHub Actions 등 CI 는 운용하지 않음. 모든 검증은 로컬에서 스킬을 호출해 수행하고, 통과한 결과를 신뢰해 PR 머지.

| 시점 | 스킬 | 내용 |
|---|---|---|
| feature 작업 중 (저장 후 자동) | post-edit hook | `swiftformat` + `swiftlint --fix` |
| feature 완료 직전 | `/verify-static` | SwiftFormat lint + SwiftLint strict + Periphery + xcodebuild analyze |
| 큰 리팩토링·동작 변경 후 | `/verify-dynamic` | SwiftData 마이그레이션 + ASan/TSan + Coverage + Instruments + 수동 시나리오 |
| 새 버전 출시 직전 1회 | `/cut-release v<x.y.z>` | git preflight + verify-static + verify-dynamic + verify-release + 릴리즈 노트 + tag |

### Branch Protection (GitHub UI 권장)

Settings → Branches → `main`, `release/v1.x`:
- Require pull request before merging
- Restrict direct push

(상태 검사 require 는 CI 가 없으므로 적용 안 함.)

---

## 6. 핫픽스 절차

이미 출시된 `v1.x.y` 에서 긴급 수정 필요 시:

1. `release/v1.x` 에서 핫픽스 브랜치 분기:
   ```bash
   git checkout release/v1.x
   git pull
   git checkout -b hotfix/v1.x.(y+1)/<short-topic>
   ```

2. 수정 + commit + push + PR (target = `release/v1.x`).

3. CI 통과 → 머지.

4. `/cut-release v1.x.(y+1)` 호출 → release notes + tag → push → GitHub Release.

5. App Store 심사 시 critical hotfix 의 경우 expedited review 신청 (App Store Connect → Resolution Center).

---

## 7. SwiftData 마이그레이션 검증

`/verify-dynamic` 스킬의 단계 1 이 `PairShotTests/MigrationVerification` XCTest 를 실행. SwiftData `@Model` 의 필드 추가 / 삭제 / nullable 변경 / 타입 변경 시 마이그레이션 케이스 추가 필수.

자동 마이그레이션이 안 되는 경우 `SchemaMigrationPlan` 의 `MigrationStage` 작성.

---

## 8. 절대 하지 말아야 할 것

- ❌ `main` 또는 `release/v1.x` 직접 push
- ❌ `--base main` PR
- ❌ `develop` 브랜치 부활
- ❌ 태그 이동·삭제·덮어쓰기 (`git tag -f`, `git tag -d` + 재생성)
- ❌ Force push to `main` / `release/v1.x` / 머지된 feature
- ❌ Co-authored-by 트레일러를 commit 메시지에 포함
- ❌ `--no-verify` 로 hook 우회
- ❌ 사용자 명시 지시 전 push / merge / GitHub Release 생성
- ❌ `/cut-release` step 7 의 검토 단계 건너뛰고 commit + tag

---

## 9. 참고 메모리·문서

- `CLAUDE.md` — iOS 빌드/테스트 명령, commit policy, 검증 cadence
- `docs/releases/_template.md` — 릴리즈 노트 양식
- `docs/project-docs/` — 기능 명세 6종 (overview / screens / data-model / capture-and-export / ads-and-coupon / architecture)
- `.claude/skills/cut-release/SKILL.md` — 릴리즈 게이트 스킬 상세
- `.claude/skills/verify-static/SKILL.md` — 정적 검증
- `.claude/skills/verify-dynamic/SKILL.md` — 동적 검증
- `.claude/skills/verify-release/SKILL.md` — 배포 정합 검증
- `.claude/skills/lint-fix/SKILL.md` — 작업 중 자동 수정
- `~/.claude/projects/-Users-kkk-Documents-projects-pairshot/memory/` — 프로젝트 메모리
