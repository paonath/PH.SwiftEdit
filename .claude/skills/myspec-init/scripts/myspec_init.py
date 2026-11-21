#!/usr/bin/env python3
"""MySpec Scaffolding Engine (myspec-init).

Bootstraps the openspec/ workspace, injects the custom tdd-spec-driven schema,
authoring config.yaml, auxiliary folders, and idempotent .gitignore rules.
Supports both pure Python scaffolding and delegation to the @fission-ai/openspec CLI.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

def _resolve_shared_scripts() -> None:
    current_dir = Path(__file__).resolve().parent
    skills_root = current_dir.parent.parent
    primary = [
        current_dir,
        skills_root / "myspec-init" / "scripts",
    ]
    for cand in reversed(primary):
        if cand.is_dir():
            cand_str = str(cand.resolve())
            if cand_str not in sys.path:
                sys.path.insert(0, cand_str)

_resolve_shared_scripts()

try:
    from myspec_config import MySpecConfigManager
except ImportError:
    try:
        from scripts.myspec_config import MySpecConfigManager
    except ImportError:
        MySpecConfigManager = None

try:
    from myspec_index import MySpecIndexManager
except ImportError:
    try:
        from scripts.myspec_index import MySpecIndexManager
    except ImportError:
        MySpecIndexManager = None


class MySpecInitializer:
    """Scaffolding and initialization engine for MySpec workspaces."""

    SECURITY_GITIGNORE_RULES = [
        "openspec/debug/**",
        "specs/debug/**",
        "**/*.har",
        "openspec/**/.env*",
        "specs/**/.env*",
        ".tmp/",
    ]
    SAFE_PLACEHOLDER_VALUE_RE = re.compile(r"^[A-Za-z0-9 _\-\./()+]{1,80}$")
    SAFE_PLACEHOLDER_KEY_RE = re.compile(r"^[A-Z0-9_]{2,40}$")
    LOCKED_ACTIVE_STATUS_KEYS = frozenset({"STATUS_TESTING", "STATUS_SECURITY", "STATUS_SDD"})

    def __init__(self, target_dir: Path | str | None = None) -> None:
        if target_dir is None:
            self.target_dir = Path.cwd().resolve()
        else:
            raw_str = str(target_dir)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in target directory: {target_dir}")
            self.target_dir = Path(target_dir).resolve()

        # Locate master template source in hermetic myspec-init resources
        script_dir = Path(__file__).resolve().parent
        bundled_schema = script_dir.parent / "resources" / "tdd-spec-driven"
        if not bundled_schema.is_dir():
            # Dynamic discovery across target directory
            for cand in self.target_dir.glob("**/myspec-init/resources/tdd-spec-driven"):
                if cand.is_dir():
                    bundled_schema = cand.resolve()
                    break
        self.master_schema_dir = bundled_schema

    def update_gitignore(self) -> list[str]:
        """Idempotently add security rules to target .gitignore. Returns rules added."""
        gitignore_path = self.target_dir / ".gitignore"
        existing_lines: list[str] = []
        if gitignore_path.is_file():
            existing_lines = gitignore_path.read_text(encoding="utf-8").splitlines()

        added_rules: list[str] = []
        clean_existing = {line.strip() for line in existing_lines}

        lines_to_append: list[str] = []
        for rule in self.SECURITY_GITIGNORE_RULES:
            if rule not in clean_existing:
                lines_to_append.append(rule)
                added_rules.append(rule)

        if lines_to_append:
            with open(gitignore_path, "a", encoding="utf-8") as f:
                if existing_lines and existing_lines[-1].strip() != "":
                    f.write("\n")
                f.write("# MySpec security exclusions\n")
                for rule in lines_to_append:
                    f.write(f"{rule}\n")

        return added_rules

    def inject_schema(self, force: bool = False) -> Path:
        """Inject master tdd-spec-driven schema and templates into target .openspec/schemas/."""
        dest_schema_dir = self.target_dir / ".openspec" / "schemas" / "tdd-spec-driven"
        dest_templates_dir = dest_schema_dir / "templates"

        if not self.master_schema_dir.is_dir():
            raise FileNotFoundError(f"Master schema directory not found at {self.master_schema_dir}")

        dest_schema_dir.mkdir(parents=True, exist_ok=True)
        dest_templates_dir.mkdir(parents=True, exist_ok=True)

        # Copy schema.yaml
        schema_src = self.master_schema_dir / "schema.yaml"
        schema_dest = dest_schema_dir / "schema.yaml"
        if force or not schema_dest.exists():
            shutil.copy2(schema_src, schema_dest)

        # Copy templates
        templates_src = self.master_schema_dir / "templates"
        if templates_src.is_dir():
            for t_file in templates_src.iterdir():
                if t_file.is_file():
                    t_dest = dest_templates_dir / t_file.name
                    if force or not t_dest.exists():
                        shutil.copy2(t_file, t_dest)

        return dest_schema_dir

    def _assert_no_symlink_ancestry(self, candidate: Path) -> None:
        """Verify candidate and every ancestor up to target_dir are non-symlinks (CWE-22)."""
        curr = candidate
        while curr != self.target_dir and curr != curr.parent:
            if curr.is_symlink():
                raise ValueError(f"Symlink target rejected at {curr} (CWE-22).")
            curr = curr.parent

    def detect_project_stack(self, spec_root: str = "openspec") -> dict[str, str]:
        """Auto-detect repository stack markers and return sanitized Bare-Bones template defaults.

        Args:
            spec_root: Active specification root ('openspec' or 'specs').

        Returns:
            Mapping of placeholder keys to CWE-77 safe default string values.
        """
        today_str = datetime.date.today().isoformat()
        raw_name = re.sub(r"[^A-Za-z0-9 _\-\./()+]", " ", self.target_dir.name).strip() or "Project"

        has_dotnet = any(self.target_dir.glob("*.sln")) or any(self.target_dir.glob("*.slnx")) or any(self.target_dir.glob("*.csproj"))
        has_angular = (self.target_dir / "angular.json").is_file()
        has_node = (self.target_dir / "package.json").is_file()
        has_python = (self.target_dir / "pyproject.toml").is_file() or any(self.target_dir.glob("tests/**/*.py"))
        has_sql = any(self.target_dir.glob("**/*.sql")) or (self.target_dir / "Migrations").is_dir()

        stacks: list[str] = []
        if has_dotnet:
            stacks.append(".NET C#")
        if has_angular:
            stacks.append("Angular Standalone Signals")
        elif has_node:
            stacks.append("TypeScript Node.js")
        if has_python:
            stacks.append("Python 3.10+")
        primary_stack = " + ".join(stacks) if stacks else "Polyglot Software Workspace"

        return {
            "PROJECT_NAME": raw_name[:80],
            "CONSTITUTION_VERSION": "1.0.0",
            "RATIFIED_DATE": today_str,
            "LAST_AMENDED_DATE": today_str,
            "PRIMARY_STACK": primary_stack[:80],
            "SPEC_ROOT": spec_root,
            "STATUS_ARCHITECTURE": "active",
            "STATUS_DOMAIN": "active" if (has_dotnet or has_python or has_node) else "not-applicable",
            "STATUS_UI_UX": "active" if (has_angular or has_node) else "not-applicable",
            "STATUS_DATA": "active" if (has_dotnet or has_sql) else "not-applicable",
            "STATUS_API": "active" if (has_dotnet or has_angular or has_node) else "not-applicable",
            "SYNC_IMPACT_SUMMARY": "AR-001..SDD-010 initial Bare-Bones scaffold",
            "SYNC_IMPACT_STATUS": "index.yml synced",
            "MODULE_ROOT_PATH": "src/" if (has_dotnet or has_node) else "scripts/",
            "CORE_MODULE_PROJECTS": "SharedKernel, Domain, ReadModel, Infrastructure, Facade, Tests",
            "KISS_LITE_PROFILE": "Facade, SharedKernel, Persistence, Tests",
            "DOMAIN_RING_NAME": "Domain and SharedKernel",
            "ADAPTER_RING_NAMES": "Facade, Infrastructure, ReadModel",
            "MODULE_REGISTRATION_CONTRACT": "IModule",
            "CLOCK_ABSTRACTION": "TimeProvider",
            "BOUNDED_CONTEXT_MAP": "Core and Supporting Bounded Contexts",
            "NEGATIVE_OWNERSHIP_SUMMARY": "Zero cross-context state mutation or policy invention",
            "EXTERNAL_DECISION_REFS": "ExternalDecisionId, ExternalIdentityId",
            "FRONTEND_STACK": "Angular Standalone Signals" if has_angular else "Modern Web UI",
            "CSS_TOKEN_PREFIX": "--app-",
            "UI_REACTIVITY_MODEL": "Angular Signals with OnPush",
            "UI_FORM_PATTERN": "Strictly Typed Reactive Forms",
            "STORAGE_ENGINES": "Relational SQL and Event/Document Store",
            "WRITE_MODEL_PATTERN": "Transactional Aggregate Write Path",
            "READ_MODEL_PATTERN": "Idempotent NoTracking ReadModel",
            "API_TRANSPORT_STYLE": "Versioned HTTP /v1 Endpoints",
            "MESSAGING_TRANSPORT": "Outbox Integration Event Bus",
            "TEST_FRAMEWORK": "xUnit / unittest / Vitest",
            "ARCH_FITNESS_TOOL": "NetArchTest / myspec_validate.py",
            "AUTHN_AUTHZ_MECHANISM": "JWT Bearer OIDC Policy Authorization",
            "TRANSPORT_CORS_POLICY": "TLS 1.2+ HSTS and Named CORS Origins",
        }

    def scaffold_constitution(
        self,
        force: bool = False,
        overrides: dict[str, str] | None = None,
        spec_root: str = "openspec",
    ) -> dict[str, Any]:
        """Render the 30 Bare-Bones Constitution files into <spec_root>/ and pin Constitution.md in index.yml.

        Args:
            force: Overwrite existing constitutional files on disk when True.
            overrides: Optional mapping of placeholder token names to sanitized replacement strings.
            spec_root: Target specification root ('openspec' or 'specs').

        Returns:
            Dictionary reporting constitution_file, constitution_dir, written_count, skipped_count, and written_files.

        Raises:
            FileNotFoundError: If the master constitution-templates bundle is missing.
            ValueError: If spec_root, overrides (CWE-77), or target symlinks/containment (CWE-22) fail validation.
        """
        if spec_root not in {"openspec", "specs"}:
            raise ValueError(f"Invalid spec_root '{spec_root}'. Must be 'openspec' or 'specs'.")

        templates_root = self.master_schema_dir / "constitution-templates"
        if not templates_root.is_dir():
            raise FileNotFoundError(f"Constitution templates directory not found at {templates_root}")

        values = self.detect_project_stack(spec_root=spec_root)
        if overrides:
            for raw_k, raw_v in overrides.items():
                key = str(raw_k).strip()
                val = str(raw_v)
                if not self.SAFE_PLACEHOLDER_KEY_RE.match(key):
                    raise ValueError(f"Invalid placeholder key '{key}' (CWE-77).")
                if key in self.LOCKED_ACTIVE_STATUS_KEYS and val != "active":
                    raise ValueError(f"Security floor violation: '{key}' cannot be set to '{val}'.")
                if "\n" in val or "\r" in val or not self.SAFE_PLACEHOLDER_VALUE_RE.match(val):
                    raise ValueError(
                        f"Invalid placeholder override for '{key}': fails CWE-77 safe value pattern."
                    )
                values[key] = val

        for status_key in ("STATUS_ARCHITECTURE", "STATUS_DOMAIN", "STATUS_UI_UX", "STATUS_DATA", "STATUS_API"):
            if values.get(status_key) not in {"active", "kiss-lite", "not-applicable"}:
                raise ValueError(f"Invalid status '{values.get(status_key)}' for '{status_key}'.")

        spec_root_dir = (self.target_dir / spec_root).resolve()
        if not spec_root_dir.is_relative_to(self.target_dir):
            raise ValueError("Resolved spec_root escapes target repository (CWE-22).")
        if spec_root_dir.is_symlink():
            raise ValueError(f"Symlink rejected at {spec_root_dir} (CWE-22).")
        spec_root_dir.mkdir(parents=True, exist_ok=True)

        written_files: list[str] = []
        skipped_files: list[str] = []

        for src_file in sorted(templates_root.rglob("*.md")):
            if src_file.is_symlink():
                raise ValueError(f"Symlink template rejected: {src_file} (CWE-22).")
            rel_sub = src_file.relative_to(templates_root)
            dest_file = spec_root_dir / rel_sub
            self._assert_no_symlink_ancestry(dest_file)

            resolved_parent = dest_file.parent.resolve()
            if not resolved_parent.is_relative_to(spec_root_dir):
                raise ValueError(f"Destination path '{dest_file}' escapes {spec_root_dir} (CWE-22).")

            dest_file.parent.mkdir(parents=True, exist_ok=True)
            if dest_file.exists() and not force:
                skipped_files.append(str(dest_file.relative_to(self.target_dir)))
                continue

            rendered = src_file.read_text(encoding="utf-8")
            for k, v in values.items():
                rendered = rendered.replace(f"{{{{{k}}}}}", v)
            dest_file.write_text(rendered, encoding="utf-8")
            written_files.append(str(dest_file.relative_to(self.target_dir)))

        if MySpecIndexManager:
            idx_mgr = MySpecIndexManager(repo_root=self.target_dir)
            idx_mgr.init_index()

        return {
            "constitution_file": str((spec_root_dir / "Constitution.md").relative_to(self.target_dir)),
            "constitution_dir": str((spec_root_dir / "constitution").relative_to(self.target_dir)),
            "written_count": len(written_files),
            "skipped_count": len(skipped_files),
            "written_files": written_files,
        }

    def initialize(
        self,
        pure_python: bool = False,
        force: bool = False,
        spec_root: str = "openspec",
        scaffold_constitution: bool = False,
        constitution_overrides: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Perform full workspace initialization; scaffold Constitution ONLY when scaffold_constitution=True."""
        try:
            self.target_dir.mkdir(parents=True, exist_ok=True)
        except (PermissionError, OSError) as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to access or create target directory {self.target_dir}: {e}"
            }

        mode = "pure_python"
        cli_used = False

        # Optional CLI delegation if available and not forced pure_python
        if not pure_python and shutil.which("openspec"):
            try:
                proc = subprocess.run(
                    ["openspec", "init", "--tools", "none"],
                    cwd=str(self.target_dir),
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=False
                )
                if proc.returncode == 0:
                    cli_used = True
                    mode = "openspec_cli"
            except Exception:
                cli_used = False

        # Scaffolding directory structures based on spec_root
        try:
            if spec_root == "specs":
                specs_dir = self.target_dir / "specs"
                specs_dir.mkdir(parents=True, exist_ok=True)
                for sub in ["changes", "implemented", "briefs", "agents", "debug", "git"]:
                    (specs_dir / sub).mkdir(parents=True, exist_ok=True)

            # Scaffolding openspec/ subdirectories (required for schema and openspec config, plus git audit namespace)
            openspec_dir = self.target_dir / "openspec"
            openspec_dir.mkdir(parents=True, exist_ok=True)
            for sub in ["changes", "specs", "briefs", "agents", "debug", "git"]:
                (openspec_dir / sub).mkdir(parents=True, exist_ok=True)

            # Write openspec/config.yaml
            config_file = openspec_dir / "config.yaml"
            if not config_file.is_file() or force:
                config_file.write_text("schema: tdd-spec-driven\n", encoding="utf-8")
            else:
                current_conf = config_file.read_text(encoding="utf-8")
                if "schema:" not in current_conf:
                    config_file.write_text(current_conf.strip() + "\nschema: tdd-spec-driven\n", encoding="utf-8")

            # Inject schema
            schema_path = self.inject_schema(force=force)

            # Update .gitignore
            added_rules = self.update_gitignore()

            # Initialize .myspec.config.json
            config_json_path = None
            if MySpecConfigManager:
                cfg_mgr = MySpecConfigManager(repo_root=self.target_dir)
                try:
                    config_json_path = str(cfg_mgr.init_config(spec_root=spec_root, force=force))
                except FileExistsError:
                    config_json_path = str(cfg_mgr.get_config_file_path())
                except Exception:
                    pass

            # Opt-in Constitution scaffolding (never auto-writes unpopulated skeletons on default init)
            constitution_result: dict[str, Any] | None = None
            if scaffold_constitution:
                constitution_result = self.scaffold_constitution(
                    force=force,
                    overrides=constitution_overrides,
                    spec_root=spec_root,
                )

            constitution_file = self.target_dir / spec_root / "Constitution.md"
            constitution_exists = constitution_file.is_file() and not constitution_file.is_symlink()

            # Initialize <spec_root>/index.yml AFTER optional constitution scaffold so existence check is exact
            index_file_path = None
            if MySpecIndexManager:
                try:
                    idx_mgr = MySpecIndexManager(repo_root=self.target_dir)
                    index_file_path = str(idx_mgr.init_index())
                except Exception:
                    pass

            return {
                "success": True,
                "target": str(self.target_dir),
                "mode": mode,
                "cli_used": cli_used,
                "spec_root": spec_root,
                "config_json_path": config_json_path,
                "index_file_path": index_file_path,
                "schema_path": str(schema_path),
                "gitignore_rules_added": added_rules,
                "constitution_exists": constitution_exists,
                "constitution_proposed": not constitution_exists and not scaffold_constitution,
                "constitution": constitution_result,
                "message": f"Successfully initialized MySpec workspace in {self.target_dir} ({mode})"
            }
        except (PermissionError, OSError) as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to scaffold openspec directory: {e}"
            }


