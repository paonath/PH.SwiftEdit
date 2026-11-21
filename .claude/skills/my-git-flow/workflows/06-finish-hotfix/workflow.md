# Workflow 06: Finish Hotfix (`/my-git-flow:hotfix-finish`)

## Purpose
Completes an active `hotfix/<slug>` branch by verifying branch-family alignment (`exit 2`), enforcing pre-merge monotonic verification (`expected_final > prod`, `exit 2`), reverse-merging `prod_branch`, passing Build & Test gates, stripping `-beta<N>`, merging into `prod_branch`, optionally propagating to active `release/*` branches (`--propagate-release`), merging and advancing `develop` by `+1`, deleting `hotfix/<slug>`, and creating dual annotated tags `v.{x.y.z}` and `hotfix/<slug>`.

## Sequence of Operations
1. **Branch-Family, Monotonic & Dual-Tag Pre-Flight**:
   - Abort with `exit 2` if `HEAD` is on `feature/*` or `release/*`, if `expected_final <= prod_ver` (`MONOTONIC VIOLATION`), or if tag `v.{x.y.z}` or `hotfix/<slug>` already exists.
   - Resolve `prod_branch` (`main` or `master`) and snapshot `pre_dev` on `develop` (persisted in `state.json` on conflict).
2. **Reverse-Merge `prod_branch`, Gate & Strip `-beta<N>`**:
   - Reverse-merge `prod_branch` into `hotfix/<slug>`, run Build & Test Gate, strip `-beta<N>` to `final_ver`, finalize `<spec_root>/git/hotfix/<slug>/README.md`, and merge `--no-ff refs/heads/hotfix/<slug>` into `prod_branch` (`prod_merge_sha`).
3. **Optional `release/*` Propagation (`--propagate-release`)**:
   - Enumerate `release/*` via `git for-each-ref`, merge `refs/heads/hotfix/<slug>`, and restore `release/*` manifest (bumping to `base(hotfix) + 1` keeping `-rc<N>` if `base(release) <= final_ver`, else keeping higher `release/*` untouched).
4. **Merge into `develop`, Advance `+1`, Delete Branch & Dual-Tag**:
   - Merge `refs/heads/hotfix/<slug>` into `develop`, write `post_dev = compute_post_merge_develop_version(pre_dev, final_ver)` (clean `+1` if `max` is clean, or suffix `+1` if `max` has a suffix), emit `[VERSION]`, and commit.
   - Delete `refs/heads/hotfix/<slug>` FIRST, then create annotated tags `v.{x.y.z}` and `hotfix/<slug>` on `prod_merge_sha`, and push.

## Operational Requirements (EARS)

- WHEN finishing a hotfix branch, the finish-hotfix workflow SHALL verify branch-family alignment, `expected_final > prod_ver`, and tag availability before reverse-merging `prod_branch`.
- WHERE `--propagate-release` is passed, the finish-hotfix workflow SHALL merge `hotfix/<slug>` into active `release/*` branches via `git for-each-ref` and preserve monotonic `-rc<N>` versions.
- WHEN production and `develop` merges finish, the finish-hotfix workflow SHALL advance `develop` via `compute_post_merge_develop_version`, delete `hotfix/<slug>`, create dual tags `v.{x.y.z}` and `hotfix/<slug>`, and push.
