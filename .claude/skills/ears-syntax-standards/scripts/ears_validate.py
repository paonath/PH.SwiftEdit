#!/usr/bin/env python3
"""
ears_validate.py: Deterministic Blackbox CLI Linter for EARS Requirements.

Validates text or markdown files against canonical EARS syntax rules:
- Validates the 6 patterns: Ubiquitous, Event-driven, State-driven, Optional, Unwanted, Complex.
- Enforces single SHALL per requirement.
- Enforces active voice and explicit system subject.
- Rejects banned vague qualifiers (fast, robust, user-friendly, etc., and/or).
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

BANNED_WORDS = [
    r"\bfast\b",
    r"\bquickly\b",
    r"\brobust\b",
    r"\brobustly\b",
    r"\badequate\b",
    r"\buser-friendly\b",
    r"\betc\b",
    r"\band/or\b",
    r"\bgracefully\b",
    r"\bshould\b",
    r"\bmay\b",
]

PATTERN_REGEX = re.compile(
    r"^(?:WHERE\s+(?P<optional>.+?),\s*)?"
    r"(?:WHILE\s+(?P<state>.+?),\s*)?"
    r"(?:WHEN\s+(?P<event>.+?),\s*)?"
    r"(?:IF\s+(?P<unwanted>.+?),\s*THEN\s*)?"
    r"(?P<subject>[A-Za-z0-9_\-\s]+?)\s+SHALL\s+(?P<response>.+?)\.?$",
    re.IGNORECASE,
)

PASSIVE_VOICE_REGEX = re.compile(
    r"\bSHALL\s+(?:BE|HAVE\s+BEEN)\s+([A-Za-z]+ED)\b", re.IGNORECASE
)


class EarsRequirementValidator:
    """Validates natural language statements against canonical EARS syntax patterns."""

    def __init__(self) -> None:
        """Initialize the validator with an empty violations registry."""
        self.violations: List[Dict[str, any]] = []

    def validate_statement(
        self, text: str, line_no: int, source_file: str = "input"
    ) -> Optional[Dict[str, any]]:
        """Validate a single requirement statement against EARS grammar.

        Args:
            text: The requirement text string to inspect.
            line_no: Source line number for error reporting.
            source_file: Source file or stream identifier.

        Returns:
            Dictionary with parsed pattern details if compliant, None otherwise.
        """
        cleaned = text.strip().rstrip(".")
        if not cleaned:
            return None

        # Check for presence of SHALL
        shall_matches = re.findall(r"\bSHALL\b", cleaned, re.IGNORECASE)
        if not shall_matches:
            self.violations.append(
                {
                    "file": source_file,
                    "line": line_no,
                    "text": cleaned,
                    "error": "Missing mandatory 'SHALL' keyword.",
                    "remedy": "Every EARS statement must contain an explicit 'SHALL' clause.",
                }
            )
            return None

        # Check for multiple SHALL (Atomicity violation)
        if len(shall_matches) > 1:
            self.violations.append(
                {
                    "file": source_file,
                    "line": line_no,
                    "text": cleaned,
                    "error": f"Atomicity violation: found {len(shall_matches)} 'SHALL' keywords in a single requirement.",
                    "remedy": "Split multiple behaviors into separate atomic requirements, each with exactly one SHALL.",
                }
            )

        # Check for banned vague terms
        for banned_pat in BANNED_WORDS:
            match = re.search(banned_pat, cleaned, re.IGNORECASE)
            if match:
                self.violations.append(
                    {
                        "file": source_file,
                        "line": line_no,
                        "text": cleaned,
                        "error": f"Banned vague qualifier detected: '{match.group(0)}'",
                        "remedy": "Replace subjective adjectives with measurable metrics, bounds, or explicit status codes.",
                    }
                )

        # Check for passive voice
        passive_match = PASSIVE_VOICE_REGEX.search(cleaned)
        if passive_match:
            self.violations.append(
                {
                    "file": source_file,
                    "line": line_no,
                    "text": cleaned,
                    "error": f"Passive voice detected: '{passive_match.group(0)}'",
                    "remedy": "State the active system subject explicitly (e.g. 'the System SHALL display ...').",
                }
            )

        # Match pattern structure
        match = PATTERN_REGEX.match(cleaned)
        if not match:
            self.violations.append(
                {
                    "file": source_file,
                    "line": line_no,
                    "text": cleaned,
                    "error": "Does not match any of the 6 canonical EARS patterns.",
                    "remedy": "Reformat into: [WHERE <feature>,] [WHILE <state>,] [WHEN <event>,] [IF <unwanted>, THEN] the <system> SHALL <response>.",
                }
            )
            return None

        groups = match.groupdict()
        pattern_type = "Ubiquitous"
        if groups.get("optional") and (
            groups.get("state") or groups.get("event") or groups.get("unwanted")
        ):
            pattern_type = "Complex"
        elif groups.get("state") and (
            groups.get("event") or groups.get("unwanted")
        ):
            pattern_type = "Complex"
        elif groups.get("unwanted"):
            pattern_type = "Unwanted Behaviour"
        elif groups.get("event"):
            pattern_type = "Event-Driven"
        elif groups.get("state"):
            pattern_type = "State-Driven"
        elif groups.get("optional"):
            pattern_type = "Optional Feature"

        return {
            "pattern": pattern_type,
            "subject": groups.get("subject", "").strip(),
            "response": groups.get("response", "").strip(),
            "line": line_no,
        }


def extract_requirements_from_markdown(content: str) -> List[Tuple[int, str]]:
    """Extract requirement sentences from markdown bullets, tables, or plain lines containing SHALL.

    Args:
        content: Raw markdown text content.

    Returns:
        List of tuples containing (line_number, cleaned_requirement_text).
    """
    reqs = []
    lines = content.splitlines()
    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if re.search(r"\bSHALL\b", stripped, re.IGNORECASE):
            cleaned = re.sub(r"^(\*|\-|\+|\d+\.)\s+", "", stripped)
            cleaned = re.sub(r"^\|\s*REQ-[^\|]+\|\s*", "", cleaned)
            cleaned = cleaned.strip("|").strip()
            if cleaned:
                reqs.append((idx, cleaned))
    return reqs


def main():
    """Main CLI entrypoint."""
    parser = argparse.ArgumentParser(
        description="Deterministic blackbox CLI validator for EARS requirements."
    )
    parser.add_argument(
        "--file", "-f", type=str, help="Path to markdown or text file containing requirements."
    )
    parser.add_argument(
        "--text", "-t", type=str, help="Single EARS requirement string to validate directly."
    )
    parser.add_argument(
        "--json", action="store_true", help="Output results in JSON format."
    )
    args = parser.parse_args()

    if not args.file and not args.text and sys.stdin.isatty():
        parser.print_help()
        sys.exit(2)

    validator = EarsRequirementValidator()
    results = []

    try:
        if args.text:
            res = validator.validate_statement(args.text, line_no=1, source_file="cli-text")
            if res:
                results.append(res)
        elif args.file:
            path = Path(args.file).expanduser().resolve()
            if not path.is_file():
                print(f"Error: file not found: {path}", file=sys.stderr)
                sys.exit(2)
            content = path.read_text(encoding="utf-8")
            items = extract_requirements_from_markdown(content)
            for line_no, req_text in items:
                res = validator.validate_statement(req_text, line_no, source_file=str(path))
                if res:
                    results.append(res)
        else:
            content = sys.stdin.read()
            items = extract_requirements_from_markdown(content)
            for line_no, req_text in items:
                res = validator.validate_statement(req_text, line_no, source_file="stdin")
                if res:
                    results.append(res)
    except Exception as e:
        print(f"Execution error: {e}", file=sys.stderr)
        sys.exit(2)

    if args.json:
        print(
            json.dumps(
                {
                    "valid": len(validator.violations) == 0,
                    "violations_count": len(validator.violations),
                    "violations": validator.violations,
                    "parsed_requirements_count": len(results),
                    "requirements": results,
                },
                indent=2,
            )
        )
        if validator.violations:
            sys.exit(1)
        sys.exit(0)
    else:
        print(f"EARS Validation Report — Parsed: {len(results)} requirements")
        if validator.violations:
            print(f"FAILED: {len(validator.violations)} violation(s) found:\n")
            for v in validator.violations:
                print(f"  [{v['file']}:{v['line']}] {v['error']}")
                print(f"    Text:   \"{v['text']}\"")
                print(f"    Remedy: {v['remedy']}\n")
            sys.exit(1)
        else:
            print("SUCCESS: 100% of analyzed requirements strictly conform to canonical EARS syntax.")
            sys.exit(0)


if __name__ == "__main__":
    main()
