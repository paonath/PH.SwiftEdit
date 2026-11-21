---
name: my-git-flow
description: >-
  HUMAN-ONLY TRIGGER — DO NOT AUTONOMOUSLY INVOKE. Orchestrates the 6 GitFlow lifecycles
  (StartFeature, FinishFeature, StartRelease, FinishRelease, StartHotfix, FinishHotfix)
  with strictly monotonic SemVer 2.0.0 versioning, dual tags, NBGV {height} protection, and Build/Test gates.
disable-model-invocation: true
user-invocable: true
argument-hint: "[workflow] [args]"
---

# My Git Flow (my-git-flow)

## Human-Only Trigger & Start Metadata Governance
- **Strict Human Execution Only**: This skill MUST NEVER be autonomously triggered by an AI model. An AI agent can suggest `/my-git-flow` (or Claude Code `/my-git-flow:<action>`), and only the human operator is permitted to invoke it.
- **Single-Reference Lock**: Load only the `workflow.md` and `rules.md` for the active command. Never read multiple workflow folders simultaneously.
- **Mandatory Start Metadata (`NAME` & `DESCRIPTION`) & Automatic Slug Normalization**: Before running `start-feature`, `start-release`, or `start-hotfix`, if `NAME` or `DESCRIPTION` (`--description`) is omitted from the user prompt, ask the user via `AskUserQuestion` or `qa` (`exit 2` if omitted in CLI). Inside Python (`normalize_branch_slug`), all 6 commands automatically fold NFKD accents, lowercase, and replace spaces/punctuation with `-` before strict lowercase validation (`\A[a-z0-9][a-z0-9_.-]{0,99}\Z`), while `start-*` persists the sanitized raw input as `- Original Name:` under `## Description` in `README.md`.
- **Zero-Rollback SemVer 2.0.0 & NBGV `{height}` Invariant**: A version NEVER moves backward in ANY command, merge, override, or `--continue` (`compare_semver >= 0`, `exit 2`); NBGV `{height}` is NEVER removed or replaced. The developer can raise it at any time (manual edit or `--set-version`).
- **Single `CurrentVersion` Audit**: lifecycle `README.md` tracks only one in-place `- CurrentVersion:` line; `StartParentVersion` comes from `git show <BaseCommitSHA>`, never from the README.
- **Concrete Stack Isolation**: Build/Test gates run only stacks with real targets (`.sln`/`.slnx`/`.csproj`, `test_*.py`, real npm `build`/`test`, `*.bats`); `Directory.Build.props` alone never triggers `dotnet`.

## Progressive Disclosure Routing Table

| Command (Antigravity / Claude Code) | Workflow Reference | Key Versioning & Lifecycle Invariant |
|---|---|---|
| `/my-git-flow start feature` / `/my-git-flow:feature-start` | `workflows/01-start-feature/workflow.md` | Require `NAME` + `DESCRIPTION`; if `develop` has suffix (`-alphaN`/`-betaN`/`-rcN`) bump suffix `+1`, if clean bump numeric `+1` + `-alpha1` |
| `/my-git-flow finish feature` / `/my-git-flow:feature-finish` | `workflows/02-finish-feature/workflow.md` | Reverse-merge `develop`; if feature has suffix increment suffix `+1` and commit on feature, if clean keep untouched; merge `develop` |
| `/my-git-flow start release` / `/my-git-flow:release-start` | `workflows/03-start-release/workflow.md` | Require `NAME` + `DESCRIPTION`; if `develop` is `-rcN` bump `-rc(N+1)`, if `-alphaN`/`-betaN` set `-rc1`, if clean bump `+1-rc1` + `WARNING` |
| `/my-git-flow finish release` / `/my-git-flow:release-finish` | `workflows/04-finish-release/workflow.md` | Pre-merge monotonic guard (`exit 2`), strip `-rc<N>`, merge `prod`, advance `develop` `+1`, delete branch & dual-tag `v.{x.y.z}` + `release/<slug>` |
| `/my-git-flow start hotfix` / `/my-git-flow:hotfix-start` | `workflows/05-start-hotfix/workflow.md` | Require `NAME` + `DESCRIPTION`; branch `hotfix/<slug>` from `main`/`master`, bump `base(prod) + 1 + -beta1`, audit in `<spec_root>/git/hotfix/` |
| `/my-git-flow finish hotfix` / `/my-git-flow:hotfix-finish` | `workflows/06-finish-hotfix/workflow.md` | Pre-merge monotonic guard (`exit 2`), strip `-beta<N>`, merge `prod`, advance `develop` `+1`, delete branch & dual-tag `v.{x.y.z}` + `hotfix/<slug>` |

