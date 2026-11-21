#!/usr/bin/env python3
"""MySpec Help and Navigation Engine.

Provides interactive overview, lifecycle sequence, Mermaid flowcharts,
and command-specific micro-help from HELP.md manifests.
"""

from __future__ import annotations

import argparse
import json
import os
import re
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


class MySpecHelpFormatter:
    """Formatter and navigation engine for the myspec-* suite."""

    CANONICAL_ORDER = [
        "myspec-help",
        "myspec-init",
        "myspec-quick",
        "myspec-tdd-spec-reasoning",
        "myspec-split",
        "myspec-validate",
        "myspec-status",
        "myspec-apply",
        "myspec-verify",
        "myspec-sync",
        "myspec-archive",
        "myspec-backfill",
        "myspec-pipeline",
    ]

    RETIRED_SHIMS = {
        "tdd-spec-reasoning": "myspec-tdd-spec-reasoning",
        "spec-split-plan": "myspec-split",
        "spec-generator": "myspec-tdd-spec-reasoning",
        "myspec-propose": "myspec-tdd-spec-reasoning",
        "propose": "myspec-tdd-spec-reasoning",
        "tdd-spec-generator": "myspec-tdd-spec-reasoning",
        "spec-executor": "myspec-apply",
        "spec-close-changelog-write": "myspec-archive",
        "feature-pipeline": "myspec-pipeline",
    }

    FLOWCHART = """```mermaid
flowchart TD
    H["/myspec-help"] -.-> I
    I["1. /myspec-init (once per project)"] --> E{"Idea already clear?"}
    E -- "No" --> X["2a. /guided-reasoning-flow"]
    E -- "Yes" --> R["2b. /myspec-tdd-spec-reasoning"]
    E -- "Quick / Agile" --> Q["2c. /myspec-quick (QA -> Execute -> Reconcile)"]
    X --> R
    R --> S{"Large document?"}
    S -- "Yes" --> SP["3a. /myspec-split"]
    S -- "No" --> P["3b. /myspec-tdd-spec-reasoning"]
    SP --> P
    P --> V["4. /myspec-validate"]
    V -- "fail" --> P
    V -- "ok" --> A["5. /myspec-apply"]
    A --> VE["6. /myspec-verify"]
    VE -- "gaps" --> A
    VE -- "ok" --> AR["7. /myspec-archive"]
    B["optional: /myspec-backfill"] -.-> P
    ST["anytime: /myspec-status"] -.-> A
```"""

    def __init__(self, skills_root: Path | str | None = None) -> None:
        if skills_root is not None:
            self.skills_root = Path(skills_root).resolve()
        else:
            current_dir = Path(__file__).resolve().parent
            # In myspec-help/scripts/ -> parent.parent is the skills directory
            candidate_skills = current_dir.parent.parent
            if candidate_skills.is_dir():
                self.skills_root = candidate_skills.resolve()
            else:
                self.skills_root = Path.cwd().resolve()

    def list_commands(self) -> list[str]:
        """List all discovered canonical myspec-* commands."""
        if not self.skills_root.is_dir():
            return []
        commands: list[str] = []
        for d in sorted(self.skills_root.iterdir()):
            if d.is_dir() and d.name.startswith("myspec-"):
                commands.append(d.name)
        return commands

    def format_command_help(self, command_name: str) -> str:
        """Format targeted help for a single command from its HELP.md."""
        # Sanitize
        raw_name = command_name.strip().lower()
        if not re.match(r'^[a-z0-9-]+$', raw_name):
            raise ValueError(f"Invalid command name '{command_name}'. Name must contain only alphanumeric and hyphens.")

        # Intercept retired legacy shims
        if raw_name in self.RETIRED_SHIMS:
            canonical = self.RETIRED_SHIMS[raw_name]
            verb = canonical.replace("myspec-", "")
            return (
                f"Notice: Legacy command '/{raw_name}' has been retired.\n"
                f"Please use canonical command '/{canonical}' (Claude Code: '/myspec:{verb}').\n"
                f"Run '/myspec-help {verb}' for detailed usage instructions."
            )

        # Normalize name: allow 'apply' or 'myspec-apply'
        target_name = raw_name if raw_name.startswith("myspec-") else f"myspec-{raw_name}"
        skill_dir = self.skills_root / target_name
        help_file = skill_dir / "HELP.md"

        if not help_file.is_file():
            available = self.list_commands()
            avail_str = ", ".join(c.replace("myspec-", "") for c in available) or "none"
            raise ValueError(f"Unknown command '{command_name}'. Available commands: {avail_str}")

        try:
            return help_file.read_text(encoding="utf-8").strip()
        except Exception as e:
            return f"Error reading help for {target_name}: {e}"

    def format_help(self) -> str:
        """Format full suite overview, flowchart, and commands index."""
        lines = [
            "# MySpec Suite Navigation & Help",
            "",
            "The `myspec-*` suite provides a unified specification-driven development workflow",
            "integrating OpenSpec living specifications with disciplined Red-Green-Refactor TDD Triads",
            "and STRIDE security defense.",
            "",
            "## 1. Lifecycle Workflow Flowchart",
            "",
            self.FLOWCHART,
            "",
            "## 2. Canonical Commands Index",
            "",
        ]

        commands = self.list_commands()
        if not commands:
            # Fallback listing canonical verbs
            commands = [c for c in self.CANONICAL_ORDER]

        for cmd in commands:
            verb = cmd.replace("myspec-", "")
            help_path = self.skills_root / cmd / "HELP.md"
            if help_path.is_file():
                try:
                    summary = help_path.read_text(encoding="utf-8").splitlines()[0]
                except Exception:
                    summary = f"`/{cmd}`"
            else:
                summary = f"Command `/{cmd}` (Claude Code: `/myspec:{verb}`)"
            lines.append(f"- **`/{cmd}`** (Claude Code: `/myspec:{verb}`): {summary}")

        lines.extend([
            "",
            "## 3. Transition Rules & Next-Step Guidance",
            "",
            "At the end of every step executed by any `myspec-*` skill, a proactive guidance box",
            "is automatically emitted indicating the next recommended command in the pipeline:",
            "",
            "```markdown",
            "---",
            "> [!TIP]",
            "> **Prossimo passo raccomandato**: `/myspec-<verbo-successivo> [parametri]` *(su Claude Code: `/myspec:<verbo-successivo> [parametri]`)*",
            "> **Motivazione**: <Spiegazione sintetica del perché questo comando è il passo naturale successivo nella pipeline>",
            "---",
            "```",
            "",
            "Use `/myspec-help <command>` (for example `/myspec-help apply`) to inspect specific command micro-help.",
        ])

        return "\n".join(lines)


