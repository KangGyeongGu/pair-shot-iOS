# v<MAJOR.MINOR.PATCH> — YYYY-MM-DD

**Build**: <CFBundleVersion>
**Range**: <prev-tag>...<this-tag>
**Compare**: https://github.com/KangGyeongGu/<repo>/compare/<prev-tag>...v<MAJOR.MINOR.PATCH>

---

## Highlights

<2~3 줄로 이번 릴리즈의 핵심을 요약. 사용자에게 가장 중요한 변화 1~3 개.>

---

## Added

<신규 기능. `feat` commit 기반. 사용자 입장에서 무엇이 새로 가능해졌는지.>

- <설명> (`<scope>`)

## Changed

<기존 기능의 동작 변경. 사용자가 체감하는 변화.>

- <설명> (`<scope>`)

## Fixed

<버그 수정. `fix` commit 기반.>

- <설명> (`<scope>`)

## Removed

<기능 제거. breaking 일 경우 별도 언급 필수.>

- <설명> (`<scope>`)

## Internal

<사용자 비가시 변경. `chore` / `refactor` / `perf` / `build` / `test` commit 기반. 한 줄 요약만.>

- <설명> (`<scope>`)

---

## Compatibility

- **iOS**: 17.0+
- **Device**: iPhone (Portrait only)
- **Data migration**: <없음 / SchemaV<n> → SchemaV<n+1> 자동 / 마이그레이션 테스트 통과>

## Known Issues

<있다면 1~3건 기록. 없으면 "None">

---

## Commits

<git log <prev>..HEAD --format='- %h %s' 결과를 그대로 붙임. cut-release 스킬이 자동 채움.>

- <short-sha> <subject>
- ...
