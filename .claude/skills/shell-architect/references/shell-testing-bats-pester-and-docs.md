---
name: shell-testing-bats-pester-and-docs
description: "Deterministic TDD for Bash, Zsh, PowerShell, and CMD scripts using BATS, Pester, Python subprocess sandboxes, ShellCheck, and CLI documentation."
---

# Shell Testing (`BATS`, `Pester`, Sandboxed TDD) and Documentation

## Red-Green-Refactor TDD for Shell Scripts

- Every `.sh`, `.zsh`, `.ps1`, or `.cmd` script must be verified through automated tests covering positive execution (`P#`: `--help`, `--dry-run`, idempotent sync, backup creation) and negative security rejection (`N#`: unknown flags exit `!= 0`, path traversal blocked, retired shims purged without deleting custom user files).
- **Sandboxed Execution Rule**: Never run shell tests against the live user home directory (`$HOME` / `$env:USERPROFILE`) or live repository root; override `HOME` / target paths to point inside a temporary directory (`mktemp -d` or Python `tempfile.TemporaryDirectory()`).

## Multi-Runner Verification Matrix

| Verification Layer | Tooling | Command / Pattern |
| :--- | :--- | :--- |
| Bash Syntax & Static Analysis | `bash -n` + `shellcheck` | `bash -n script.sh && shellcheck -s bash script.sh` |
| PowerShell Static Analysis | `PSScriptAnalyzer` | `Invoke-ScriptAnalyzer -Path script.ps1 -Severity Error,Warning` |
| Bash Unit / Integration TDD | `BATS` (`bats-core`) or Python `unittest` `subprocess.run` | Run script inside sandboxed temp dir and assert exit code, stdout, and file tree state |
| PowerShell Unit / Integration TDD | `Pester v5` (`Describe` / `Context` / `It`) | Mock or sandbox `$TestDrive` and assert `Should -Be` / `Should -Exist` |
| Parity Verification (`.sh` vs `.ps1`) | Cross-script contract tests (`tests/governance/`) | Verify identical array entries (`DEPRECATED_SKILLS`, `RETIRED_SHIMS` / `$RetiredShims`) and CLI flags |

## CLI Documentation and Help Standards

- Every shell script must include:
  1. **Header Synopsis Comment**: Purpose, supported OS/shells, usage examples, and exit codes at the top of the file.
  2. **`usage()` / `--help` Handler**: Prints concise help text to `stdout` and exits `0` without modifying any files.
  3. **PowerShell Comment-Based Help**: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE` blocks inside `.ps1` scripts so `Get-Help .\script.ps1 -Full` renders native documentation.
