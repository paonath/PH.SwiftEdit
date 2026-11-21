#!/usr/bin/env python3
"""MySpec Living Specification & Workspace Diagnostics Engine (myspec-status).

Provides real-time visibility into active changes, living specifications,
TDD triad progress, legacy specifications, and security hygiene.
Supports human-oriented console output and machine-readable JSON.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable

def _resolve_shared_scripts() -> None:
    current_dir = Path(__file__).resolve().parent
    skills_root = current_dir.parent.parent
    candidates = [
        current_dir,
        skills_root / "myspec-init" / "scripts",
        current_dir.parent.parent.parent / ".agents" / "skills" / "myspec-init" / "scripts",
        current_dir.parent.parent.parent / ".claude" / "skills" / "myspec-init" / "scripts",
    ]
    cwd = Path.cwd().resolve()
    candidates.extend([
        cwd / ".agents" / "skills" / "myspec-init" / "scripts",
        cwd / ".claude" / "skills" / "myspec-init" / "scripts",
    ])
    for cand in candidates:
        if cand.is_dir() and (cand / "myspec_config.py").is_file():
            cand_str = str(cand.resolve())
            if cand_str not in sys.path:
                sys.path.insert(0, cand_str)
            break

_resolve_shared_scripts()


class _EmbeddedConfigManager:
    """Self-contained embedded configuration manager for MySpec status diagnostics."""

    CONFIG_FILE_NAME = ".myspec.config.json"
    ALLOWED_SPEC_ROOTS = {"openspec", "specs"}

    DEFAULT_PATHS: dict[str, dict[str, str]] = {
        "openspec": {
            "specs": "openspec/specs",
            "changes": "openspec/changes",
            "archive": "openspec/changes/archive",
            "briefs": "openspec/briefs",
            "debug": "openspec/debug",
            "constitution_file": "openspec/Constitution.md",
            "constitution_dir": "openspec/constitution",
        },
        "specs": {
            "specs": "specs",
            "changes": "specs/changes",
            "archive": "specs/implemented",
            "briefs": "specs/briefs",
            "debug": "specs/debug",
            "constitution_file": "specs/Constitution.md",
            "constitution_dir": "specs/constitution",
        },
    }

    def __init__(self, repo_root: Path | str | None = None) -> None:
        if repo_root is None:
            self.repo_root = Path.cwd().resolve()
        else:
            raw_str = str(repo_root)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in repo_root: {repo_root}")
            self.repo_root = Path(repo_root).resolve()
        self._resolved_config: dict[str, Any] | None = None

    def get_config_file_path(self) -> Path:
        return self.repo_root / self.CONFIG_FILE_NAME

    def has_config_file(self) -> bool:
        return self.get_config_file_path().is_file()

    def sanitize_relative_path(self, path_str: str, key_name: str) -> str:
        if not path_str or not isinstance(path_str, str):
            raise ValueError(f"Invalid path value for '{key_name}': must be a non-empty string.")
        clean = path_str.strip().replace("\\", "/")
        if clean.startswith("/") or clean.startswith("\\"):
            raise ValueError(f"Security error: Absolute path detected in '{key_name}': '{path_str}'")
        parts = clean.split("/")
        if ".." in parts:
            raise ValueError(f"Security error: Path traversal ('..') detected in '{key_name}': '{path_str}'")
        resolved = (self.repo_root / clean).resolve()
        try:
            resolved.relative_to(self.repo_root)
        except ValueError:
            raise ValueError(f"Security error: Path '{path_str}' in '{key_name}' escapes repository root.")
        return clean

    def auto_discover_spec_root(self) -> str:
        openspec_dir = self.repo_root / "openspec"
        specs_dir = self.repo_root / "specs"
        openspec_count = self._count_spec_documents(openspec_dir)
        specs_count = self._count_spec_documents(specs_dir)
        if specs_count > openspec_count:
            return "specs"
        return "openspec"

    def _count_spec_documents(self, root_dir: Path) -> int:
        if not root_dir.is_dir():
            return 0
        count = 0
        for _dirpath, dirnames, filenames in os.walk(str(root_dir)):
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in {"node_modules", "bin", "obj", "__pycache__"}]
            for fname in filenames:
                if fname.endswith(".md"):
                    count += 1
        return count

    def resolve_config(self, force_reload: bool = False) -> dict[str, Any]:
        if self._resolved_config is not None and not force_reload:
            return self._resolved_config

        config_path = self.get_config_file_path()
        if config_path.is_file():
            try:
                raw_text = config_path.read_text(encoding="utf-8")
                data = json.loads(raw_text)
            except Exception as e:
                raise ValueError(f"Failed to read .myspec.config.json: {e}") from e

            if not isinstance(data, dict):
                raise ValueError("Root element of .myspec.config.json must be a JSON object.")

            spec_root = data.get("spec_root")
            if not spec_root or not isinstance(spec_root, str):
                raise ValueError("Missing or invalid 'spec_root' in .myspec.config.json.")

            spec_root_clean = self.sanitize_relative_path(spec_root, "spec_root")
            if spec_root_clean not in self.ALLOWED_SPEC_ROOTS:
                raise ValueError(f"Invalid spec_root '{spec_root}'. Must be one of: {sorted(self.ALLOWED_SPEC_ROOTS)}")

            defaults = dict(self.DEFAULT_PATHS[spec_root_clean])
            paths_obj = data.get("paths", {})
            if isinstance(paths_obj, dict):
                for k, v in paths_obj.items():
                    if isinstance(v, str):
                        defaults[k] = self.sanitize_relative_path(v, f"paths.{k}")

            resolved = {
                "spec_root": spec_root_clean,
                "paths": defaults,
                "source": "file",
                "config_file": str(config_path),
            }
        else:
            discovered_root = self.auto_discover_spec_root()
            resolved = {
                "spec_root": discovered_root,
                "paths": dict(self.DEFAULT_PATHS[discovered_root]),
                "source": "auto_discovered",
            }

        self._resolved_config = resolved
        return resolved

    def get_spec_root(self) -> str:
        return self.resolve_config()["spec_root"]

    def get_specs_dir(self) -> Path:
        return self.repo_root / self.resolve_config()["paths"]["specs"]

    def get_changes_dir(self) -> Path:
        return self.repo_root / self.resolve_config()["paths"]["changes"]

    def get_archive_dir(self) -> Path:
        return self.repo_root / self.resolve_config()["paths"]["archive"]

    def get_briefs_dir(self) -> Path:
        return self.repo_root / self.resolve_config()["paths"]["briefs"]

    def get_debug_dir(self) -> Path:
        return self.repo_root / self.resolve_config()["paths"]["debug"]

    def get_index_file(self) -> Path:
        return self.repo_root / self.get_spec_root() / "index.yml"

    def get_constitution_file(self) -> Path:
        """Return the confined absolute path to <spec_root>/Constitution.md."""
        return self.repo_root / self.resolve_config()["paths"]["constitution_file"]

    def get_constitution_dir(self) -> Path:
        """Return the confined absolute path to <spec_root>/constitution."""
        return self.repo_root / self.resolve_config()["paths"]["constitution_dir"]


class _EmbeddedIndexManager:
    """Self-contained embedded index manager for MySpec status diagnostics."""

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

    def read_index(self) -> dict[str, Any]:
        if not self.index_path.is_file():
            return {"always_read": [], "specs": []}
        content = self.index_path.read_text(encoding="utf-8")
        return self.parse_yaml_content(content)

    def parse_yaml_content(self, content: str) -> dict[str, Any]:
        always_read: list[str] = []
        specs: list[dict[str, Any]] = []

        current_section: str | None = None
        current_spec: dict[str, Any] | None = None

        for raw_line in content.splitlines():
            line = raw_line.rstrip()
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            if stripped.startswith("always_read:"):
                current_section = "always_read"
                if current_spec is not None:
                    specs.append(current_spec)
                    current_spec = None
                rest = stripped[len("always_read:"):].strip()
                if rest.startswith("[") and rest.endswith("]"):
                    inner = rest[1:-1].strip()
                    if inner:
                        for item in inner.split(","):
                            c = item.strip().strip("\"'")
                            if c:
                                always_read.append(c)
                continue

            if stripped.startswith("specs:"):
                current_section = "specs"
                if current_spec is not None:
                    specs.append(current_spec)
                    current_spec = None
                continue

            if current_section == "always_read":
                if stripped.startswith("- "):
                    val = stripped[2:].strip().strip("\"'")
                    if val:
                        always_read.append(val)
                elif not stripped.startswith("-") and not line.startswith(" ") and not line.startswith("\t"):
                    current_section = None

            elif current_section == "specs":
                if stripped.startswith("- "):
                    if current_spec is not None:
                        specs.append(current_spec)
                    current_spec = {}
                    item_part = stripped[2:].strip()
                    if ":" in item_part:
                        k, v = item_part.split(":", 1)
                        current_spec[k.strip()] = v.strip().strip("\"'")
                elif current_spec is not None and (line.startswith("  ") or line.startswith("\t")):
                    if ":" in stripped:
                        k, v = stripped.split(":", 1)
                        k_clean = k.strip()
                        v_clean = v.strip()
                        if v_clean.startswith("[") and v_clean.endswith("]"):
                            inner = v_clean[1:-1].strip()
                            current_spec[k_clean] = [x.strip().strip("\"'") for x in inner.split(",") if x.strip()]
                        else:
                            current_spec[k_clean] = v_clean.strip("\"'")
                elif not stripped.startswith("-") and not line.startswith(" ") and not line.startswith("\t"):
                    if current_spec is not None:
                        specs.append(current_spec)
                        current_spec = None
                    current_section = None

        if current_spec is not None:
            specs.append(current_spec)

        return {"always_read": always_read, "specs": specs}


MySpecConfigManager =  _EmbeddedConfigManager
MySpecIndexManager = _EmbeddedIndexManager



def default_git_runner(cmd: list[str], cwd: Path) -> tuple[int, str, str]:
    try:
        res = subprocess.run(["git"] + cmd, cwd=str(cwd), capture_output=True, text=True)
        return res.returncode, res.stdout, res.stderr
    except Exception as e:
        return 128, "", str(e)


class MySpecDeltaScanner:
    """Detects unaligned source modifications and suggests doc-align workflows."""

    IGNORED_DIRS = {".git", ".tokensave", ".tmp", ".vscode", ".idea"}

    def __init__(
        self,
        target_dir: Path | str | None = None,
        git_runner: Callable[[list[str], Path], tuple[int, str, str]] | None = None,
    ) -> None:
        if target_dir is None:
            self.target_dir = Path.cwd().resolve()
        else:
            raw_str = str(target_dir)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in target directory: {target_dir}")
            self.target_dir = Path(target_dir).resolve()

        self.git_runner = git_runner or default_git_runner

        if MySpecConfigManager:
            self.config_mgr = MySpecConfigManager(repo_root=self.target_dir)
            self.cfg = self.config_mgr.resolve_config()
            self.spec_root = self.cfg.get("spec_root", "openspec")
        else:
            self.config_mgr = None
            self.spec_root = "openspec"

    def _is_source_file(self, rel_path: str) -> bool:
        norm = rel_path.strip().replace("\\", "/")
        if not norm:
            return False
        if norm == self.spec_root or norm.startswith(self.spec_root + "/"):
            return False
        parts = norm.split("/")
        if any(p in self.IGNORED_DIRS for p in parts):
            return False
        return True

    def scan(self) -> dict[str, Any]:
        """Inspect uncommitted working tree changes and the last 3 commits."""
        ret, out, err = self.git_runner(["status", "--porcelain"], self.target_dir)
        if ret != 0:
            return {
                "status": "git_unavailable",
                "error": err.strip() or "Not a git repository",
                "uncommitted_files": [],
                "recent_commits": [],
                "recommendations": [],
            }

        uncommitted_files: list[str] = []
        for line in out.splitlines():
            line = line.strip()
            if not line:
                continue
            file_part = line[2:].strip()
            if " -> " in file_part:
                file_part = file_part.split(" -> ")[1].strip()
            if self._is_source_file(file_part):
                uncommitted_files.append(file_part)

        ret, log_out, _ = self.git_runner(
            ["log", "-n", "3", "--format=%H|%s", "--name-only"], self.target_dir
        )
        recent_commits: list[dict[str, Any]] = []
        if ret == 0 and log_out.strip():
            lines = log_out.splitlines()
            current_commit: dict[str, Any] | None = None
            for raw_l in lines:
                l = raw_l.strip()
                if not l:
                    continue
                if "|" in l:
                    parts = l.split("|")
                    if len(parts) >= 3:
                        c_hash = parts[0].strip()
                        c_msg = parts[1].strip()
                        c_files = [f.strip() for f in parts[2].split(",") if self._is_source_file(f.strip())]
                        if c_files:
                            recent_commits.append({
                                "commit": c_hash,
                                "message": c_msg,
                                "files": c_files,
                            })
                    else:
                        if current_commit and current_commit["files"]:
                            recent_commits.append(current_commit)
                        current_commit = {
                            "commit": parts[0].strip(),
                            "message": parts[1].strip(),
                            "files": [],
                        }
                else:
                    if current_commit is not None:
                        if self._is_source_file(l):
                            current_commit["files"].append(l)
            if current_commit and current_commit["files"]:
                recent_commits.append(current_commit)

        recommendations: list[str] = []
        if uncommitted_files or recent_commits:
            status = "delta_detected"
            recommendations.append(
                "Execute /myspec-tdd-spec-reasoning in doc-align mode to align living specifications without rewriting code."
            )
        else:
            status = "clean"

        return {
            "status": status,
            "uncommitted_files": uncommitted_files,
            "recent_commits": recent_commits,
            "recommendations": recommendations,
        }

    def scan_deep(self) -> dict[str, Any]:
        """Perform deep comparison across all source files and living specs.

        Records the last_deep_scan timestamp in config, and warns if run within 24h.
        """
        warning: str | None = None
        config_file = self.target_dir / ".myspec.config.json"

        if config_file.is_file():
            try:
                cfg_data = json.loads(config_file.read_text(encoding="utf-8"))
                if "last_deep_scan" in cfg_data:
                    last_dt = datetime.fromisoformat(cfg_data["last_deep_scan"])
                    if last_dt.tzinfo is None:
                        last_dt = last_dt.replace(tzinfo=timezone.utc)
                    now_utc = datetime.now(timezone.utc)
                    if now_utc - last_dt < timedelta(hours=24):
                        warning = (
                            f"A deep scan was already run at {cfg_data['last_deep_scan']} "
                            f"(within the last 24 hours). Recommend using standard delta scan instead."
                        )
            except Exception:
                pass

        res = self.scan()
        now_iso = datetime.now(timezone.utc).isoformat()
        res["last_deep_scan"] = now_iso
        if warning:
            res["warning"] = warning

        if config_file.is_file():
            try:
                cfg_data = json.loads(config_file.read_text(encoding="utf-8"))
                cfg_data["last_deep_scan"] = now_iso
                config_file.write_text(json.dumps(cfg_data, indent=2), encoding="utf-8")
            except Exception:
                pass

        return res


class MySpecStatusReporter:
    """Status and diagnostics reporter for MySpec workspaces."""

    CHANGE_ID_PATTERN = re.compile(r"^([0-9]{3}-)?[a-z0-9-]+$")
    TASK_CHECKBOX_PATTERN = re.compile(r"^[-*]\s*\[([ xX])\]\s*(.*)$")
    VERDICT_PATTERN = re.compile(r"Verdict:\s*([a-zA-Z_-]+)", re.IGNORECASE)
    REQ_PATTERN = re.compile(r"^###\s+Requirement:", re.MULTILINE)
    SCENARIO_PATTERN = re.compile(r"^####\s+Scenario:", re.MULTILINE)

    def __init__(self, target_dir: Path | str | None = None) -> None:
        if target_dir is None:
            self.target_dir = Path.cwd().resolve()
        else:
            raw_str = str(target_dir)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in target directory: {target_dir}")
            self.target_dir = Path(target_dir).resolve()

        if MySpecConfigManager:
            self.config_mgr = MySpecConfigManager(repo_root=self.target_dir)
            self.cfg = self.config_mgr.resolve_config()
            self.spec_root = self.cfg["spec_root"]
            self.specs_dir = self.config_mgr.get_specs_dir()
            self.changes_dir = self.config_mgr.get_changes_dir()
            self.archive_dir = self.config_mgr.get_archive_dir()
            self.briefs_dir = self.config_mgr.get_briefs_dir()
            self.debug_dir = self.config_mgr.get_debug_dir()
            self.spec_root_dir = self.target_dir / self.spec_root
            self.openspec_dir = self.spec_root_dir
        else:
            self.spec_root = "openspec"
            self.spec_root_dir = self.target_dir / "openspec"
            self.openspec_dir = self.spec_root_dir
            self.specs_dir = self.openspec_dir / "specs"
            self.changes_dir = self.openspec_dir / "changes"
            self.archive_dir = self.changes_dir / "archive"
            self.briefs_dir = self.openspec_dir / "briefs"
            self.debug_dir = self.openspec_dir / "debug"

        self.delta_scanner = MySpecDeltaScanner(target_dir=self.target_dir)

    def is_initialized(self) -> bool:
        """Check whether the target workspace has been initialized with openspec/ or specs/."""
        if hasattr(self, "config_mgr") and self.config_mgr.has_config_file():
            return True
        return self.spec_root_dir.is_dir() or self.specs_dir.is_dir()

    def get_schema(self) -> str | None:
        """Extract configured schema from openspec/config.yaml or default to tdd-spec-driven."""
        config_path = self.spec_root_dir / "config.yaml"
        if not config_path.is_file():
            return None
        content = config_path.read_text(encoding="utf-8")
        match = re.search(r"^schema:\s*([a-zA-Z0-9_\"'-]+)", content, re.MULTILINE)
        if match:
            return match.group(1).strip().strip("\"'")
        return "tdd-spec-driven"

    def get_change_detail(self, change_id: str) -> dict[str, Any]:
        """Retrieve detailed progress, artifact presence, and tasks for a single change."""
        if not self.CHANGE_ID_PATTERN.match(change_id) or ".." in change_id:
            raise ValueError(f"Invalid change identifier: '{change_id}'. Must match pattern ^([0-9]{3}-)?[a-z0-9-]+$")

        change_dir = self.changes_dir / change_id
        if not change_dir.is_dir():
            raise FileNotFoundError(f"Change '{change_id}' not found in {self.changes_dir}")

        # Check standard artifacts
        artifacts: dict[str, bool] = {
            "proposal.md": (change_dir / "proposal.md").is_file(),
            "design.md": (change_dir / "design.md").is_file(),
            "threat-model.md": (change_dir / "threat-model.md").is_file(),
            "test-plan.md": (change_dir / "test-plan.md").is_file(),
            "tasks.md": (change_dir / "tasks.md").is_file(),
            "specs": (change_dir / "specs").is_dir(),
        }

        # Check verdict
        verdict = "pending"
        for doc in ["threat-model.md", "design.md"]:
            doc_path = change_dir / doc
            if doc_path.is_file():
                v_match = self.VERDICT_PATTERN.search(doc_path.read_text(encoding="utf-8"))
                if v_match:
                    verdict = v_match.group(1).lower()
                    break

        # Parse tasks
        tasks: list[dict[str, Any]] = []
        triads = {"RED": 0, "GREEN": 0, "REFACTOR": 0}
        convergence_info: dict[str, Any] = {
            "active": False,
            "units": [],
            "total_tasks": 0,
            "completed_tasks": 0,
            "pending_tasks": 0,
            "drift_categories": [],
        }
        current_unit_name: str | None = None
        tasks_path = change_dir / "tasks.md"
        if tasks_path.is_file():
            raw_text = tasks_path.read_text(encoding="utf-8")
            clean_text = re.sub(r"<!--.*?-->", "", raw_text, flags=re.DOTALL)
            for line in clean_text.splitlines():
                line_stripped = line.strip()
                unit_match = re.match(r"^##\s+\d+\.\s+Unit:\s*([A-Za-z0-9_-]+)", line_stripped)
                if unit_match:
                    current_unit_name = unit_match.group(1).strip()
                    if current_unit_name.startswith("Convergence_"):
                        convergence_info["active"] = True
                        if current_unit_name not in convergence_info["units"]:
                            convergence_info["units"].append(current_unit_name)

                m = self.TASK_CHECKBOX_PATTERN.match(line_stripped)
                if m:
                    is_done = (m.group(1).lower() == "x")
                    desc = m.group(2).strip()
                    triad = None
                    if "[RED]" in desc or "[PHASE: RED]" in desc:
                        triad = "RED"
                        triads["RED"] += 1
                    elif "[GREEN]" in desc or "[PHASE: GREEN]" in desc:
                        triad = "GREEN"
                        triads["GREEN"] += 1
                    elif "[REFACTOR]" in desc or "[PHASE: REFACTOR]" in desc:
                        triad = "REFACTOR"
                        triads["REFACTOR"] += 1

                    is_convergence_task = False
                    if current_unit_name and current_unit_name.startswith("Convergence_"):
                        is_convergence_task = True
                    conv_match = re.search(r"\[CONVERGENCE:\s*([a-zA-Z_-]+)\]", desc)
                    if conv_match:
                        is_convergence_task = True
                        drift_cat = conv_match.group(1).lower()
                        if drift_cat not in convergence_info["drift_categories"]:
                            convergence_info["drift_categories"].append(drift_cat)

                    if is_convergence_task:
                        convergence_info["active"] = True
                        convergence_info["total_tasks"] += 1
                        if is_done:
                            convergence_info["completed_tasks"] += 1
                        else:
                            convergence_info["pending_tasks"] += 1

                    tasks.append({
                        "raw": line_stripped,
                        "description": desc,
                        "completed": is_done,
                        "triad": triad,
                    })

        total_tasks = len(tasks)
        completed_tasks = sum(1 for t in tasks if t["completed"])
        progress_percent = round((completed_tasks / total_tasks * 100), 1) if total_tasks > 0 else 0.0

        return {
            "change_id": change_id,
            "artifacts": artifacts,
            "verdict": verdict,
            "tasks": tasks,
            "total_tasks": total_tasks,
            "completed_tasks": completed_tasks,
            "progress_percent": progress_percent,
            "triads": triads,
            "convergence": convergence_info,
        }

    def _scan_changes(self) -> dict[str, dict[str, Any]]:
        """Scan all active changes in configured changes directory."""
        changes_dir = self.changes_dir
        if not changes_dir.is_dir():
            return {}

        results: dict[str, dict[str, Any]] = {}
        for entry in sorted(changes_dir.iterdir()):
            if entry.is_dir() and entry.name != "archive" and self.CHANGE_ID_PATTERN.match(entry.name):
                try:
                    results[entry.name] = self.get_change_detail(entry.name)
                except Exception:
                    continue
        return results

    def _scan_living_specs(self) -> dict[str, dict[str, Any]]:
        """Scan living specifications in configured specs directory."""
        specs_dir = self.specs_dir
        if not specs_dir.is_dir():
            return {}

        results: dict[str, dict[str, Any]] = {}
        for entry in sorted(specs_dir.iterdir()):
            spec_file: Path | None = None
            cap_name = entry.name

            if entry.is_dir():
                candidate = entry / "spec.md"
                if candidate.is_file():
                    spec_file = candidate
            elif entry.is_file() and entry.suffix == ".md":
                spec_file = entry
                cap_name = entry.stem

            if spec_file and spec_file.is_file():
                content = spec_file.read_text(encoding="utf-8")
                reqs = len(self.REQ_PATTERN.findall(content))
                scens = len(self.SCENARIO_PATTERN.findall(content))
                results[cap_name] = {
                    "capability": cap_name,
                    "requirements": reqs,
                    "scenarios": scens,
                    "path": str(spec_file.relative_to(self.target_dir)),
                }

        return results

    def _scan_legacy_specs(self) -> list[str]:
        """Scan unarchived specifications in legacy specs/ directory."""
        if self.spec_root == "specs":
            return []

        legacy_dir = self.target_dir / "specs"
        if not legacy_dir.is_dir():
            return []

        excluded_names = {"readme.md", "index.md", "agents.md"}
        legacy_files: list[str] = []
        for f in sorted(legacy_dir.iterdir()):
            if f.is_file() and f.suffix == ".md":
                if f.name.lower() not in excluded_names:
                    legacy_files.append(f.name)
        return legacy_files

    def _scan_index(self) -> dict[str, Any]:
        """Scan and extract status metadata from <spec_root>/index.yml."""
        index_info: dict[str, Any] = {
            "exists": False,
            "path": f"{self.spec_root}/index.yml",
            "specs_count": 0,
            "always_read": [],
        }
        try:
            idx_mgr = MySpecIndexManager(repo_root=self.target_dir)
            if idx_mgr.index_path.is_file():
                idx_data = idx_mgr.read_index()
                try:
                    rel_path = str(idx_mgr.index_path.relative_to(self.target_dir)).replace("\\", "/")
                except ValueError:
                    rel_path = str(idx_mgr.index_path).replace("\\", "/")
                index_info = {
                    "exists": True,
                    "path": rel_path,
                    "specs_count": len(idx_data.get("specs", [])),
                    "always_read": idx_data.get("always_read", []),
                }
        except Exception:
            pass
        return index_info

    def _scan_constitution(self) -> dict[str, Any]:
        """Scan <spec_root>/Constitution.md and <spec_root>/constitution/ for diagnostic telemetry.

        Returns:
            Dictionary containing exists, path, version, active_areas, not_applicable_areas, rules_count, and valid.
        """
        const_file = self.config_mgr.get_constitution_file()
        const_dir = self.config_mgr.get_constitution_dir()
        try:
            rel_path = str(const_file.relative_to(self.target_dir)).replace("\\", "/")
        except ValueError:
            rel_path = f"{self.spec_root}/Constitution.md"

        info: dict[str, Any] = {
            "exists": False,
            "path": rel_path,
            "version": None,
            "active_areas": [],
            "not_applicable_areas": [],
            "rules_count": 0,
            "valid": False,
        }
        if not const_file.is_file() or const_file.is_symlink():
            return info

        info["exists"] = True
        try:
            root_text = const_file.read_text(encoding="utf-8")
            m_ver = re.search(r'^version:\s*["\']?([^"\'\n]+)["\']?', root_text, re.MULTILINE)
            if m_ver:
                info["version"] = m_ver.group(1).strip()
        except Exception:
            pass

        rule_re = re.compile(r"^-\s+\*\*(?:AR|BC|UI|DATA|API|TEST|SEC|SDD)-\d{3}\*\*:\s+")
        if const_dir.is_dir() and not const_dir.is_symlink():
            for area_dir in sorted(const_dir.iterdir()):
                if not area_dir.is_dir() or area_dir.is_symlink():
                    continue
                idx_file = area_dir / "index.md"
                status_val = "active"
                if idx_file.is_file():
                    try:
                        idx_text = idx_file.read_text(encoding="utf-8")
                        m_st = re.search(r'^status:\s*["\']?([^"\'\n]+)["\']?', idx_text, re.MULTILINE)
                        if m_st:
                            status_val = m_st.group(1).strip()
                    except Exception:
                        pass
                if status_val == "not-applicable":
                    info["not_applicable_areas"].append(area_dir.name)
                else:
                    info["active_areas"].append(area_dir.name)

                for mf in sorted(area_dir.glob("*.md")):
                    if mf.name == "index.md" or mf.is_symlink():
                        continue
                    try:
                        for line in mf.read_text(encoding="utf-8").splitlines():
                            if rule_re.match(line.strip()):
                                info["rules_count"] += 1
                    except Exception:
                        pass

        # Validate tree if MySpecValidator is importable
        valid = len(info["active_areas"]) + len(info["not_applicable_areas"]) == 8 and info["rules_count"] > 0
        try:
            val_dir = str(Path(__file__).resolve().parents[2] / "myspec-validate" / "scripts")
            if val_dir not in sys.path:
                sys.path.insert(0, val_dir)
            from myspec_validate import MySpecValidator  # type: ignore

            errs, _ = MySpecValidator(repo_root=self.target_dir)._validate_constitution_tree(require_exists=True)
            valid = len(errs) == 0
        except Exception:
            pass
        info["valid"] = valid
        return info

    def _scan_hygiene(self) -> dict[str, Any]:
        """Scan debug/ for unredacted HAR or sensitive environment files."""
        debug_dir = self.debug_dir
        warnings: list[str] = []

        if debug_dir.is_dir():
            for item in debug_dir.rglob("*"):
                if item.is_file():
                    name_lower = item.name.lower()
                    if item.suffix.lower() == ".har":
                        warnings.append(f"Potentially sensitive capture file in debug/: {item.name}")
                    elif ".env" in name_lower:
                        warnings.append(f"Potentially sensitive environment file in debug/: {item.name}")

        return {
            "status": "Warning" if warnings else "Clean",
            "warnings": warnings,
        }

    def get_status(self) -> dict[str, Any]:
        """Aggregate complete status for the target workspace."""
        legacy_specs = self._scan_legacy_specs()

        if not self.is_initialized():
            return {
                "initialized": False,
                "message": f"Workspace is not initialized. Run /myspec-init to set up {self.spec_root}/.",
                "schema": None,
                "root": str(self.spec_root_dir),
                "active_changes_count": 0,
                "changes": {},
                "living_specs_count": 0,
                "living_specs": {},
                "legacy_specs_count": len(legacy_specs),
                "legacy_specs": legacy_specs,
                "constitution": self._scan_constitution(),
                "hygiene": {"status": "Clean", "warnings": []},
            }

        schema = self.get_schema()
        changes = self._scan_changes()
        living_specs = self._scan_living_specs()
        hygiene = self._scan_hygiene()
        index_info = self._scan_index()
        constitution_info = self._scan_constitution()

        return {
            "initialized": True,
            "schema": schema,
            "root": str(self.spec_root_dir),
            "index": index_info,
            "constitution": constitution_info,
            "active_changes_count": len(changes),
            "changes": changes,
            "living_specs_count": len(living_specs),
            "living_specs": living_specs,
            "legacy_specs_count": len(legacy_specs),
            "legacy_specs": legacy_specs,
            "hygiene": hygiene,
        }

    def get_status_json(self, indent: int = 2) -> str:
        """Return the aggregated status formatted as structured JSON."""
        return json.dumps(self.get_status(), indent=indent)

    def format_console_report(self) -> str:
        """Format a human-readable console status report with D10 next-step handoff."""
        status = self.get_status()
        lines: list[str] = [
            "=== MySpec Workspace Status ===",
        ]

        if not status["initialized"]:
            lines.append("Status: UNINITIALIZED")
            lines.append(f"Notice: {status.get('message', '')}")
            if status["legacy_specs"]:
                lines.append(f"\nLegacy Specifications ({len(status['legacy_specs'])}):")
                for s in status["legacy_specs"]:
                    lines.append(f"  - {s}")
            lines.append("\n---")
            lines.append("> [!TIP]")
            lines.append("> **Next Steps**:")
            lines.append("> - Initialize workspace: `/myspec-init`")
            return "\n".join(lines)

        lines.append(f"Active Schema: {status['schema']}")
        lines.append(f"Root: {status['root']}")
        idx = status.get("index", {})
        if idx.get("exists"):
            lines.append(
                f"Specification Index: {idx['path']} ({idx['specs_count']} specs, "
                f"{len(idx.get('always_read', []))} always_read)"
            )
        lines.append("")

        try:
            changes_rel = str(self.changes_dir.relative_to(self.target_dir)).replace("\\", "/")
        except ValueError:
            changes_rel = str(self.changes_dir).replace("\\", "/")

        try:
            specs_rel = str(self.specs_dir.relative_to(self.target_dir)).replace("\\", "/")
        except ValueError:
            specs_rel = str(self.specs_dir).replace("\\", "/")

        # Active changes
        changes = status["changes"]
        lines.append(f"Active Changes ({len(changes)}):")
        if not changes:
            lines.append(f"  None active in {changes_rel}/")
        else:
            for cid, cdata in changes.items():
                t_total = cdata["total_tasks"]
                t_done = cdata["completed_tasks"]
                pct = cdata["progress_percent"]
                triads = cdata["triads"]
                verdict = cdata["verdict"]
                conv_info = cdata.get("convergence", {})
                conv_suffix = ""
                if conv_info.get("active"):
                    conv_suffix = f" | Convergence: {conv_info['completed_tasks']}/{conv_info['total_tasks']} ({', '.join(conv_info['drift_categories'])})"
                lines.append(
                    f"  [{cid}] {t_done}/{t_total} tasks ({pct}%) | "
                    f"Triads: {triads['RED']} RED, {triads['GREEN']} GREEN, {triads['REFACTOR']} REFACTOR | "
                    f"Review: {verdict}{conv_suffix}"
                )

        lines.append("")

        # Living specs
        living = status["living_specs"]
        lines.append(f"Living Specifications ({len(living)}):")
        if not living:
            lines.append(f"  None active in {specs_rel}/")
        else:
            for cap, data in living.items():
                lines.append(f"  [{cap}] {data['requirements']} requirements, {data['scenarios']} scenarios")

        lines.append("")

        # Legacy specs
        legacy = status["legacy_specs"]
        lines.append(f"Legacy Specifications ({len(legacy)}):")
        if not legacy:
            lines.append("  None pending in specs/")
        else:
            for s in legacy:
                lines.append(f"  - {s}")

        lines.append("")

        # Hygiene
        hygiene = status["hygiene"]
        if hygiene["status"] == "Clean":
            lines.append("Hygiene Status: Clean (0 warnings)")
        else:
            lines.append(f"Hygiene Status: Warning ({len(hygiene['warnings'])} warnings)")
            for w in hygiene["warnings"]:
                lines.append(f"  [!] {w}")

        lines.append("\n---")
        lines.append("> [!TIP]")
        lines.append("> **Next Steps**:")
        lines.append(f"> - To implement tasks in an active change: `/myspec-apply @{changes_rel}/<id>`")
        lines.append("> - To validate workspace integrity: `/myspec-validate`")

        return "\n".join(lines)


def main() -> None:
    """CLI entrypoint for MySpecStatusReporter."""
    parser = argparse.ArgumentParser(
        description="MySpec Workspace Diagnostics & Living Specification Status Reporter",
    )
    parser.add_argument(
        "--target",
        type=str,
        default=".",
        help="Target project directory (default: current working directory)",
    )
    parser.add_argument(
        "--change",
        type=str,
        help="Optional single change identifier to inspect in detail",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output diagnostics in structured JSON format",
    )
    parser.add_argument(
        "--detect-delta",
        action="store_true",
        help="Detect unaligned source code modifications against living specifications",
    )
    parser.add_argument(
        "--deep-scan",
        action="store_true",
        help="Perform deep comparison across all source files and living specs",
    )

    args = parser.parse_args()

    try:
        reporter = MySpecStatusReporter(target_dir=args.target)
        if args.detect_delta:
            if args.deep_scan and hasattr(reporter.delta_scanner, "scan_deep"):
                res = reporter.delta_scanner.scan_deep()
            else:
                res = reporter.delta_scanner.scan()
            if args.json:
                print(json.dumps(res, indent=2))
            else:
                if res.get("warning"):
                    print(f"[!] Warning: {res['warning']}")
                if res["status"] == "clean":
                    print("[OK] Codebase delta scan: clean. No uncommitted source changes or unaligned commits detected.")
                elif res["status"] == "delta_detected":
                    print("=== MySpec Delta Changes Detected ===")
                    if res["uncommitted_files"]:
                        print("\nUncommitted modified files:")
                        for f in res["uncommitted_files"]:
                            print(f"  - {f}")
                    if res["recent_commits"]:
                        print("\nRecent unaligned commits:")
                        for c in res["recent_commits"]:
                            print(f"  - {c['commit']}: {c['message']} ({', '.join(c['files'])})")
                    print("\nRecommendations:")
                    for r in res["recommendations"]:
                        print(f"  * {r}")
                else:
                    print(f"Git unavailable: {res.get('error', 'Unknown error')}", file=sys.stderr)
            return

        if args.change:
            detail = reporter.get_change_detail(args.change)
            if args.json:
                print(json.dumps(detail, indent=2))
            else:
                print(f"=== Change Detail: {detail['change_id']} ===")
                print(f"Progress: {detail['completed_tasks']}/{detail['total_tasks']} tasks ({detail['progress_percent']}%)")
                print(f"Security Verdict: {detail['verdict']}")
                if detail.get("convergence", {}).get("active"):
                    conv = detail["convergence"]
                    cats = ", ".join(conv["drift_categories"]) if conv["drift_categories"] else "none"
                    print(f"Convergence: Active ({conv['completed_tasks']}/{conv['total_tasks']} tasks in {len(conv['units'])} units) | Categories: {cats}")
                print("Artifacts:")
                for art, present in detail["artifacts"].items():
                    print(f"  - {art}: {'Present' if present else 'Missing'}")
                print("\nTasks:")
                for t in detail["tasks"]:
                    status_mark = "[x]" if t["completed"] else "[ ]"
                    triad_mark = f" [{t['triad']}]" if t["triad"] else ""
                    print(f"  {status_mark}{triad_mark} {t['description']}")
        else:
            if args.json:
                print(reporter.get_status_json())
            else:
                print(reporter.format_console_report())
    except Exception as exc:
        if args.json:
            print(json.dumps({"error": str(exc)}, indent=2))
        else:
            print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
