# Invariants & Rules: Start Release

## Core Invariants
- **Mandatory `NAME`, `DESCRIPTION` & Automatic Slug Normalization (`exit 2`)**: Require both release identifier and `--description` at creation; Python normalizes explicit identifiers via `normalize_branch_slug` (security pre-guards, NFKD ASCII, lowercase, spaces/punctuation to `-`) prior to validation and records sanitized `- Original Name:` inside `## Description`.
- **Deterministic `-rc` Transition**: `-rc<N>` on `develop` increments to `-rc<N+1>`; `-alpha<N>`/`-beta<N>` becomes `-rc1` on the same base; clean `develop > prod` bumps `+1-rc1` with `WARNING [CLEAN_DEVELOP_BUMPED_FOR_RC]` to prevent SemVer downgrade (`1.2.0 -> 1.2.0-rc1` is forbidden).
- **Dual-Tag Pre-Flight (`exit 2`)**: Abort before creating the branch if either `v.{x.y.z}` or `release/<slug>` already exists as a tag.
- **Accurate Provenance**: Record `develop`'s HEAD SHA as `BaseCommitSHA` and `dev_ver` as `StartParentVersion` in `<spec_root>/git/release/<slug>/README.md`.
- **Optional `--set-version "<ver>"`**: must be `-rc<N>` or clean (gets `-rc1`), above `develop` and its base above production; `--version` remains the slug.

## Formal Requirements (EARS)

- IF release identifier or `--description` is missing, `base(develop) <= base(prod)`, or either `v.{x.y.z}` or `release/<slug>` exists, THEN the start-release rules SHALL abort with exit `2`.
- WHEN `develop` carries a clean version above production, the start-release rules SHALL increment the numeric base by `+1` with `-rc1` and emit `WARNING [CLEAN_DEVELOP_BUMPED_FOR_RC]`.
- WHERE `--set-version "<ver>"` is provided, the start-release rules SHALL require a clean or `-rc<N>` version strictly above `develop` with base above production and preserve `- Original Name:` in `README.md`.
