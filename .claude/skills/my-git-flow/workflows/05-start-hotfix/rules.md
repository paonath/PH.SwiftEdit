# Invariants & Rules: Start Hotfix

## Core Invariants
- **Mandatory `NAME`, `DESCRIPTION` & Automatic Slug Normalization (`exit 2`)**: Require both hotfix identifier and `--description` at creation; Python normalizes explicit identifiers via `normalize_branch_slug` (security pre-guards, NFKD ASCII, lowercase, spaces/punctuation to `-`) prior to validation and records sanitized `- Original Name:` inside `## Description`.
- **Production Branch Anchor**: Hotfix branches MUST branch from `main` or `master` (resolved via Git plumbing), never from `develop`.
- **Mandatory `+1 -beta1` Progression**: Opening a hotfix MUST increment `base(prod)` by `+1` and set `-beta1` while preserving numeric segment precision and NBGV `{height}` tokens.
- **Dual-Tag Pre-Flight (`exit 2`)**: Abort before creating the branch if either `v.{x.y.z}` or `hotfix/<slug>` already exists as a tag.
- **Optional `--set-version "<ver>"`**: must be `-beta<N>` or clean (gets `-beta1`) and above production; an explicit prerelease other than `-beta<N>` is rejected.

## Formal Requirements (EARS)

- The start-hotfix rules SHALL anchor `hotfix/<slug>` exclusively from `main` or `master` and preserve NBGV `{height}` tokens while incrementing `base(prod)` by `+1` with `-beta1`.
- IF hotfix identifier or `--description` is missing, a target tag collides, or `--set-version` uses a non-`-beta` prerelease, THEN the start-hotfix rules SHALL abort with exit `2`.
- WHEN initializing audit metadata, the start-hotfix rules SHALL normalize `<slug>` via `normalize_branch_slug` and record `- Original Name:` in `<spec_root>/git/hotfix/<slug>/README.md`.
