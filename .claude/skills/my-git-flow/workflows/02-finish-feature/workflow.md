# Workflow 02: Finish Feature (`/my-git-flow:feature-finish`)

## Purpose
Completes an active `feature/<name>` branch after verifying active branch-family alignment (`exit 2`), reverse-merging `develop` with monotonic `max_semver` reconciliation, incrementing any prerelease suffix by `+1` on the feature branch (or leaving a clean manually bumped version untouched), passing Build & Test gates, finalizing `<spec_root>/git/feature/<name>/README.md`, and merging into `develop`.

## Sequence of Operations
1. **Branch-Family Guard & Pre-Flight**:
   - Verify active branch is `feature/<name>` (or `develop` with explicit `<name>`); abort with `exit 2` if `HEAD` is on `release/*` or `hotfix/*`.
   - Verify clean working tree (`exit 20`).
2. **Pre-Closure Parent Sync & Monotonic Reverse-Merge**:
   - Checkout and pull `develop` (`--ff-only`); read `CurrentParentVersion`.
   - Checkout `feature/<name>`, record `orig_branch_ver`, and reverse-merge `develop` keeping `max_semver(ours, after, theirs)` (`exit 10` + `state.json` on non-manifest conflict).
3. **Prerelease Suffix Increment (`+1`) or Clean Retention, Dual-Baseline & Build/Test Gate**:
   - Realign against `max_semver(StartParentVersion, CurrentParentVersion)`.
   - If the realigned version carries a prerelease suffix (`-alpha<N>`, `-beta<N>`, `-rc<N>`), increment its suffix counter by `+1`, write to manifest, emit `[VERSION]`, and commit on `feature/<name>`. If it is clean (manual bump), leave it untouched.
   - Verify Dual-Baseline (`BranchVersion > CurrentParentVersion`) and run multi-stack Build & Test Gate (`exit 1` on failure).
4. **Audit Finalization & Merge into `develop`**:
   - Finalize `<spec_root>/git/feature/<name>/README.md` (migrating legacy paths lazily if pre-060).
   - Checkout `develop`, merge `--no-ff refs/heads/feature/<name>`, push `develop`, and delete `feature/<name>`.

## Operational Requirements (EARS)

- WHEN finishing a feature branch, the finish-feature workflow SHALL reverse-merge `develop` keeping `max_semver`, evaluate Dual-Baseline validity, and run the concrete Build and Test gate.
- IF reverse-merge encounters a non-manifest conflict or the Build and Test gate fails, THEN the finish-feature workflow SHALL halt with exit `10` (saving `state.json`) or exit `1` before merging into `develop`.
- WHEN Dual-Baseline and Build and Test gates pass, the finish-feature workflow SHALL finalize `<spec_root>/git/feature/<name>/README.md`, merge `--no-ff` into `develop`, push, and delete `feature/<name>`.
