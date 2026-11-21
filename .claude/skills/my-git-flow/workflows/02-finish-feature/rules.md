# Invariants & Rules: Finish Feature

## Core Invariants
- **Branch-Family Mismatch Guard & Automatic Slug Normalization (`exit 2`)**: Running `finish-feature` while checked out on `release/*` or `hotfix/*` aborts before any Git mutation; any explicit `<name>` passed to `finish-feature` is automatically normalized via `normalize_branch_slug` before matching the active branch.
- **Suffix `+1` on Close vs. Clean Manual Retention**: If the feature version has a prerelease suffix (`-alpha<N>`, `-beta<N>`, `-rc<N>`), increment the suffix by `+1` and commit on the feature branch before merging; if the developer manually set a clean higher version (`1.1.0`), leave it untouched.
- **Monotonic Merge Reconciliation**: Reverse-merging `develop` into `feature/<name>` always reconciles the manifest to `max_semver` so manual version bumps are never downgraded.
- **Zero Tags**: Feature branches NEVER create Git tags.
- **Lazy Legacy Audit Migration**: Pre-060 `<spec_root>/feature/<name>/README.md` migrates atomically to `<spec_root>/git/feature/<name>/README.md` (`exit 3` if both exist).
- **Zero Rollback**: the suffix decision uses the persisted pre-reverse-merge version (`orig_branch_version`) so a clean `develop` is never taken for a manual bump; the result is never below the on-disk version. `--set-version` must be >= branch and > `develop`. `StartParentVersion` is derived from `git show <BaseCommitSHA>` (non-ancestor SHA = `exit 1`).

## Formal Requirements (EARS)

- IF `HEAD` is on `release/*` or `hotfix/*`, THEN the finish-feature rules SHALL abort execution with exit `2` before any Git mutation.
- WHILE reverse-merging `develop` into `feature/<name>`, the finish-feature rules SHALL reconcile manifest versions to `max_semver` and derive `StartParentVersion` from `git show <BaseCommitSHA>`.
- The finish-feature rules SHALL enforce Zero Rollback across `orig_branch_version`, `--set-version`, and manifest updates while creating zero Git tags.
