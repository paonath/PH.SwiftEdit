---
name: bash-zsh-modular-automation
description: "Bash and Zsh modular script architecture, strict error handling, trap lifecycle management, array argument parsing, and performance."
---

# Bash and Zsh Modular Automation Architecture

## Canonical Script Skeleton (`Bash 4+` / `Bash 3.2 macOS` / `Zsh`)

- Structure production `.sh` scripts with a strict preamble, scoped functions, deterministic `trap` cleanup, and an explicit `main "$@"` entrypoint:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  IFS=$'\n\t'

  readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TMP_WORK_DIR=""

  cleanup() {
    if [[ -n "${TMP_WORK_DIR:-}" && -d "${TMP_WORK_DIR}" ]]; then
      rm -rf -- "${TMP_WORK_DIR}"
    fi
  }
  trap cleanup EXIT INT TERM
  ```
- Remember that macOS ships `/bin/bash` `3.2` by default: avoid Bash 4+ associative arrays (`declare -A`), `readarray`/`mapfile`, or `${var,,}` case modification when targeting portable macOS/Linux scripts unless `#!/usr/bin/env zsh` or modern Bash is explicitly verified.

## Argument Parsing and Dry-Run Idempotency

- Parse CLI flags (`--dry-run`, `--force`, `--target <dir>`, `--help`) using a `while [[ $# -gt 0 ]]; do case "$1" in ... esac; done` state machine.
- Support `--dry-run` (`-n`) on every synchronizer, installer, or cleanup script (`my-agent-setup.sh`, `my-agent-global-sync.sh`) so callers can preview file mutations without side effects.

## Performance and Subshell Avoidance

| Anti-Pattern | High-Performance Idiom | Benefit |
| :--- | :--- | :--- |
| `basename "$p"` / `dirname "$p"` in a loop | Parameter expansion: `"${p##*/}"` and `"${p%/*}"` | Zero process fork overhead (`100x` faster in large file loops) |
| `cat file \| grep pattern` | `grep -- "pattern" "$file"` or `while IFS= read -r line; do ... done < "$file"` | Eliminates redundant `cat` pipeline and subshell variable loss |
| `for f in $(find ...)` | `while IFS= read -r -d '' f; do ... done < <(find ... -print0)` | Handles filenames with spaces/newlines safely (`CWE-78`) |
| Repeated `rsync` per file | Batch `rsync -a --exclude=... "$src/" "$dst/"` | Single delta transfer pass |
