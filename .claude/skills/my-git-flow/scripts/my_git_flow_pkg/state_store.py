"""Checkpoint state machine persistence and schema validation for interrupted workflows.

Safely writes and loads .tmp/my-git-flow/state.json while rejecting symlinks,
tampered production branch fields, and malformed pre-merge develop versions.
"""

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

from .semver import validate_version_str
from .version_engine import _safe_write_text

REQUIRED_STATE_FIELDS = {
    "workflow",
    "branch_name",
    "parent_branch",
    "current_phase",
    "gate_passed_tree_sha",
    "main_already_pushed",
}
ALLOWED_WORKFLOWS = {"finish-feature", "finish-release", "finish-hotfix"}
ALLOWED_PROD_BRANCHES = {"main", "master"}
ALLOWED_PHASES = {"REVERSE_MERGE_PARENT", "MERGE_INTO_MAIN", "PROPAGATE_RELEASE", "MERGE_INTO_DEVELOP"}
_SHA_RE = re.compile(r"\A(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")


def _is_safe_branch_token(val: Any) -> bool:
    """Return True if val is a bounded non-flag branch string free of traversal or control bytes."""
    return (
        isinstance(val, str)
        and 0 < len(val) <= 160
        and not val.startswith("-")
        and ".." not in val
        and not any(c in val for c in ("\n", "\r", "\x00", "\\"))
    )


