"""Historical GitFlow audit trail generator under <spec_root>/git/<type>/<id>/README.md.

Persists lifecycle metadata without modifying index.yml, enforcing per-segment symlink
and traversal confinement, mandatory Name and Description fields, and secret/ANSI sanitization.
"""

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

from .git_gateway import sanitize_terminal_text
from .semver import validate_branch_slug
from .version_engine import _safe_write_text

HTML_COMMENT_REGEX = re.compile(r"<!--[\s\S]*?-->")
GHP_SECRET_REGEX = re.compile(r"ghp_[A-Za-z0-9]{20,}")
AWS_SECRET_REGEX = re.compile(r"AKIA[0-9A-Z]{16}")
BEARER_REGEX = re.compile(r"(bearer\s+)[A-Za-z0-9._~+/-]{20,}", re.IGNORECASE)
PRIVATE_KEY_REGEX = re.compile(
    r"-----BEGIN[A-Z\s]+PRIVATE KEY-----[\s\S]*?-----END[A-Z\s]+PRIVATE KEY-----"
)
ALLOWED_WORKFLOW_TYPES = {"feature", "release", "hotfix"}
_HISTORY_PREFIXES = ("- StartParentVersion:", "- CurrentParentVersion:", "- FinalBranchVersion:")


class AuditDocs:
    """Manages creation, sanitization, and lifecycle migration of GitFlow audit logs."""

    def validate_spec_root(self, repo_root: Path) -> str:
        """Validate .myspec.config.json and ensure spec_root is whitelisted and non-symlink."""
        config_path = repo_root / ".myspec.config.json"
        if not config_path.is_file() or config_path.is_symlink():
            raise ValueError("Invalid or missing .myspec.config.json. Run myspec-init first (CWE-22).")
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
        except Exception as err:
            raise ValueError(f"Failed to parse .myspec.config.json: {err}") from err

        spec_root = data.get("spec_root")
        if spec_root not in {"openspec", "specs"}:
            raise ValueError(
                f"Invalid spec_root '{spec_root}'. Only 'openspec' and 'specs' are allowed."
            )
        target_dir = repo_root / spec_root
        if target_dir.is_symlink():
            raise ValueError(f"spec_root directory '{spec_root}' cannot be a symlink.")
        return spec_root

    def _validate_identifier(self, workflow_type: str, branch_id: str) -> None:
        """Validate workflow_type and branch_id against traversal and format rules."""
        if workflow_type not in ALLOWED_WORKFLOW_TYPES:
            raise ValueError(f"Invalid workflow_type '{workflow_type}'.")
        if not branch_id or "/" in branch_id or "\\" in branch_id or ".." in branch_id:
            raise ValueError(f"Invalid branch identifier '{branch_id}'.")
        if not validate_branch_slug(branch_id):
            raise ValueError(f"Invalid {workflow_type} identifier '{branch_id}'.")

    @staticmethod
    def _assert_no_symlinks_and_confined(base_dir: Path, target_path: Path) -> None:
        """Reject symlink segments between base_dir and target_path and verify containment."""
        rel = target_path.relative_to(base_dir)
        cur = base_dir
        if cur.is_symlink():
            raise ValueError(f"Symlink detected at '{cur}' (CWE-59).")
        for part in rel.parts:
            cur = cur / part
            if cur.is_symlink():
                raise ValueError(f"Symlink detected in audit path '{cur}' (CWE-59).")
        if not target_path.resolve(strict=False).is_relative_to(base_dir.resolve(strict=False)):
            raise ValueError(f"Audit path escapes base directory '{base_dir}' (CWE-22).")

    def resolve_lifecycle_readme_path(
        self, repo_root: Path, workflow_type: str, branch_id: str
    ) -> Path:
        """Resolve canonical <spec_root>/git/<workflow_type>/<branch_id>/README.md safely."""
        self._validate_identifier(workflow_type, branch_id)
        spec_root = self.validate_spec_root(repo_root)
        spec_dir = repo_root / spec_root
        git_dir = spec_dir / "git"
        target = git_dir / workflow_type / branch_id / "README.md"
        self._assert_no_symlinks_and_confined(spec_dir, target)
        if not target.resolve(strict=False).is_relative_to(git_dir.resolve(strict=False)):
            raise ValueError("Audit path escapes <spec_root>/git confinement (CWE-22).")
        return target

    def _resolve_legacy_readme_path(
        self, repo_root: Path, spec_root: str, workflow_type: str, branch_id: str
    ) -> Path:
        """Resolve pre-060 <spec_root>/<workflow_type>/<branch_id>/README.md for lazy migration."""
        spec_dir = repo_root / spec_root
        legacy = spec_dir / workflow_type / branch_id / "README.md"
        self._assert_no_symlinks_and_confined(spec_dir, legacy)
        return legacy

    def sanitize_text(self, text: str) -> str:
        """Strip HTML comments, ANSI/control escapes, and redact secret literals."""
        if not text:
            return ""
        sanitized = HTML_COMMENT_REGEX.sub("", text)
        sanitized = sanitize_terminal_text(sanitized)
        sanitized = GHP_SECRET_REGEX.sub("***REDACTED***", sanitized)
        sanitized = AWS_SECRET_REGEX.sub("***REDACTED***", sanitized)
        sanitized = BEARER_REGEX.sub(r"\1***REDACTED***", sanitized)
        sanitized = PRIVATE_KEY_REGEX.sub("***REDACTED PRIVATE KEY***", sanitized)
        return sanitized.strip()

    def create_lifecycle_readme(
        self,
        repo_root: Path,
        workflow_type: str,
        branch_id: str,
        current_ver: str,
        base_commit_sha: str,
        description: str = "",
        original_name: Optional[str] = None,
    ) -> Path:
        """Create the audit README under ``<spec_root>/git/<type>/<id>/``.

        Validates that ``description`` is non-empty prior to rendering optional sanitized
        ``- Original Name:`` inside ``## Description`` so ``original_name`` never bypasses N23.

        Args:
            repo_root: Target repository root directory.
            workflow_type: Lifecycle family (``feature``, ``release``, or ``hotfix``).
            branch_id: Normalized lowercase branch slug.
            current_ver: Active manifest version written for the branch.
            base_commit_sha: Parent branch HEAD SHA recorded at branch creation.
            description: Mandatory human lifecycle description.
            original_name: Optional raw unnormalized identifier passed at start.

        Returns:
            Resolved path to the written ``README.md`` file.

        Raises:
            ValueError: If ``spec_root``/path confinement fails or ``description`` is empty.
        """
        readme_path = self.resolve_lifecycle_readme_path(repo_root, workflow_type, branch_id)
        now_utc = datetime.now(timezone.utc).isoformat()
        clean_desc = self.sanitize_text(description)
        if not clean_desc:
            raise ValueError(f"Missing mandatory DESCRIPTION for {workflow_type}/{branch_id}.")
        clean_orig = self.sanitize_text(original_name) if original_name is not None else ""
        desc_body = f"- Original Name: {clean_orig}\n\n{clean_desc}" if clean_orig else clean_desc
        content = (
            f"# GitFlow Lifecycle: {workflow_type}/{branch_id}\n\n"
            f"## Metadata\n"
            f"- Name: {branch_id}\n"
            f"- Status: OPEN\n"
            f"- Branch: {workflow_type}/{branch_id}\n"
            f"- Created At: {now_utc}\n"
            f"- BaseCommitSHA: {base_commit_sha}\n"
            f"- CurrentVersion: {current_ver}\n\n"
            f"## Description\n"
            f"{desc_body}\n"
        )
        _safe_write_text(readme_path, content)
        return readme_path

    @staticmethod
    def _set_current_version(text: str, version: str) -> str:
        """Return text with exactly one in-place ``- CurrentVersion:`` line and no history lines."""
        kept = [ln for ln in text.splitlines() if not ln.startswith(_HISTORY_PREFIXES)]
        out: List[str] = []
        placed = False
        for ln in kept:
            if ln.startswith("- CurrentVersion:"):
                if not placed:
                    out.append(f"- CurrentVersion: {version}")
                    placed = True
                continue
            out.append(ln)
            if not placed and ln.startswith("- BaseCommitSHA:"):
                out.append(f"- CurrentVersion: {version}")
                placed = True
        if not placed:
            idx = next((i + 1 for i, ln in enumerate(out) if ln.strip() == "## Metadata"), len(out))
            out.insert(idx, f"- CurrentVersion: {version}")
        return "\n".join(out) + "\n"

    def update_current_version(
        self, repo_root: Path, workflow_type: str, branch_id: str, current_ver: str
    ) -> Optional[Path]:
        """Rewrite ``- CurrentVersion:`` in place; return None when no README exists (external branch)."""
        readme = self.resolve_lifecycle_readme_path(repo_root, workflow_type, branch_id)
        if not readme.is_file():
            return None
        _safe_write_text(readme, self._set_current_version(readme.read_text(encoding="utf-8"), current_ver))
        return readme

    def finalize_lifecycle_readme(
        self,
        repo_root: Path,
        workflow_type: str,
        branch_id: str,
        final_branch_ver: str,
        notes: str = "",
    ) -> Path:
        """Close the audit README at the canonical path, migrating a legacy path lazily.

        Sets ``Status: CLOSED``, records the final ``- CurrentVersion:`` and strips legacy
        ``StartParentVersion``/``CurrentParentVersion``/``FinalBranchVersion`` history lines.
        """
        canonical = self.resolve_lifecycle_readme_path(repo_root, workflow_type, branch_id)
        spec_root = self.validate_spec_root(repo_root)
        legacy = self._resolve_legacy_readme_path(repo_root, spec_root, workflow_type, branch_id)
        if canonical.exists() and legacy.exists():
            raise ValueError(
                f"Dual audit path collision: both '{canonical}' and '{legacy}' exist (N20)."
            )

        now_utc = datetime.now(timezone.utc).isoformat()
        clean_notes = self.sanitize_text(notes)
        migrated_from_legacy = False
        existing = ""
        if canonical.is_file():
            existing = canonical.read_text(encoding="utf-8")
        elif legacy.is_file():
            existing = legacy.read_text(encoding="utf-8")
            migrated_from_legacy = True

        if existing:
            updated = self._set_current_version(existing.replace("- Status: OPEN", "- Status: CLOSED"), final_branch_ver)
            if "- Closed At:" not in updated:
                updated = updated.replace("- Status: CLOSED\n", f"- Status: CLOSED\n- Closed At: {now_utc}\n", 1)
            if clean_notes:
                updated += f"\n## Notes\n{clean_notes}\n"
            _safe_write_text(canonical, updated)
        else:
            fallback = (
                f"# GitFlow Lifecycle: {workflow_type}/{branch_id}\n\n"
                f"## Metadata\n"
                f"- Name: {branch_id}\n"
                f"- Status: CLOSED\n"
                f"- Branch: {workflow_type}/{branch_id}\n"
                f"- Closed At: {now_utc}\n"
                f"- CurrentVersion: {final_branch_ver}\n\n"
                f"## Notes\n"
                f"{clean_notes or 'Closed.'}\n"
            )
            _safe_write_text(canonical, fallback)

        if migrated_from_legacy:
            legacy.unlink()
            for d in (legacy.parent, legacy.parent.parent):
                if d.is_dir() and not d.is_symlink() and not any(d.iterdir()):
                    d.rmdir()
        return canonical

    def _read_field(self, repo_root: Path, workflow_type: str, branch_id: str, prefix: str) -> Optional[str]:
        """Read a ``- <Field>:`` value from the canonical README, or None when absent or unreadable."""
        try:
            p = self.resolve_lifecycle_readme_path(repo_root, workflow_type, branch_id)
            if p.is_file():
                for line in p.read_text(encoding="utf-8").splitlines():
                    if line.startswith(prefix):
                        return line.split(":", 1)[1].strip()
        except Exception:
            pass
        return None

    def read_base_commit_sha(self, repo_root: Path, workflow_type: str, branch_id: str) -> Optional[str]:
        """Return the recorded BaseCommitSHA (untrusted; callers must verify ancestry), or None."""
        return self._read_field(repo_root, workflow_type, branch_id, "- BaseCommitSHA:")

    def read_current_version(self, repo_root: Path, workflow_type: str, branch_id: str) -> Optional[str]:
        """Return the README ``- CurrentVersion:`` value (informational only), or None."""
        return self._read_field(repo_root, workflow_type, branch_id, "- CurrentVersion:")
