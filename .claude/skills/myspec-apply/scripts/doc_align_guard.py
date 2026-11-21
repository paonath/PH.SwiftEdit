#!/usr/bin/env python3
"""DocAlignGuard: Fail-closed security guard enforcing documentation-only modifications.

In doc-align mode, modifications to any file outside spec_root are strictly
blocked unless the user explicitly provides an override in the prompt.
Zero code rewriting allowed!
"""

from __future__ import annotations

import re
from pathlib import Path


class DocAlignGuard:
    """Enforces fail-closed guard preventing code modifications in doc-align mode."""

    OVERRIDE_PATTERNS = [
        re.compile(r"override-doc-align", re.IGNORECASE),
        re.compile(r"allow-code-rewrite", re.IGNORECASE),
        re.compile(r"force-code-edit", re.IGNORECASE),
        re.compile(r"explicit prompt authorization", re.IGNORECASE),
    ]

    def __init__(self, repo_root: Path | str | None = None, spec_root: str = "openspec") -> None:
        if repo_root is None:
            self.repo_root = Path.cwd().resolve()
        else:
            self.repo_root = Path(repo_root).resolve()
        self.spec_root = spec_root

    def is_override_authorized(self, prompt: str) -> bool:
        """Check whether prompt contains explicit authorization token."""
        if not prompt:
            return False
        return any(pat.search(prompt) for pat in self.OVERRIDE_PATTERNS)

    def is_inside_spec_root(self, target_file: Path | str) -> bool:
        """Check whether target file is strictly inside spec_root."""
        target_path = Path(target_file).resolve()
        spec_dir = (self.repo_root / self.spec_root).resolve()
        try:
            target_path.relative_to(spec_dir)
            return True
        except ValueError:
            return False

    def check_write_permission(
        self,
        target_file: Path | str,
        is_doc_align: bool,
        prompt: str = "",
    ) -> None:
        """Enforce fail-closed permission check.

        Raises PermissionError if target_file is outside spec_root and no override is present.
        """
        if not is_doc_align:
            return

        if self.is_inside_spec_root(target_file):
            return

        if self.is_override_authorized(prompt):
            return

        raise PermissionError(
            f"[SECURITY] Doc-Align Guard: Editing file '{target_file}' outside spec_root ('{self.spec_root}') "
            f"is strictly forbidden in doc-align mode without explicit prompt authorization. "
            f"Zero code rewriting allowed."
        )
