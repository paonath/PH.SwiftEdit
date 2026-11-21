---
name: cross-platform-unix-windows-systems
description: "Cross-platform Python filesystem, encoding, atomic writes, process management, and OS portability across Unix/macOS/Linux and Windows."
---

# Cross-Platform Unix and Windows Systems Architecture in Python

## Filesystem and Path Portability

- Use `pathlib.Path` exclusively for path manipulation; never split or join paths with hardcoded `"/"` or `"\\"` separators.
- When serializing paths into JSON manifests, YAML indexes (`index.yml`), or cross-platform hashes, normalize relative paths to POSIX forward slashes via `rel_path.as_posix()`.
- Respect Windows filesystem constraints: avoid reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`), trailing dots/spaces, and handle case-insensitive path collisions explicitly.

## Explicit Encoding and Line-Ending Normalization

- Always pass `encoding="utf-8"` to `Path.read_text()`, `Path.write_text()`, and `open()` calls; never rely on platform default encodings (`cp1252` on Windows vs `UTF-8` on Unix).
- When computing deterministic SHA-256 content digests across macOS/Linux and Windows, normalize CRLF to LF before hashing (`content.replace(b"\r\n", b"\n")`).
- When writing shell scripts (`.sh`) from Python on Windows, pass `newline="\n"` inside `open(..., "w", encoding="utf-8", newline="\n")` so Bash shebangs are never corrupted by `\r`.

## Atomic File Replacement and Staging

- Prevent partial file corruption on crash or interrupt by writing to a sibling temporary file in the same directory and replacing atomically via `os.replace()` / `Path.replace()`:
  ```python
  def atomic_write_text(target: Path, content: str) -> None:
      target.parent.mkdir(parents=True, exist_ok=True)
      tmp_path = target.with_name(f".{target.name}.tmp.{os.getpid()}")
      try:
          tmp_path.write_text(content, encoding="utf-8", newline="\n")
          tmp_path.replace(target)
      finally:
          if tmp_path.exists():
              tmp_path.unlink(missing_ok=True)
  ```

## Executable Permissions and Subprocess Resolution

- On POSIX (`os.name == "posix"`), preserve or apply executable bits via `path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)`.
- Locate external CLI binaries via `shutil.which("tool")` and invoke Python sub-interpreters via `sys.executable` rather than assuming `python3` is on `PATH` on Windows.
