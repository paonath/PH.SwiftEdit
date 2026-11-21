---
name: ai-skill-and-plugin-cli-scripts
description: "Architecture of AI-oriented blackbox CLI scripts inside skills and plugins with argparse, JSON output, exit codes, and CWE-22/CWE-78 safety."
---

# AI Skill and Plugin Blackbox CLI Scripts

## Blackbox CLI Design Principles

- Treat Python scripts inside skill `scripts/` folders and plugin directories as **self-contained blackbox CLI tools** that AI agents invoke via `--help` and structured flags without reading the script source code into context.
- Rely exclusively on the **Python Standard Library** (`argparse`, `json`, `pathlib`, `re`, `subprocess`, `sys`, `tempfile`, ` hashlib`, `dataclasses`) unless the host project explicitly provides a managed virtualenv.

## Standard CLI Contract (`argparse` + Exit Codes)

| Exit Code | Meaning | Standard Stream | Payload Format |
| :--- | :--- | :--- | :--- |
| `0` | Success / validation passed | `stdout` | Human summary or `--json` object (`{"status": "ok", ...}`) |
| `1` | Domain / validation failure | `stdout` (with `--json`) or `stderr` | Structured diagnostics (`{"status": "error", "errors": [...]}`) |
| `2` | CLI usage / invalid flag error | `stderr` | `argparse` usage synopsis and error message |

- Always expose `--help` (`-h`) with a concise usage description and example invocations; verify `--help` executes with zero filesystem side effects.
- Provide `--target <dir>` (defaulting to current working directory) so governance tests can execute the script inside an isolated `tempfile.TemporaryDirectory()` sandbox.
- Provide `--json` on diagnostic, status, and validation scripts so orchestrating agents parse deterministic JSON rather than scraping prose.

## Defensive Execution and Path Confinement (`CWE-22` / `CWE-78`)

- **Path Traversal Guard (`CWE-22`)**:
  ```python
  def resolve_confined(root: Path, candidate: str | Path) -> Path:
      resolved_root = root.resolve()
      resolved_target = (resolved_root / candidate).resolve()
      if not resolved_target.is_relative_to(resolved_root):
          raise ValueError(f"Path traversal rejected: {candidate}")
      return resolved_target
  ```
- **Subprocess Safety (`CWE-78`)**: Always call `subprocess.run([cmd, *args], shell=False, cwd=str(root), capture_output=True, text=True, check=False)`. Never use `shell=True`, `os.system()`, `eval()`, `exec()`, or untrusted `pickle.loads()`.
- Reject symlinks (`path.is_symlink()`) when staging or mirroring configuration directories across trust boundaries.
