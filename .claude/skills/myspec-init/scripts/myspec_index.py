#!/usr/bin/env python3
"""MySpec AI-Oriented Prepend Index & Git Branch Provenance Engine (myspec_index.py - Spec 035).

Maintains <spec_root>/index.yml with:
- Top-level `always_read:` list of human-designated mandatory reference documents (preserved on updates).
- Top-level `specs:` list written in strict prepend (append-top) order: newest created or implemented
  specifications at index 0 (top), oldest at the bottom.
- Ultra-lean AI discovery schema per entry: `id`, `status`, `date`, `capabilities`, `path`, `summary` (<= 120 chars).
- Zero `branch` metadata inside `index.yml`.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys
import subprocess
from pathlib import Path
from typing import Any, Callable

from myspec_config import MySpecConfigManager


def _default_git_runner(cmd: list[str], cwd: Path) -> tuple[int, str, str]:
    try:
        res = subprocess.run(["git"] + cmd, cwd=str(cwd), capture_output=True, text=True, timeout=5)
        return res.returncode, res.stdout, res.stderr
    except Exception as e:
        return 128, "", str(e)


class MySpecGitBranchTracker:
    """Detects active Git branch and records branch provenance inside specifications only (proposal.md)."""

    BRANCH_LINE_RE = re.compile(r"^-\s*Branch:\s*(.+)$", re.MULTILINE)

    def __init__(
        self,
        repo_root: Path | str | None = None,
        git_runner: Callable[[list[str], Path], tuple[int, str, str]] | None = None,
    ) -> None:
        if repo_root is None:
            self.repo_root = Path.cwd().resolve()
        else:
            raw_str = str(repo_root)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in repo_root: {repo_root}")
            self.repo_root = Path(repo_root).resolve()
        self.git_runner = git_runner or _default_git_runner

    def detect_branch(self) -> str:
        """Detect current Git branch with graceful fallback to detached:<sha> or n/a."""
        code, out, _err = self.git_runner(["rev-parse", "--abbrev-ref", "HEAD"], self.repo_root)
        if code != 0:
            return "n/a"
        branch = " ".join(out.strip().splitlines()).strip()
        if not branch:
            return "n/a"
        if branch == "HEAD":
            sha_code, sha_out, _ = self.git_runner(["rev-parse", "--short", "HEAD"], self.repo_root)
            if sha_code == 0 and sha_out.strip():
                return f"detached:{sha_out.strip().splitlines()[0].strip()}"
            return "detached:unknown"
        return branch

    def record_branch_in_proposal(self, proposal_path: Path | str, phase: str = "draft") -> str:
        """Record or update `- Branch:` inside proposal.md under ## Metadata."""
        p_path = Path(proposal_path)
        if not p_path.is_file():
            raise FileNotFoundError(f"Proposal file not found: {p_path}")

        current_branch = self.detect_branch()
        content = p_path.read_text(encoding="utf-8")

        m = self.BRANCH_LINE_RE.search(content)
        if m:
            existing_val = m.group(1).strip()
            # Extract original draft branch before any (implemented: ...) suffix
            base_branch = re.sub(r"\s*\(implemented:\s*[^)]+\)$", "", existing_val).strip()
            if phase == "implemented" and current_branch != "n/a" and base_branch != current_branch:
                new_val = f"{base_branch} (implemented: {current_branch})"
            elif phase == "draft":
                new_val = current_branch
            else:
                new_val = existing_val

            updated_content = self.BRANCH_LINE_RE.sub(f"- Branch: {new_val}", content, count=1)
            p_path.write_text(updated_content, encoding="utf-8")
            return new_val

        # No - Branch: line exists yet -> insert under ## Metadata if present, else append ## Metadata
        if "## Metadata" in content:
            updated_content = re.sub(
                r"(## Metadata\s*\n)",
                rf"\1- Branch: {current_branch}\n",
                content,
                count=1,
            )
        else:
            updated_content = content.rstrip() + f"\n\n## Metadata\n- Branch: {current_branch}\n"

        p_path.write_text(updated_content, encoding="utf-8")
        return current_branch


