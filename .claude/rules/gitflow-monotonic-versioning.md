---
description: "my-git-flow versioning invariants - versions only ever increase, additive overrides, single CurrentVersion audit line, concrete stack isolation"
paths:
  - "**/my-git-flow/**"
---

## Zero-Rollback Versioning (absolute)

- No my-git-flow command (`start-*`, `finish-*`, `--continue`), merge reconciliation, override, or checkpoint resume may EVER lower a version, numerically or from a clean `X.Y.Z` back to a prerelease of it (`X.Y.Z-rc1 < X.Y.Z`).
- Every manifest write enforces `compare_semver(new, current) >= 0` (`exit 2`, `MONOTONIC VIOLATION`); merges keep `max_semver(ours, after, theirs)`.
- A version raised manually on a `feature/*`, `release/*`, `hotfix/*`, or `develop` branch is always honored and continued from, never recomputed downward.

## Additive Overrides

- The developer may raise the version at any moment by editing the manifest or passing `--set-version "<ver>"` (all 6 commands). `--version` stays the branch slug alias.
- Bounds: `start-*` strictly above the parent; `finish-feature` at least the branch and above `develop`; `finish-release`/`finish-hotfix` clean, at least the stripped branch version and above production, tag collision checked on the overridden tag.
- Overrides never replace NBGV `{height}`; they only set the segments before it.

## Audit Trail

- The lifecycle `README.md` under `<spec_root>/git/<type>/<id>/` records only the single current version: one in-place `- CurrentVersion: <ver>` line, resynced on every command. No version history lines.
- `StartParentVersion` is derived from `git show <BaseCommitSHA>:<manifest>` (ancestor-verified), never read from the README.

## Concrete Stack Isolation

- Build/test gates run only stacks with concrete targets: `.NET` needs `.sln`/`.slnx`/`.csproj` (`Directory.Build.props` alone never counts); `Python` needs `test_*.py`/`*_test.py`; `Node` needs a real `build` or `test` script; `Shell` needs `*.bats`.
- Dot-directories and build output are never scanned.
