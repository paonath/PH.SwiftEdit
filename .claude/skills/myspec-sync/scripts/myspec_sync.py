#!/usr/bin/env python3
"""MySpec Living Specification Merger Engine (scripts/myspec_sync.py).

Merges delta specifications from OpenSpec changes (openspec/changes/<change-id>/specs/<cap>/spec.md)
into living capability specifications (openspec/specs/<cap>/spec.md).
Supports ADDED, MODIFIED, REMOVED, and RENAMED delta requirements, scenario preservation,
living spec auto-scaffolding, and optional CLI parity delegation (Decision D2).
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
from dataclasses import dataclass, field
from pathlib import Path

def _resolve_shared_scripts() -> None:
    current_dir = Path(__file__).resolve().parent
    skills_root = current_dir.parent.parent
    primary = [
        current_dir,
        skills_root / "myspec-init" / "scripts",
        skills_root / "myspec-validate" / "scripts",
    ]
    for cand in reversed(primary):
        if cand.is_dir():
            cand_str = str(cand.resolve())
            if cand_str not in sys.path:
                sys.path.insert(0, cand_str)

_resolve_shared_scripts()

try:
    from myspec_validate import MySpecValidator
except ImportError:
    try:
        from scripts.myspec_validate import MySpecValidator
    except ImportError:
        MySpecValidator = None

try:
    from myspec_config import MySpecConfigManager
except ImportError:
    try:
        from scripts.myspec_config import MySpecConfigManager
    except ImportError:
        MySpecConfigManager = None

try:
    from myspec_index import MySpecGitBranchTracker, MySpecIndexManager
except ImportError:
    try:
        from scripts.myspec_index import MySpecGitBranchTracker, MySpecIndexManager
    except ImportError:
        MySpecIndexManager = None
        MySpecGitBranchTracker = None



@dataclass
class DeltaMergeReport:
    """Structured report outcome for a change or capability living spec merge."""

    success: bool
    capabilities_merged: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    details: dict[str, dict] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "status": "success" if self.success else "fail",
            "capabilities_merged": self.capabilities_merged,
            "errors": self.errors,
            "warnings": self.warnings,
            "details": self.details,
        }


class MySpecLivingSpecMerger:
    """Core merge engine for delta specifications into durable living capability specs."""

    RFC2119_KEYWORDS = {"SHALL", "MUST"}
    ALLOWED_DELTA_HEADERS = {
        "ADDED": "## ADDED Requirements",
        "MODIFIED": "## MODIFIED Requirements",
        "REMOVED": "## REMOVED Requirements",
        "RENAMED": "## RENAMED Requirements",
    }

    def __init__(self, repo_root: Path | str | None = None, strict: bool = True) -> None:
        self.repo_root = Path(repo_root or os.getcwd()).resolve()
        self.strict = strict

        if MySpecConfigManager:
            self.config_mgr = MySpecConfigManager(repo_root=self.repo_root)
            self.cfg = self.config_mgr.resolve_config()
            self.spec_root = self.cfg["spec_root"]
            self.openspec_dir = self.repo_root / self.spec_root
            self.changes_dir = self.config_mgr.get_changes_dir()
            self.living_specs_dir = self.config_mgr.get_specs_dir()
            self.archive_dir = self.config_mgr.get_archive_dir()
        else:
            self.spec_root = "openspec"
            self.openspec_dir = self.repo_root / "openspec"
            self.changes_dir = self.openspec_dir / "changes"
            self.living_specs_dir = self.openspec_dir / "specs"
            self.archive_dir = self.changes_dir / "archive"

    def validate_path_identifier(self, identifier: str) -> None:
        """Sanitize change identifiers and capability paths against path traversal."""
        if not identifier or ".." in identifier or "\\" in identifier:
            raise ValueError(f"Invalid identifier or path traversal detected: '{identifier}'")
        # Ensure identifier doesn't start with absolute slash or forbidden characters
        clean = identifier.strip("/").strip()
        if not clean or clean.startswith("/"):
            raise ValueError(f"Invalid identifier format: '{identifier}'")

    @staticmethod
    def _strip_delta_directives(desc: str) -> str:
        """Strip reconciliation directives and Security-Waiver lines from requirement description."""
        if not desc:
            return ""
        cleaned_lines = []
        for line in desc.splitlines():
            if re.match(
                r'^[ \t]*-\s*\*\*(?:REMOVED-SCENARIO|RENAMED-SCENARIO)\*\*\s*:',
                line,
                re.IGNORECASE,
            ):
                continue
            if re.match(r'^[ \t]*(?:-\s*)?\*\*?Security-Waiver\*\*?\s*:', line, re.IGNORECASE) or re.match(
                r'^[ \t]*Security-Waiver\s*:', line, re.IGNORECASE
            ):
                continue
            cleaned_lines.append(line)
        return "\n".join(cleaned_lines).strip()

    @staticmethod
    def _is_security_scenario(sc_data: dict) -> bool:
        """Return True if a scenario carries the security trait."""
        body = sc_data.get("body", "")
        return bool(re.search(r'-\s*\*\*Trait\*\*:\s*[^\n]*\bsecurity\b', body, re.IGNORECASE))

    RULE_G3_PROTECTED_ID_RE = re.compile(
        r"\b(?:SEC-\d+|(?:UI|DATA|API|TEST|SDD)-\d{3}|BC-(?:(?:OWN|FORBID|REF|POL)-)?\d{3}|AR-(?:(?:MOD|SAGA)-)?\d{3})\b"
    )

    @classmethod
    def _is_security_requirement(cls, req_data: dict) -> bool:
        """Determine whether a living requirement is protected by Rule G3.

        Args:
            req_data: Parsed living requirement dictionary containing title, body, and scenarios.

        Returns:
            True when the requirement carries any AR/BC/UI/DATA/API/TEST/SEC/SDD rule ID or security scenario.
        """
        title = req_data.get("title", "")
        body = req_data.get("body", "")
        if cls.RULE_G3_PROTECTED_ID_RE.search(title) or cls.RULE_G3_PROTECTED_ID_RE.search(body):
            return True
        scenarios = req_data.get("scenarios", {})
        sc_iter = scenarios.values() if isinstance(scenarios, dict) else scenarios
        return any(cls._is_security_scenario(sc) for sc in sc_iter)

    @staticmethod
    def _has_post_merge_path_coverage(scenarios_dict: dict) -> bool:
        """Verify that merged scenarios retain at least one positive (P#) and one negative (N#) path."""
        has_p = False
        has_n = False
        for sc_title, sc_data in scenarios_dict.items():
            body = sc_data.get("body", "")
            if re.search(r'-\s*\*\*Path\*\*:\s*P\d+', body) or re.search(r'\bP\d+\b', sc_title):
                has_p = True
            if re.search(r'-\s*\*\*Path\*\*:\s*N\d+', body) or re.search(r'\bN\d+\b', sc_title):
                has_n = True
        return has_p and has_n

    def parse_delta_spec(self, delta_content: str) -> dict:
        """Parse delta spec into structured sections: purpose, ADDED, MODIFIED, REMOVED, RENAMED."""
        parsed = {
            "purpose": "",
            "added": [],
            "modified": [],
            "removed": [],
            "renamed": [],
        }

        # Extract purpose if present (stripping any Security-Waiver lines)
        purpose_match = re.search(r'^## Purpose\s*\n+([\s\S]*?)(?=^## |\Z)', delta_content, re.MULTILINE)
        if purpose_match:
            parsed["purpose"] = self._strip_delta_directives(purpose_match.group(1).strip())

        # Split into ## sections anchored at start of line
        sections = re.findall(r'^(## [^\n]+)([\s\S]*?)(?=^## |\Z)', delta_content, re.MULTILINE)
        for sec_header, raw_sec_body in sections:
            sec_body = re.sub(r'<!--[\s\S]*?-->', '', raw_sec_body)
            header = sec_header.strip()
            sec_type = None
            if "ADDED Requirements" in header:
                sec_type = "added"
            elif "MODIFIED Requirements" in header:
                sec_type = "modified"
            elif "REMOVED Requirements" in header:
                sec_type = "removed"
            elif "RENAMED Requirements" in header:
                sec_type = "renamed"

            if not sec_type:
                continue

            if sec_type == "renamed":
                rename_pairs = re.findall(
                    r'-\s*FROM:\s*`?(?:###\s+Requirement:\s*)?([^`\n]+?)`?\s*\n\s*-\s*TO:\s*`?(?:###\s+Requirement:\s*)?([^`\n]+?)`?[ \t]*(?=\n|\Z)',
                    sec_body,
                    re.IGNORECASE,
                )
                if sec_body.strip() and not rename_pairs and self.strict:
                    raise ValueError(
                        "RENAMED Requirements section contains no valid '- FROM: `### Requirement: <Old>`' / '- TO: `### Requirement: <New>`' pairs"
                    )
                for old_raw, new_raw in rename_pairs:
                    old_t = old_raw.strip()
                    new_t = new_raw.strip()
                    if self.strict and (not old_t or not new_t or old_t == new_t):
                        raise ValueError(
                            f"Invalid RENAMED requirement pair: FROM '{old_t}' TO '{new_t}' (titles must be non-empty and distinct)"
                        )
                    parsed["renamed"].append({"from": old_t, "to": new_t})
                continue

            # Extract requirements: ### Requirement: <Title> anchored to start of line
            req_blocks = re.findall(
                r'^(### Requirement:[^\n]+)([\s\S]*?)(?=^### Requirement:|^## |\Z)',
                sec_body,
                re.MULTILINE,
            )

            for req_header, req_body in req_blocks:
                req_title = req_header.replace("### Requirement:", "").strip()
                desc_match = re.search(r'([\s\S]*?)(?=^#### Scenario:|\Z)', req_body, re.MULTILINE)
                raw_desc = desc_match.group(1).strip() if desc_match else ""

                removed_scenarios: list[dict[str, str]] = []
                renamed_scenarios: list[dict[str, str]] = []
                if sec_type == "modified":
                    for m in re.finditer(
                        r'^[ \t]*-\s*\*\*REMOVED-SCENARIO\*\*:\s*`?([^`\n—–-]+?)`?(?:\s*(?:—|–|--|-)\s*\*\*Reason\*\*:\s*(.+))?[ \t]*$',
                        raw_desc,
                        re.MULTILINE,
                    ):
                        sc_name = m.group(1).replace("#### Scenario:", "").strip()
                        sc_reason = (m.group(2) or "").strip()
                        if self.strict and not sc_reason:
                            raise ValueError(
                                f"REMOVED-SCENARIO directive for '{sc_name}' in '{req_title}' requires a '**Reason**: <text>' clause"
                            )
                        removed_scenarios.append({"title": sc_name, "reason": sc_reason})

                    for m in re.finditer(
                        r'^[ \t]*-\s*\*\*RENAMED-SCENARIO\*\*:\s*FROM\s+`?([^`\n]+?)`?\s+TO\s+`?([^`\n]+?)`?[ \t]*$',
                        raw_desc,
                        re.MULTILINE | re.IGNORECASE,
                    ):
                        old_sc = m.group(1).replace("#### Scenario:", "").strip()
                        new_sc = m.group(2).replace("#### Scenario:", "").strip()
                        if self.strict and (not old_sc or not new_sc or old_sc == new_sc):
                            raise ValueError(
                                f"Invalid RENAMED-SCENARIO directive in '{req_title}': FROM '{old_sc}' TO '{new_sc}'"
                            )
                        renamed_scenarios.append({"from": old_sc, "to": new_sc})

                desc = self._strip_delta_directives(raw_desc)

                # RFC 2119 keyword check for added/modified requirements
                if sec_type in ("added", "modified") and self.strict:
                    if not any(kw in desc for kw in self.RFC2119_KEYWORDS):
                        raise ValueError(
                            f"Requirement '{req_title}' in delta spec lacks RFC 2119 keyword (SHALL or MUST): '{desc}'"
                        )

                # Extract scenarios anchored to start of line
                scenarios = re.findall(
                    r'^(#### Scenario:[^\n]+)([\s\S]*?)(?=^#### Scenario:|\Z)',
                    req_body,
                    re.MULTILINE,
                )
                scenarios_list = []
                for sc_hdr, sc_body in scenarios:
                    sc_title = sc_hdr.replace("#### Scenario:", "").strip()
                    scenarios_list.append({
                        "header": sc_hdr.strip(),
                        "title": sc_title,
                        "body": sc_body.strip(),
                        "full_text": f"{sc_hdr.strip()}\n{sc_body.strip()}\n",
                    })

                block_lines = [req_header.strip(), desc]
                for sc_item in scenarios_list:
                    block_lines.append("")
                    block_lines.append(sc_item["header"])
                    block_lines.append(sc_item["body"])
                clean_full_block = "\n".join(block_lines).rstrip() + "\n"

                parsed[sec_type].append({
                    "header": req_header.strip(),
                    "title": req_title,
                    "body": req_body.strip(),
                    "raw_description": raw_desc,
                    "description": desc,
                    "removed_scenarios": removed_scenarios,
                    "renamed_scenarios": renamed_scenarios,
                    "scenarios": scenarios_list,
                    "full_block": clean_full_block,
                })

        return parsed

    def _parse_living_spec(self, living_content: str) -> dict:
        """Parse existing living spec into purpose and dictionary of requirements."""
        living = {
            "title": "",
            "purpose": "",
            "requirements": {},  # title -> {header, body, description, scenarios, full_block}
            "order": [],         # list of requirement titles in original order
        }

        # Title
        title_match = re.search(r'^#\s+Capability:\s*([^\n]+)', living_content, re.MULTILINE)
        if title_match:
            living["title"] = title_match.group(1).strip()

        # Purpose
        purpose_match = re.search(r'^## Purpose\s*\n+([\s\S]*?)(?=^## |\Z)', living_content, re.MULTILINE)
        if purpose_match:
            living["purpose"] = purpose_match.group(1).strip()

        # Extract requirements under ## Requirements anchored to start of line
        req_blocks = re.findall(
            r'^(### Requirement:[^\n]+)([\s\S]*?)(?=^### Requirement:|^## |\Z)',
            living_content,
            re.MULTILINE,
        )

        for req_header, req_body in req_blocks:
            req_title = req_header.replace("### Requirement:", "").strip()
            desc_match = re.search(r'([\s\S]*?)(?=^#### Scenario:|\Z)', req_body, re.MULTILINE)
            desc = desc_match.group(1).strip() if desc_match else ""

            scenarios = re.findall(
                r'^(#### Scenario:[^\n]+)([\s\S]*?)(?=^#### Scenario:|\Z)',
                req_body,
                re.MULTILINE,
            )
            scenarios_dict = {}
            for sc_hdr, sc_body in scenarios:
                sc_title = sc_hdr.replace("#### Scenario:", "").strip()
                scenarios_dict[sc_title] = {
                    "header": sc_hdr.strip(),
                    "body": sc_body.strip(),
                    "full_text": f"{sc_hdr.strip()}\n{sc_body.strip()}\n",
                }

            living["requirements"][req_title] = {
                "header": req_header.strip(),
                "title": req_title,
                "body": req_body.strip(),
                "description": desc,
                "scenarios": scenarios_dict,
                "full_block": f"{req_header.strip()}\n{req_body.strip()}\n",
            }
            living["order"].append(req_title)

        return living

    @staticmethod
    def _rebuild_req_full_block(req_data: dict) -> str:
        """Rebuild the markdown block for a living requirement from its header, description, and scenarios."""
        block_lines = [req_data["header"], req_data["description"]]
        for sc_data in req_data["scenarios"].values():
            block_lines.append("")
            block_lines.append(sc_data["header"])
            block_lines.append(sc_data["body"])
        return "\n".join(block_lines).rstrip() + "\n"

    def _enforce_living_spec_rule_g3(self, parsed_delta: dict, living: dict, delta_content: str) -> None:
        """Enforce Living-Spec-Aware Rule G3 when removing, renaming, or weakening security requirements/scenarios."""
        if not self.strict:
            return
        has_waiver = bool(re.search(r'Security-Waiver\s*:', delta_content, re.IGNORECASE))
        if has_waiver:
            return

        for pair in parsed_delta["renamed"]:
            old_t = pair["from"]
            if old_t in living["requirements"] and self.RULE_G3_PROTECTED_ID_RE.search(old_t):
                raise ValueError(
                    f"Rule G3 Violation: Renaming security requirement '{old_t}' requires an explicit 'Security-Waiver:' in the delta spec."
                )

        for rem_req in parsed_delta["removed"]:
            title = rem_req["title"]
            if title in living["requirements"] and self._is_security_requirement(living["requirements"][title]):
                raise ValueError(
                    f"Rule G3 Violation: Removing security-sensitive requirement '{title}' requires an explicit 'Security-Waiver:' in the delta spec."
                )

        # Map post-rename titles back to living requirements for pre-flight G3 inspection
        rename_map = {pair["to"]: pair["from"] for pair in parsed_delta["renamed"]}
        for mod_req in parsed_delta["modified"]:
            title = mod_req["title"]
            lookup_title = rename_map.get(title, title)
            orig_req = living["requirements"].get(lookup_title)
            if not orig_req:
                continue

            if self.RULE_G3_PROTECTED_ID_RE.search(orig_req["title"]) or self.RULE_G3_PROTECTED_ID_RE.search(
                orig_req.get("body", "")
            ):
                raise ValueError(
                    f"Rule G3 Violation: Modifying security requirement '{orig_req['title']}' requires an explicit 'Security-Waiver:' in the delta spec."
                )

            for rem_sc in mod_req.get("removed_scenarios", []):
                sc_title = rem_sc["title"]
                orig_sc = orig_req["scenarios"].get(sc_title)
                if orig_sc and self._is_security_scenario(orig_sc):
                    raise ValueError(
                        f"Rule G3 Violation: Removing security-traited scenario '{sc_title}' from '{title}' requires an explicit 'Security-Waiver:'."
                    )

            for sc in mod_req.get("scenarios", []):
                orig_sc = orig_req["scenarios"].get(sc["title"])
                if orig_sc and self._is_security_scenario(orig_sc) and not self._is_security_scenario(sc):
                    raise ValueError(
                        f"Rule G3 Violation: Dropping '- **Trait**: security' from scenario '{sc['title']}' in '{title}' requires an explicit 'Security-Waiver:'."
                    )

    def merge_capability_delta(
        self,
        capability: str,
        delta_content: str,
        living_content: str | None = None,
    ) -> tuple[str, list[str]]:
        """Merge delta content for a capability into living spec format in canonical RENAMED -> REMOVED -> MODIFIED -> ADDED order."""
        self.validate_path_identifier(capability)
        warnings: list[str] = []

        parsed_delta = self.parse_delta_spec(delta_content)

        # Scaffolding when living spec does not exist
        if not living_content or not living_content.strip():
            purpose = parsed_delta["purpose"]
            if not purpose or len(purpose) < 50:
                purpose = f"Core {capability} capability living specification, operational contracts, and behavioral requirements."

            lines = [
                f"# Capability: {capability}",
                "",
                "## Purpose",
                purpose,
                "",
                "## Requirements",
                "",
            ]

            for req in parsed_delta["added"]:
                lines.append(req["full_block"].rstrip())
                lines.append("")

            return "\n".join(lines).rstrip() + "\n", warnings

        # Merge into existing living content
        living = self._parse_living_spec(living_content)
        if parsed_delta["purpose"] and len(parsed_delta["purpose"]) >= 50:
            living["purpose"] = parsed_delta["purpose"]

        # Pre-flight Living-Spec-Aware Rule G3 check
        self._enforce_living_spec_rule_g3(parsed_delta, living, delta_content)

        # 1. Apply RENAMED requirements
        for pair in parsed_delta["renamed"]:
            old_t, new_t = pair["from"], pair["to"]
            if old_t in living["requirements"]:
                req_obj = living["requirements"].pop(old_t)
                req_obj["title"] = new_t
                req_obj["header"] = f"### Requirement: {new_t}"
                req_obj["full_block"] = self._rebuild_req_full_block(req_obj)
                living["requirements"][new_t] = req_obj
                living["order"] = [new_t if t == old_t else t for t in living["order"]]
            else:
                if self.strict:
                    raise ValueError(f"RENAMED requirement '{old_t}' was not found in living spec")
                warnings.append(f"RENAMED requirement '{old_t}' was not found in living spec")

        # 2. Apply REMOVED requirements
        for rem_req in parsed_delta["removed"]:
            title = rem_req["title"]
            if title in living["requirements"]:
                del living["requirements"][title]
                living["order"] = [t for t in living["order"] if t != title]
            else:
                warnings.append(f"REMOVED requirement '{title}' was not found in living spec")

        # 3. Apply MODIFIED requirements
        for mod_req in parsed_delta["modified"]:
            title = mod_req["title"]
            if title in living["requirements"]:
                orig_req = living["requirements"][title]

                # 3a. Apply RENAMED-SCENARIO directives preserving scenario order
                for sc_pair in mod_req.get("renamed_scenarios", []):
                    old_sc, new_sc = sc_pair["from"], sc_pair["to"]
                    if old_sc in orig_req["scenarios"]:
                        rebuilt_scenarios = {}
                        for k, v in orig_req["scenarios"].items():
                            if k == old_sc:
                                new_hdr = f"#### Scenario: {new_sc}"
                                rebuilt_scenarios[new_sc] = {
                                    "header": new_hdr,
                                    "body": v["body"],
                                    "full_text": f"{new_hdr}\n{v['body']}\n",
                                }
                            else:
                                rebuilt_scenarios[k] = v
                        orig_req["scenarios"] = rebuilt_scenarios
                    else:
                        if self.strict:
                            raise ValueError(
                                f"RENAMED-SCENARIO source '{old_sc}' was not found in requirement '{title}'"
                            )
                        warnings.append(f"RENAMED-SCENARIO '{old_sc}' was not found in requirement '{title}'")

                # 3b. Apply REMOVED-SCENARIO directives
                for rem_sc in mod_req.get("removed_scenarios", []):
                    sc_name = rem_sc["title"]
                    if sc_name in orig_req["scenarios"]:
                        del orig_req["scenarios"][sc_name]
                    else:
                        if self.strict:
                            raise ValueError(
                                f"REMOVED-SCENARIO target '{sc_name}' was not found in requirement '{title}'"
                            )
                        warnings.append(f"REMOVED-SCENARIO '{sc_name}' was not found in requirement '{title}'")

                # 3c. Upsert scenarios from the MODIFIED delta block
                for sc in mod_req["scenarios"]:
                    orig_req["scenarios"][sc["title"]] = {
                        "header": sc["header"],
                        "body": sc["body"],
                        "full_text": sc["full_text"],
                    }

                # 3d. Verify post-merge Path Coverage (P# and N#) if scenarios were removed or renamed
                if self.strict and (mod_req.get("removed_scenarios") or mod_req.get("renamed_scenarios")):
                    if not self._has_post_merge_path_coverage(orig_req["scenarios"]):
                        raise ValueError(
                            f"Post-merge requirement '{title}' violates Path Coverage Rule (requires at least one P# and one N# scenario)"
                        )

                # Update description (already stripped of directives) and rebuild full_block
                orig_req["description"] = mod_req["description"]
                orig_req["full_block"] = self._rebuild_req_full_block(orig_req)
            else:
                warnings.append(f"MODIFIED requirement '{title}' was not found in existing living spec; treating as ADDED")
                living["requirements"][title] = {
                    "header": mod_req["header"],
                    "title": title,
                    "description": mod_req["description"],
                    "scenarios": {s["title"]: s for s in mod_req["scenarios"]},
                    "full_block": mod_req["full_block"],
                }
                living["order"].append(title)

        # 4. Apply ADDED requirements
        for add_req in parsed_delta["added"]:
            title = add_req["title"]
            if title in living["requirements"]:
                warnings.append(f"ADDED requirement '{title}' already exists in living spec; updating existing")
            else:
                living["order"].append(title)
            living["requirements"][title] = {
                "header": add_req["header"],
                "title": title,
                "description": add_req["description"],
                "scenarios": {s["title"]: s for s in add_req["scenarios"]},
                "full_block": add_req["full_block"],
            }

        # Render living specification
        cap_title = living["title"] or capability
        lines = [
            f"# Capability: {cap_title}",
            "",
            "## Purpose",
            living["purpose"] or f"Core {capability} capability living specification and behavioral requirements.",
            "",
            "## Requirements",
            "",
        ]

        for req_title in living["order"]:
            req_data = living["requirements"].get(req_title)
            if req_data:
                lines.append(req_data["full_block"].rstrip())
                lines.append("")

        return "\n".join(lines).rstrip() + "\n", warnings

    @staticmethod
    def _auto_close_sync_tasks(change_path: Path) -> int:
        """Automatically mark unchecked [SYNC] tasks in tasks.md as completed (- [x])."""
        tasks_file = change_path / "tasks.md"
        if not tasks_file.is_file():
            return 0
        content = tasks_file.read_text(encoding="utf-8")
        pattern = re.compile(
            r'^([ \t]*-\s*)\[\s\](\s+\d+\.\d+\s+.*?\[(?:PHASE:\s*)?SYNC\].*)$',
            re.MULTILINE,
        )
        new_content, count = pattern.subn(r'\1[x]\2', content)
        if count > 0 and new_content != content:
            tasks_file.write_text(new_content, encoding="utf-8")
        return count

    @classmethod
    def _find_unchecked_tasks(cls, change_path: Path) -> list[str]:
        """Return all unchecked task lines (- [ ]) remaining in tasks.md, ignoring HTML comments."""
        tasks_file = change_path / "tasks.md"
        if not tasks_file.is_file():
            return []
        raw_content = tasks_file.read_text(encoding="utf-8")
        content = re.sub(r'<!--[\s\S]*?-->', '', raw_content)
        return [
            m.group(1).strip()
            for m in re.finditer(r'^[ \t]*-\s*\[\s\]\s+(.+)$', content, re.MULTILINE)
        ]

    @classmethod
    def _find_unchecked_non_sync_tasks(cls, change_path: Path) -> list[str]:
        """Return all unchecked task lines (- [ ]) in tasks.md that are not [SYNC] tasks, ignoring HTML comments."""
        tasks_file = change_path / "tasks.md"
        if not tasks_file.is_file():
            return []
        raw_content = tasks_file.read_text(encoding="utf-8")
        content = re.sub(r'<!--[\s\S]*?-->', '', raw_content)
        unchecked = []
        for m in re.finditer(r'^[ \t]*-\s*\[\s\]\s+(.+)$', content, re.MULTILINE):
            line = m.group(1).strip()
            if not re.search(r'\[(?:PHASE:\s*)?SYNC\]', line, re.IGNORECASE):
                unchecked.append(line)
        return unchecked

    def merge_change(
        self,
        change_id_or_path: Path | str,
        cli_parity: bool = False,
    ) -> DeltaMergeReport:
        """Merge all capability deltas in a change directory into openspec/specs/ and auto-close [SYNC] tasks."""
        change_str = str(change_id_or_path).strip()
        self.validate_path_identifier(change_str)

        change_path = Path(change_id_or_path)
        if not change_path.is_absolute():
            # Check if relative to cwd or under openspec/changes
            cand1 = (self.repo_root / change_path).resolve()
            cand2 = (self.changes_dir / change_str).resolve()
            change_path = cand2 if cand2.is_dir() else cand1

        if not change_path.is_dir():
            return DeltaMergeReport(
                success=False,
                errors=[f"Change directory not found: {change_path}"],
            )

        specs_dir = change_path / "specs"
        if not specs_dir.is_dir():
            return DeltaMergeReport(
                success=False,
                errors=[f"No specs/ directory found inside change: {change_path}"],
            )

        delta_files = list(specs_dir.glob("**/spec.md"))
        if not delta_files:
            return DeltaMergeReport(
                success=False,
                errors=[f"No capability spec.md files found in {specs_dir}"],
            )

        capabilities_merged: list[str] = []
        errors: list[str] = []
        warnings: list[str] = []
        details: dict[str, dict] = {}

        if MySpecValidator is not None:
            val_inst = MySpecValidator(repo_root=self.repo_root, strict=self.strict)
            if val_inst.constitution_file.is_file():
                tr_errs, _tr_warns = val_inst._validate_constitution_traceability(change_path)
                if tr_errs:
                    return DeltaMergeReport(
                        success=False,
                        errors=tr_errs,
                        warnings=warnings,
                        details={"constitution_traceability_errors": tr_errs},
                    )

        # First pass: parse all deltas to ensure zero errors before writing any file
        prepared_merges: dict[str, tuple[Path, str]] = {}
        for delta_file in delta_files:
            capability = str(delta_file.relative_to(specs_dir).parent)
            try:
                delta_content = delta_file.read_text(encoding="utf-8")
                living_file = self.living_specs_dir / capability / "spec.md"
                living_content = living_file.read_text(encoding="utf-8") if living_file.is_file() else None

                merged_content, cap_warnings = self.merge_capability_delta(
                    capability=capability,
                    delta_content=delta_content,
                    living_content=living_content,
                )
                warnings.extend(cap_warnings)
                prepared_merges[capability] = (living_file, merged_content)
            except Exception as e:
                errors.append(f"Failed to process delta for capability '{capability}': {e}")

        if errors:
            return DeltaMergeReport(
                success=False,
                errors=errors,
                warnings=warnings,
                details=details,
            )

        # Second pass: commit all living specs atomically to disk
        for capability, (living_file, merged_content) in prepared_merges.items():
            living_file.parent.mkdir(parents=True, exist_ok=True)
            living_file.write_text(merged_content, encoding="utf-8")
            capabilities_merged.append(capability)
            details[capability] = {"status": "merged", "file": str(living_file)}

        # Automatically close any [SYNC] tasks in tasks.md upon successful merge
        closed_sync_tasks = self._auto_close_sync_tasks(change_path)
        if closed_sync_tasks > 0:
            details["sync_tasks_closed"] = {"count": closed_sync_tasks}

        # Optional CLI parity check / delegation
        if cli_parity:
            cli_res = self._check_cli_parity(change_path)
            details["cli_parity"] = cli_res
            if not cli_res.get("pass", True):
                warnings.append(f"CLI parity warning: {cli_res.get('message')}")

        return DeltaMergeReport(
            success=True,
            capabilities_merged=capabilities_merged,
            errors=[],
            warnings=warnings,
            details=details,
        )

    def _check_cli_parity(self, change_path: Path) -> dict:
        """Verify parity against upstream openspec CLI if installed."""
        openspec_bin = shutil.which("openspec")
        if not openspec_bin:
            return {"pass": True, "message": "openspec CLI not installed; pure-Python execution active"}

        try:
            res = subprocess.run(
                [openspec_bin, "validate", "--change", change_path.name, "--strict"],
                cwd=str(self.repo_root),
                capture_output=True,
                text=True,
                timeout=15,
            )
            return {
                "pass": res.returncode == 0,
                "message": f"CLI validation returncode: {res.returncode}",
                "output": res.stdout,
                "stderr": res.stderr,
            }
        except Exception as e:
            return {"pass": False, "message": f"CLI validation invocation failed: {e}"}

    def archive_change(
        self,
        change_id_or_path: Path | str,
        date_str: str | None = None,
        cli_parity: bool = False,
    ) -> DeltaMergeReport:
        """Fail-closed 6-stage gating pipeline for archiving an OpenSpec change."""
        change_str = str(change_id_or_path).strip()
        self.validate_path_identifier(change_str)

        change_path = Path(change_id_or_path)
        if not change_path.is_absolute():
            cand1 = (self.repo_root / change_path).resolve()
            cand2 = (self.changes_dir / change_str).resolve()
            change_path = cand2 if cand2.is_dir() else cand1

        if not change_path.is_dir():
            return DeltaMergeReport(
                success=False,
                errors=[f"Change directory not found: {change_path}"],
            )

        # 1. Validation Gate
        if MySpecValidator is not None:
            validator = MySpecValidator(repo_root=self.repo_root, strict=self.strict)
            val_report = validator.validate_change(change_path, cli_parity=cli_parity)
            if not val_report.valid:
                return DeltaMergeReport(
                    success=False,
                    errors=[f"Pre-archive validation failed: {'; '.join(val_report.errors)}"],
                    details={"validation_errors": val_report.errors},
                )

            # 2. Secret Scan Gate
            sec_errors = validator.validate_hygiene_and_secrets(change_path)
            if sec_errors:
                return DeltaMergeReport(
                    success=False,
                    errors=[f"Pre-archive secret/hygiene scan failed: {'; '.join(sec_errors)}"],
                    details={"secret_errors": sec_errors},
                )

        # 3. Security Review Verdict Gate (in design.md or threat-model.md)
        design_file = change_path / "design.md"
        threat_file = change_path / "threat-model.md"
        verdict_approved = False
        for f in (design_file, threat_file):
            if f.is_file():
                try:
                    c = f.read_text(encoding="utf-8")
                    m = re.search(r'Verdict:\s*(\w+)', c, re.IGNORECASE)
                    if m and m.group(1).lower() == "approved":
                        verdict_approved = True
                        break
                except Exception:
                    pass

        if not verdict_approved:
            return DeltaMergeReport(
                success=False,
                errors=[
                    "Pre-archive security review verdict check failed: "
                    "'Verdict: approved' required in design.md or threat-model.md"
                ],
            )

        # 3b. Pre-Merge Task Completion Gate: verify zero unchecked non-SYNC tasks remain before living spec merge
        unchecked_non_sync = self._find_unchecked_non_sync_tasks(change_path)
        if unchecked_non_sync:
            return DeltaMergeReport(
                success=False,
                errors=[
                    f"Pre-archive task completion gate failed: {len(unchecked_non_sync)} unchecked task(s) remain in tasks.md ({'; '.join(unchecked_non_sync[:3])})"
                ],
                details={"unchecked_tasks": unchecked_non_sync},
            )

        # 4. Living Spec Merge Gate (also auto-closes [SYNC] tasks in tasks.md)
        merge_report = self.merge_change(change_path, cli_parity=cli_parity)
        if not merge_report.success:
            return merge_report

        # 4b. Task Completion Gate: verify zero unchecked tasks remain in tasks.md before relocation
        unchecked_tasks = self._find_unchecked_tasks(change_path)
        if unchecked_tasks:
            return DeltaMergeReport(
                success=False,
                errors=[
                    f"Pre-archive task completion gate failed: {len(unchecked_tasks)} unchecked task(s) remain in tasks.md ({'; '.join(unchecked_tasks[:3])})"
                ],
                details={"unchecked_tasks": unchecked_tasks},
            )

        # 5. Archive Relocation Gate: openspec/changes/archive/YYYY-MM-DD-<change-id>/
        if not date_str:
            date_str = datetime.date.today().isoformat()

        archive_dir = self.archive_dir
        archive_dir.mkdir(parents=True, exist_ok=True)
        dest_folder_name = f"{date_str}-{change_path.name}"
        dest_path = archive_dir / dest_folder_name

        if dest_path.exists():
            return DeltaMergeReport(
                success=False,
                errors=[f"Archive destination already exists: {dest_path}"],
            )

        if MySpecGitBranchTracker is not None and (change_path / "proposal.md").is_file():
            try:
                MySpecGitBranchTracker(repo_root=self.repo_root).record_branch_in_proposal(
                    change_path / "proposal.md", phase="implemented"
                )
            except Exception:
                pass

        try:
            shutil.move(str(change_path), str(dest_path))
        except Exception as e:
            return DeltaMergeReport(
                success=False,
                errors=[f"Failed to relocate change to archive: {e}"],
            )

        if MySpecIndexManager is not None:
            try:
                idx_mgr = MySpecIndexManager(repo_root=self.repo_root)
                rel_dest = str(dest_path.relative_to(self.repo_root)).replace("\\", "/")
                summary = idx_mgr._extract_summary_from_markdown(dest_path / "proposal.md", change_path.name)
                idx_mgr.upsert_spec(
                    spec_id=change_path.name,
                    status="implemented",
                    date=date_str,
                    capabilities=merge_report.capabilities_merged or [change_path.name],
                    path=rel_dest,
                    summary=summary,
                )
            except Exception:
                pass

        return DeltaMergeReport(
            success=True,
            capabilities_merged=merge_report.capabilities_merged,
            warnings=merge_report.warnings,
            details={
                "archived_path": str(dest_path),
                "merged_capabilities": merge_report.details,
            },
        )


def main() -> int:
    """CLI entry point for scripts/myspec_sync.py."""
    parser = argparse.ArgumentParser(
        description="Merge OpenSpec delta specifications into living capability specs or archive changes."
    )
    parser.add_argument(
        "--change",
        "-c",
        required=True,
        help="Change identifier or path to change directory under openspec/changes/.",
    )
    parser.add_argument(
        "--target",
        "-t",
        default=".",
        help="Repository root target path (default: current directory).",
    )
    parser.add_argument(
        "--archive",
        action="store_true",
        help="Execute 6-stage fail-closed archive pipeline with relocation to openspec/changes/archive/.",
    )
    parser.add_argument(
        "--cli-parity",
        action="store_true",
        help="Execute upstream openspec CLI validation check if available.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON summary report to stdout.",
    )

    args = parser.parse_args()
    merger = MySpecLivingSpecMerger(repo_root=args.target)

    if args.archive:
        report = merger.archive_change(change_id_or_path=args.change, cli_parity=args.cli_parity)
    else:
        report = merger.merge_change(change_id_or_path=args.change, cli_parity=args.cli_parity)

    if args.json:
        print(json.dumps(report.to_dict(), indent=2))
    else:
        action_name = "archived" if args.archive else "merged"
        if report.success:
            print(f"PASS: Successfully {action_name} change '{args.change}' ({len(report.capabilities_merged)} capabilities):")
            for cap in report.capabilities_merged:
                print(f"  - {cap} -> openspec/specs/{cap}/spec.md")
            if args.archive and "archived_path" in report.details:
                print(f"  Archived destination: {report.details['archived_path']}")
            if report.warnings:
                print("Warnings:")
                for w in report.warnings:
                    print(f"  [WARN] {w}")
        else:
            print(f"FAIL: {action_name.capitalize()} failed with {len(report.errors)} error(s):")
            for err in report.errors:
                print(f"  [ERROR] {err}")

    return 0 if report.success else 1


if __name__ == "__main__":
    sys.exit(main())