class MySpecGovernanceHelpVerifier:
    """Governance verifier for HELP.md micro-docs and backward-compatibility shims."""

    def __init__(self, skills_root: Path | str | None = None) -> None:
        if skills_root is not None:
            self.skills_root = Path(skills_root).resolve()
        else:
            current_dir = Path(__file__).resolve().parent
            candidate_skills = current_dir.parent.parent
            if candidate_skills.is_dir():
                self.skills_root = candidate_skills.resolve()
            else:
                self.skills_root = Path.cwd().resolve()

    def validate_help_content(self, content: str) -> list[str]:
        """Validate HELP.md content against formatting and length constraints."""
        errors: list[str] = []
        non_empty_lines = [line.strip() for line in content.splitlines() if line.strip()]

        if len(non_empty_lines) > 5:
            errors.append(f"Line count {len(non_empty_lines)} exceeds maximum of 5 non-empty lines.")

        has_what = any(l.startswith("**What**:") for l in non_empty_lines)
        has_when = any(l.startswith("**When**:") for l in non_empty_lines)
        has_how = any(l.startswith("**How**:") for l in non_empty_lines)
        has_before = any(l.startswith("**Before**:") for l in non_empty_lines)
        has_after = any("· **After**:" in l for l in non_empty_lines)

        if not has_what:
            errors.append("Missing required key '**What**:'.")
        if not has_when:
            errors.append("Missing required key '**When**:'.")
        if not has_how:
            errors.append("Missing required key '**How**:'.")
        if not has_before:
            errors.append("Missing required key '**Before**:'.")
        if not has_after:
            errors.append("Missing required key '· **After**:'.")

        if len(non_empty_lines) < 4:
            errors.append(f"HELP.md has only {len(non_empty_lines)} non-empty lines; must contain at least 4 lines.")

        return errors

    def validate_help_file(self, file_path: Path | str) -> list[str]:
        """Validate a HELP.md file on disk."""
        path = Path(file_path)
        if not path.is_file():
            return [f"File not found: {path}"]
        try:
            content = path.read_text(encoding="utf-8")
        except Exception as e:
            return [f"Error reading file {path}: {e}"]
        return self.validate_help_content(content)

    def verify_canonical_skills(self, canonical_skills: list[str]) -> dict[str, list[str]]:
        """Verify that all canonical skills exist and possess compliant HELP.md files."""
        errors: dict[str, list[str]] = {}
        for skill_name in canonical_skills:
            skill_dir = self.skills_root / skill_name
            if not skill_dir.is_dir():
                errors[skill_name] = [f"Skill directory does not exist: {skill_dir}"]
                continue
            help_file = skill_dir / "HELP.md"
            if not help_file.is_file():
                errors[skill_name] = [f"HELP.md does not exist in {skill_dir}"]
                continue
            file_errors = self.validate_help_file(help_file)
            if file_errors:
                errors[skill_name] = file_errors
        return errors

    def verify_shims(self, legacy_shims: dict[str, str]) -> dict[str, list[str]]:
        """Verify legacy shims exist, declare deprecation, and point to existing targets."""
        errors: dict[str, list[str]] = {}
        for legacy_name, target_name in legacy_shims.items():
            legacy_dir = self.skills_root / legacy_name
            if not legacy_dir.is_dir():
                errors[legacy_name] = [f"Legacy shim directory does not exist: {legacy_dir}"]
                continue
            skill_file = legacy_dir / "SKILL.md"
            if not skill_file.is_file():
                errors[legacy_name] = [f"Legacy shim SKILL.md does not exist: {skill_file}"]
                continue

            # Verify target canonical skill exists (Orphan detection, N4)
            target_dir = self.skills_root / target_name
            if not target_dir.is_dir():
                errors[legacy_name] = [f"Orphan shim reference: target '{target_name}' does not exist in {self.skills_root}"]
                continue

            content = skill_file.read_text(encoding="utf-8")
            shim_errs: list[str] = []
            if "deprecat" not in content.lower():
                shim_errs.append("Shim SKILL.md must declare deprecation status.")
            if target_name not in content:
                shim_errs.append(f"Shim SKILL.md must explicitly reference canonical target '{target_name}'.")

            if shim_errs:
                errors[legacy_name] = shim_errs

        return errors


