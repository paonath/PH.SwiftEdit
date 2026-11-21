# Invariants & Rules: Start Feature

## Core Invariants
- **Mandatory `NAME`, `DESCRIPTION` & Automatic Slug Normalization (`exit 2`)**: Never start a feature without both `NAME` and a non-empty `--description`. Python automatically normalizes `NAME` via `normalize_branch_slug` (CWE-78/CWE-22 pre-guards, NFKD ASCII, lowercase, spaces/punctuation to `-`) before validating `\A[a-z0-9][a-z0-9_.-]{0,99}\Z`, and records sanitized `- Original Name:` inside `## Description` of `README.md`.
- **Clean Working Tree Mandatory**: Never start a feature when modified or untracked files exist (`exit 20`).
- **Suffix Increment on Prerelease `develop`**: When `develop` carries `-alpha<N>`, `-beta<N>`, or `-rc<N>`, increment the existing suffix counter by `+1` (`-alpha4 -> -alpha5`, `-beta1 -> -beta2`, `-rc4 -> -rc5`); when `develop` is clean (`{x}`, `{x.y}`, `{x.y.z}`), increment the numeric segment by `+1` and append `-alpha1`.
- **Granularity & NBGV `{height}` Immutability**: Preserve `1`, `2`, or `3` numeric segments and never remove or replace NBGV `{height}` tokens (`1.2.{height}` -> `1.3.{height}-alpha1`).
- **Canonical Audit Namespace**: Write `<spec_root>/git/feature/<name>/README.md` without modifying `<spec_root>/index.yml`.
- **Optional `--set-version "<ver>"`**: must be strictly above `develop`; shape-mapped so NBGV `{height}` is kept; README `- CurrentVersion:` is written with the new branch version.

## Formal Requirements (EARS)

- IF `NAME` or `--description` is empty or the working tree is dirty, THEN the start-feature rules SHALL reject execution with exit `2` or `20`.
- The start-feature rules SHALL normalize feature identifiers with `normalize_branch_slug`, retain NBGV `{height}` tokens, and record sanitized `- Original Name:` in `<spec_root>/git/feature/<name>/README.md`.
- WHERE `--set-version "<ver>"` is supplied, the start-feature rules SHALL enforce a version strictly above `develop` without altering `<spec_root>/index.yml`.