def main() -> int:
    """CLI entrypoint for myspec-init."""
    parser = argparse.ArgumentParser(description="MySpec Workspace Initializer and Scaffolder")
    parser.add_argument("--target", "-t", type=str, default=None, help="Target directory to initialize (default: current dir)")
    parser.add_argument("--spec-root", type=str, default=None, choices=["openspec", "specs"], help="Specification root directory (openspec or specs)")
    parser.add_argument("--pure-python", action="store_true", help="Force pure Python scaffolding ignoring external CLI")
    parser.add_argument("--force", "-f", action="store_true", help="Force refresh of schema definition and templates")
    parser.add_argument(
        "--scaffold-constitution",
        action="store_true",
        help="Opt-in scaffolding of Bare-Bones <spec_root>/Constitution.md and <spec_root>/constitution/** skeleton",
    )
    parser.add_argument(
        "--set",
        dest="overrides",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="Override placeholder token when --scaffold-constitution is passed (repeatable)",
    )
    parser.add_argument("--json", action="store_true", help="Output machine-readable JSON")

    args = parser.parse_args()

    target_path = Path(args.target).resolve() if args.target else Path.cwd().resolve()
    spec_root = args.spec_root
    if spec_root is None:
        if sys.stdin.isatty() and not args.json:
            print("\nSelect specification root folder / compatibility layer:")
            print("  1) openspec (Recommended: modern OpenSpec atomic living specs & delta changes)")
            print("  2) specs    (Legacy compatibility layer: specs/changes, specs/implemented)")
            try:
                choice = input("Enter choice [1/2] (default: 1): ").strip()
                if choice == "2" or choice.lower() == "specs":
                    spec_root = "specs"
                else:
                    spec_root = "openspec"
            except (EOFError, KeyboardInterrupt):
                spec_root = "openspec"
        else:
            if MySpecConfigManager:
                try:
                    cfg_mgr = MySpecConfigManager(repo_root=target_path)
                    spec_root = cfg_mgr.auto_discover_spec_root()
                except Exception:
                    spec_root = "openspec"
            else:
                spec_root = "openspec"

    try:
        parsed_overrides: dict[str, str] = {}
        for item in args.overrides:
            if "=" not in item:
                raise ValueError(f"Invalid --set argument '{item}': expected KEY=VALUE")
            k, v = item.split("=", 1)
            parsed_overrides[k.strip()] = v

        init = MySpecInitializer(target_dir=args.target)
        result = init.initialize(
            pure_python=args.pure_python,
            force=args.force,
            spec_root=spec_root,
            scaffold_constitution=args.scaffold_constitution,
            constitution_overrides=parsed_overrides or None,
        )

        if args.json:
            print(json.dumps(result, indent=2))
        else:
            if result.get("success"):
                print(f"[OK] {result.get('message')}")
                print(f"     Schema: tdd-spec-driven ({result.get('schema_path')})")
                if result.get("gitignore_rules_added"):
                    print(f"     .gitignore updated with {len(result.get('gitignore_rules_added'))} security rules.")
            else:
                print(f"[ERROR] {result.get('message')}", file=sys.stderr)

        return 0 if result.get("success") else 1
    except ValueError as e:
        if args.json:
            print(json.dumps({"success": False, "error": str(e)}, indent=2))
        else:
            print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
