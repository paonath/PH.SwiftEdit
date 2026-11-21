---
name: cross-platform-portability-and-security
description: "Cross-platform BSD/GNU shell portability, CRLF/LF normalization, CWE-78 command injection defense, and CWE-22 path confinement."
---

# Cross-Platform Portability and Shell Security (`CWE-78` / `CWE-22`)

## Defensive Shell Security Controls

| Threat / CWE | Vulnerable Pattern | Mandatory Defensive Pattern |
| :--- | :--- | :--- |
| Command & Argument Injection (`CWE-78`) | `eval "$cmd"`, unquoted `$var`, `rm -rf $dir/$name` | Use arrays (`cmd=("git" "diff" "--" "$path"); "${cmd[@]}"`), quote `"$var"`, and pass `--` before positional paths |
| Path Traversal & Empty Variable Deletion (`CWE-22`) | `rm -rf "$TARGET_DIR/$item"` when `$TARGET_DIR` is empty or `$item` contains `../` | Require non-empty expansion `"${TARGET_DIR:?}"`, validate `[[ "$item" =~ ^[a-zA-Z0-9._-]+$ ]]`, and verify canonical path prefix |
| Symlink & TOCTOU Escape (`CWE-59`) | Copying or deleting recursive trees containing untrusted symlinks | Reject symlinks (`[[ -L "$path" ]]`) or use `rsync --no-links` when syncing untrusted trees |
| Secret Exposure in Process Table (`CWE-214`) | Passing tokens via CLI flags (`curl -H "Authorization: Bearer $TOKEN"`) | Pass secrets via stdin, file descriptors (`--config -`), or scoped environment variables |

## Guarded Deletion Invariant (`DEPRECATED_SKILLS` / `RETIRED_SHIMS`)

- In Bash (`set -euo pipefail`) and PowerShell (`$ErrorActionPreference = 'Stop'`), always validate both the base directory and the item slug before recursive removal:
  ```bash
  safe_remove_child_dir() {
    local base_dir="${1:?Base directory required}"
    local slug="${2:?Item slug required}"
    if [[ ! "$slug" =~ ^[a-zA-Z0-9._-]+$ || "$slug" == "." || "$slug" == ".." ]]; then
      echo "ERROR: Invalid directory slug: $slug" >&2
      return 1
    fi
    local target="${base_dir}/${slug}"
    if [[ -d "$target" && ! -L "$target" ]]; then
      rm -rf -- "$target"
    fi
  }
  ```

## macOS (BSD) vs Linux (GNU) Coreutils Portability

- Avoid non-portable `sed -i` differences (`sed -i ''` on macOS BSD vs `sed -i` on GNU Linux); prefer `python3 -c` or write to a temporary file and `mv`.
- For SHA-256 hashing in Bash across macOS and Linux, detect `shasum -a 256` vs `sha256sum` via `command -v`.
- Enforce `.gitattributes` line-ending rules (`*.sh text eol=lf`, `*.zsh text eol=lf`, `*.ps1 text eol=crlf`, `*.cmd text eol=crlf`) so cross-OS checkouts never break script execution.
