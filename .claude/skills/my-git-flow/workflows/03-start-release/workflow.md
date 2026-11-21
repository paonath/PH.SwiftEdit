# Workflow 03: Start Release (`/my-git-flow:release-start`)

## Purpose
Initializes `release/<slug>` from `develop` after enforcing mandatory `NAME` and `DESCRIPTION` collection, resolving production (`main` or `master`) via plumbing, enforcing the `base(develop) > base(prod)` gate (`exit 2`), checking dual-tag collisions (`v.{x.y.z}` and `release/<slug>`), and applying the SemVer 2.0.0 `-rc` transition.

## Sequence of Operations
1. **Mandatory Start Metadata, Pre-Flight & Production Detection**:
   - If `NAME` (version or slug) or `DESCRIPTION` (`--description`) is omitted from the user context, ask the user before invoking the script (`exit 2` if missing).
   - Verify clean working tree (`exit 20`) and resolve `prod_branch` (`main` or `master`) via `git show-ref --verify --quiet --` (`exit 1` if neither or both exist).
2. **`StartRelease` Baseline Gate & `-rc` Calculation**:
   - Read `prod_ver` on `prod_branch` and `dev_ver`, `dev_sha` on `develop`.
   - If `base(dev_ver) <= base(prod_ver)` without an explicit higher version, abort (`exit 2`).
   - If `develop` already has `-rc<N>`, increment to `-rc<N+1>`; if `-alpha<N>` or `-beta<N>`, transition to `<base>-rc1`; if `develop` is clean (`> prod`), bump numeric base `+1` + `-rc1` and emit `WARNING [CLEAN_DEVELOP_BUMPED_FOR_RC]` (persisted in `README.md`).
3. **Dual-Tag Collision Check, Branch Creation & Audit Initialization**:
   - Verify neither `v.{x.y.z}` nor `release/<slug>` exists in `refs/tags/*` (`exit 2` on collision).
   - Normalize explicit `<version>`/`<slug>` inside Python (`normalize_branch_slug`), checkout `release/<slug>`, create `<spec_root>/git/release/<slug>/README.md` (`- Name: <slug>`, `BaseCommitSHA = dev_sha`, `- CurrentVersion:`, and sanitized `- Original Name:` when supplied in `## Description`), write manifest, emit `[VERSION]`, and commit.

## Operational Requirements (EARS)

- WHEN starting a release branch, the start-release workflow SHALL resolve `prod_branch` via Git plumbing, validate `base(dev_ver) > base(prod_ver)`, and verify zero dual-tag collisions.
- IF `base(dev_ver) <= base(prod_ver)` without an explicit override or a target tag already exists, THEN the start-release workflow SHALL abort with exit `2`.
- WHEN preconditions pass, the start-release workflow SHALL apply the deterministic `-rc` transition, create `release/<slug>`, scaffold `<spec_root>/git/release/<slug>/README.md`, emit `[VERSION]`, and commit.
