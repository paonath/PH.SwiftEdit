---
name: windows-cmd-and-powershell-architecture
description: "PowerShell 5.1 and 7+ advanced script architecture, ShouldProcess support, structured pipelines, and Windows CMD batch wrappers."
---

# Windows CMD and PowerShell 5.1 / 7+ Architecture

## PowerShell Canonical Script Structure (`.ps1` / `.psm1`)

- Author PowerShell scripts compatible with both Windows PowerShell `5.1` and cross-platform `pwsh` `7+`:
  ```powershell
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
      [Parameter(Mandatory = $false)]
      [ValidateNotNullOrEmpty()]
      [string]$TargetDir = (Get-Location).Path,

      [Parameter(Mandatory = $false)]
      [switch]$DryRun,

      [Parameter(Mandatory = $false)]
      [switch]$Force
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  ```
- Gate every destructive or state-changing filesystem operation (`Copy-Item`, `Remove-Item`, `Move-Item`) with `if ($PSCmdlet.ShouldProcess($targetPath, 'Synchronize'))` or explicit `if (-not $DryRun)` checks.

## PowerShell Performance and Pipeline Best Practices

- Avoid `+=` on standard arrays (`$arr += $item` copies the entire array on every iteration, causing `O(n^2)` allocations); collect pipeline output directly (`$items = foreach ($x in $source) { ... }`) or use `[System.Collections.Generic.List[string]]::new()`.
- Use `Join-Path` and `[System.IO.Path]::GetFullPath()` for path resolution; use `Get-FileHash -Algorithm SHA256` (after normalizing `\r\n` to `\n` when comparing hashes with macOS/Linux).
- Check `$LASTEXITCODE` immediately after invoking native external executables (`git`, `dotnet`, `node`, `python`).

## Windows CMD (`.cmd` / `.bat`) Wrapper Architecture

- Keep `.cmd` scripts thin—use them primarily as bootstrap wrappers that invoke PowerShell or Python with safe argument forwarding:
  ```bat
  @echo off
  setlocal EnableExtensions EnableDelayedExpansion
  set "SCRIPT_DIR=%~dp0"
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPT_DIR%my-script.ps1" %*
  set "EXIT_CODE=%ERRORLEVEL%"
  endlocal & exit /b %EXIT_CODE%
  ```
- Always quote `set "VAR=value"` assignments to prevent trailing whitespace pollution and check `if errorlevel 1` or `%ERRORLEVEL%` after commands.
