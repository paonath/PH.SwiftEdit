# Workflow 01: Preconditions, Base Branch Resolution & Diff Collection (`release-notes`)

## Preconditions

1. Run `git branch --show-current` and verify the branch starts with `release/` or `hotfix/`.
2. Set branch variables:
   - `release/*`: Set `$TYPE` = `release`, `$KIND_LABEL` = `Release`, target folder = `docs/releases/<version>/`, filename = `RELEASE-<version>.md`.
   - `hotfix/*`: Set `$TYPE` = `hotfix`, `$KIND_LABEL` = `Hotfix`, target folder = `docs/hotfixes/<version>/`, filename = `HOTFIX-<version>.md`.
3. Run `git status --porcelain` and warn user if uncommitted changes exist (notes reflect committed history only).

## Step 1: Base Branch Resolution

1. Run `git fetch origin --prune` (best effort; proceed if network fails).
2. Resolve base trunk in priority order: `origin/main`, `origin/master`, local `main`, local `master` (prompt user if none exist).
3. Compute divergence point: `BASE_SHA=$(git merge-base <base> HEAD)` and run `git remote get-url origin` (best effort).

## Step 2: History and Diff Collection

Run read-only collection commands:
- `git log --oneline --no-merges $BASE_SHA..HEAD`
- `git log --pretty=format:"%h|%an|%ad|%s" --date=short --no-merges $BASE_SHA..HEAD`
- `git diff --stat $BASE_SHA...HEAD`
- `git diff $BASE_SHA...HEAD` (inspect in directory chunks if diff is large)
- `git shortlog -sne $BASE_SHA..HEAD`
- `git tag --sort=-creatordate`

## Operational Requirements (EARS)

- IF the active branch returned by `git branch --show-current` matches neither `release/*` nor `hotfix/*`, THEN the preconditions-and-diff workflow SHALL stop immediately and report the active branch.
- IF `git status --porcelain` reports uncommitted changes, THEN the preconditions-and-diff workflow SHALL warn the user and request confirmation before proceeding.
- The preconditions-and-diff workflow SHALL compute `BASE_SHA` via `git merge-base` against the highest-priority resolved trunk branch and collect only read-only git history and diff data.
