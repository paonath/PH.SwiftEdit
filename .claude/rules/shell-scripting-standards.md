---
description: "Bash, Zsh, Windows CMD, and PowerShell 5.1/7+ scripting, portability, and security standards"
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.zsh"
  - "**/*.ps1"
  - "**/*.psm1"
  - "**/*.cmd"
  - "**/*.bat"
---

## Shell Scripting Standards

### Bash and Zsh Standards

- Start executable scripts with `#!/usr/bin/env bash` (or `#!/usr/bin/env zsh` when Zsh-specific) and enable strict fail-fast mode: `set -euo pipefail` and `IFS=$'\n\t'`.
- Double-quote all variable and command expansions (`"$target_dir"`, `"${args[@]}"`) to prevent word splitting and glob injection (`CWE-78`).
- Use `local` variables inside functions, `readonly` for constants, and `[[ ... ]]` for conditional tests.
- Register `trap cleanup EXIT INT TERM` handlers when creating temporary files or directories under `.tmp/`.
- Guard destructive commands (`rm -rf -- "${target:?}"`) against empty or root variables and validate paths before deletion.

### PowerShell 5.1 / 7+ and Windows CMD Standards

- Include `[CmdletBinding(SupportsShouldProcess = $true)]` and `param(...)` blocks at the top of `.ps1` scripts and functions.
- Set `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version Latest` at script entry.
- Use approved PowerShell `Verb-Noun` naming, structured object pipelines, and `Join-Path` / `Resolve-Path` for cross-platform path construction.
- In Windows `.cmd` / `.bat` wrappers, start with `@echo off`, `setlocal EnableExtensions EnableDelayedExpansion`, quote path arguments, and propagate exit codes with `exit /b %ERRORLEVEL%`.

### Cross-Platform CLI Ergonomics and Documentation

- Provide a header comment block (or PowerShell `.SYNOPSIS` / `.DESCRIPTION` comment-based help) documenting purpose, flags (`--dry-run` / `-DryRun`, `--help`), and exit codes.
- Normalize CRLF/LF line endings (`*.sh text eol=lf`, `*.ps1 text eol=crlf`) and avoid non-portable GNU/BSD sed flags without OS detection.
- Never hardcode credentials, tokens, or user-specific absolute paths; read configuration from environment variables or CLI parameters.