class MySpecIndexManager:
    """Manages <spec_root>/index.yml in prepend (append-top) order with minimal AI discovery keys."""

    ALLOWED_SPEC_KEYS = ("id", "status", "date", "capabilities", "path", "summary")
    ALLOWED_STATUSES = {"draft", "implemented"}
    MAX_SUMMARY_LENGTH = 120

    def __init__(self, repo_root: Path | str | None = None) -> None:
        if repo_root is None:
            self.repo_root = Path.cwd().resolve()
        else:
            raw_str = str(repo_root)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in repo_root: {repo_root}")
            self.repo_root = Path(repo_root).resolve()

        self.config_mgr = MySpecConfigManager(repo_root=self.repo_root)
        self.cfg = self.config_mgr.resolve_config()
        self.spec_root = self.cfg["spec_root"]
        self.index_path = self.config_mgr.get_index_file()

    def _sanitize_path(self, rel_path: str, label: str) -> str:
        """Validate relative path against directory traversal and root escape (CWE-22)."""
        return self.config_mgr.sanitize_relative_path(rel_path, label)

    @staticmethod
    def _escape_yaml_str(val: str) -> str:
        """Format a single-line string safely as double-quoted YAML scalar."""
        single_line = " ".join(str(val).splitlines()).strip()
        escaped = single_line.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'

    @staticmethod
    def _unescape_yaml_str(raw: str) -> str:
        """Unquote a YAML scalar string."""
        s = raw.strip()
        if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
            s = s[1:-1]
            s = s.replace('\\"', '"').replace("\\\\", "\\")
        return s

    def parse_yaml_content(self, content: str) -> dict[str, Any]:
        """Parse <spec_root>/index.yml content into structured dict (`always_read`, `specs`)."""
        always_read: list[str] = []
        specs: list[dict[str, Any]] = []

        section: str | None = None
        current_spec: dict[str, Any] | None = None

        for raw_line in content.splitlines():
            stripped = raw_line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            if stripped.startswith("always_read:"):
                if current_spec is not None:
                    specs.append(current_spec)
                    current_spec = None
                section = "always_read"
                rest = stripped[len("always_read:") :].strip()
                if rest.startswith("[") and rest.endswith("]"):
                    inner = rest[1:-1].strip()
                    if inner:
                        for item in inner.split(","):
                            always_read.append(self._unescape_yaml_str(item))
                continue

            if stripped.startswith("specs:"):
                if current_spec is not None:
                    specs.append(current_spec)
                    current_spec = None
                section = "specs"
                continue

            if section == "always_read":
                if stripped.startswith("- "):
                    val = self._unescape_yaml_str(stripped[2:].strip())
                    if val:
                        always_read.append(val)
            elif section == "specs":
                if stripped.startswith("- "):
                    if current_spec is not None:
                        specs.append(current_spec)
                    current_spec = {}
                    kv_part = stripped[2:].strip()
                    if ":" in kv_part:
                        k, v = kv_part.split(":", 1)
                        current_spec[k.strip()] = self._parse_scalar_or_list(v.strip())
                elif current_spec is not None and ":" in stripped:
                    k, v = stripped.split(":", 1)
                    current_spec[k.strip()] = self._parse_scalar_or_list(v.strip())

        if current_spec is not None:
            specs.append(current_spec)

        return {
            "always_read": always_read,
            "specs": specs,
        }

    def _parse_scalar_or_list(self, val_str: str) -> Any:
        if val_str.startswith("[") and val_str.endswith("]"):
            inner = val_str[1:-1].strip()
            if not inner:
                return []
            return [self._unescape_yaml_str(x) for x in inner.split(",") if x.strip()]
        return self._unescape_yaml_str(val_str)

    def serialize_yaml(self, always_read: list[str], specs: list[dict[str, Any]]) -> str:
        """Serialize `always_read` and `specs` into canonical YAML with newest specs at top."""
        lines: list[str] = [
            "# MySpec AI-Oriented Specification Index",
            "# Order: PREPEND (newest created/implemented at top, oldest at bottom)",
            "# Planning skills MUST always read documents in `always_read` and consult `specs` first.",
        ]

        if not always_read:
            lines.append("always_read: []")
        else:
            lines.append("always_read:")
            for doc in always_read:
                lines.append(f"  - {self._escape_yaml_str(doc)}")

        if not specs:
            lines.append("specs: []")
        else:
            lines.append("specs:")
            for entry in specs:
                caps = entry.get("capabilities", [])
                caps_str = "[" + ", ".join(self._escape_yaml_str(str(c)) for c in caps) + "]"
                lines.append(f"  - id: {self._escape_yaml_str(str(entry['id']))}")
                lines.append(f"    status: {self._escape_yaml_str(str(entry['status']))}")
                lines.append(f"    date: {self._escape_yaml_str(str(entry['date']))}")
                lines.append(f"    capabilities: {caps_str}")
                lines.append(f"    path: {self._escape_yaml_str(str(entry['path']))}")
                lines.append(f"    summary: {self._escape_yaml_str(str(entry['summary']))}")

        return "\n".join(lines) + "\n"

    def read_index(self) -> dict[str, Any]:
        """Read and parse <spec_root>/index.yml, returning empty structure if absent."""
        if not self.index_path.is_file():
            return {"always_read": [], "specs": []}
        content = self.index_path.read_text(encoding="utf-8")
        return self.parse_yaml_content(content)

    def init_index(self, always_read: list[str] | None = None, force: bool = False) -> Path:
        """Create <spec_root>/index.yml if missing, preserving existing content unless forced."""
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        existing = self.read_index() if self.index_path.is_file() else {"always_read": [], "specs": []}

        target_always_read = always_read if always_read is not None else existing.get("always_read", [])
        clean_always_read = [self._sanitize_path(p, "always_read") for p in target_always_read]

        const_rel = f"{self.spec_root}/Constitution.md"
        const_abs = self.repo_root / const_rel
        if const_abs.is_file() and not const_abs.is_symlink():
            if const_rel in clean_always_read:
                clean_always_read.remove(const_rel)
            clean_always_read.insert(0, const_rel)

        specs = [] if (force and not existing.get("specs")) else existing.get("specs", [])
        yaml_text = self.serialize_yaml(clean_always_read, specs)
        self.index_path.write_text(yaml_text, encoding="utf-8")
        return self.index_path

    def upsert_spec(
        self,
        spec_id: str,
        status: str,
        date: str,
        capabilities: list[str],
        path: str,
        summary: str,
    ) -> dict[str, Any]:
        """Prepend or move a spec entry to index 0 (top) of `specs:` in <spec_root>/index.yml."""
        if not spec_id or ".." in spec_id or "/" in spec_id or "\\" in spec_id:
            raise ValueError(f"Invalid spec_id: '{spec_id}'")
        if status not in self.ALLOWED_STATUSES:
            raise ValueError(f"Invalid status '{status}'. Must be one of {sorted(self.ALLOWED_STATUSES)}")

        clean_path = self._sanitize_path(path, "specs.path")
        clean_summary = " ".join(summary.strip().splitlines())
        if len(clean_summary) > self.MAX_SUMMARY_LENGTH:
            clean_summary = clean_summary[: self.MAX_SUMMARY_LENGTH - 3].rstrip() + "..."

        data = self.read_index()
        always_read = [self._sanitize_path(p, "always_read") for p in data.get("always_read", [])]
        existing_specs: list[dict[str, Any]] = data.get("specs", [])

        # Match by exact id or shared numeric prefix + normalized slug
        norm_entry = {
            "id": spec_id.strip(),
            "status": status,
            "date": date.strip() or datetime.date.today().isoformat(),
            "capabilities": [c.strip() for c in capabilities if c.strip()] or ["general"],
            "path": clean_path,
            "summary": clean_summary,
        }

        remaining_specs = [s for s in existing_specs if s.get("id") != norm_entry["id"]]
        # Prepend (append-top): newest/updated entry is always at index 0
        new_specs = [norm_entry] + remaining_specs

        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        self.index_path.write_text(self.serialize_yaml(always_read, new_specs), encoding="utf-8")
        return norm_entry

    def validate_index(self) -> list[str]:
        """Validate <spec_root>/index.yml structure, minimal keys, absence of `branch`, and path safety."""
        errors: list[str] = []
        if not self.index_path.is_file():
            return [f"Missing specification index file: {self.index_path}"]

        try:
            data = self.read_index()
        except Exception as e:
            return [f"Failed to parse {self.index_path.name}: {e}"]

        for doc_path in data.get("always_read", []):
            try:
                self._sanitize_path(doc_path, "always_read")
            except ValueError as e:
                errors.append(str(e))

        seen_ids: set[str] = set()
        for idx, entry in enumerate(data.get("specs", [])):
            sid = str(entry.get("id", f"<entry-{idx}>"))
            if "branch" in entry:
                errors.append(
                    f"Forbidden key 'branch' in index.yml entry '{sid}': "
                    f"branch metadata must be recorded ONLY inside specifications (proposal.md), not in index.yml"
                )

            extra_keys = set(entry.keys()) - set(self.ALLOWED_SPEC_KEYS)
            if extra_keys:
                errors.append(f"Disallowed keys {sorted(extra_keys)} in index.yml entry '{sid}'")

            missing_keys = set(self.ALLOWED_SPEC_KEYS) - set(entry.keys())
            if missing_keys:
                errors.append(f"Missing required keys {sorted(missing_keys)} in index.yml entry '{sid}'")

            if sid in seen_ids:
                errors.append(f"Duplicate spec id '{sid}' in index.yml")
            seen_ids.add(sid)

            status = entry.get("status", "")
            if status not in self.ALLOWED_STATUSES:
                errors.append(f"Invalid status '{status}' in index.yml entry '{sid}'")

            spec_path = str(entry.get("path", ""))
            try:
                self._sanitize_path(spec_path, f"specs[{sid}].path")
            except ValueError as e:
                errors.append(str(e))

            summary = str(entry.get("summary", ""))
            if len(summary) > self.MAX_SUMMARY_LENGTH:
                errors.append(
                    f"Summary in index.yml entry '{sid}' exceeds {self.MAX_SUMMARY_LENGTH} chars ({len(summary)} chars)"
                )

        return errors

    def get_next_prefix(self) -> str:
        """Compute the next sequential 3-digit prefix (e.g. '035') across index.yml and workspace."""
        max_num = -1
        num_pattern = re.compile(r"^(?:[0-9]{4}-[0-9]{2}-[0-9]{2}-)?([0-9]{3})[-_]")

        data = self.read_index()
        for entry in data.get("specs", []):
            m = num_pattern.match(str(entry.get("id", "")))
            if m:
                max_num = max(max_num, int(m.group(1)))

        for folder in [
            self.config_mgr.get_changes_dir(),
            self.config_mgr.get_archive_dir(),
            self.repo_root / "specs",
            self.repo_root / "specs" / "implemented",
        ]:
            if folder.is_dir():
                for item in folder.iterdir():
                    m = num_pattern.match(item.name)
                    if m:
                        max_num = max(max_num, int(m.group(1)))

        return f"{max_num + 1:03d}"

    @staticmethod
    def _extract_summary_from_markdown(md_path: Path, fallback: str) -> str:
        """Extract a concise 1-line summary (<= 120 chars) from a spec or proposal markdown file."""
        if not md_path.is_file():
            return fallback[:120]
        try:
            text = md_path.read_text(encoding="utf-8")
        except Exception:
            return fallback[:120]

        # Try # Title first
        title_m = re.search(r"^#\s+(?:Specification:\s*|Proposal:\s*)?(.+)$", text, re.MULTILINE)
        if title_m:
            cand = title_m.group(1).strip()
            if len(cand) > 120:
                return cand[:117].rstrip() + "..."
            return cand
        return fallback[:120]

    def backfill_workspace(self) -> list[dict[str, Any]]:
        """Discover all legacy specs, archived changes, and active draft changes and populate index.yml in prepend order."""
        existing = self.read_index()
        always_read = [self._sanitize_path(p, "always_read") for p in existing.get("always_read", [])]

        collected: list[tuple[int, str, dict[str, Any]]] = []

        # 1. Legacy implemented specs (specs/implemented/*.md) and unarchived legacy specs (specs/*.md)
        for leg_dir, status_val in [
            (self.repo_root / "specs" / "implemented", "implemented"),
            (self.repo_root / "specs", "draft"),
        ]:
            if leg_dir.is_dir():
                for f in sorted(leg_dir.iterdir()):
                    if f.is_file() and f.suffix == ".md" and f.name.lower() not in {"readme.md", "index.md", "agents.md"}:
                        m = re.match(r"^([0-9]{3})[-_](.+)$", f.stem)
                        num = int(m.group(1)) if m else 0
                        slug = m.group(2) if m else f.stem
                        cap = re.sub(r"^spec[-_]?(?:tool[-_]?)?", "", slug).strip("-_") or "general"
                        rel_p = str(f.relative_to(self.repo_root)).replace("\\", "/")
                        summary = self._extract_summary_from_markdown(f, f.stem)
                        # Extract date from frontmatter if present, else fallback
                        raw_txt = f.read_text(encoding="utf-8", errors="ignore")
                        dm = re.search(r"created:\s*\"?([0-9]{4}-[0-9]{2}-[0-9]{2})\"?", raw_txt)
                        date_str = dm.group(1) if dm else "2026-10-10"
                        collected.append((
                            num,
                            f.stem,
                            {
                                "id": f.stem,
                                "status": status_val,
                                "date": date_str,
                                "capabilities": [cap],
                                "path": rel_p,
                                "summary": summary,
                            },
                        ))

        # 2. Archived OpenSpec changes (openspec/changes/archive/YYYY-MM-DD-NNN-slug)
        archive_dir = self.config_mgr.get_archive_dir()
        if archive_dir.is_dir():
            for d in sorted(archive_dir.iterdir()):
                if d.is_dir() and d.name != "legacy-specs":
                    m = re.match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2})-(([0-9]{3})-(.+))$", d.name)
                    if m:
                        date_str = m.group(1)
                        change_id = m.group(2)
                        num = int(m.group(3))
                        fallback_cap = m.group(4)
                    else:
                        date_str = datetime.date.today().isoformat()
                        change_id = d.name
                        m_num = re.match(r"^([0-9]{3})-(.+)$", d.name)
                        num = int(m_num.group(1)) if m_num else 900
                        fallback_cap = m_num.group(2) if m_num else d.name

                    caps = [
                        sub.name
                        for sub in sorted((d / "specs").iterdir())
                        if sub.is_dir()
                    ] if (d / "specs").is_dir() else [fallback_cap]
                    rel_p = str(d.relative_to(self.repo_root)).replace("\\", "/")
                    summary = self._extract_summary_from_markdown(d / "proposal.md", change_id)
                    collected.append((
                        num,
                        change_id,
                        {
                            "id": change_id,
                            "status": "implemented",
                            "date": date_str,
                            "capabilities": caps or [fallback_cap],
                            "path": rel_p,
                            "summary": summary,
                        },
                    ))

        # 3. Active OpenSpec draft changes (openspec/changes/NNN-slug)
        changes_dir = self.config_mgr.get_changes_dir()
        if changes_dir.is_dir():
            for d in sorted(changes_dir.iterdir()):
                if d.is_dir() and d.name != "archive":
                    m_num = re.match(r"^([0-9]{3})-(.+)$", d.name)
                    num = int(m_num.group(1)) if m_num else 999
                    fallback_cap = m_num.group(2) if m_num else d.name
                    caps = [
                        sub.name
                        for sub in sorted((d / "specs").iterdir())
                        if sub.is_dir()
                    ] if (d / "specs").is_dir() else [fallback_cap]
                    rel_p = str(d.relative_to(self.repo_root)).replace("\\", "/")
                    summary = self._extract_summary_from_markdown(d / "proposal.md", d.name)
                    collected.append((
                        num,
                        d.name,
                        {
                            "id": d.name,
                            "status": "draft",
                            "date": datetime.date.today().isoformat(),
                            "capabilities": caps or [fallback_cap],
                            "path": rel_p,
                            "summary": summary,
                        },
                    ))

        # Sort ascending by (num, id), then reverse so newest is at index 0 (prepend order)
        collected.sort(key=lambda item: (item[0], item[1]))
        dedup: dict[str, dict[str, Any]] = {}
        for _num, cid, entry in collected:
            dedup[cid] = entry

        ordered_specs = list(reversed(list(dedup.values())))
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        self.index_path.write_text(self.serialize_yaml(always_read, ordered_specs), encoding="utf-8")
        return ordered_specs


