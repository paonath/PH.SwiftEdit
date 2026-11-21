# Workflow 04: Finish Release (`/my-git-flow:release-finish`)

## Purpose
Completes an active `release/<slug>` branch by enforcing branch-family validation (`exit 2`), pre-merge monotonic verification (`expected_final > prod`, `exit 2`), reverse-merging `prod_branch` (`main` or `master`), running Build & Test gates, stripping `-rc<N>`, merging into `prod_branch` and `develop` (advancing `develop` by `+1`), deleting `release/<slug>`, and creating dual annotated tags `v.{x.y.z}` and `release/<slug>` on `prod_branch`.

## Sequence of Operations
1. **Branch-Family, Monotonic & Dual-Tag Pre-Flight**:
   - Abort with `exit 2` if `HEAD` is on `feature/*` or `hotfix/*`, if `expected_final <= prod_ver` (`MONOTONIC VIOLATION`), or if tag `v.{x.y.z}` or `release/<slug>` already exists.
   - Verify clean working tree (`exit 20`) and resolve `prod_branch` (`main` or `master`, `exit 1` on ambiguity).
2. **Reverse-Merge `prod_branch` & Build/Test Gate**:
   - Pull `prod_branch` and reverse-merge `prod_branch` into `release/<slug>` (`exit 10` + `state.json` on conflict).
   - Execute Build & Test Gate (`exit 1` on failure).
3. **Strip `-rc<N>` & Finalize Audit**:
   - Strip `-rc<N>` from the active `release/<slug>` manifest (`final_ver` is strictly clean `{x}`, `{x.y}`, or `{x.y.z}`).
   - Finalize `<spec_root>/git/release/<slug>/README.md` and commit clean manifest.
4. **Merge `prod_branch`, Merge & Advance `develop` (`+1`), Delete Branch & Dual-Tag**:
   - Merge `--no-ff refs/heads/release/<slug>` into `prod_branch` and record `prod_merge_sha`.
   - Merge `--no-ff refs/heads/release/<slug>` into `develop`, compute `post_dev = compute_post_merge_develop_version(pre_dev, final_ver)` (clean `+1` if `max` is clean, or suffix `+1` if `max` has a suffix), write manifest, emit `[VERSION]`, and commit.
   - Delete `refs/heads/release/<slug>` FIRST, then create annotated tags `v.{x.y.z}` (3-segment normalized) and `release/<slug>` on `prod_merge_sha`, and push.

## Operational Requirements (EARS)

- WHEN finishing a release branch, the finish-release workflow SHALL verify branch-family alignment, `expected_final > prod_ver`, and tag availability before reverse-merging `prod_branch`.
- WHEN Build and Test gates pass, the finish-release workflow SHALL strip `-rc<N>`, finalize `<spec_root>/git/release/<slug>/README.md`, and merge `--no-ff` into `prod_branch` and `develop`.
- WHEN both target merges complete, the finish-release workflow SHALL advance `develop` using `compute_post_merge_develop_version`, delete `release/<slug>`, tag `v.{x.y.z}` and `release/<slug>` on `prod_merge_sha`, and push.
