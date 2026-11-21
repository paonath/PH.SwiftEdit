#!/usr/bin/env python3
"""MySpec Central Configuration Engine (scripts/myspec_config.py - Spec 030).

Provides centralized configuration loading, validation, anti-path-traversal protection,
and auto-discovery of specification workspaces for the MySpec suite.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any, Dict, Optional


class MySpecConfigManager:
    """Central configuration and path resolution manager for MySpec."""

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

    _instance: Optional[MySpecConfigManager] = None

    def __init__(self, repo_root: Path | str | None = None) -> None:
        if repo_root is None:
            self.repo_root = Path.cwd().resolve()
        else:
            raw_str = str(repo_root)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in repo_root: {repo_root}")
            self.repo_root = Path(repo_root).resolve()

        self._resolved_config: Optional[dict[str, Any]] = None

    @classmethod
    def get_instance(cls, repo_root: Path | str | None = None) -> MySpecConfigManager:
        """Retrieve singleton or cached instance for given repo_root."""
        if cls._instance is None or (repo_root is not None and cls._instance.repo_root != Path(repo_root).resolve()):
            cls._instance = cls(repo_root=repo_root)
        return cls._instance

    @classmethod
    def reset_instance(cls) -> None:
        """Reset cached singleton instance (useful for testing)."""
        cls._instance = None

    def get_config_file_path(self) -> Path:
        """Return the absolute path to .myspec.config.json."""
        return self.repo_root / self.CONFIG_FILE_NAME

    def has_config_file(self) -> bool:
        """Check whether .myspec.config.json exists in repo root."""
        return self.get_config_file_path().is_file()

    def sanitize_relative_path(self, path_str: str, key_name: str) -> str:
        """Validate that a path string is relative and contains no path traversal (CWE-22)."""
        if not path_str or not isinstance(path_str, str):
            raise ValueError(f"Invalid path value for '{key_name}': must be a non-empty string.")

        clean = path_str.strip().replace("\\", "/")
        if clean.startswith("/") or clean.startswith("\\"):
            raise ValueError(f"Security error: Absolute path detected in '{key_name}': '{path_str}'")

        parts = clean.split("/")
        if ".." in parts:
            raise ValueError(f"Security error: Path traversal ('..') detected in '{key_name}': '{path_str}'")

        # Resolve against repo_root and verify containment
        resolved = (self.repo_root / clean).resolve()
        try:
            resolved.relative_to(self.repo_root)
        except ValueError:
            raise ValueError(f"Security error: Path '{path_str}' in '{key_name}' escapes repository root.")

        return clean

    def resolve_config(self, force_reload: bool = False) -> dict[str, Any]:
        """Load and validate configuration from .myspec.config.json or trigger auto-discovery."""
        if self._resolved_config is not None and not force_reload:
            return self._resolved_config

        config_path = self.get_config_file_path()

        if config_path.is_file():
            try:
                raw_text = config_path.read_text(encoding="utf-8")
                data = json.loads(raw_text)
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON in .myspec.config.json: {e}") from e
            except Exception as e:
                raise ValueError(f"Failed to read .myspec.config.json: {e}") from e

            if not isinstance(data, dict):
                raise ValueError("Root element of .myspec.config.json must be a JSON object.")

            spec_root = data.get("spec_root")
            if not spec_root or not isinstance(spec_root, str):
                raise ValueError("Missing or invalid 'spec_root' in .myspec.config.json.")

            spec_root_clean = self.sanitize_relative_path(spec_root, "spec_root")
            if spec_root_clean not in self.ALLOWED_SPEC_ROOTS:
                raise ValueError(
                    f"Invalid spec_root '{spec_root}'. Must be one of: {sorted(self.ALLOWED_SPEC_ROOTS)}"
                )

            # Determine baseline defaults
            defaults = dict(self.DEFAULT_PATHS[spec_root_clean])

            # Apply custom path overrides if present
            paths_obj = data.get("paths", {})
            if paths_obj is not None:
                if not isinstance(paths_obj, dict):
                    raise ValueError("'paths' property in .myspec.config.json must be an object.")
                for k, v in paths_obj.items():
                    if isinstance(v, str):
                        clean_subpath = self.sanitize_relative_path(v, f"paths.{k}")
                        defaults[k] = clean_subpath

            resolved = {
                "spec_root": spec_root_clean,
                "paths": defaults,
                "source": "file",
                "config_file": str(config_path),
                "suggested_save": False,
            }
        else:
            # Auto-discovery fallback
            discovered_root = self.auto_discover_spec_root()
            resolved = {
                "spec_root": discovered_root,
                "paths": dict(self.DEFAULT_PATHS[discovered_root]),
                "source": "auto_discovered",
                "config_file": None,
                "suggested_save": True,
            }

        self._resolved_config = resolved
        return resolved

    def auto_discover_spec_root(self) -> str:
        """Scan repository for specs/ and openspec/ and resolve according to document counts."""
        openspec_dir = self.repo_root / "openspec"
        specs_dir = self.repo_root / "specs"

        has_openspec = openspec_dir.is_dir()
        has_specs = specs_dir.is_dir()

        if has_openspec and not has_specs:
            return "openspec"
        if has_specs and not has_openspec:
            return "specs"
        if not has_openspec and not has_specs:
            # Default to openspec if neither exists yet
            return "openspec"

        # Both exist: count .md specification documents
        openspec_count = self._count_spec_documents(openspec_dir)
        specs_count = self._count_spec_documents(specs_dir)

        if specs_count > openspec_count:
            return "specs"
        if openspec_count > specs_count:
            return "openspec"

        # Exact tie: openspec wins
        return "openspec"

    def _count_spec_documents(self, root_dir: Path) -> int:
        """Count markdown specification documents in a directory tree, ignoring hidden folders."""
        count = 0
        if not root_dir.is_dir():
            return 0

        # Pattern for spec documents
        for dirpath, dirnames, filenames in os.walk(str(root_dir)):
            # Filter out hidden or cache directories
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in {"node_modules", "bin", "obj", "__pycache__"}]
            for fname in filenames:
                if fname.endswith(".md"):
                    # Check if it looks like a spec or task/proposal file
                    count += 1
        return count

    # Convenience absolute path accessors
    def get_spec_root(self) -> str:
        """Return the resolved spec root string ('openspec' or 'specs')."""
        return self.resolve_config()["spec_root"]

    def get_specs_dir(self) -> Path:
        """Return the absolute path to the living specs / specs directory."""
        return self.repo_root / self.resolve_config()["paths"]["specs"]

    def get_changes_dir(self) -> Path:
        """Return the absolute path to the changes directory."""
        return self.repo_root / self.resolve_config()["paths"]["changes"]

    def get_archive_dir(self) -> Path:
        """Return the absolute path to the archive directory."""
        return self.repo_root / self.resolve_config()["paths"]["archive"]

    def get_briefs_dir(self) -> Path:
        """Return the absolute path to the briefs directory."""
        return self.repo_root / self.resolve_config()["paths"]["briefs"]

    def get_debug_dir(self) -> Path:
        """Return the absolute path to the debug directory."""
        return self.repo_root / self.resolve_config()["paths"]["debug"]

    def get_index_file(self) -> Path:
        """Return the absolute path to <spec_root>/index.yml."""
        return self.repo_root / self.get_spec_root() / "index.yml"

    def get_constitution_file(self) -> Path:
        """Return the confined absolute path to <spec_root>/Constitution.md.

        Returns:
            Absolute Path to the root Constitution gateway file.

        Raises:
            ValueError: If configured constitution_file contains path traversal or escapes repo_root.
        """
        return self.repo_root / self.resolve_config()["paths"]["constitution_file"]

    def get_constitution_dir(self) -> Path:
        """Return the confined absolute path to <spec_root>/constitution.

        Returns:
            Absolute Path to the 2-level progressive-disclosure constitution directory.

        Raises:
            ValueError: If configured constitution_dir contains path traversal or escapes repo_root.
        """
        return self.repo_root / self.resolve_config()["paths"]["constitution_dir"]

    def init_config(self, spec_root: str, force: bool = False) -> Path:
        """Create or overwrite .myspec.config.json with specified root."""
        clean_root = self.sanitize_relative_path(spec_root, "spec_root")
        if clean_root not in self.ALLOWED_SPEC_ROOTS:
            raise ValueError(f"Invalid spec_root: '{spec_root}'. Must be one of {sorted(self.ALLOWED_SPEC_ROOTS)}")

        config_path = self.get_config_file_path()
        if config_path.exists() and not force:
            raise FileExistsError(f"Config file already exists at {config_path}. Use force=True to overwrite.")

        content = {
            "spec_root": clean_root,
        }
        config_path.write_text(json.dumps(content, indent=2) + "\n", encoding="utf-8")
        self.resolve_config(force_reload=True)
        return config_path


def get_config(repo_root: Path | str | None = None) -> dict[str, Any]:
    """Helper function to quickly obtain resolved configuration dictionary."""
    return MySpecConfigManager.get_instance(repo_root=repo_root).resolve_config()
