---
name: shell-architect
description: "Progressive-disclosure Shell architecture skill across Bash, Zsh, Windows CMD, and PowerShell 5.1/7+ covering modular automation, cross-platform sync/installer pipelines, CWE-78/CWE-22 defensive execution, BATS/Pester TDD, and CLI documentation."
---

# Shell Architect Skill

## Core Engineering Pillars

- **Efficiency, Readability, and Performance**: Write clean, modular, human-readable scripts across Bash, Zsh, Windows CMD, and PowerShell 5.1/7+ that minimize unnecessary subshell forks (`$(...)` in tight loops) and process spawns.
- **TDD and Defensive Execution**: Drive automation pipelines via deterministic test harnesses (`BATS`, `Pester`, `ShellCheck`, `PSScriptAnalyzer`, or Python `subprocess` smoke suites) with strict fail-fast execution (`set -euo pipefail`, `$ErrorActionPreference = 'Stop'`).
- **Cross-Platform Parity**: Maintain behavioral parity between Unix (`.sh` / `.zsh`) and Windows (`.ps1` / `.cmd`) scripts (such as `my-agent-global-sync.sh` and `my-agent-global-sync.ps1`).
- **Code Documentation**: Require clear header synopsis blocks, flag tables (`--dry-run` / `-DryRun`, `--help`, `--force` / `-Force`), and inline explanations for non-obvious parameter expansions.
- **KISS-First & Pragmatic SOLID**: Consult `the kiss-and-solid-principles skill` (`Single-Reference Lock`) to prefer **KISS** (short single-purpose functions, flat control flow, zero speculative wrappers) and apply **SOLID** single-responsibility and dependency-inversion boundaries in modular scripts and PowerShell classes/cmdlets while enforcing the Non-Simplification Security Floor.
- **Zero Inline Coding Rules**: Normative scripting rules live exclusively in `the shell-scripting-standards rule` and `the security-secrets-policy rule`.

## Discovery-First Existing Project Rule

1. **Inspect Existing Topology First**: Query TokenSave (`tokensave_context`, `tokensave_search`) and inspect existing `.sh`, `.zsh`, `.ps1`, `.cmd` scripts, `.gitattributes`, `AGENTS.md`, and living specifications before proposing any script structure.
2. **Respect Established Conventions**: Always conform to the CLI flags, exit code conventions, backup folders (`.backups/`), and logging helpers already established in the repository.
3. **Greenfield Selection**: Only propose a new automation layout when creating a greenfield script or installer.

## Progressive-Disclosure Reference Index (`Single-Reference Lock`)

Load **at most ONE** `references/<file>.md` per turn or sub-agent invocation based on the active architectural concern:

| Reference File | Architectural Scope |
| :--- | :--- |
| `references/bash-zsh-modular-automation.md` | Bash/Zsh modular function architecture, `set -euo pipefail`, `trap` cleanup, array argument parsing, `rsync` staging, and zero-subshell loops |
| `references/windows-cmd-and-powershell-architecture.md` | PowerShell 5.1/7+ `[CmdletBinding(SupportsShouldProcess)]`, structured pipelines, `$ErrorActionPreference = 'Stop'`, and Windows `.cmd`/`.bat` wrappers |
| `references/cross-platform-portability-and-security.md` | macOS BSD vs GNU coreutils portability, CRLF/LF normalization, `CWE-78` argument quoting, `CWE-22` path confinement, and guarded `rm -rf` |
| `references/shell-testing-bats-pester-and-docs.md` | Deterministic shell testing (`BATS`, `Pester`, sandboxed `TemporaryDirectory` harnesses), `ShellCheck`, `PSScriptAnalyzer`, and CLI help documentation |

## Self-Evolution Reference Proposal Gate

When recurring project patterns reveal an architectural domain not covered by the existing `references/*.md` catalog:
1. Formulate a structured proposal specifying the candidate filename (`references/<slug>.md`), target scope, and key architectural invariants.
2. Validate that `<slug>.md` matches `^[a-z0-9]+(-[a-z0-9]+)*\.md$`, contains no `..` or path separators (`CWE-22`), and stays `< 150` lines.
3. Prompt the user via `AskUserQuestion` for explicit confirmation before creating or modifying any file inside `references/`. Never auto-create or overwrite reference files autonomously.

## Behavioral Contracts (EARS & BDD)

- WHEN a shell automation task begins, the shell-architect skill SHALL inspect existing scripts via TokenSave before proposing any structure.
- The shell-architect skill SHALL enforce Single-Reference Lock by loading at most one reference module per invocation.
- IF a candidate reference slug fails regex validation or lacks AskUserQuestion approval, THEN the shell-architect skill SHALL block the file write.

```gherkin
Feature: Shell Architect Progressive Disclosure
  @REQ-SH-001
  Scenario: Inspect automation scripts and enforce single-reference loading
    Given a repository with Bash and PowerShell automation pipelines
    When the architect plans cross-platform synchronization logic
    Then existing script conventions are inspected before proposing new layouts
    And at most one reference module is loaded into context

  @REQ-SH-002
  Scenario: Reject unapproved or unsafe reference proposals
    Given a proposed reference slug containing path traversal characters
    When the self-evolution gate evaluates the proposal without human confirmation
    Then the reference file creation is blocked
```
