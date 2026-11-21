# Workflow 05: Start Hotfix (`/my-git-flow:hotfix-start`)

## Purpose
Initializes `hotfix/<slug>` directly from `prod_branch` (`main` or `master` detected via plumbing), enforces mandatory `NAME` and `DESCRIPTION` collection, checks dual-tag collisions (`v.{x.y.z}` and `hotfix/<slug>`), increments `base(prod_branch)` by `+1` (`--bump patch|minor|major`, `patch` default) with mandatory suffix `-beta1`, and scaffolds `<spec_root>/git/hotfix/<slug>/README.md`.

## Sequence of Operations
1. **Mandatory Start Metadata, Pre-Flight & Plumbing Production Detection**:
   - If `NAME` (version or slug) or `DESCRIPTION` (`--description`) is omitted from the user context, ask the user before invoking the script (`exit 2` if missing).
   - Verify clean working tree (`exit 20`) and resolve `prod_branch` (`main` or `master`) via `git show-ref --verify --quiet --` (`exit 1` if neither or both exist).
2. **Mandatory `+1 -beta1` Calculation & Dual-Tag Collision Check**:
   - Checkout and pull `prod_branch`; read `prod_ver` and `BaseCommitSHA`.
   - Compute `manifest_ver = bump(base(prod_ver), --bump) + "-beta1"` (or validate explicit `<version> > base(prod_ver)` and attach `-beta1` if clean).
   - Verify neither `v.{x.y.z}` nor `hotfix/<slug>` exists in `refs/tags/*` (`exit 2` on collision).
3. **Branch Creation, Manifest Write & Audit Initialization**:
   - Normalize explicit `<version>`/`<slug>` inside Python (`normalize_branch_slug`), checkout `hotfix/<slug>`, create `<spec_root>/git/hotfix/<slug>/README.md` (`- Name: <slug>`, `BaseCommitSHA`, `- CurrentVersion:`, and sanitized `- Original Name:` when supplied in `## Description`), write `manifest_ver`, emit `[VERSION]`, and commit `"Initial commit for hotfix/<slug>"`.

## Operational Requirements (EARS)

- WHEN starting a hotfix branch, the start-hotfix workflow SHALL resolve `prod_branch` via Git plumbing and compute `base(prod_ver)` bumped by `+1` with `-beta1`.
- IF `NAME` or `--description` is missing or either `v.{x.y.z}` or `hotfix/<slug>` already exists, THEN the start-hotfix workflow SHALL abort with exit `2`.
- WHEN preconditions pass, the start-hotfix workflow SHALL create `hotfix/<slug>` from `prod_branch`, scaffold `<spec_root>/git/hotfix/<slug>/README.md`, write the manifest, emit `[VERSION]`, and commit.