class StateStore:
    """Manages atomic persistence and fail-closed validation of workflow checkpoint state."""

    def state_path(self, repo_root: Path) -> Path:
        """Return canonical .tmp/my-git-flow/state.json path under repo_root."""
        return repo_root / ".tmp" / "my-git-flow" / "state.json"

    def _check_symlinks(self, repo_root: Path, target: Path) -> None:
        """Reject symlinks on .tmp, .tmp/my-git-flow, or state.json."""
        tmp_dir = repo_root / ".tmp"
        mgf_dir = tmp_dir / "my-git-flow"
        for candidate in (tmp_dir, mgf_dir, target):
            if candidate.is_symlink():
                raise ValueError("State file or parent directory is an unsafe symlink (CWE-59).")

    def _validate_payload(self, data: Dict[str, Any]) -> None:
        """Enforce required fields and strict type/format bounds on loaded or saved state."""
        missing = REQUIRED_STATE_FIELDS - set(data.keys())
        if missing:
            raise ValueError(f"Checkpoint state file missing required fields: {missing}")
        if data.get("workflow") not in ALLOWED_WORKFLOWS:
            raise ValueError(f"Unsupported checkpoint workflow: {data.get('workflow')}")
        if not _is_safe_branch_token(data.get("branch_name")) or not _is_safe_branch_token(
            data.get("parent_branch")
        ):
            raise ValueError("Invalid branch_name or parent_branch in checkpoint state.")
        if not isinstance(data.get("main_already_pushed"), bool):
            raise ValueError("Invalid main_already_pushed boolean in checkpoint state.")

        prod_branch = data.get("prod_branch")
        if prod_branch is not None and prod_branch not in ALLOWED_PROD_BRANCHES:
            raise ValueError(f"Tampered or unsupported prod_branch in state.json: '{prod_branch}'")

        if data.get("current_phase") not in ALLOWED_PHASES:
            raise ValueError(f"Unsupported or legacy checkpoint phase: '{data.get('current_phase')}'")

        for key, allow_height in (
            ("pre_merge_develop_version", True),
            ("orig_branch_version", True),
            ("finalized_version", True),
            ("set_version", False),
        ):
            val = data.get(key)
            if val is not None and (not isinstance(val, str) or not validate_version_str(val, allow_height=allow_height)):
                raise ValueError(f"Tampered or invalid {key} in state.json: '{val}'")

        sha = data.get("prod_merge_sha")
        if sha is not None and (not isinstance(sha, str) or not _SHA_RE.match(sha)):
            raise ValueError("Tampered or invalid prod_merge_sha in state.json.")
        if not isinstance(data.get("propagate_release", False), bool):
            raise ValueError("Invalid propagate_release boolean in checkpoint state.")

    def has_active_state(self, repo_root: Path) -> bool:
        """Return True if a non-symlink checkpoint state file exists."""
        target = self.state_path(repo_root)
        return target.is_file() and not target.is_symlink()

    def load_state(self, repo_root: Path) -> Optional[Dict[str, Any]]:
        """Load and validate saved checkpoint state, failing closed on tampering or symlinks."""
        target = self.state_path(repo_root)
        self._check_symlinks(repo_root, target)
        if not target.exists():
            return None
        try:
            data = json.loads(target.read_text(encoding="utf-8"))
        except Exception as err:
            raise ValueError(f"Failed to parse checkpoint state file: {err}") from err
        if not isinstance(data, dict):
            raise ValueError("Checkpoint state root must be a JSON object.")
        self._validate_payload(data)
        return data

    def save_state(self, repo_root: Path, state: Dict[str, Any]) -> None:
        """Persist checkpoint state atomically after checking symlink safety."""
        target = self.state_path(repo_root)
        self._check_symlinks(repo_root, target)
        payload = dict(state)
        if "created_at" not in payload:
            payload["created_at"] = datetime.now(timezone.utc).isoformat()
        _safe_write_text(target, json.dumps(payload, indent=2) + "\n")

    def save_pause(
        self, repo_root: Path, wf: str, branch: str, parent: str, phase: str,
        prod: Optional[str] = None, pre_dev: Optional[str] = None, pushed: bool = False,
        orig_ver: Optional[str] = None, final_ver: Optional[str] = None,
        merge_sha: Optional[str] = None, set_version: Optional[str] = None,
        propagate: bool = False,
    ) -> None:
        """Persist conflict-pause checkpoint state atomically (phase must be in ALLOWED_PHASES)."""
        self.save_state(repo_root, {
            "workflow": wf, "branch_name": branch, "parent_branch": parent,
            "prod_branch": prod, "pre_merge_develop_version": pre_dev,
            "orig_branch_version": orig_ver, "finalized_version": final_ver,
            "prod_merge_sha": merge_sha, "set_version": set_version, "propagate_release": propagate,
            "current_phase": phase, "gate_passed_tree_sha": None, "main_already_pushed": pushed,
        })

    def clear_state(self, repo_root: Path) -> None:
        """Remove active checkpoint state file upon workflow completion or abort."""
        target = self.state_path(repo_root)
        self._check_symlinks(repo_root, target)
        if target.is_file():
            target.unlink()

    def abort_checkpoint(self, repo_root: Path, gw: Any) -> tuple[int, str]:
        """Validate state, abort active git merge, clear state, and protect pushed prod_branch."""
        try:
            state = self.load_state(repo_root)
        except ValueError as exc:
            return 1, str(exc)
        if not state:
            return 1, "No active checkpoint state found to abort."
        gw.run_git(repo_root, ["merge", "--abort"])
        self.clear_state(repo_root)
        prod_name = state.get("prod_branch") or "main"
        if state.get("main_already_pushed"):
            return 0, f"Protected {prod_name}: develop merge aborted. {prod_name} and tag remain intact."
        return 0, "Workflow aborted and checkpoint state cleared."

    def resume_checkpoint(self, repo_root: Path, orch: Any) -> tuple[int, str]:
        """Validate conflict markers and state, then continue from the exact paused phase.

        Completed phases are never re-run: post-production phases resume with the persisted
        ``finalized_version`` and ``prod_merge_sha`` so versions can never regress on resume.
        """
        if orch.gw.has_unmerged_entries(repo_root) or orch.gw.scan_for_conflict_markers(repo_root):
            return 10, "Unresolved merge conflicts or conflict markers remain in workspace."
        try:
            state = self.load_state(repo_root)
        except ValueError as exc:
            return 1, str(exc)
        if not state:
            return 1, "No active checkpoint state found to continue."
        if (repo_root / ".git" / "MERGE_HEAD").exists():
            orch.gw.commit_if_changes(repo_root, f"merge: resolve {state['branch_name']}")
        wf, branch, phase = state["workflow"], state["branch_name"], state["current_phase"]
        slug = branch.split("/", 1)[-1]
        if wf == "finish-feature":
            if phase == "MERGE_INTO_DEVELOP":
                rc, msg = orch.complete_feature_close(repo_root, branch)
            else:
                rc, msg = orch.finish_feature(
                    repo_root, slug, skip_tests_confirm=True,
                    set_version=state.get("set_version"), orig_branch_ver=state.get("orig_branch_version"),
                )
        elif phase == "REVERSE_MERGE_PARENT":
            extra = {} if wf == "finish-release" else {"propagate_release": bool(state.get("propagate_release"))}
            fn = orch.finish_release if wf == "finish-release" else orch.finish_hotfix
            rc, msg = fn(repo_root, slug, skip_tests_confirm=True, set_version=state.get("set_version"), **extra)
        else:
            rc, msg = orch.resume_prod_workflow(repo_root, state)
        if rc == 0:
            self.clear_state(repo_root)
        return rc, msg
