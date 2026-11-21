#!/usr/bin/env python3
"""MySpec Validator and Governance Engine.

Validates OpenSpec changes and living specs for tdd-spec-driven workflow,
ensuring vanilla delta grammar parity, strict TDD triads, STRIDE threat modeling,
Rule G3 security enforcement, workspace hygiene, and legacy spec parity.
"""

from __future__ import annotations

import argparse
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


@dataclass
class ValidationReport:
    """Structured report outcome for a change or workspace validation."""

    valid: bool
    status: str = "pass"
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    checks: dict[str, dict] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "status": "pass" if self.valid else "fail",
            "errors": self.errors,
            "warnings": self.warnings,
            "checks": self.checks,
        }


class MySpecValidator:
    """Core validation engine for tdd-spec-driven OpenSpec changes."""

    REQUIRED_ARTIFACT_FILES = {
        "proposal.md",
        "design.md",
        "threat-model.md",
        "test-plan.md",
        "tasks.md",
    }
    ALLOWED_DELTA_HEADERS = {
        "## ADDED Requirements",
        "## MODIFIED Requirements",
        "## REMOVED Requirements",
        "## RENAMED Requirements",
    }
    RFC2119_KEYWORDS = {"SHALL", "MUST"}
    STRIDE_CATEGORIES = {
        "Spoofing",
        "Tampering",
        "Repudiation",
        "Information Disclosure",
        "Denial of Service",
        "Elevation of Privilege",
    }
    TASK_PHASES = {"RED", "GREEN", "REFACTOR", "DOC", "SYNC", "MANUAL"}
    HTML_COMMENT_RE = re.compile(r"<!--[\s\S]*?-->")
    BC_SECTION_HEADER_RE = re.compile(
        r"^##\s+[^\n]*(?:Domain Carrier|Bounded Context Ownership|Decision Ownership)",
        re.IGNORECASE | re.MULTILINE,
    )
    AR_SECTION_HEADER_RE = re.compile(
        r"^##\s+[^\n]*(?:Architecture Memory|Module Boundaries)",
        re.IGNORECASE | re.MULTILINE,
    )
    BC_ID_RE = re.compile(
        r"^[ \t]*-\s*(?:\*\*BC-(?:(?:OWN|FORBID|REF|POL)-)?\d{3}\*\*|BC-(?:(?:OWN|FORBID|REF|POL)-)?\d{3})\s*:\s*(.+)$",
        re.MULTILINE,
    )
    AR_ID_RE = re.compile(
        r"^[ \t]*-\s*(?:\*\*AR-(?:(?:MOD|SAGA)-)?\d{3}\*\*|AR-(?:(?:MOD|SAGA)-)?\d{3})\s*:\s*(.+)$",
        re.MULTILINE,
    )
    OWNED_DECISIONS_RE = re.compile(
        r"^[ \t]*-\s*(?:\*\*Owned Decisions\*\*|Owned Decisions)\s*:\s*(.+)$",
        re.IGNORECASE | re.MULTILINE,
    )
    FORBIDDEN_RESP_RE = re.compile(
        r"^[ \t]*-\s*(?:\*\*Forbidden Responsibilities\*\*|Forbidden Responsibilities)\s*:\s*(.+)$",
        re.IGNORECASE | re.MULTILINE,
    )
    EXTERNAL_DECISION_REFS_RE = re.compile(
        r"^[ \t]*-\s*(?:\*\*External Decision References\*\*|External Decision References)\s*:\s*(.+)$",
        re.IGNORECASE | re.MULTILINE,
    )
    NEEDS_CLARIFICATION_RE = re.compile(r"\[NEEDS\s+CLARIFICATION\b[^\]]*\]", re.IGNORECASE)
    TBD_PLACEHOLDER_RE = re.compile(r"(?:\[\s*TBD\s*\]|\bTBD\b|\bTODO\b)")
    RULE_G3_PROTECTED_ID_RE = re.compile(
        r"\b(?:SEC-\d+|(?:UI|DATA|API|TEST|SDD)-\d{3}|BC-(?:(?:OWN|FORBID|REF|POL)-)?\d{3}|AR-(?:(?:MOD|SAGA)-)?\d{3})\b"
    )
    CONVERGENCE_CATEGORIES = {"missing", "partial", "contradicts", "unrequested"}
    CONVERGENCE_TAG_RE = re.compile(r"\[CONVERGENCE:\s*([a-zA-Z_-]+)\]", re.IGNORECASE)

    CONSTITUTION_ROOT_MAX_LINES = 45
    CONSTITUTION_INDEX_MAX_LINES = 25
    CONSTITUTION_MICRO_MAX_LINES = 40
    CONSTITUTION_MAX_BYTES = 65536
    CANONICAL_CONSTITUTION_AREAS: dict[str, str] = {
        "01-architecture": "AR",
        "02-domain": "BC",
        "03-ui-ux": "UI",
        "04-data-persistence": "DATA",
        "05-api-contracts": "API",
        "06-testing-fitness": "TEST",
        "07-security-privacy": "SEC",
        "08-sdd-governance": "SDD",
    }
    MANDATORY_ACTIVE_AREAS = frozenset(
        {"06-testing-fitness", "07-security-privacy", "08-sdd-governance"}
    )
    BARE_BONES_HEADING_RE = re.compile(r"^#{1,3}\s+\S.*$")
    BARE_BONES_TABLE_RE = re.compile(r"^\|.+\|$")
    BARE_BONES_CONTEXT_RE = re.compile(r"^-\s+[a-z0-9_]+:\s+\S.*$")
    BARE_BONES_RULE_RE = re.compile(
        r"^-\s+\*\*(AR|BC|UI|DATA|API|TEST|SEC|SDD)-(\d{3})\*\*:\s+.*\bSHALL\b.*$"
    )
    FORBIDDEN_PROSE_SECTION_RE = re.compile(
        r"^#{1,6}\s+(?:Purpose|Overview|Introduction|Background|Rationale|Preambolo)\b",
        re.IGNORECASE,
    )
    CONSTITUTION_CITATION_RE = re.compile(
        r"\b(AR|BC|UI|DATA|API|TEST|SEC|SDD)-(\d{3})\b"
    )
    CONSTITUTION_SECRET_PATTERNS = (
        (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS Access Key"),
        (re.compile(r"ghp_[A-Za-z0-9]{36}"), "GitHub Personal Access Token"),
        (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "Private Key"),
        (re.compile(r"sk-[A-Za-z0-9]{32,}"), "API Secret Key"),
    )

    def __init__(self, repo_root: Path | str | None = None, strict: bool = True) -> None:
        self.repo_root = Path(repo_root or os.getcwd()).resolve()
        self.strict = strict

        if MySpecConfigManager:
            self.config_mgr = MySpecConfigManager(repo_root=self.repo_root)
            self.cfg = self.config_mgr.resolve_config()
            self.spec_root = self.cfg["spec_root"]
            self.changes_dir = self.config_mgr.get_changes_dir()
            self.specs_dir = self.config_mgr.get_specs_dir()
            self.constitution_file = self.config_mgr.get_constitution_file()
            self.constitution_dir = self.config_mgr.get_constitution_dir()
        else:
            self.spec_root = "openspec"
            self.changes_dir = self.repo_root / "openspec" / "changes"
            self.specs_dir = self.repo_root / "openspec" / "specs"
            self.constitution_file = self.repo_root / "openspec" / "Constitution.md"
            self.constitution_dir = self.repo_root / "openspec" / "constitution"

    @staticmethod
    def _strip_delta_directives(desc: str) -> str:
        """Strip reconciliation directives and Security-Waiver lines from requirement description."""
        if not desc:
            return ""
        cleaned = []
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
            cleaned.append(line)
        return "\n".join(cleaned).strip()

    def _load_living_spec_requirements(self, capability: str) -> dict[str, dict] | None:
        """Load and parse consolidated requirements from <specs_dir>/<capability>/spec.md if present."""
        living_file = self.specs_dir / capability / "spec.md"
        if not living_file.is_file():
            return None
        try:
            content = living_file.read_text(encoding="utf-8")
        except Exception:
            return None

        reqs: dict[str, dict] = {}
        req_blocks = re.findall(
            r'^(### Requirement:[^\n]+)([\s\S]*?)(?=^### Requirement:|^## |\Z)',
            content,
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
            sc_dict: dict[str, str] = {}
            for sc_hdr, sc_body in scenarios:
                sc_title = sc_hdr.replace("#### Scenario:", "").strip()
                sc_dict[sc_title] = sc_body.strip()
            reqs[req_title] = {
                "title": req_title,
                "body": req_body.strip(),
                "description": desc,
                "scenarios": sc_dict,
            }
        return reqs

    @staticmethod
    def _is_security_scenario_body(sc_body: str) -> bool:
        """Return True if a scenario body carries '- **Trait**: security'."""
        return bool(re.search(r'-\s*\*\*Trait\*\*:\s*[^\n]*\bsecurity\b', sc_body, re.IGNORECASE))

    @classmethod
    def _is_living_req_security(cls, req_data: dict) -> bool:
        """Return True if a living spec requirement has SEC-xxx, BC-xxx, AR-xxx, or any security-traited scenario."""
        if cls.RULE_G3_PROTECTED_ID_RE.search(req_data.get("title", "")) or cls.RULE_G3_PROTECTED_ID_RE.search(
            req_data.get("body", "")
        ):
            return True
        return any(cls._is_security_scenario_body(body) for body in req_data.get("scenarios", {}).values())

    @classmethod
    def _is_change_already_synced(cls, change_path: Path) -> bool:
        """Return True if tasks.md has at least one completed (- [x]) [SYNC] task AND zero unchecked (- [ ]) [SYNC] tasks."""
        tasks_file = change_path / "tasks.md"
        if not tasks_file.is_file():
            return False
        try:
            content = cls._strip_html_comments(tasks_file.read_text(encoding="utf-8"))
            has_completed_sync = bool(
                re.search(
                    r'^[ \t]*-\s*\[[xX]\]\s+\d+\.\d+\s+.*?\[(?:PHASE:\s*)?SYNC\]',
                    content,
                    re.MULTILINE,
                )
            )
            has_unchecked_sync = bool(
                re.search(
                    r'^[ \t]*-\s*\[ \]\s+\d+\.\d+\s+.*?\[(?:PHASE:\s*)?SYNC\]',
                    content,
                    re.MULTILINE,
                )
            )
            return has_completed_sync and not has_unchecked_sync
        except Exception:
            return False

    @staticmethod
    def _strip_html_comments(text: str) -> str:
        """Strip HTML comment blocks (<!-- ... -->) from markdown content."""
        return re.sub(r'<!--[\s\S]*?-->', '', text)

    @classmethod
    def _change_modifies_prior_specs(cls, change_path: Path) -> bool:
        """Return True if any capability delta in change_path declares RENAMED, REMOVED, or MODIFIED entries."""
        specs_dir = change_path / "specs"
        if not specs_dir.is_dir():
            return False
        for spec_file in specs_dir.glob("**/spec.md"):
            try:
                content = spec_file.read_text(encoding="utf-8")
            except Exception:
                continue
            sections = re.findall(r'^(## [^\n]+)([\s\S]*?)(?=^## |\Z)', content, re.MULTILINE)
            for sec_hdr, sec_body in sections:
                if any(k in sec_hdr for k in ("MODIFIED Requirements", "REMOVED Requirements", "RENAMED Requirements")):
                    if cls._strip_html_comments(sec_body).strip():
                        return True
        return False

    def validate_change(
        self,
        change_dir: Path | str,
        cli_parity: bool = False,
    ) -> ValidationReport:
        """Validate a single change directory against all specification rules."""
        change_path = Path(change_dir)
        if not change_path.is_absolute():
            candidate = (self.repo_root / change_path).resolve()
            if not candidate.is_dir() and hasattr(self, "changes_dir"):
                candidate_under_changes = (self.changes_dir / change_path).resolve()
                if candidate_under_changes.is_dir():
                    candidate = candidate_under_changes
            change_path = candidate

        errors: list[str] = []
        warnings: list[str] = []
        checks: dict[str, dict] = {}

        if not change_path.is_dir():
            return ValidationReport(
                valid=False,
                status="fail",
                errors=[f"Change directory does not exist: {change_path}"],
                checks={"directory": {"pass": False}},
            )

        # 1. Artifact Presence Check
        art_errors = self._validate_artifact_presence(change_path)
        errors.extend(art_errors)
        checks["artifacts"] = {"pass": len(art_errors) == 0, "issues": art_errors}

        # 2. Delta Grammar in specs/**/spec.md
        spec_errors, spec_warnings = self._validate_delta_specs(change_path)
        errors.extend(spec_errors)
        warnings.extend(spec_warnings)
        checks["delta_specs"] = {
            "pass": len(spec_errors) == 0,
            "issues": spec_errors,
            "warnings": spec_warnings,
        }

        # 3. Tasks Triads & Stray Checkboxes
        tasks_errors = self._validate_tasks_triads(change_path)
        errors.extend(tasks_errors)
        checks["tasks"] = {"pass": len(tasks_errors) == 0, "issues": tasks_errors}

        # 4. Manual Operations Runbook & Proposal Metadata
        manual_errors = self._validate_manual_steps(change_path)
        errors.extend(manual_errors)
        checks["manual_steps"] = {"pass": len(manual_errors) == 0, "issues": manual_errors}

        # 5. Security, STRIDE & Rule G3
        sec_errors = self.validate_security(change_path)
        errors.extend(sec_errors)
        checks["security"] = {"pass": len(sec_errors) == 0, "issues": sec_errors}

        # 6. Domain Carrier (BC-###) & Architecture Memory (AR-###) Conditional Guards
        bc_ar_errors, bc_ar_warnings = self._validate_domain_architecture_guards(change_path)
        errors.extend(bc_ar_errors)
        warnings.extend(bc_ar_warnings)
        checks["domain_architecture"] = {
            "pass": len(bc_ar_errors) == 0,
            "issues": bc_ar_errors,
            "warnings": bc_ar_warnings,
        }

        # 6b. Presence-Aware 6-Artifact Constitutional Traceability & Sync Impact Gate
        if self.constitution_file.is_file() and change_path.resolve().is_relative_to(self.repo_root):
            tr_errors, tr_warnings = self._validate_constitution_traceability(change_path)
            errors.extend(tr_errors)
            warnings.extend(tr_warnings)
            checks["constitution_traceability"] = {
                "pass": len(tr_errors) == 0,
                "issues": tr_errors,
                "warnings": tr_warnings,
            }

        # 7. CLI Parity (Optional subprocess execution)
        cli_res = self._run_cli_parity_if_requested(change_path, cli_parity)
        checks["cli_parity"] = cli_res
        if not cli_res.get("pass", True):
            errors.append(cli_res.get("error", "CLI parity validation failed"))

        is_valid = len(errors) == 0
        return ValidationReport(
            valid=is_valid,
            status="pass" if is_valid else "fail",
            errors=errors,
            warnings=warnings,
            checks=checks,
        )

    def _validate_artifact_presence(self, change_path: Path) -> list[str]:
        """Verify presence of required artifact files and specs subfolder."""
        errors: list[str] = []
        for req_file in self.REQUIRED_ARTIFACT_FILES:
            if not (change_path / req_file).is_file():
                errors.append(f"Missing required artifact: {req_file}")

        # Check for specs/**/*.md
        specs_dir = change_path / "specs"
        if not specs_dir.is_dir():
            errors.append("Missing required specs/ directory for capability deltas")
        else:
            spec_files = list(specs_dir.glob("**/spec.md"))
            if not spec_files:
                errors.append("Missing capability delta: no specs/**/spec.md found")

        # Validate - Branch: inside proposal.md when ## Metadata is present
        proposal_file = change_path / "proposal.md"
        if proposal_file.is_file():
            try:
                prop_text = proposal_file.read_text(encoding="utf-8")
                if "## Metadata" in prop_text:
                    branch_match = re.search(r"^-\s*Branch:\s*(.+)$", prop_text, re.MULTILINE)
                    if not branch_match or not branch_match.group(1).strip():
                        errors.append(
                            "proposal.md missing required '- Branch: <git-branch>' entry under '## Metadata'"
                        )
            except Exception as e:
                errors.append(f"Could not read proposal.md: {e}")

        return errors

    def _validate_delta_specs(self, change_path: Path) -> tuple[list[str], list[str]]:
        """Verify section-aware OpenSpec delta grammar, requirement length, living-spec cross-check, and path coverage."""
        errors: list[str] = []
        warnings: list[str] = []
        specs_dir = change_path / "specs"
        if not specs_dir.is_dir():
            return errors, warnings

        already_synced = self._is_change_already_synced(change_path)
        spec_files = list(specs_dir.glob("**/spec.md"))
        for spec_file in spec_files:
            try:
                content = spec_file.read_text(encoding="utf-8")
            except Exception as e:
                errors.append(f"Could not read {spec_file.relative_to(change_path)}: {e}")
                continue

            capability = str(spec_file.relative_to(specs_dir).parent)
            living_reqs = self._load_living_spec_requirements(capability)

            # Purpose check
            if "## Purpose" in content:
                purpose_match = re.search(r'^## Purpose\s*\n+([\s\S]*?)(?=^## |\Z)', content, re.MULTILINE)
                if purpose_match:
                    purpose_text = self._strip_delta_directives(purpose_match.group(1).strip())
                    if self.strict and len(purpose_text) < 50:
                        errors.append(
                            f"Purpose in {spec_file.name} is {len(purpose_text)} chars (< 50 chars required in strict mode)"
                        )
            elif self.strict:
                warnings.append(f"Missing '## Purpose' in {spec_file.name}")

            # Check for at least one delta section header
            delta_headers = [h for h in self.ALLOWED_DELTA_HEADERS if h in content]
            if not delta_headers:
                errors.append(
                    f"{spec_file.name} has no delta section. Must declare one of: {', '.join(self.ALLOWED_DELTA_HEADERS)}"
                )

            sections = re.findall(r'^(## [^\n]+)([\s\S]*?)(?=^## |\Z)', content, re.MULTILINE)
            renamed_to_from: dict[str, str] = {}
            total_delta_items = 0

            # First pass: collect RENAMED pairs so MODIFIED can resolve post-rename titles
            for sec_header, raw_sec_body in sections:
                sec_body = self._strip_html_comments(raw_sec_body)
                if "RENAMED Requirements" in sec_header:
                    rename_pairs = re.findall(
                        r'-\s*FROM:\s*`?(?:###\s+Requirement:\s*)?([^`\n]+?)`?\s*\n\s*-\s*TO:\s*`?(?:###\s+Requirement:\s*)?([^`\n]+?)`?[ \t]*(?=\n|\Z)',
                        sec_body,
                        re.IGNORECASE,
                    )
                    if sec_body.strip() and not rename_pairs:
                        errors.append(
                            f"RENAMED Requirements section in {spec_file.name} contains no valid '- FROM: `### Requirement: <Old>`' / '- TO: `### Requirement: <New>`' pairs"
                        )
                    for old_raw, new_raw in rename_pairs:
                        total_delta_items += 1
                        old_t, new_t = old_raw.strip(), new_raw.strip()
                        if not old_t or not new_t or old_t == new_t:
                            errors.append(
                                f"Invalid RENAMED pair in {spec_file.name}: FROM '{old_t}' TO '{new_t}' (titles must be non-empty and distinct)"
                            )
                        else:
                            renamed_to_from[new_t] = old_t
                            if living_reqs is not None:
                                pre_ok = old_t in living_reqs
                                post_ok = already_synced and (new_t in living_reqs)
                                if not (pre_ok or post_ok):
                                    msg = f"RENAMED source requirement '{old_t}' in {spec_file.name} was not found in living spec '{capability}/spec.md'"
                                    if self.strict:
                                        errors.append(msg)
                                    else:
                                        warnings.append(msg)

            # Second pass: validate ADDED, MODIFIED, and REMOVED requirements
            for sec_header, raw_sec_body in sections:
                sec_body = self._strip_html_comments(raw_sec_body)
                header = sec_header.strip()
                sec_type = None
                if "ADDED Requirements" in header:
                    sec_type = "added"
                elif "MODIFIED Requirements" in header:
                    sec_type = "modified"
                elif "REMOVED Requirements" in header:
                    sec_type = "removed"
                elif "RENAMED Requirements" in header:
                    continue

                if not sec_type:
                    continue

                req_blocks = re.findall(
                    r'^(### Requirement:[^\n]+)([\s\S]*?)(?=^### Requirement:|^## |\Z)',
                    sec_body,
                    re.MULTILINE,
                )

                for req_header, req_body in req_blocks:
                    total_delta_items += 1
                    req_title = req_header.replace("### Requirement:", "").strip()
                    desc_match = re.search(r'([\s\S]*?)(?=^#### Scenario:|\Z)', req_body, re.MULTILINE)
                    raw_desc = desc_match.group(1).strip() if desc_match else ""

                    if sec_type == "removed":
                        if not re.search(r'(?:\*\*Reason\*\*|Reason)\s*:\s*\S+', req_body, re.IGNORECASE):
                            errors.append(
                                f"REMOVED requirement '{req_title}' in {spec_file.name} missing required '**Reason**: <justification>'"
                            )
                        if living_reqs is not None:
                            pre_ok = req_title in living_reqs
                            post_ok = already_synced and (req_title not in living_reqs)
                            if not (pre_ok or post_ok):
                                msg = f"REMOVED requirement '{req_title}' in {spec_file.name} was not found in living spec '{capability}/spec.md'"
                                if self.strict:
                                    errors.append(msg)
                                else:
                                    warnings.append(msg)
                        continue

                    # Parse scenario directives in MODIFIED
                    removed_sc_titles: list[str] = []
                    renamed_sc_pairs: list[tuple[str, str]] = []
                    if sec_type == "modified":
                        for m in re.finditer(
                            r'^[ \t]*-\s*\*\*REMOVED-SCENARIO\*\*:\s*`?([^`\n—–-]+?)`?(?:\s*(?:—|–|--|-)\s*\*\*Reason\*\*:\s*(.+))?[ \t]*$',
                            raw_desc,
                            re.MULTILINE,
                        ):
                            sc_name = m.group(1).replace("#### Scenario:", "").strip()
                            sc_reason = (m.group(2) or "").strip()
                            if not sc_reason:
                                errors.append(
                                    f"REMOVED-SCENARIO directive for '{sc_name}' in '{req_title}' ({spec_file.name}) requires '**Reason**: <text>'"
                                )
                            removed_sc_titles.append(sc_name)

                        for m in re.finditer(
                            r'^[ \t]*-\s*\*\*RENAMED-SCENARIO\*\*:\s*FROM\s+`?([^`\n]+?)`?\s+TO\s+`?([^`\n]+?)`?[ \t]*$',
                            raw_desc,
                            re.MULTILINE | re.IGNORECASE,
                        ):
                            old_sc = m.group(1).replace("#### Scenario:", "").strip()
                            new_sc = m.group(2).replace("#### Scenario:", "").strip()
                            if not old_sc or not new_sc or old_sc == new_sc:
                                errors.append(
                                    f"Invalid RENAMED-SCENARIO directive in '{req_title}' ({spec_file.name}): FROM '{old_sc}' TO '{new_sc}'"
                                )
                            else:
                                renamed_sc_pairs.append((old_sc, new_sc))

                    desc = self._strip_delta_directives(raw_desc)

                    # RFC 2119 Keyword Check
                    has_rfc = any(kw in desc for kw in self.RFC2119_KEYWORDS)
                    if not has_rfc:
                        errors.append(
                            f"Requirement '{req_title}' in {spec_file.name} lacks English RFC 2119 keyword (SHALL or MUST)"
                        )

                    # 500 characters limit (excluding directive lines)
                    if len(desc) > 500:
                        errors.append(
                            f"Requirement '{req_title}' in {spec_file.name} exceeds 500 characters ({len(desc)} chars)"
                        )

                    # Cross-check against living spec if present
                    orig_living_req = None
                    if living_reqs is not None:
                        if sec_type == "modified":
                            lookup_title = renamed_to_from.get(req_title, req_title)
                            orig_living_req = living_reqs.get(lookup_title) or living_reqs.get(req_title)
                            if orig_living_req is None:
                                msg = f"MODIFIED requirement '{req_title}' in {spec_file.name} was not found in living spec '{capability}/spec.md'"
                                if self.strict:
                                    errors.append(msg)
                                else:
                                    warnings.append(msg)
                        elif sec_type == "added":
                            if req_title in living_reqs and not already_synced:
                                live_desc = living_reqs[req_title].get("description", "")
                                if live_desc != desc:
                                    msg = f"ADDED requirement '{req_title}' in {spec_file.name} already exists in living spec '{capability}/spec.md' (use MODIFIED instead)"
                                    if self.strict:
                                        errors.append(msg)
                                    else:
                                        warnings.append(msg)

                    # Scenarios check anchored to start of line
                    scenarios = re.findall(
                        r'^(#### Scenario:[^\n]+)([\s\S]*?)(?=^#### Scenario:|\Z)',
                        req_body,
                        re.MULTILINE,
                    )
                    if not scenarios and not (sec_type == "modified" and (removed_sc_titles or renamed_sc_pairs)):
                        errors.append(f"Requirement '{req_title}' in {spec_file.name} has 0 scenarios (>= 1 required)")
                        continue

                    for sc_header, sc_body in scenarios:
                        has_given = bool(re.search(r'(?:- \*\*GIVEN\*\*|Given\b)', sc_body, re.IGNORECASE))
                        has_when = bool(re.search(r'(?:- \*\*WHEN\*\*|When\b)', sc_body, re.IGNORECASE))
                        has_then = bool(re.search(r'(?:- \*\*THEN\*\*|Then\b)', sc_body, re.IGNORECASE))

                        if not (has_given and has_when and has_then):
                            errors.append(
                                f"Scenario in requirement '{req_title}' missing Given/When/Then structure"
                            )

                    # Build effective scenario dictionary for Path Coverage check (post-merge for MODIFIED)
                    effective_scenarios: dict[str, str] = {}
                    if sec_type == "modified" and orig_living_req is not None:
                        effective_scenarios = dict(orig_living_req.get("scenarios", {}))
                        for old_sc, new_sc in renamed_sc_pairs:
                            if old_sc in effective_scenarios:
                                effective_scenarios[new_sc] = effective_scenarios.pop(old_sc)
                        for rem_sc in removed_sc_titles:
                            effective_scenarios.pop(rem_sc, None)

                    for sc_header, sc_body in scenarios:
                        sc_title = sc_header.replace("#### Scenario:", "").strip()
                        effective_scenarios[sc_title] = sc_body.strip()

                    has_positive_path = False
                    has_negative_path = False
                    for sc_title, sc_body in effective_scenarios.items():
                        path_match = re.search(r'-\s*\*\*Path\*\*:\s*([^\n·]+)', sc_body)
                        if path_match:
                            path_str = path_match.group(1).strip()
                            if "P" in path_str:
                                has_positive_path = True
                            if "N" in path_str:
                                has_negative_path = True

                    if not (has_positive_path and has_negative_path):
                        errors.append(
                            f"Requirement '{req_title}' in {spec_file.name} violates Path Coverage Rule: "
                            f"must contain at least 1 positive path (P#) and 1 negative path (N#)"
                        )

            if total_delta_items == 0 and delta_headers:
                errors.append(f"{spec_file.name} declares delta headers but contains no '### Requirement:' or RENAMED pairs")

        return errors, warnings

    def _validate_tasks_triads(self, change_path: Path) -> list[str]:
        """Verify tasks.md numbering, TDD triad/quad sequences (including DOC, SYNC, and MANUAL), and stray checkboxes.

        Args:
            change_path: Path to the target change directory containing tasks.md.

        Returns:
            List of diagnostic validation error messages (empty if valid).
        """
        errors: list[str] = []
        tasks_file = change_path / "tasks.md"
        if not tasks_file.is_file():
            return errors

        try:
            content = tasks_file.read_text(encoding="utf-8")
        except Exception as e:
            return [f"Could not read tasks.md: {e}"]

        clean_content = self._strip_html_comments(content)
        lines = clean_content.splitlines()
        in_code_block = False

        # Unit groups tracking: unit_id -> list of (phase, paths)
        unit_tasks: dict[str, list[dict]] = {}
        current_unit = "Default"
        has_sync_task = False

        for line_num, raw_line in enumerate(lines, 1):
            line = raw_line.strip()
            if line.startswith("```"):
                in_code_block = not in_code_block
                continue

            # Detect unit headers: ## 1. Unit: <UnitName>
            unit_header_match = re.match(r'^##\s+[0-9]+\.\s+Unit:\s*(.+)$', line, re.IGNORECASE)
            if unit_header_match:
                current_unit = unit_header_match.group(1).strip()
                if current_unit not in unit_tasks:
                    unit_tasks[current_unit] = []
                continue

            # Checkbox detection
            checkbox_match = re.search(r'-\s*\[([ xX])\]\s*(.*)$', line)
            if checkbox_match:
                task_text = checkbox_match.group(2).strip()

                # Rule: Checkbox inside code fence or prose commentary is stray
                if in_code_block:
                    errors.append(f"Stray checkbox detected inside code fence at tasks.md:{line_num}")
                    continue

                # Rule: Must match strict numbering ^[0-9]+\.[0-9]+
                num_match = re.match(r'^([0-9]+\.[0-9]+)\s*(.*)$', task_text)
                if not num_match:
                    errors.append(
                        f"Stray checkbox detected at tasks.md:{line_num}: "
                        f"Must follow format '- [ ] X.Y ...' (got: '{line}')"
                    )
                    continue

                task_num = num_match.group(1)
                task_desc = num_match.group(2)

                # Convergence tag validation (ignoring inline markdown code spans)
                desc_without_code = re.sub(r"`[^`]*`", "", task_desc)
                conv_match = self.CONVERGENCE_TAG_RE.search(desc_without_code)
                if conv_match:
                    cat = conv_match.group(1).lower()
                    if cat not in self.CONVERGENCE_CATEGORIES:
                        errors.append(
                            f"Invalid convergence drift category '{conv_match.group(1)}' at tasks.md:{line_num} "
                            f"(must be one of: {', '.join(sorted(self.CONVERGENCE_CATEGORIES))})"
                        )

                # Phase detection
                phase = None
                if "[PHASE: RED]" in task_desc or "[RED]" in task_desc:
                    phase = "RED"
                elif "[PHASE: GREEN]" in task_desc or "[GREEN]" in task_desc:
                    phase = "GREEN"
                elif "[PHASE: REFACTOR]" in task_desc or "[REFACTOR]" in task_desc:
                    phase = "REFACTOR"
                elif "[PHASE: DOC]" in task_desc or "[DOC]" in task_desc:
                    phase = "DOC"
                elif "[PHASE: SYNC]" in task_desc or "[SYNC]" in task_desc:
                    phase = "SYNC"
                    has_sync_task = True
                elif "[PHASE: MANUAL]" in task_desc or "[MANUAL]" in task_desc:
                    phase = "MANUAL"

                if current_unit not in unit_tasks:
                    unit_tasks[current_unit] = []

                unit_tasks[current_unit].append({
                    "line": line_num,
                    "num": task_num,
                    "desc": task_desc,
                    "phase": phase,
                })

        # Verify TDD Triads and Quad (RED -> GREEN -> REFACTOR -> [DOC]) order per unit (ignoring standalone SYNC tasks)
        for unit_name, tasks in unit_tasks.items():
            phases = [t["phase"] for t in tasks if t["phase"] is not None and t["phase"] != "SYNC"]
            if not phases:
                continue

            # State machine validates cycles: RED -> GREEN -> REFACTOR -> (optional DOC) -> (next cycle or end)
            state = "EXPECT_RED"
            for t in tasks:
                p = t["phase"]
                if p is None or p == "SYNC":
                    continue
                num = t["num"]

                if state == "EXPECT_RED":
                    if p == "MANUAL":
                        continue
                    if p != "RED":
                        errors.append(
                            f"TDD Triad sequence violation in Unit '{unit_name}' (task {num}): "
                            f"Expected RED to start cycle, got {p}"
                        )
                        break
                    state = "EXPECT_GREEN"

                elif state == "EXPECT_GREEN":
                    if p != "GREEN":
                        errors.append(
                            f"TDD Triad sequence violation in Unit '{unit_name}' (task {num}): "
                            f"Expected GREEN, got {p}"
                        )
                        break
                    state = "EXPECT_REFACTOR"

                elif state == "EXPECT_REFACTOR":
                    if p != "REFACTOR":
                        errors.append(
                            f"TDD Triad sequence violation in Unit '{unit_name}' (task {num}): "
                            f"Expected REFACTOR, got {p}"
                        )
                        break
                    state = "AFTER_REFACTOR"

                elif state == "AFTER_REFACTOR":
                    if p == "DOC":
                        state = "EXPECT_RED"
                    elif p == "MANUAL":
                        state = "EXPECT_RED"
                    elif p == "RED":
                        state = "EXPECT_GREEN"
                    else:
                        errors.append(
                            f"TDD Triad sequence violation in Unit '{unit_name}' (task {num}): "
                            f"Expected RED, DOC, or MANUAL after REFACTOR, got {p}"
                        )
                        break

            if state in ("EXPECT_GREEN", "EXPECT_REFACTOR"):
                errors.append(
                    f"TDD Triad sequence violation in Unit '{unit_name}': "
                    f"Incomplete cycle, ended in state {state}"
                )

        # Require a [SYNC] task when the change modifies consolidated specifications (MODIFIED, REMOVED, or RENAMED)
        if self.strict and self._change_modifies_prior_specs(change_path) and not has_sync_task:
            errors.append(
                "Missing required '[SYNC]' task in tasks.md: changes with MODIFIED, REMOVED, or RENAMED requirements must include a '- [ ] X.Y [SYNC] ...' reconciliation task."
            )

        return errors

    def _validate_manual_steps(self, change_path: Path) -> list[str]:
        """Validate manual operations runbook (manual-steps.md), proposal metadata, and [MANUAL] tasks.

        Verifies bidirectional presence between manual-steps.md, proposal.md (- Manual-Steps:),
        and tasks.md ([MANUAL] task), path confinement against directory traversal (CWE-22),
        and schematic step structure (action, numbered step, reason <= 2 lines).

        Args:
            change_path: Path to the target change directory.

        Returns:
            List of diagnostic or security validation error messages (empty if valid).
        """
        errors: list[str] = []

        # 1. Inspect proposal.md for - Manual-Steps: declaration
        proposal_file = change_path / "proposal.md"
        manual_meta_val: str | None = None
        if proposal_file.is_file():
            try:
                p_text = proposal_file.read_text(encoding="utf-8")
                m_meta = re.search(r'^[ \t]*-\s*Manual-Steps\s*:\s*([^\n\r]+)', p_text, re.MULTILINE | re.IGNORECASE)
                if m_meta:
                    manual_meta_val = m_meta.group(1).strip()
            except Exception as e:
                errors.append(f"Could not read proposal.md: {e}")

        has_proposal_decl = False
        if manual_meta_val:
            raw_target = manual_meta_val.split("(")[0].strip()
            # If template placeholder like [none | ...], treat as none
            if raw_target.startswith("[") and "none" in raw_target.lower():
                raw_target = "none"

            # Path confinement check (CWE-22)
            if ".." in raw_target or raw_target.startswith("/") or raw_target.startswith("\\"):
                errors.append(
                    f"Security violation (CWE-22): Path traversal or absolute path detected in - Manual-Steps: '{manual_meta_val}' in proposal.md"
                )
            elif raw_target.lower() != "none":
                has_proposal_decl = True
                if raw_target != "manual-steps.md":
                    errors.append(
                        f"Invalid path in - Manual-Steps:: must reference 'manual-steps.md' inside change directory (got '{raw_target}')"
                    )

        # 2. Inspect tasks.md for [MANUAL] tasks
        tasks_file = change_path / "tasks.md"
        has_manual_task = False
        if tasks_file.is_file():
            try:
                t_text = tasks_file.read_text(encoding="utf-8")
                clean_t_text = self._strip_html_comments(t_text)
                has_manual_task = bool(
                    re.search(
                        r'-\s*\[([ xX])\]\s*[0-9]+\.[0-9]+\s*(?:\[PHASE:\s*MANUAL\]|\[MANUAL\])',
                        clean_t_text,
                        re.IGNORECASE,
                    )
                )
            except Exception:
                pass

        # 3. Inspect manual-steps.md file existence
        manual_file = change_path / "manual-steps.md"
        has_manual_file = manual_file.is_file()

        # 4. Bidirectional presence enforcement
        if has_manual_file or has_proposal_decl or has_manual_task:
            if not has_manual_file:
                errors.append(
                    "Missing required 'manual-steps.md' runbook file in change directory: "
                    "manual operations declared in proposal.md or tasks.md but file not found"
                )
            if not has_proposal_decl:
                errors.append(
                    "Missing '- Manual-Steps:' declaration under '## Metadata' in proposal.md for manual operations"
                )
            if not has_manual_task:
                errors.append(
                    "Missing required '[MANUAL]' task in tasks.md: "
                    "manual-steps.md runbook exists but no completion task is defined in tasks.md"
                )

        # 5. Validate schematic content of manual-steps.md if present
        if has_manual_file:
            try:
                m_content = manual_file.read_text(encoding="utf-8")
                lines = m_content.splitlines()

                step_pattern = re.compile(
                    r'^(?:#{2,4}\s+(?:Step|Passaggio)\s+[0-9]+[:\s].*|[0-9]+\.\s+\*\*.*)',
                    re.IGNORECASE,
                )

                steps: list[tuple[str, list[str]]] = []
                current_title = ""
                current_body: list[str] = []

                for line in lines:
                    if step_pattern.match(line.strip()):
                        if current_title:
                            steps.append((current_title, current_body))
                        current_title = line.strip()
                        current_body = []
                    elif current_title:
                        current_body.append(line)

                if current_title:
                    steps.append((current_title, current_body))

                if not steps:
                    errors.append(
                        "Invalid manual-steps.md: must contain at least one numbered step "
                        "(e.g. '### Step N: <Title>' or '### Passaggio N: <Titolo>')"
                    )
                else:
                    for title, body_lines in steps:
                        body_text = "\n".join(body_lines)
                        if not re.search(r'-\s*\*\*(?:Action|Cosa si fa)\*\*\s*:', body_text, re.IGNORECASE):
                            errors.append(
                                f"Missing action ('- **Action**:' or '- **Cosa si fa**:') in manual-steps.md for step '{title}'"
                            )

                        why_lines: list[str] = []
                        found_why = False
                        for bline in body_lines:
                            if not found_why:
                                m = re.match(r'^\s*-\s*\*\*(?:Why|Motivo)\*\*\s*:(.*)', bline, re.IGNORECASE)
                                if m:
                                    found_why = True
                                    inline_text = m.group(1).strip()
                                    if inline_text:
                                        why_lines.append(inline_text)
                            else:
                                if re.match(r'^\s*-\s*\*\*', bline) or step_pattern.match(bline.strip()):
                                    break
                                sline = bline.strip()
                                if sline:
                                    why_lines.append(sline)

                        if not found_why:
                            errors.append(
                                f"Missing rationale ('- **Why**:' or '- **Motivo**:') in manual-steps.md for step '{title}'"
                            )
                        elif len(why_lines) > 2:
                            errors.append(
                                f"Step rationale in manual-steps.md exceeds 2 lines limit (got {len(why_lines)} lines in step '{title}')"
                            )
                        elif len(why_lines) == 0:
                            errors.append(
                                f"Empty rationale in manual-steps.md for step '{title}'"
                            )
            except Exception as e:
                errors.append(f"Could not read manual-steps.md: {e}")

        return errors

    def _validate_domain_architecture_guards(self, change_path: Path) -> tuple[list[str], list[str]]:
        """Validate opt-in Domain Carrier (BC-###) and Architecture Memory (AR-###) governance guards.

        Strips HTML comments first so commented-out template sections remain 100% backward-compatible.
        When uncommented BC-### or AR-### sections or rule definitions are present, enforces:
        - Non-empty Owned Decisions, Forbidden Responsibilities, and External Decision References for BC-###
        - At least one concrete AR-### rule definition when an AR section is declared
        - Zero unresolved [NEEDS CLARIFICATION...] or [TBD]/TODO placeholders (BC-011 / CWE-636)
        - At least one negative (N#), architecture, or security verification path across spec.md/test-plan.md/tasks.md
        """
        errors: list[str] = []
        warnings: list[str] = []

        target_files: list[Path] = []
        for name in ("proposal.md", "design.md"):
            f = change_path / name
            if f.is_file():
                target_files.append(f)
        specs_dir = change_path / "specs"
        if specs_dir.is_dir():
            target_files.extend(sorted(specs_dir.glob("**/spec.md")))

        cleaned_by_file: dict[Path, str] = {}
        unquoted_by_file: dict[Path, str] = {}
        for f in target_files:
            try:
                raw = f.read_text(encoding="utf-8")
            except Exception:
                continue
            no_html = self._strip_html_comments(raw)
            cleaned_by_file[f] = no_html
            no_fences = re.sub(r"```[\s\S]*?```", "", no_html)
            no_inline_code = re.sub(r"`[^`\n]+`", "", no_fences)
            unquoted_by_file[f] = no_inline_code

        # 1. Fail-closed check for uncommented, unquoted [NEEDS CLARIFICATION...] markers (BC-011)
        for f, unquoted in unquoted_by_file.items():
            if self.NEEDS_CLARIFICATION_RE.search(unquoted):
                errors.append(
                    f"Unresolved policy clarification marker '[NEEDS CLARIFICATION]' in {f.name} "
                    f"(BC-011: resolve policy via QA before finalizing specification)"
                )

        combined_clean = "\n\n".join(cleaned_by_file.values())
        combined_unquoted = "\n\n".join(unquoted_by_file.values())

        bc_header_active = bool(self.BC_SECTION_HEADER_RE.search(combined_unquoted))
        ar_header_active = bool(self.AR_SECTION_HEADER_RE.search(combined_unquoted))
        bc_rule_matches = self.BC_ID_RE.findall(combined_unquoted)
        ar_rule_matches = self.AR_ID_RE.findall(combined_unquoted)

        bc_active = bc_header_active or len(bc_rule_matches) > 0
        ar_active = ar_header_active or len(ar_rule_matches) > 0

        if not (bc_active or ar_active):
            return errors, warnings

        # 2. Placeholder check ([TBD] / TODO) inside active BC/AR governance artifacts
        for f in (change_path / "proposal.md", change_path / "design.md"):
            unquoted = unquoted_by_file.get(f, "")
            if self.TBD_PLACEHOLDER_RE.search(unquoted):
                errors.append(
                    f"Unresolved placeholder ([TBD] or TODO) in active BC/AR governance file {f.name}"
                )

        # 3. Validate Domain Carrier (BC-###) completeness when active
        if bc_active:
            valid_bc_rules = [m.strip() for m in bc_rule_matches if m.strip() and not m.strip().startswith("[")]
            if not valid_bc_rules:
                errors.append(
                    "Domain Carrier section active but no valid '- **BC-###**: <description>' rule definition found"
                )
            field_regexes = (
                ("Owned Decisions", self.OWNED_DECISIONS_RE),
                ("Forbidden Responsibilities", self.FORBIDDEN_RESP_RE),
                ("External Decision References", self.EXTERNAL_DECISION_REFS_RE),
            )
            for required_label, field_re in field_regexes:
                field_match = field_re.search(combined_unquoted)
                if not field_match or not field_match.group(1).strip():
                    errors.append(
                        f"Active BC-### declaration missing required '- **{required_label}**:' field"
                    )

        # 4. Validate Architecture Memory (AR-###) completeness when active
        if ar_active:
            valid_ar_rules = [m.strip() for m in ar_rule_matches if m.strip() and not m.strip().startswith("[")]
            if not valid_ar_rules:
                errors.append(
                    "Architecture Memory section active but no valid '- **AR-###**: <description>' rule definition found"
                )

        # 5. Require at least one negative/boundary verification path (N#, architecture, or security trait)
        verification_texts = [combined_clean]
        for extra_name in ("test-plan.md", "tasks.md"):
            ef = change_path / extra_name
            if ef.is_file():
                try:
                    verification_texts.append(self._strip_html_comments(ef.read_text(encoding="utf-8")))
                except Exception:
                    pass
        all_verif = "\n".join(verification_texts)
        has_verif_path = bool(
            re.search(r"-\s*\*\*Path\*\*:\s*[^\n]*\bN\d+\b", all_verif)
            or re.search(r"-\s*\*\*Trait\*\*:\s*[^\n]*\b(?:architecture|security|negative)\b", all_verif, re.IGNORECASE)
            or re.search(r"\[ARCH\]|\btags\s*:\s*[^\n]*\barchitecture\b", all_verif, re.IGNORECASE)
        )
        if not has_verif_path:
            errors.append(
                "Active BC-###/AR-### governance requires at least one negative (N#), architecture, or security verification path"
            )

        return errors, warnings

    def validate_security(self, change_path: Path) -> list[str]:
        """Validate STRIDE completeness, Security Review verdict, and Living-Spec-Aware Rule G3."""
        errors: list[str] = []

        # 1. Threat Model & STRIDE Table
        tm_file = change_path / "threat-model.md"
        if tm_file.is_file():
            try:
                tm_content = tm_file.read_text(encoding="utf-8")
                # Check 6 categories
                for category in self.STRIDE_CATEGORIES:
                    if category not in tm_content:
                        errors.append(f"threat-model.md missing required STRIDE category: {category}")
            except Exception as e:
                errors.append(f"Could not read threat-model.md: {e}")

        # 2. Security Review Verdict in design.md or threat-model.md
        design_file = change_path / "design.md"
        verdict_found = False
        verdict_approved = False

        files_to_check = [f for f in (design_file, tm_file) if f.is_file()]
        for f in files_to_check:
            try:
                c = f.read_text(encoding="utf-8")
                m = re.search(r'Verdict:\s*(\w+)', c, re.IGNORECASE)
                if m:
                    verdict_found = True
                    if m.group(1).lower() == "approved":
                        verdict_approved = True
                        break
            except Exception:
                pass

        if not verdict_found:
            errors.append("Missing '## Security Review Verdict' in design.md or threat-model.md")
        elif not verdict_approved:
            errors.append("Security Review verdict is not 'approved' (approval is required to proceed)")

        # 3. Rule G3: Security requirement alteration without waiver (Delta text + Living-Spec lookup)
        specs_dir = change_path / "specs"
        if specs_dir.is_dir():
            for spec_file in specs_dir.glob("**/spec.md"):
                try:
                    c = spec_file.read_text(encoding="utf-8")
                    c_clean = self._strip_html_comments(c)
                    has_waiver = bool(re.search(r'Security-Waiver\s*:', c_clean, re.IGNORECASE))
                    if has_waiver:
                        continue

                    # 3a. Direct delta text check inside MODIFIED, REMOVED, or RENAMED sections
                    sections = re.findall(r'^(## [^\n]+)([\s\S]*?)(?=^## |\Z)', c_clean, re.MULTILINE)
                    delta_sec_violation = False
                    for sec_hdr, sec_body in sections:
                        if any(k in sec_hdr for k in ("MODIFIED Requirements", "REMOVED Requirements", "RENAMED Requirements")):
                            if re.search(r'(?:security|SEC-\d+)', sec_body, re.IGNORECASE):
                                delta_sec_violation = True
                                break

                    if delta_sec_violation:
                        errors.append(
                            f"Rule G3 Violation in {spec_file.name}: Modifying, renaming, or removing a security requirement "
                            f"requires explicit 'Security-Waiver: <justification>' and approved review."
                        )
                        continue

                    # 3b. Living-Spec-Aware Rule G3 check (catches deltas that omit the word 'security')
                    capability = str(spec_file.relative_to(specs_dir).parent)
                    living_reqs = self._load_living_spec_requirements(capability)
                    if not living_reqs:
                        continue

                    renamed_to_from: dict[str, str] = {}
                    for sec_hdr, sec_body in sections:
                        if "RENAMED Requirements" in sec_hdr:
                            for old_raw, new_raw in re.findall(
                                r'-\s*FROM:\s*`?(?:###\s+Requirement:\s*)?([^`\n]+?)`?\s*\n\s*-\s*TO:\s*`?(?:###\s+Requirement:\s*)?([^`\n]+?)`?[ \t]*(?=\n|\Z)',
                                sec_body,
                                re.IGNORECASE,
                            ):
                                old_t, new_t = old_raw.strip(), new_raw.strip()
                                renamed_to_from[new_t] = old_t
                                if old_t in living_reqs and self.RULE_G3_PROTECTED_ID_RE.search(old_t):
                                    errors.append(
                                        f"Rule G3 Violation in {spec_file.name}: Renaming security/boundary requirement '{old_t}' "
                                        f"in living spec requires explicit 'Security-Waiver: <justification>'."
                                    )

                    for sec_hdr, sec_body in sections:
                        if "REMOVED Requirements" in sec_hdr:
                            for req_hdr in re.findall(r'^### Requirement:[^\n]+', sec_body, re.MULTILINE):
                                r_title = req_hdr.replace("### Requirement:", "").strip()
                                if r_title in living_reqs and self._is_living_req_security(living_reqs[r_title]):
                                    errors.append(
                                        f"Rule G3 Violation in {spec_file.name}: Removing security-sensitive requirement '{r_title}' "
                                        f"from living spec requires explicit 'Security-Waiver: <justification>'."
                                    )
                        elif "MODIFIED Requirements" in sec_hdr:
                            req_blocks = re.findall(
                                r'^(### Requirement:[^\n]+)([\s\S]*?)(?=^### Requirement:|^## |\Z)',
                                sec_body,
                                re.MULTILINE,
                            )
                            for req_hdr, req_body in req_blocks:
                                r_title = req_hdr.replace("### Requirement:", "").strip()
                                lookup_title = renamed_to_from.get(r_title, r_title)
                                orig_req = living_reqs.get(lookup_title) or living_reqs.get(r_title)
                                if not orig_req:
                                    continue
                                if self.RULE_G3_PROTECTED_ID_RE.search(orig_req["title"]) or self.RULE_G3_PROTECTED_ID_RE.search(
                                    orig_req.get("body", "")
                                ):
                                    errors.append(
                                        f"Rule G3 Violation in {spec_file.name}: Modifying security/boundary requirement '{orig_req['title']}' "
                                        f"requires explicit 'Security-Waiver: <justification>'."
                                    )
                                for m in re.finditer(
                                    r'^[ \t]*-\s*\*\*REMOVED-SCENARIO\*\*:\s*`?([^`\n—–-]+?)`?(?:\s*(?:—|–|--|-)\s*\*\*Reason\*\*:|$)',
                                    req_body,
                                    re.MULTILINE,
                                ):
                                    sc_name = m.group(1).replace("#### Scenario:", "").strip()
                                    orig_sc_body = orig_req.get("scenarios", {}).get(sc_name, "")
                                    if orig_sc_body and self._is_security_scenario_body(orig_sc_body):
                                        errors.append(
                                            f"Rule G3 Violation in {spec_file.name}: Removing security-traited scenario '{sc_name}' "
                                            f"from '{r_title}' requires explicit 'Security-Waiver: <justification>'."
                                        )
                except Exception:
                    pass

        return errors

    def validate_hygiene_and_secrets(self, target_dir: Path | str) -> list[str]:
        """Scan directory for secrets, forbidden auxiliary files, and path traversal."""
        errors: list[str] = []
        target_path = Path(target_dir)
        if not target_path.is_absolute():
            target_path = (self.repo_root / target_path).resolve()

        if not target_path.exists():
            return [f"Target path does not exist: {target_path}"]

        # Secret patterns (AWS, GitHub tokens, private keys)
        secret_patterns = [
            (re.compile(r'A' + r'KIA[0-9A-Z]{16}'), "AWS Access Key"),
            (re.compile(r'ghp_[0-9a-zA-Z]{36}'), "GitHub Personal Access Token"),
            (re.compile(r'-----BEGIN (?:RSA )?PRIVATE KEY-----'), "Private Key"),
        ]

        # Scan files in target_path
        for root, dirs, files in os.walk(target_path):
            rel_root = Path(root).relative_to(target_path)

            # Check auxiliary directory containment: no spec.md or *.har in briefs/, agents/, debug/
            if any(part in ("briefs", "agents", "debug") for part in rel_root.parts):
                for f in files:
                    if f == "spec.md":
                        errors.append(f"Forbidden file 'spec.md' found in auxiliary folder: {rel_root / f}")
                    if f.endswith(".har"):
                        errors.append(f"Forbidden unredacted network archive 'session.har' in: {rel_root / f}")

            for f in files:
                file_path = Path(root) / f
                if file_path.suffix in (".md", ".yaml", ".yml", ".json", ".txt"):
                    try:
                        text = file_path.read_text(encoding="utf-8", errors="ignore")
                        for pattern, name in secret_patterns:
                            # Allow standard documentation placeholder
                            if ("A" + "KIAIOSFODNN7EXAMPLE") in text and name == "AWS Access Key":
                                continue
                            if pattern.search(text):
                                errors.append(f"Plaintext secret literal detected ({name}) in {rel_root / f}")
                    except Exception:
                        pass

        # Naming allowlists on change directories: ^[0-9]{3}-[a-z0-9-]+$
        if target_path.parent.name == "changes" or "changes" in target_path.parts:
            name = target_path.name
            if not re.match(r'^[0-9]{3}-[a-z0-9-]+$', name):
                errors.append(
                    f"Invalid change directory name '{name}': must match '^[0-9]{{3}}-[a-z0-9-]+$'"
                )

        return errors

    def _scan_bare_bones_constitution_file(
        self,
        file_path: Path,
        max_lines: int,
        expected_prefix: str | None = None,
        allow_rules_and_context: bool = False,
        check_unresolved_placeholders: bool = True,
    ) -> tuple[list[str], dict[str, str], list[str]]:
        """Validate a Constitution file against line caps, frontmatter, secrets, and 4-pattern Bare-Bones grammar.

        Args:
            file_path: Path to Constitution.md, area index.md, or atomic micro-file.
            max_lines: Maximum permitted line count for this file tier (45, 25, or 40).
            expected_prefix: Canonical rule prefix for the parent folder (e.g. 'AR', 'SEC').
            allow_rules_and_context: Permit '- key: val' context bullets and '- **PREFIX-NNN**: ... SHALL ...' rules.
            check_unresolved_placeholders: Reject '{{...}}' tokens when the area is active.

        Returns:
            Tuple of (validation_errors, parsed_frontmatter_dict, discovered_rule_ids).
        """
        errors: list[str] = []
        frontmatter: dict[str, str] = {}
        found_rules: list[str] = []

        try:
            rel_path = str(file_path.relative_to(self.repo_root)).replace("\\", "/")
        except ValueError:
            rel_path = str(file_path)

        if file_path.is_symlink():
            return [f"Symlink rejected in Constitution tree: {rel_path} (CWE-22)"], frontmatter, found_rules

        resolved = file_path.resolve()
        if not resolved.is_relative_to(self.repo_root):
            return [f"Constitution path escapes repository root: {rel_path} (CWE-22)"], frontmatter, found_rules

        try:
            stat_size = file_path.stat().st_size
            if stat_size > self.CONSTITUTION_MAX_BYTES:
                errors.append(
                    f"{rel_path} exceeds max file size ({stat_size} > {self.CONSTITUTION_MAX_BYTES} bytes)"
                )
            text = file_path.read_text(encoding="utf-8")
        except Exception as e:
            return [f"Failed to read {rel_path}: {e}"], frontmatter, found_rules

        lines = text.splitlines()
        if len(lines) > max_lines:
            errors.append(f"{rel_path} exceeds Bare-Bones line cap ({len(lines)} > {max_lines} lines)")

        if not lines or lines[0].strip() != "---":
            errors.append(f"{rel_path}:1 missing opening YAML frontmatter delimiter '---'")
            return errors, frontmatter, found_rules

        fm_end = None
        for idx in range(1, len(lines)):
            if lines[idx].strip() == "---":
                fm_end = idx
                break
            kv_match = re.match(r'^([a-zA-Z0-9_-]+):\s*(.+)$', lines[idx].strip())
            if kv_match:
                val = kv_match.group(2).strip().strip('"').strip("'")
                frontmatter[kv_match.group(1)] = val

        if fm_end is None:
            errors.append(f"{rel_path} missing closing YAML frontmatter delimiter '---'")
            return errors, frontmatter, found_rules

        if check_unresolved_placeholders and re.search(r"\{\{[A-Z0-9_]+\}\}", text):
            errors.append(f"{rel_path} contains unresolved '{{{{...}}}}' placeholder token(s)")

        for pattern, sec_name in self.CONSTITUTION_SECRET_PATTERNS:
            if pattern.search(text):
                errors.append(f"Plaintext secret literal detected ({sec_name}) in {rel_path} (CWE-798)")

        for offset, raw_line in enumerate(lines[fm_end + 1 :], start=fm_end + 2):
            stripped = raw_line.strip()
            if not stripped:
                continue
            if stripped.startswith(">"):
                errors.append(
                    f"CONST-PROSE-FORBIDDEN: Forbidden blockquote preamble in {rel_path}:{offset}"
                )
                continue
            if self.FORBIDDEN_PROSE_SECTION_RE.match(stripped):
                errors.append(
                    f"CONST-PROSE-FORBIDDEN: Forbidden narrative section heading '{stripped}' in {rel_path}:{offset}"
                )
                continue
            if self.BARE_BONES_HEADING_RE.match(stripped) or self.BARE_BONES_TABLE_RE.match(stripped):
                continue
            if allow_rules_and_context:
                if self.BARE_BONES_CONTEXT_RE.match(stripped):
                    continue
                m_rule = self.BARE_BONES_RULE_RE.match(stripped)
                if m_rule:
                    rule_prefix, rule_num = m_rule.group(1), m_rule.group(2)
                    if expected_prefix and rule_prefix != expected_prefix:
                        errors.append(
                            f"Rule prefix mismatch in {rel_path}:{offset}: found '{rule_prefix}-{rule_num}', expected '{expected_prefix}-###'"
                        )
                    found_rules.append(f"{rule_prefix}-{rule_num}")
                    continue
            errors.append(
                f"CONST-PROSE-FORBIDDEN: Disallowed non-atomic or discursive prose line in {rel_path}:{offset}: '{stripped[:80]}'"
            )

        return errors, frontmatter, found_rules

    def _validate_constitution_tree(
        self, require_exists: bool = False
    ) -> tuple[list[str], list[str]]:
        """Validate 2-level Constitution tree, 45/25/40 line caps, prefix bijection, and 4-pattern Bare-Bones grammar.

        Args:
            require_exists: Emit a missing-file error when <spec_root>/Constitution.md does not exist.

        Returns:
            Tuple of (errors, warnings).
        """
        errors: list[str] = []
        warnings: list[str] = []

        if self.constitution_file.is_symlink():
            return [f"Symlink rejected at {self.constitution_file} (CWE-22)"], warnings

        if not self.constitution_file.is_file():
            if require_exists:
                errors.append(f"Constitution file not found: {self.constitution_file}")
            return errors, warnings

        root_errs, _root_fm, _ = self._scan_bare_bones_constitution_file(
            self.constitution_file,
            max_lines=self.CONSTITUTION_ROOT_MAX_LINES,
            allow_rules_and_context=False,
            check_unresolved_placeholders=True,
        )
        errors.extend(root_errs)

        if self.constitution_dir.is_symlink() or not self.constitution_dir.is_dir():
            errors.append(f"Missing or invalid constitution directory: {self.constitution_dir}")
            return errors, warnings

        seen_rules: set[str] = set()
        for entry in sorted(self.constitution_dir.iterdir()):
            if entry.is_symlink():
                errors.append(f"Symlink rejected in constitution directory: {entry.name} (CWE-22)")
                continue
            if entry.is_dir() and entry.name not in self.CANONICAL_CONSTITUTION_AREAS:
                errors.append(f"Unexpected non-canonical folder in constitution/: '{entry.name}'")

        for area_name, expected_prefix in self.CANONICAL_CONSTITUTION_AREAS.items():
            area_dir = self.constitution_dir / area_name
            if not area_dir.is_dir() or area_dir.is_symlink():
                errors.append(f"Missing canonical constitutional area folder: constitution/{area_name}/")
                continue

            index_file = area_dir / "index.md"
            if not index_file.is_file():
                errors.append(f"Missing mini-index router: constitution/{area_name}/index.md")
                continue

            idx_errs, idx_fm, _ = self._scan_bare_bones_constitution_file(
                index_file,
                max_lines=self.CONSTITUTION_INDEX_MAX_LINES,
                expected_prefix=expected_prefix,
                allow_rules_and_context=False,
                check_unresolved_placeholders=True,
            )
            errors.extend(idx_errs)

            area_status = idx_fm.get("status", "active")
            if area_status not in {"active", "kiss-lite", "not-applicable"}:
                errors.append(
                    f"Invalid status '{area_status}' in constitution/{area_name}/index.md"
                )
            if area_name in self.MANDATORY_ACTIVE_AREAS and area_status != "active":
                errors.append(
                    f"Security floor violation: mandatory area '{area_name}' must have status: active (found '{area_status}')"
                )
            if idx_fm.get("prefix") and idx_fm.get("prefix") != expected_prefix:
                errors.append(
                    f"Prefix mismatch in constitution/{area_name}/index.md: expected '{expected_prefix}', found '{idx_fm.get('prefix')}'"
                )

            check_placeholders = area_status != "not-applicable"
            micro_files = [
                p for p in sorted(area_dir.iterdir()) if p.name != "index.md"
            ]
            if not micro_files:
                errors.append(f"Area constitution/{area_name}/ contains zero micro-files")

            for sub in micro_files:
                if sub.is_dir():
                    errors.append(
                        f"Max depth (2) exceeded in constitution/{area_name}/{sub.name}/"
                    )
                    continue
                if sub.suffix != ".md":
                    continue
                m_errs, _m_fm, m_rules = self._scan_bare_bones_constitution_file(
                    sub,
                    max_lines=self.CONSTITUTION_MICRO_MAX_LINES,
                    expected_prefix=expected_prefix,
                    allow_rules_and_context=True,
                    check_unresolved_placeholders=check_placeholders,
                )
                errors.extend(m_errs)
                for rid in m_rules:
                    if rid in seen_rules:
                        errors.append(f"Duplicate constitutional rule ID '{rid}' in {sub.name}")
                    seen_rules.add(rid)

        return errors, warnings

    def validate_constitution(self) -> ValidationReport:
        """Validate the workspace Constitution tree on demand (--validate-constitution)."""
        c_errors, c_warnings = self._validate_constitution_tree(require_exists=True)
        is_valid = len(c_errors) == 0
        return ValidationReport(
            valid=is_valid,
            status="pass" if is_valid else "fail",
            errors=c_errors,
            warnings=c_warnings,
            checks={"constitution": {"pass": is_valid, "issues": c_errors, "warnings": c_warnings}},
        )

    def _collect_active_constitution_rules(self) -> tuple[set[str], set[str]]:
        """Collect active area prefixes and defined Bare-Bones rule IDs from <spec_root>/constitution/.

        Returns:
            Tuple of (active_prefixes, defined_rule_ids).
        """
        active_prefixes: set[str] = set()
        defined_rules: set[str] = set()
        if not self.constitution_dir.is_dir():
            return active_prefixes, defined_rules

        for area_name, prefix in self.CANONICAL_CONSTITUTION_AREAS.items():
            area_dir = self.constitution_dir / area_name
            idx_file = area_dir / "index.md"
            status_val = "active"
            if idx_file.is_file():
                try:
                    m_st = re.search(
                        r'^status:\s*["\']?([^"\'\n]+)["\']?',
                        idx_file.read_text(encoding="utf-8"),
                        re.MULTILINE,
                    )
                    if m_st:
                        status_val = m_st.group(1).strip()
                except Exception:
                    pass
            if status_val != "not-applicable":
                active_prefixes.add(prefix)
            if area_dir.is_dir():
                for mf in sorted(area_dir.glob("*.md")):
                    if mf.name == "index.md" or mf.is_symlink():
                        continue
                    try:
                        for line in mf.read_text(encoding="utf-8").splitlines():
                            m_rule = self.BARE_BONES_RULE_RE.match(line.strip())
                            if m_rule:
                                defined_rules.add(f"{m_rule.group(1)}-{m_rule.group(2)}")
                    except Exception:
                        pass
        return active_prefixes, defined_rules

    def _validate_constitution_traceability(
        self, change_path: Path
    ) -> tuple[list[str], list[str]]:
        """Verify 6-artifact [<PREFIX>-###] citations and Sync Impact Report updates when Constitution.md exists.

        Args:
            change_path: Path to the active OpenSpec change directory.

        Returns:
            Tuple of (errors, warnings).
        """
        errors: list[str] = []
        warnings: list[str] = []
        if not self.constitution_file.is_file():
            return errors, warnings

        tree_errs, tree_warns = self._validate_constitution_tree(require_exists=True)
        errors.extend(tree_errs)
        warnings.extend(tree_warns)

        active_prefixes, defined_rules = self._collect_active_constitution_rules()

        artifact_targets: list[tuple[str, Path]] = []
        for req_name in sorted(self.REQUIRED_ARTIFACT_FILES):
            f_path = change_path / req_name
            if f_path.is_file():
                artifact_targets.append((req_name, f_path))
        specs_dir = change_path / "specs"
        if specs_dir.is_dir():
            for sf in sorted(specs_dir.glob("**/spec.md")):
                rel_sf = str(sf.relative_to(change_path)).replace("\\", "/")
                artifact_targets.append((rel_sf, sf))

        for label, f_path in artifact_targets:
            try:
                clean_text = self._strip_html_comments(f_path.read_text(encoding="utf-8"))
            except Exception:
                continue
            matches = [
                f"{p}-{num}"
                for p, num in self.CONSTITUTION_CITATION_RE.findall(clean_text)
                if p in active_prefixes and (not defined_rules or f"{p}-{num}" in defined_rules)
            ]
            if not matches:
                errors.append(
                    f"CONST-CITATION-MISSING: {label} must cite at least one active constitutional rule ID ([<PREFIX>-###])"
                )

        # Verify - Amends-Constitution: updates Sync Impact Report in Constitution.md
        proposal_file = change_path / "proposal.md"
        if proposal_file.is_file():
            try:
                prop_clean = self._strip_html_comments(proposal_file.read_text(encoding="utf-8"))
                m_amends = re.search(
                    r"^[ \t]*-\s*Amends-Constitution\s*:\s*([^\n]+)$",
                    prop_clean,
                    re.IGNORECASE | re.MULTILINE,
                )
                if m_amends:
                    amends_val = m_amends.group(1).strip()
                    if amends_val and amends_val.lower() != "none" and not amends_val.startswith("["):
                        const_text = self.constitution_file.read_text(encoding="utf-8")
                        sync_sec_match = re.search(
                            r"^##\s+[^\n]*Sync Impact[^\n]*\n([\s\S]*?)(?=^## |\Z)",
                            const_text,
                            re.IGNORECASE | re.MULTILINE,
                        )
                        sync_body = sync_sec_match.group(1) if sync_sec_match else ""
                        amended_ids = [
                            f"{p}-{n}" for p, n in self.CONSTITUTION_CITATION_RE.findall(amends_val)
                        ]
                        has_change_ref = change_path.name in sync_body
                        has_rule_row = any(
                            rid in line and "initial Bare-Bones scaffold" not in line
                            for line in sync_body.splitlines()
                            for rid in amended_ids
                        )
                        if not (has_change_ref or has_rule_row):
                            errors.append(
                                f"Constitutional amendment '{amends_val}' in proposal.md requires updating '## Sync Impact Report' in {self.spec_root}/Constitution.md"
                            )
            except Exception:
                pass

        return errors, warnings

    def validate_legacy_parity(
        self,
        change_path: Path | str,
        legacy_spec_file: Path | str | None = None,
    ) -> list[str]:
        """Verify that all legacy requirement IDs are accounted for in the change."""
        errors: list[str] = []
        change_dir = Path(change_path)
        if not legacy_spec_file:
            # Look for legacy reference inside proposal.md
            proposal = change_dir / "proposal.md"
            if proposal.is_file():
                try:
                    c = proposal.read_text(encoding="utf-8")
                    m = re.search(r'legacy_spec:\s*([^\n]+)', c)
                    if m:
                        legacy_spec_file = self.repo_root / m.group(1).strip()
                except Exception:
                    pass

        if not legacy_spec_file or not Path(legacy_spec_file).is_file():
            return errors

        # Extract legacy REQ-xxx and SEC-xxx IDs from legacy spec
        try:
            legacy_text = Path(legacy_spec_file).read_text(encoding="utf-8")
            legacy_ids = set(re.findall(r'\b(REQ-\d+|SEC-\d+|NFR-\d+)\b', legacy_text))
        except Exception:
            return errors

        # Read change delta files
        change_specs_text = ""
        specs_dir = change_dir / "specs"
        if specs_dir.is_dir():
            for sf in specs_dir.glob("**/spec.md"):
                try:
                    change_specs_text += "\n" + sf.read_text(encoding="utf-8")
                except Exception:
                    pass

        # Compare
        for leg_id in sorted(legacy_ids):
            if leg_id not in change_specs_text:
                errors.append(
                    f"Legacy parity error: Legacy requirement '{leg_id}' from {Path(legacy_spec_file).name} "
                    f"is not accounted for in change deltas."
                )

        return errors

    def _run_cli_parity_if_requested(self, change_path: Path, requested: bool) -> dict:
        """Run external openspec validate if installed and requested."""
        if not requested:
            return {"pass": True, "executed": False, "mode": "skipped"}

        openspec_bin = shutil.which("openspec")
        if not openspec_bin:
            return {"pass": True, "executed": False, "mode": "cli_not_installed"}

        try:
            res = subprocess.run(
                [openspec_bin, "validate", change_path.name, "--strict"],
                cwd=str(self.repo_root),
                capture_output=True,
                text=True,
                timeout=15,
            )
            return {
                "pass": res.returncode == 0,
                "executed": True,
                "mode": "cli_executed",
                "returncode": res.returncode,
                "stdout": res.stdout,
                "stderr": res.stderr,
            }
        except Exception as e:
            return {"pass": False, "executed": True, "mode": "cli_error", "error": str(e)}

    def validate_all(self, cli_parity: bool = False) -> ValidationReport:
        """Validate all active changes, workspace hygiene, and <spec_root>/index.yml."""
        errors: list[str] = []
        warnings: list[str] = []
        checks: dict[str, dict] = {}

        # 1. Validate active changes
        change_issues: list[str] = []
        if self.changes_dir.is_dir():
            for d in sorted(self.changes_dir.iterdir()):
                if d.is_dir() and d.name != "archive":
                    rep = self.validate_change(d, cli_parity=cli_parity)
                    if not rep.valid:
                        for err in rep.errors:
                            change_issues.append(f"[{d.name}] {err}")
                    for warn in rep.warnings:
                        warnings.append(f"[{d.name}] {warn}")
        errors.extend(change_issues)
        checks["active_changes"] = {"pass": len(change_issues) == 0, "issues": change_issues}

        # 2. Validate <spec_root>/index.yml if present
        index_issues: list[str] = []
        if MySpecIndexManager is not None:
            try:
                idx_mgr = MySpecIndexManager(repo_root=self.repo_root)
                if idx_mgr.index_path.is_file():
                    index_issues = idx_mgr.validate_index()
            except Exception as e:
                index_issues.append(str(e))
        errors.extend(index_issues)
        checks["index"] = {"pass": len(index_issues) == 0, "issues": index_issues}

        # 3. Validate hygiene across spec_root
        spec_root_dir = self.repo_root / self.spec_root
        hygiene_issues: list[str] = []
        if spec_root_dir.is_dir():
            hygiene_issues = self.validate_hygiene_and_secrets(spec_root_dir)
        errors.extend(hygiene_issues)
        checks["hygiene"] = {"pass": len(hygiene_issues) == 0, "issues": hygiene_issues}

        # 4. Validate Constitution tree when present
        const_issues, const_warnings = self._validate_constitution_tree(require_exists=False)
        errors.extend(const_issues)
        warnings.extend(const_warnings)
        checks["constitution"] = {
            "pass": len(const_issues) == 0,
            "issues": const_issues,
            "warnings": const_warnings,
        }

        is_valid = len(errors) == 0
        return ValidationReport(
            valid=is_valid,
            status="pass" if is_valid else "fail",
            errors=errors,
            warnings=warnings,
            checks=checks,
        )


def main() -> int:
    """CLI entrypoint for MySpecValidator."""
    parser = argparse.ArgumentParser(description="MySpec Validator and Governance Engine")
    parser.add_argument("--change", type=str, help="Name or path of the change directory")
    parser.add_argument("--repo-root", "--target", dest="repo_root", type=str, default=None, help="Root path of the repository")
    parser.add_argument("--strict", action="store_true", default=True, help="Enforce strict validation")
    parser.add_argument("--json", action="store_true", help="Output report in JSON format")
    parser.add_argument("--cli-parity", action="store_true", help="Execute openspec CLI parity if available")
    parser.add_argument("--all", action="store_true", help="Validate all active changes and hygiene")
    parser.add_argument("--validate-constitution", action="store_true", help="Validate Bare-Bones 2-level Constitution tree")

    args = parser.parse_args()
    validator = MySpecValidator(repo_root=args.repo_root, strict=args.strict)

    if args.validate_constitution or args.change or args.all:
        if args.validate_constitution and not args.change and not args.all:
            report = validator.validate_constitution()
        elif args.change:
            report = validator.validate_change(args.change, cli_parity=args.cli_parity)
        else:
            report = validator.validate_all(cli_parity=args.cli_parity)
        if args.json:
            print(json.dumps(report.to_dict(), indent=2))
        else:
            status_str = "PASS" if report.valid else "FAIL"
            print(f"Validation Status: {status_str}")
            if report.errors:
                print("\nErrors:")
                for err in report.errors:
                    print(f"  - {err}")
            if report.warnings:
                print("\nWarnings:")
                for warn in report.warnings:
                    print(f"  - {warn}")
        return 0 if report.valid else 1

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
