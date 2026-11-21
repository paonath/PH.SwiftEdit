# Invariants & Rules: Finish Hotfix

## Core Invariants
- **Branch-Family, Slug Normalization & Pre-Merge Monotonic Guard (`exit 2`)**: Explicit hotfix identifiers normalize via `normalize_branch_slug`; invoking `finish-hotfix` on `feature/*`/`release/*` or when `expected_final <= prod_ver` aborts before Git mutations.
- **Clean Production & Dual Annotated Tags**: After deleting `refs/heads/hotfix/<slug>`, create BOTH `v.{x.y.z}` (normalized to 3 segments) and `hotfix/<slug>` on `prod_merge_sha`.
- **Mandatory Post-Merge `develop` `+1`**: After merging into `develop`, advance `max_semver(pre_dev, final_ver)` by `+1` (clean numeric `+1` if `max` is clean, or suffix `+1` if `develop` was ahead on a prerelease like `2.0.0-alpha2 -> 2.0.0-alpha3`).
- **Deterministic `release/*` Propagation**: Active `release/* <= hotfix` bumps to `hotfix + 1` retaining its existing `-rc<N>` counter; higher `release/*` stays untouched.
- **Zero Rollback & Resume**: `--set-version` must be clean and > production; propagated `release/*` keep their `-rc<N>` and their README `CurrentVersion` is resynced. `--continue` resumes from persisted `finalized_version`/`prod_merge_sha`.

## Formal Requirements (EARS)

- IF `HEAD` is on `feature/*` or `release/*` or `expected_final <= prod_ver`, THEN the finish-hotfix rules SHALL abort with exit `2` before any Git mutation.
- WHERE active `release/*` branches exist during `--propagate-release`, the finish-hotfix rules SHALL bump releases at or below `hotfix` to `hotfix + 1` preserving `-rc<N>` and resync their README `CurrentVersion`.
- WHEN production and `develop` merges finish, the finish-hotfix rules SHALL delete `refs/heads/hotfix/<slug>`, advance `develop` by `+1` on `max_semver(pre_dev, final_ver)`, and create dual tags `v.{x.y.z}` and `hotfix/<slug>` on `prod_merge_sha`.
