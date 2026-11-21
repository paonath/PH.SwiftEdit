---
description: "Python 3.10+ coding, typing, performance, CLI blackbox, and security standards"
paths:
  - "**/*.py"
---

## Python Coding Standards

### Style, Typing, and Documentation

- Follow **PEP 8** naming and formatting conventions (`snake_case` functions/variables, `PascalCase` classes, `UPPER_SNAKE_CASE` constants, 4-space indentation).
- Enforce **PEP 484** explicit type annotations on all function and method signatures (`def run(target: Path, *, strict: bool = False) -> int:`) and include `from __future__ import annotations`.
- Follow **PEP 257** docstring conventions for modules, classes, and public functions, documenting parameters, return values, and raised exceptions concisely in English.
- Prefer `@dataclass(frozen=True, slots=True)` or `NamedTuple` for immutable value objects and structured payloads.

### Filesystem, Subprocess, and Security Hygiene

- Use `pathlib.Path` for all filesystem operations (`Path.resolve()`, `.is_file()`, `.read_text(encoding="utf-8")`); avoid raw `os.path` string concatenation.
- Validate untrusted relative paths against canonical root confinement (`resolved.is_relative_to(root_dir)`) to prevent path traversal (`CWE-22`).
- Execute external processes exclusively via `subprocess.run([...], shell=False, check=False, capture_output=True, text=True)` with explicit argument lists; never pass untrusted strings to `shell=True`, `os.system`, `eval`, or `exec` (`CWE-78`).
- Use `tempfile.TemporaryDirectory()` or project `.tmp/` subdirectories via context managers (`with`) for scratch artifacts.

### Performance, Memory, and AI CLI Script Design

- Prefer generators, iterators, and streaming file reads over materializing large collections in memory.
- Support `--help`, `--json` machine-readable output, and deterministic exit codes (`0` success, `1` validation/domain failure, `2` usage/CLI error) in AI skill and plugin scripts.
- Keep standard library dependencies first; avoid heavy third-party packages in skill helper scripts unless required by the target project.

### Testing

- Write deterministic unit tests using `unittest` or `pytest` with isolated `tempfile.TemporaryDirectory` fixtures.
- Cover both positive (`P#`) and negative/security rejection (`N#`) paths without network or external state dependencies.
