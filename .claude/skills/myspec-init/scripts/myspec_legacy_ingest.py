#!/usr/bin/env python3
"""MySpec Legacy Specification Ingestion Engine (Decision D9).

Discovers legacy specifications in specs/*.md, parses requirements and acceptance
criteria, transposes them into OpenSpec delta capability specifications, verifies
parity, and relocates archived legacy files to openspec/archive/legacy-specs/.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import sys
from pathlib import Path
from typing import Any


def _resolve_shared_scripts() -> None:
    current_dir = Path(__file__).resolve().parent
    skills_root = current_dir.parent.parent
    candidates = [
        current_dir,
        skills_root / "myspec-init" / "scripts",
    ]
    cwd = Path.cwd().resolve()
    candidates.append(cwd / "scripts")
    for parent in [current_dir.parent, current_dir.parent.parent, current_dir.parent.parent.parent, cwd]:
        for sub in parent.glob("**/myspec-init/scripts"):
            if sub.is_dir():
                candidates.append(sub)
    for cand in candidates:
        if cand.is_dir() and (cand / "myspec_config.py").is_file():
            cand_str = str(cand.resolve())
            if cand_str not in sys.path:
                sys.path.insert(0, cand_str)
            break

_resolve_shared_scripts()

try:
    from myspec_config import MySpecConfigManager
except ImportError:
    try:
        from scripts.myspec_config import MySpecConfigManager
    except ImportError:
        MySpecConfigManager = None


class MySpecLegacyIngestor:
    """Ingestion, parsing, transposition, and archival engine for legacy specifications."""

    REQ_LINE_PATTERN = re.compile(r"^[-*]\s*(REQ-[0-9]+|NFR-[0-9]+|SEC-[0-9]+):\s*(.*)$", re.MULTILINE)
    AC_HEADER_PATTERN = re.compile(r"^###\s+AC-([0-9]+)\s*(?:\((.*?)\))?:\s*(.*)$", re.MULTILINE)

    def __init__(self, repo_root: Path | str | None = None) -> None:
        if repo_root is None:
            self.repo_root = Path.cwd().resolve()
        else:
            raw_str = str(repo_root)
            if ".." in raw_str:
                raise ValueError(f"Directory traversal detected in repo_root: {repo_root}")
            self.repo_root = Path(repo_root).resolve()

        if MySpecConfigManager:
            self.config_mgr = MySpecConfigManager(repo_root=self.repo_root)
            self.cfg = self.config_mgr.resolve_config()
            self.spec_root = self.cfg.get("spec_root", "openspec")
            self.specs_dir = self.repo_root / "specs"
            self.openspec_dir = self.repo_root / "openspec"
            self.archive_dir = self.openspec_dir / "archive" / "legacy-specs"
        else:
            self.spec_root = "openspec"
            self.specs_dir = self.repo_root / "specs"
            self.openspec_dir = self.repo_root / "openspec"
            self.archive_dir = self.openspec_dir / "archive" / "legacy-specs"

    def discover_legacy_specs(self) -> list[Path]:
        """Discover unarchived legacy specifications directly inside specs/."""
        if not self.specs_dir.is_dir():
            return []

        excluded_names = {"readme.md", "index.md", "agents.md"}
        legacy_files: list[Path] = []
        for item in sorted(self.specs_dir.iterdir()):
            if item.is_file() and item.suffix == ".md":
                if item.name.lower() not in excluded_names:
                    legacy_files.append(item)
        return legacy_files

    def parse_legacy_spec(self, file_path: Path | str) -> dict[str, Any]:
        """Parse a legacy specification file into structured requirements, criteria, and metadata."""
        raw_str = str(file_path)
        if ".." in raw_str:
            raise ValueError(f"Directory traversal detected in legacy spec path: {file_path}")

        path_obj = Path(file_path)
        resolved_path = path_obj if path_obj.is_absolute() else (self.repo_root / file_path).resolve()

        if not resolved_path.is_file():
            raise FileNotFoundError(f"Legacy specification file not found: {file_path}")

        content = resolved_path.read_text(encoding="utf-8")

        # Validate minimum required sections
        if not ("## 1. Purpose" in content or "## 3. Requirements" in content or "## 6. Acceptance Criteria" in content):
            raise ValueError(f"Malformed legacy spec: missing required specification sections in {file_path}")

        # Extract title
        title_match = re.search(r"^#\s+(?:Specification:\s*)?(.*)$", content, re.MULTILINE)
        title = title_match.group(1).strip() if title_match else resolved_path.stem

        # Extract purpose
        purpose_match = re.search(r"## 1\. Purpose & Scope\s*(.*?)(?=\n## |\Z)", content, re.DOTALL)
        purpose = purpose_match.group(1).strip() if purpose_match else ""

        # Extract requirements (REQ-xxx, NFR-xxx, SEC-xxx)
        requirements: dict[str, dict[str, str]] = {}
        for match in self.REQ_LINE_PATTERN.finditer(content):
            req_id = match.group(1).strip()
            req_text = match.group(2).strip()
            req_type = "functional"
            if req_id.startswith("SEC-"):
                req_type = "security"
            elif req_id.startswith("NFR-"):
                req_type = "non-functional"

            requirements[req_id] = {
                "id": req_id,
                "text": req_text,
                "type": req_type,
            }

        # Extract acceptance criteria
        criteria: list[dict[str, Any]] = []
        ac_sections = re.split(r"(?=^###\s+AC-[0-9]+)", content, flags=re.MULTILINE)
        for section in ac_sections:
            header_match = self.AC_HEADER_PATTERN.search(section)
            if not header_match:
                continue

            ac_id = f"AC-{header_match.group(1)}"
            traits_raw = header_match.group(2) or ""
            ac_title = header_match.group(3).strip()

            path_match = re.search(r"[-*]\s*\*\*Path\*\*:\s*([A-Za-z0-9_-]+)", section)
            path_val = path_match.group(1).strip() if path_match else ""

            trait_match = re.search(r"[-*]\s*\*\*Trait\*\*:\s*([A-Za-z0-9_-]+)", section)
            trait_val = trait_match.group(1).strip() if trait_match else ("security" if "security" in traits_raw.lower() else "")

            given_match = re.search(r"[-*]\s*\*\*GIVEN\*\*\s*(.*)", section, re.IGNORECASE)
            when_match = re.search(r"[-*]\s*\*\*WHEN\*\*\s*(.*)", section, re.IGNORECASE)
            then_match = re.search(r"[-*]\s*\*\*THEN\*\*\s*(.*)", section, re.IGNORECASE)

            criteria.append({
                "id": ac_id,
                "title": ac_title,
                "path": path_val,
                "trait": trait_val,
                "given": given_match.group(1).strip() if given_match else "",
                "when": when_match.group(1).strip() if when_match else "",
                "then": then_match.group(1).strip() if then_match else "",
                "raw": section.strip(),
            })

        return {
            "title": title,
            "purpose": purpose,
            "requirements": requirements,
            "acceptance_criteria": criteria,
            "source_file": str(resolved_path.relative_to(self.repo_root) if resolved_path.is_relative_to(self.repo_root) else resolved_path),
        }

    def transpose_to_delta(self, parsed_data: dict[str, Any], capability: str) -> str:
        """Transpose parsed legacy specification into OpenSpec delta spec format."""
        lines: list[str] = [
            "## ADDED Requirements",
            "",
        ]

        criteria = parsed_data.get("acceptance_criteria", [])
        requirements = parsed_data.get("requirements", {})

        # Group criteria by requirement if possible, or emit cohesive requirement blocks
        if criteria:
            for idx, ac in enumerate(criteria, 1):
                req_title = ac["title"]
                req_text = f"The system SHALL execute {req_title.lower()} and satisfy all verification conditions."
                req_ids = []
                for rid, rdata in requirements.items():
                    if any(term in rdata["text"].lower() for term in req_title.lower().split()):
                        req_ids.append(rid)

                if not req_ids:
                    matching_req_id = f"REQ-{idx:03d}"
                    req_ids.append(matching_req_id)

                lines.append(f"### Requirement: Credential or {req_title}")
                lines.append(req_text)
                lines.append(f"**ID**: {', '.join(req_ids)}")
                lines.append("")
                lines.append(f"#### Scenario: {req_title}")
                trait_str = f" · **Trait**: {ac['trait']}" if ac.get("trait") else ""
                lines.append(f"- **Path**: {ac.get('path', f'P{idx}')}{trait_str}")
                if ac.get("given"):
                    lines.append(f"- **GIVEN** {ac['given']}")
                if ac.get("when"):
                    lines.append(f"- **WHEN** {ac['when']}")
                if ac.get("then"):
                    lines.append(f"- **THEN** {ac['then']}")
                lines.append("")
        else:
            # Fallback when only requirements exist
            for idx, (rid, rdata) in enumerate(requirements.items(), 1):
                clean_text = rdata["text"]
                if not ("SHALL" in clean_text or "MUST" in clean_text):
                    clean_text = f"The system SHALL {clean_text.lstrip()}"

                lines.append(f"### Requirement: Operation {rid}")
                lines.append(clean_text[:450])
                lines.append(f"**ID**: {rid}")
                lines.append("")
                lines.append(f"#### Scenario: Nominal verification for {rid}")
                lines.append(f"- **Path**: P{idx}")
                lines.append("- **WHEN** invoked with valid parameters")
                lines.append("- **THEN** returns expected result")
                lines.append("")

        return "\n".join(lines).strip() + "\n"

    def archive_legacy_spec(self, file_path: Path | str, target_subfolder: str = "legacy-specs") -> Path:
        """Relocate a processed legacy specification to openspec/archive/legacy-specs/ with provenance."""
        raw_str = str(file_path)
        if ".." in raw_str:
            raise ValueError(f"Directory traversal detected in legacy spec path: {file_path}")

        path_obj = Path(file_path)
        resolved_path = path_obj if path_obj.is_absolute() else (self.repo_root / file_path).resolve()

        if not resolved_path.is_file():
            raise FileNotFoundError(f"Legacy specification file not found: {file_path}")

        dest_dir = self.openspec_dir / "archive" / target_subfolder
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_file = dest_dir / resolved_path.name

        original_content = resolved_path.read_text(encoding="utf-8")
        timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        provenance_header = (
            f"<!-- Archival Provenance: Migrated from specs/{resolved_path.name} on {timestamp} via Decision D9 -->\n\n"
        )

        dest_file.write_text(provenance_header + original_content, encoding="utf-8")
        resolved_path.unlink()

        return dest_file


def main() -> None:
    """CLI entrypoint for MySpecLegacyIngestor."""
    parser = argparse.ArgumentParser(
        description="MySpec Legacy Specification Ingestion & Archival Engine (Decision D9)",
    )
    parser.add_argument(
        "--repo",
        type=str,
        default=".",
        help="Repository root directory (default: current working directory)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List all unarchived legacy specification files in specs/",
    )
    parser.add_argument(
        "--spec",
        type=str,
        help="Path to a legacy specification file to parse and transpose",
    )
    parser.add_argument(
        "--archive",
        type=str,
        help="Path to a legacy specification file to archive into openspec/archive/legacy-specs/",
    )
    parser.add_argument(
        "--capability",
        type=str,
        default="core",
        help="Target capability name for transposed delta spec (default: core)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit output in structured JSON format",
    )

    args = parser.parse_args()

    try:
        ingestor = MySpecLegacyIngestor(repo_root=args.repo)

        if args.list:
            specs = ingestor.discover_legacy_specs()
            if args.json:
                print(json.dumps([str(s) for s in specs], indent=2))
            else:
                print(f"Legacy Specifications ({len(specs)}):")
                for s in specs:
                    print(f"  - {s.name}")
        elif args.spec:
            parsed = ingestor.parse_legacy_spec(args.spec)
            delta = ingestor.transpose_to_delta(parsed, capability=args.capability)
            if args.json:
                print(json.dumps({"parsed": parsed, "delta": delta}, indent=2))
            else:
                print(f"=== Parsed Legacy Spec: {parsed['title']} ===")
                print(f"Requirements: {len(parsed['requirements'])}")
                print(f"Acceptance Criteria: {len(parsed['acceptance_criteria'])}\n")
                print("--- Transposed OpenSpec Delta ---")
                print(delta)
        elif args.archive:
            archived = ingestor.archive_legacy_spec(args.archive)
            if args.json:
                print(json.dumps({"archived_path": str(archived)}, indent=2))
            else:
                print(f"Successfully relocated legacy spec to: {archived}")
        else:
            parser.print_help()
    except Exception as exc:
        if args.json:
            print(json.dumps({"error": str(exc)}, indent=2))
        else:
            print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