## Core Requirements (EARS)

- The my-git-flow skill SHALL require explicit human invocation (`disable-model-invocation: true`) and enforce `Single-Reference Lock` per command.
- WHEN starting a branch, the my-git-flow skill SHALL require `NAME` and `DESCRIPTION` inputs and normalize branch slugs via `normalize_branch_slug`.
- The my-git-flow skill SHALL enforce monotonic SemVer 2.0.0 versioning (`compare_semver >= 0`) and preserve NBGV `{height}` tokens across all transitions.
- IF a version downgrade, tag collision, or branch-family mismatch occurs, THEN the my-git-flow skill SHALL abort before Git mutation with exit code `2`.

## Behavioral Scenarios

```gherkin
Feature: Monotonic GitFlow Lifecycle Orchestration

  @REQ-MGF-001
  Scenario: Start a feature branch with normalized slug and monotonic version
    Given a clean working tree on develop with a valid manifest version
    When the human operator starts a feature branch with name and description
    Then the branch slug normalizes monotonically and records Original Name in the audit README

  @REQ-MGF-002
  Scenario: Reject version rollback during branch closure
    Given an active release branch whose target version is not strictly above production
    When the human operator executes finish-release
    Then the workflow aborts with exit code 2 without mutating production or tags
```

## Black-Box Execution

- **Do not read** script source code before execution; the scripts are tested black boxes.
- Run commands from repository root with Python 3.10+ (`python3` on Unix, `py -3` on Windows).
- Read script source only after a non-zero exit code that stderr does not explain.

| Command | Parameters | Stdout | Exit codes |
|---|---|---|---|
| `python3 ./scripts/my_git_flow.py` | `[--dry-run] start-feature "<name>" --description "<text>" [--bump "patch\|minor\|major"] [--set-version "<ver>"]` | JSON or `[VERSION]` status summary | `0` OK, `2` error, `3` config, `20` dirty |
| `python3 ./scripts/my_git_flow.py` | `[--dry-run] finish-feature ["<name>"] [--bump "patch\|minor\|major"] [--notes "<text>"] [--set-version "<ver>"]` | JSON or `[VERSION]` gate summary | `0` OK, `1` gate, `2` mismatch, `10` conflict, `20` dirty |
| `python3 ./scripts/my_git_flow.py` | `[--dry-run] start-release ["<ver>"] --description "<text>" [--override] [--set-version "<ver>"]` | JSON or `[VERSION]` status summary | `0` OK, `2` gate/arg, `3` config, `20` dirty |
| `python3 ./scripts/my_git_flow.py` | `[--dry-run] finish-release ["<ver>"] [--notes "<text>"] [--set-version "<ver>"]` | JSON or `[VERSION]` gate summary | `0` OK, `1` gate, `2` mismatch, `10` conflict, `20` dirty |
| `python3 ./scripts/my_git_flow.py` | `[--dry-run] start-hotfix ["<ver>"] --description "<text>" [--bump "patch\|minor\|major"] [--set-version "<ver>"]` | JSON or `[VERSION]` status summary | `0` OK, `2` error, `3` config, `20` dirty |
| `python3 ./scripts/my_git_flow.py` | `[--dry-run] finish-hotfix ["<ver>"] [--propagate-release] [--notes "<text>"] [--set-version "<ver>"]` | JSON or `[VERSION]` gate summary | `0` OK, `1` gate, `2` mismatch, `10` conflict, `20` dirty |
| `python3 ./scripts/my_git_flow.py` | `--continue` / `--abort` | JSON checkpoint summary | `0` OK, `1` error, `10` paused |
