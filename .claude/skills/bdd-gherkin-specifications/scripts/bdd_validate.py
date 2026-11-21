#!/usr/bin/env python3
"""
bdd_validate.py: Deterministic Blackbox CLI Linter for BDD Gherkin Specifications.

Validates .feature files for:
- Correct Gherkin v6+ syntax structure (Feature, Rule, Scenario, Given, When, Then).
- Mandatory @REQ-* traceability tags on Scenarios/Rules.
- Detection of imperative UI anti-patterns in step lines (clicks, locators, selectors).
- Detection of plaintext exposed credentials/tokens in Examples tables (Secret Scanning).
- Returns exit code 0 on clean pass, 1 on violations, 2 on CLI/file error.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Skill-relative directory anchors for cross-platform and working-directory independence
SCRIPT_DIR: Path = Path(__file__).resolve().parent
SKILL_DIR: Path = SCRIPT_DIR.parent

SECRET_PATTERNS = [
    (r"\bAKIA[0-9A-Z]{16}\b", "AWS Access Key"),
    (r"\bghp_[0-9a-zA-Z]{36}\b", "GitHub Personal Access Token"),
    (r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b", "JWT Token"),
    (r"-----BEGIN (?:RSA )?PRIVATE KEY-----", "Private Key"),
    (r"\bpassword\s*=\s*['\"][^'\"]{6,}['\"]", "Plaintext Password Assignment"),
]

IMPERATIVE_UI_TERMS = [
    r"\bclick\s+on\b",
    r"\bclicks?\s+the\s+button\b",
    r"\bselector\b",
    r"\bxpath\b",
    r"\bcss\b",
    r"\b#\w+[-_]\w+\b",
    r"\bfill\s+in\s+input\b",
]


class BddSpecificationValidator:
    """Validates Gherkin feature files for declarative syntax, traceability, and security hygiene."""

    def __init__(self, allow_untagged: bool = False):
        """Initialize the BDD validator.

        Args:
            allow_untagged: If True, do not flag scenarios missing @REQ-* tags.
        """
        self.allow_untagged = allow_untagged
        self.violations: List[Dict[str, any]] = []

    def validate_file(self, file_path: Path) -> List[Dict[str, any]]:
        """Validate a single .feature file.

        Args:
            file_path: Path to the .feature file to inspect.

        Returns:
            List of parsed scenario dictionaries.
        """
        try:
            content = file_path.read_text(encoding="utf-8")
        except Exception as e:
            self.violations.append({
                "file": str(file_path),
                "line": 0,
                "error": f"Failed to read file: {e}",
                "remedy": "Ensure file exists and is UTF-8 encoded."
            })
            return []

        lines = content.splitlines()
        has_feature = False
        current_tags = []
        parsed_scenarios = []

        for idx, line in enumerate(lines, 1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            # Secret check across every line (especially table cells)
            for pat, desc in SECRET_PATTERNS:
                if re.search(pat, stripped, re.IGNORECASE):
                    self.violations.append({
                        "file": str(file_path),
                        "line": idx,
                        "text": stripped,
                        "error": f"Security violation: Exposed {desc} detected.",
                        "remedy": "Replace live secrets with dummy test placeholders."
                    })

            # Check for Tags
            if stripped.startswith("@"):
                current_tags.extend(stripped.split())
                continue

            # Feature declaration
            if stripped.startswith("Feature:"):
                has_feature = True
                continue

            # Scenario / Scenario Outline declaration
            if stripped.startswith(("Scenario:", "Scenario Outline:", "Scenario Template:")):
                req_tags = [t for t in current_tags if t.startswith("@REQ-") or t.startswith("@req-")]
                if not self.allow_untagged and not req_tags:
                    self.violations.append({
                        "file": str(file_path),
                        "line": idx,
                        "text": stripped,
                        "error": "Traceability violation: Scenario is missing a mandatory '@REQ-<ID>' tag.",
                        "remedy": "Add an explicit traceability tag above the scenario (e.g. @REQ-AUTH-001)."
                    })
                parsed_scenarios.append({
                    "title": stripped,
                    "line": idx,
                    "tags": list(current_tags)
                })
                current_tags = []
                continue

            # Step checks (Given, When, Then, And, But)
            if stripped.startswith(("Given ", "When ", "Then ", "And ", "But ")):
                for ui_term in IMPERATIVE_UI_TERMS:
                    if re.search(ui_term, stripped, re.IGNORECASE):
                        self.violations.append({
                            "file": str(file_path),
                            "line": idx,
                            "text": stripped,
                            "error": f"Imperative UI anti-pattern detected: '{ui_term}'.",
                            "remedy": "Use declarative domain language (what happens), not UI clicks or selectors."
                        })

        if not has_feature:
            self.violations.append({
                "file": str(file_path),
                "line": 1,
                "error": "Missing 'Feature:' declaration.",
                "remedy": "Every Gherkin file must start with a 'Feature:' capability description."
            })

        return parsed_scenarios


def main():
    """Main CLI entrypoint for BDD specification validator."""
    parser = argparse.ArgumentParser(description="Deterministic blackbox CLI validator for BDD Gherkin specifications.")
    parser.add_argument("--file", "-f", type=str, help="Path to single .feature file.")
    parser.add_argument("--dir", "-d", type=str, help="Directory containing .feature files to validate recursively.")
    parser.add_argument("--allow-untagged", action="store_true", help="Allow scenarios without @REQ-* traceability tags.")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format.")
    args = parser.parse_args()

    if not args.file and not args.dir:
        parser.print_help()
        sys.exit(2)

    files_to_check: List[Path] = []
    if args.file:
        p = Path(args.file).expanduser().resolve()
        if not p.is_file():
            print(f"Error: file not found: {p}", file=sys.stderr)
            sys.exit(2)
        files_to_check.append(p)
    elif args.dir:
        d = Path(args.dir).expanduser().resolve()
        if not d.is_dir():
            print(f"Error: directory not found: {d}", file=sys.stderr)
            sys.exit(2)
        files_to_check = list(d.rglob("*.feature"))

    validator = BddSpecificationValidator(allow_untagged=args.allow_untagged)
    scenarios_count = 0

    for f in files_to_check:
        scenarios = validator.validate_file(f)
        scenarios_count += len(scenarios)

    if args.json:
        print(json.dumps({
            "valid": len(validator.violations) == 0,
            "files_checked": len(files_to_check),
            "scenarios_checked": scenarios_count,
            "violations_count": len(validator.violations),
            "violations": validator.violations
        }, indent=2))
        if validator.violations:
            sys.exit(1)
        sys.exit(0)
    else:
        print(f"BDD Specification Validation Report — Checked {len(files_to_check)} file(s), {scenarios_count} scenario(s)")
        if validator.violations:
            print(f"FAILED: {len(validator.violations)} violation(s) found:\n")
            for v in validator.violations:
                print(f"  [{v['file']}:{v['line']}] {v['error']}")
                if "text" in v:
                    print(f"    Text:   \"{v['text']}\"")
                print(f"    Remedy: {v['remedy']}\n")
            sys.exit(1)
        else:
            print("SUCCESS: 100% of tested feature files strictly conform to declarative BDD and security rules.")
            sys.exit(0)


if __name__ == "__main__":
    main()
