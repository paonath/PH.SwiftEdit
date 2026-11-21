# Workflow 01: Start Feature (`/my-git-flow:feature-start`)

## Purpose
Initializes a new feature branch (`feature/<name>`) from `develop`, enforces mandatory `NAME` and `DESCRIPTION` collection, increments the existing prerelease suffix counter on `develop` by `+1` (`-alpha4 -> -alpha5`, `-beta1 -> -beta2`, `-rc4 -> -rc5`) or bumps clean `{x}`/`{x.y}`/`{x.y.z}` by `+1` with `-alpha1`, and scaffolds `<spec_root>/git/feature/<name>/README.md`.

## Sequence of Operations
1. **Mandatory Start Metadata & Pre-Flight Validation**:
   - If `NAME` (`<feature-name>`) or `DESCRIPTION` (`--description`) is omitted from the user context, ask the user via `AskUserQuestion` or `qa` before invoking the script (`exit 2` if missing).
   - Verify clean working tree and attached `HEAD` (`exit 20` if dirty).
   - Validate `.myspec.config.json` and per-segment symlink confinement (`exit 3`).
2. **Parent Synchronization (`develop`)**:
   - Switch to `develop` (creating from `main`/`master` if absent) and execute `git pull --ff-only -- origin develop`.
   - Record `StartParentVersion` and `BaseCommitSHA` (`git rev-parse HEAD`).
3. **Monotonic SemVer Version Calculation**:
   - If `develop` has a prerelease suffix (`-alpha<N>`, `-beta<N>`, `-rc<N>`), increment its suffix counter by `+1` keeping the base version untouched (unless `--bump minor|major` bumps the numeric base to `-alpha1`).
   - If `develop` is clean (`{x}`, `{x.y}`, `{x.y.z}`), bump the target segment by `+1` (`patch` default, preserving segment count and NBGV `{height}`) and append `-alpha1`.
4. **Branch Creation, Manifest Write & Audit Initialization**:
   - Normalize `<name>` automatically inside Python (`normalize_branch_slug`: security pre-guards -> NFKD ASCII -> lowercase -> spaces/punctuation to `-`) before `validate_branch_slug`, then create and checkout `feature/<slug>`.
   - Create `<spec_root>/git/feature/<slug>/README.md` (`- Name: <slug>`, `Status: OPEN`, `BaseCommitSHA`, `- CurrentVersion:`, and sanitized `- Original Name:` + `## Description`).
   - Update version manifest monotonically, emit `[VERSION]` notification, and commit `"Initial commit for feature/<name>"`.

## Operational Requirements (EARS)

- WHEN starting a feature branch, the start-feature workflow SHALL synchronize `develop`, capture `StartParentVersion` and `BaseCommitSHA`, and compute the next monotonic `-alpha` or incremented prerelease version.
- IF `NAME` or `--description` is omitted from user context, THEN the start-feature workflow SHALL collect both inputs via `AskUserQuestion` or `qa` before invoking the CLI.
- WHEN `feature/<slug>` is checked out, the start-feature workflow SHALL scaffold `<spec_root>/git/feature/<slug>/README.md`, update the manifest monotonically, emit `[VERSION]`, and commit initial audit state.
