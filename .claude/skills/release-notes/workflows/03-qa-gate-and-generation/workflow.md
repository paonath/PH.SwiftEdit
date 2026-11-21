# Workflow 03: Blocking Human QA Gate & Document Generation (`release-notes`)

## Step 6: Human QA Gate

**BLOCKING**: Present summary and wait for user confirmation before creating files:
- Branch type (`$KIND_LABEL`), detected versioning strategy, proposed version (e.g., `v2.1.0` or `v2.0.1`), proposed title/name, highlights list (3-6 bullets), and hotfix feature anomaly warning (if new features were detected on hotfix).

## Step 7: Document Generation

1. Resolve target path: `docs/releases/<version>/RELEASE-<version>.md` (release) or `docs/hotfixes/<version>/HOTFIX-<version>.md` (hotfix).
2. Run `git check-ignore -v <target-path>` and verify overwrite confirmation if the file exists.
3. Format document using plain Markdown (no raw HTML, badges, details tags, or images), omitting empty category sections except **Breaking Changes & Migration Notes**:

```markdown
# <KIND_LABEL> <version> — <confirmed name>

**Branch:** `<release|hotfix>/<name>` -> `<base>`
**Date:** <YYYY-MM-DD>
**Versioning:** <detected strategy>
**Commits:** <N> · **Files changed:** <N> (+<added>/-<removed> lines)
**Contributors:** <name1, name2, ...>

## Summary
<3-5 plain-English sentences. Release: business value and delivery. Hotfix: incident details, impact, and fix confirmation.>

## Highlights
- <3-6 items, 1 line each; benefit-first for release / impact-first for hotfix>

## What's New

### New Features
- <description> (`<short-sha>`)

### Bug Fixes
- <description> (`<short-sha>`)

### Improvements
- <description> (`<short-sha>`)

### Breaking Changes & Migration Notes
- <description + required action> (or "No breaking changes in this release.")

### Documentation
- <description>

### Internal / Technical
- <description>

## Full Diff
`<base>...<branch>` — compare: https://github.com/<owner>/<repo>/compare/<base>...<branch>
```

## Operational Requirements (EARS)

- WHILE awaiting Step 6 Human QA Gate confirmation, the qa-gate-and-generation workflow SHALL block file creation until the user confirms or overrides version and title.
- IF `git check-ignore -v <target-path>` matches an ignore rule, THEN the qa-gate-and-generation workflow SHALL stop immediately without writing the file.
- IF the target release or hotfix notes file already exists, THEN the qa-gate-and-generation workflow SHALL prompt the user before overwriting it.