def main() -> int:
    """CLI entrypoint for myspec_index.py."""
    parser = argparse.ArgumentParser(description="MySpec AI-Oriented Prepend Specification Index Manager")
    parser.add_argument("--target", "-t", type=str, default=".", help="Repository root directory")
    parser.add_argument("--init", action="store_true", help="Initialize <spec_root>/index.yml if missing")
    parser.add_argument("--backfill", action="store_true", help="Backfill index.yml from workspace specs and changes")
    parser.add_argument("--validate", action="store_true", help="Validate <spec_root>/index.yml schema and security")
    parser.add_argument("--next-prefix", action="store_true", help="Print the next 3-digit change ID prefix")
    parser.add_argument("--json", action="store_true", help="Emit JSON output")

    args = parser.parse_args()
    mgr = MySpecIndexManager(repo_root=args.target)

    if args.init:
        p = mgr.init_index()
        if args.json:
            print(json.dumps({"status": "ok", "index_path": str(p)}, indent=2))
        else:
            print(f"[OK] Initialized {p}")
        return 0

    if args.backfill:
        entries = mgr.backfill_workspace()
        if args.json:
            print(json.dumps({"status": "ok", "count": len(entries), "index_path": str(mgr.index_path)}, indent=2))
        else:
            print(f"[OK] Backfilled {len(entries)} specifications into {mgr.index_path} (newest at top).")
        return 0

    if args.validate:
        errs = mgr.validate_index()
        if args.json:
            print(json.dumps({"valid": len(errs) == 0, "errors": errs}, indent=2))
        else:
            if not errs:
                print(f"[OK] {mgr.index_path} is valid.")
            else:
                for e in errs:
                    print(f"[ERROR] {e}", file=sys.stderr)
        return 0 if not errs else 1

    if args.next_prefix:
        prefix = mgr.get_next_prefix()
        if args.json:
            print(json.dumps({"next_prefix": prefix}, indent=2))
        else:
            print(prefix)
        return 0

    data = mgr.read_index()
    if args.json:
        print(json.dumps(data, indent=2))
    else:
        print(f"Index: {mgr.index_path} ({len(data.get('specs', []))} specs, {len(data.get('always_read', []))} always_read)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