class MySpecShimForwarder:
    """Forwarder and resolver for legacy backward-compatibility shims."""

    LEGACY_MAPPING = {
        "tdd-spec-reasoning": "myspec-tdd-spec-reasoning",
        "spec-split-plan": "myspec-split",
        "spec-generator": "myspec-tdd-spec-reasoning",
        "myspec-propose": "myspec-tdd-spec-reasoning",
        "propose": "myspec-tdd-spec-reasoning",
        "tdd-spec-generator": "myspec-tdd-spec-reasoning",
        "spec-executor": "myspec-apply",
        "spec-close-changelog-write": "myspec-archive",
        "feature-pipeline": "myspec-pipeline",
    }

    def __init__(self, skills_root: Path | str | None = None) -> None:
        if skills_root is not None:
            self.skills_root = Path(skills_root).resolve()
        else:
            current_dir = Path(__file__).resolve().parent
            self.skills_root = current_dir.parent.parent.resolve()

    def forward(self, legacy_command: str, args: str = "") -> dict[str, str]:
        """Resolves target canonical skill and prepares deprecation forwarding message."""
        clean_name = legacy_command.strip().lstrip("/")
        target = self.LEGACY_MAPPING.get(clean_name)
        if not target:
            raise ValueError(f"'{legacy_command}' is not a recognized legacy shim.")

        target_dir = self.skills_root / target
        if not target_dir.is_dir():
            raise FileNotFoundError(f"Canonical target '{target}' does not exist.")

        needs_args = clean_name in {"spec-executor", "spec-close-changelog-write"}
        if needs_args and not args.strip():
            hint = f"Usage hint: /{clean_name} requires a target parameter (e.g. /{clean_name} @specs/<file>.md). Forwarding to /{target}."
        else:
            hint = ""

        notice = f"[DEPRECATION NOTICE] Command '/{clean_name}' is deprecated. Delegating to '/{target}'. Please update invocations to '/{target}'."
        return {
            "legacy": clean_name,
            "target": target,
            "notice": notice,
            "forwarded_args": args.strip(),
            "hint": hint,
        }


def main() -> int:
    """CLI entrypoint for myspec-help."""
    parser = argparse.ArgumentParser(description="MySpec Suite Help and Navigation Engine")
    parser.add_argument("--command", "-c", type=str, help="Specific command to inspect (e.g. apply, validate)")
    parser.add_argument("--list", "-l", action="store_true", help="List all available commands")
    parser.add_argument("--json", action="store_true", help="Output help details in JSON format")

    args = parser.parse_args()
    formatter = MySpecHelpFormatter()

    if args.list:
        cmds = formatter.list_commands()
        if args.json:
            print(json.dumps({"commands": cmds}, indent=2))
        else:
            for c in cmds:
                print(f"- {c}")
        return 0

    if args.command:
        try:
            help_text = formatter.format_command_help(args.command)
            if args.json:
                print(json.dumps({"command": args.command, "help": help_text}, indent=2))
            else:
                print(help_text)
            return 0
        except ValueError as e:
            if args.json:
                print(json.dumps({"error": str(e)}, indent=2))
            else:
                print(f"Error: {e}", file=sys.stderr)
            return 1

    # Full help
    help_doc = formatter.format_help()
    if args.json:
        print(json.dumps({"help": help_doc}, indent=2))
    else:
        print(help_doc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
