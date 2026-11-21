# Invariants & Rules: Finish Release

## Core Invariants
- **Branch-Family, Slug Normalization & Pre-Merge Monotonic Guard (`exit 2`)**: Explicit release identifiers normalize via `normalize_branch_slug`; invoking `finish-release` on `feature/*`/`hotfix/*` or when `expected_final <= prod_ver` aborts before any Git mutation.
- **Clean Production & Dual Annotated Tags**: `main`/`master` receives only clean `{x}`, `{x.y}`, or `{x.y.z}` versions. After deleting `refs/heads/release/<slug>`, create BOTH `v.{x.y.z}` (normalized to 3 segments) and `release/<slug>` on `prod_merge_sha`.
- **Mandatory Post-Merge `develop` `+1`**: After merging into `develop`, advance `max_semver(pre_dev, final_ver)` by `+1` (clean numeric `+1` if `max` is clean, or suffix `+1` if `develop` was ahead on a prerelease like `2.0.0-alpha2 -> 2.0.0-alpha3`).
- **Zero Rollback & Resume**: `--set-version` must be clean, >= stripped branch version, > production, tag collision checked on it. `--continue` resumes from the persisted `finalized_version` and `prod_merge_sha`, completing branch deletion, dual tags, and pushes.

## Formal Requirements (EARS)

- IF `HEAD` is on `feature/*` or `hotfix/*` or `expected_final <= prod_ver`, THEN the finish-release rules SHALL abort with exit `2` before any Git mutation.
- WHEN merging into production (`main` or `master`), the finish-release rules SHALL strip `-rc<N>`, delete `refs/heads/release/<slug>` first, and apply dual annotated tags `v.{x.y.z}` and `release/<slug>` on `prod_merge_sha`.
- WHEN merging into `develop`, the finish-release rules SHALL advance `max_semver(pre_dev, final_ver)` by `+1` and support `--continue` checkpoint resumption via `finalized_version` and `prod_merge_sha`.
