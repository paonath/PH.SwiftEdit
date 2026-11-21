"""GitFlow workflow orchestrator coordinating monotonic SemVer transitions and gates.

Invariant: no command, merge, override, or checkpoint resume ever lowers a version.
"""

import re
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

from . import workflow_versioning as wv
from .audit_docs import AuditDocs
from .build_test_gate import BuildTestGate
from .git_gateway import GitGateway, sanitize_terminal_text
from .semver import (
    base_version_str,
    compare_semver,
    evaluate_dual_baseline,
    max_semver,
    normalize_branch_slug,
    resolve_tag_version_3seg,
    validate_branch_slug,
    validate_version_str,
)
from .state_store import StateStore
from .version_engine import VersionEngine

_SHA_RE = re.compile(r"\A(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")


class WorkflowOrchestrator:
    """Orchestrates Feature, Release, and Hotfix lifecycles across GitFlow branches."""

    def __init__(self) -> None:
        self.gw, self.ver_engine, self.gate = GitGateway(), VersionEngine(), BuildTestGate()
        self.audit, self.state_store = AuditDocs(), StateStore()

    # ------------------------------------------------------------------ helpers
    def _guard_finish(self, repo_root: Path, family: str, explicit_id: Optional[str]) -> Tuple[int, str]:
        """Validate active branch family against finish-<family> with slug normalization and terminal sanitization."""
        raw = self.gw.current_branch(repo_root)
        rc, res = wv.resolve_finish_target_slug(sanitize_terminal_text(raw), family, explicit_id)
        return (rc, sanitize_terminal_text(res)) if rc != 0 else (0, res)

    @staticmethod
    def _normalize_start_id(
        raw_id: Optional[str], error_label: str
    ) -> Tuple[Optional[str], Optional[Tuple[int, str]]]:
        """Normalize an optional start identifier and return ``(norm_slug, error_tuple)``."""
        if raw_id is None:
            return None, None
        norm_id = normalize_branch_slug(raw_id)
        if not validate_branch_slug(norm_id):
            return None, (2, f"Invalid {error_label} '{sanitize_terminal_text(raw_id)}'.")
        return norm_id, None

    @staticmethod
    def _validate_set_version(set_version: Optional[str]) -> Optional[Tuple[int, str]]:
        """Reject malformed --set-version values (dash, {height}, control bytes) before any Git work."""
        if set_version is not None and not validate_version_str(set_version, allow_height=False):
            return 2, f"Invalid --set-version '{sanitize_terminal_text(set_version)}'."
        return None

    def _sync_read(self, repo_root: Path, branch: str, ensure_dev: bool = False) -> Tuple[bool, str, str]:
        """Checkout (or ensure develop), pull fast-forward, and return (ok, err_or_ver, head_sha)."""
        ok, msg = self.gw.ensure_develop(repo_root) if ensure_dev else self.gw.checkout(repo_root, branch)
        if not ok:
            return False, f"Failed to checkout {branch}: {msg}", ""
        self.gw.pull_if_remote(repo_root, branch)
        return True, self.ver_engine.read_version(repo_root), self.gw.get_head_sha(repo_root)

    def _write_and_notify(
        self, repo_root: Path, new_ver: str, reason: str, notes: List[str]
    ) -> Optional[Tuple[int, str]]:
        """Write new_ver monotonically and append [VERSION] audit line to notes."""
        m_info = self.ver_engine.discover_manifest(repo_root)
        old_ver = m_info.raw_version
        try:
            self.ver_engine.write_version(repo_root, new_ver)
        except ValueError as exc:
            return 2, str(exc)
        notes.append(f"[VERSION] {m_info.relative_path}: {old_ver} -> {new_ver} ({reason})")
        return None

    def _merge_keeping_max_version(
        self, repo_root: Path, source_ref: str, msg: str, notes: List[str], theirs_ver: str
    ) -> Tuple[bool, str]:
        """Merge source_ref into current branch and monotonically keep max_semver(ours, after, theirs)."""
        ours_ver = self.ver_engine.read_version(repo_root)
        m_info = self.ver_engine.discover_manifest(repo_root)
        ok, out = self.gw.merge_resolving_manifest(repo_root, source_ref, msg, m_info.relative_path)
        if not ok:
            return False, out
        after_ver = self.ver_engine.read_version(repo_root)
        best_ver = max_semver(ours_ver, max_semver(after_ver, theirs_ver))
        if best_ver != after_ver:
            self.ver_engine.write_version(repo_root, best_ver)
            self.gw.commit_if_changes(repo_root, f"chore: reconcile monotonic version {best_ver} after merge")
            notes.append(
                f"[VERSION] {m_info.relative_path}: {after_ver} -> {best_ver} (merge monotonic max reconciliation)"
            )
        return True, ""

    def _sync_readme(self, repo_root: Path, family: str, slug: str) -> Optional[Tuple[int, str]]:
        """Resync the lifecycle README ``- CurrentVersion:`` from the manifest and commit if changed."""
        version = self.ver_engine.read_version(repo_root)
        try:
            self.audit.update_current_version(repo_root, family, slug, version)
        except ValueError as exc:
            return 3, str(exc)
        self.gw.commit_if_changes(repo_root, f"chore: sync {family}/{slug} current version {version}")
        return None

    def _start_parent_version(
        self, repo_root: Path, family: str, slug: str, parent: str, fallback: str
    ) -> Tuple[str, str]:
        """Derive StartParentVersion from Git objects at BaseCommitSHA; return (version, error).

        README values are never trusted: a recorded BaseCommitSHA must be an ancestor of HEAD,
        otherwise the gate fails closed. Without a README the merge-base with the parent is used.
        """
        base_sha = self.audit.read_base_commit_sha(repo_root, family, slug)
        try:
            if base_sha is not None:
                if not _SHA_RE.match(base_sha) or not self.gw.is_ancestor(repo_root, base_sha, "HEAD"):
                    return "", (
                        f"BaseCommitSHA in {family}/{slug} README is not an ancestor of HEAD (possible tampering)."
                    )
            else:
                base_sha = self.gw.merge_base(repo_root, "HEAD", parent)
                if not base_sha:
                    return fallback, ""
            name = self.ver_engine.discover_manifest(repo_root).relative_path
            text = self.gw.cat_file_at_commit(repo_root, base_sha, name)
            if text is None:
                return fallback, ""
            return self.ver_engine.read_version_from_text(name, text), ""
        except ValueError:
            return fallback, ""

    def _spawn_branch(
        self,
        repo_root: Path,
        wf: str,
        slug: str,
        b_sha: str,
        m_ver: str,
        desc: str,
        reason: str,
        warn: str = "",
        original_name: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Create ``<wf>/<slug>``, scaffold audit README, write ``m_ver``, and commit.

        Args:
            repo_root: Target repository root directory.
            wf: Workflow family (``feature``, ``release``, or ``hotfix``).
            slug: Normalized lowercase branch slug.
            b_sha: Parent branch HEAD SHA at creation.
            m_ver: Calculated or overridden target manifest version.
            desc: Mandatory human description text.
            reason: Audit tag for ``[VERSION]`` status output.
            warn: Optional warning line prepended to status output.
            original_name: Optional raw unnormalized identifier persisted in ``README.md``.

        Returns:
            ``(exit_code, status_message)`` tuple.
        """
        branch = f"{wf}/{slug}"
        ok, msg = self.gw.checkout(repo_root, branch, create=True)
        if not ok:
            return 1, f"Failed to create branch {branch}: {msg}"
        try:
            self.audit.create_lifecycle_readme(
                repo_root, wf, slug, m_ver, b_sha, desc, original_name=original_name
            )
        except ValueError as exc:
            return 3, str(exc)
        v_notes: List[str] = [warn] if warn else []
        if err := self._write_and_notify(repo_root, m_ver, reason, v_notes):
            return err
        self.gw.commit_if_changes(repo_root, f"Initial commit for {branch}")
        v_notes.append(f"{wf.capitalize()} branch '{branch}' started at {m_ver}.")
        return 0, "\n".join(v_notes)

    def _safe_finalize_audit(
        self, repo_root: Path, wf: str, slug: str, final_ver: str, notes: str
    ) -> Optional[Tuple[int, str]]:
        """Finalize lifecycle README, mapping security/collision ValueError to exit code 3."""
        try:
            self.audit.finalize_lifecycle_readme(repo_root, wf, slug, final_ver, notes)
            return None
        except ValueError as exc:
            return 3, str(exc)

    # ------------------------------------------------------------------ start-*
    def start_feature(
        self,
        repo_root: Path,
        feature_name: str,
        description: str = "",
        bump_level: str = "patch",
        dry_run: bool = False,
        set_version: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Create feature/<slug> from develop after normalizing feature_name and validating metadata."""
        norm_name, slug_err = self._normalize_start_id(feature_name, "feature name")
        if slug_err or norm_name is None:
            return slug_err or (2, "Missing mandatory feature name.")
        if not description or not self.audit.sanitize_text(description):
            return 2, "Missing mandatory DESCRIPTION (--description) for feature start."
        if err := self._validate_set_version(set_version):
            return err
        if not dry_run and (err := self.gw.preflight(repo_root)):
            return err

        def _target(start_ver: str) -> Tuple[int, str]:
            if set_version:
                return wv.resolve_override_for_start("feature", start_ver, set_version, start_ver)
            return 0, wv.compute_start_feature_version(start_ver, bump_level)

        if dry_run:
            start_ver = self.ver_engine.read_version(repo_root)
            rc, next_ver = _target(start_ver)
            if rc != 0:
                return rc, next_ver
            m_info = self.ver_engine.discover_manifest(repo_root)
            return (
                0,
                f"[DRY-RUN] [VERSION] {m_info.relative_path}: {start_ver} -> {next_ver} (start-feature on feature/{norm_name})",
            )
        ok, start_ver, base_sha = self._sync_read(repo_root, "develop", ensure_dev=True)
        if not ok:
            return 1, start_ver
        rc, next_ver = _target(start_ver)
        if rc != 0:
            return rc, next_ver
        return self._spawn_branch(
            repo_root, "feature", norm_name, base_sha, next_ver, description, "start-feature",
            original_name=feature_name,
        )

    def start_release(
        self,
        repo_root: Path,
        version: Optional[str] = None,
        description: str = "",
        override: bool = False,
        dry_run: bool = False,
        set_version: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Start release/<slug> from develop after normalizing optional version/slug identifier."""
        norm_version, slug_err = self._normalize_start_id(version, "release version or slug")
        if slug_err:
            return slug_err
        if not description or not self.audit.sanitize_text(description):
            return 2, "Missing mandatory DESCRIPTION (--description) for release start."
        if err := self._validate_set_version(set_version):
            return err
        if not dry_run and (err := self.gw.preflight(repo_root)):
            return err
        try:
            prod = self.gw.detect_production_branch(repo_root)
        except ValueError as exc:
            return 1, str(exc)
        _, prod_ver, _ = self._sync_read(repo_root, prod)
        ok, dev_ver, dev_sha = self._sync_read(repo_root, "develop", ensure_dev=True)
        if not ok:
            return 1, dev_ver
        if set_version:
            rc, m_ver = wv.resolve_override_for_start("release", dev_ver, set_version, dev_ver, prod_ver)
            slug, warn = (norm_version or base_version_str(m_ver)), None
        else:
            rc, slug, m_ver, warn = wv.resolve_start_release_plan(
                sanitize_terminal_text(dev_ver), sanitize_terminal_text(prod_ver), prod, norm_version, override
            )
        if rc != 0:
            return rc, (m_ver if set_version else slug)
        clean_ver = wv.compute_finish_release_version(m_ver)
        tag_v, tag_b = f"v.{resolve_tag_version_3seg(clean_ver)}", f"release/{slug}"
        if self.gw.tag_exists(repo_root, tag_v) or self.gw.tag_exists(repo_root, tag_b):
            return 2, f"Tag collision: '{tag_v}' or '{tag_b}' already exists."
        if dry_run:
            m_info = self.ver_engine.discover_manifest(repo_root)
            lines = ([warn] if warn else []) + [
                f"[DRY-RUN] [VERSION] {m_info.relative_path}: {dev_ver} -> {m_ver} (start-release on {tag_b})"
            ]
            return 0, "\n".join(lines)
        full_desc = f"{description}\n\n{warn}" if warn else description
        return self._spawn_branch(
            repo_root, "release", slug, dev_sha, m_ver, full_desc, "start-release", warn or "",
            original_name=version,
        )

    def start_hotfix(
        self,
        repo_root: Path,
        version: Optional[str] = None,
        description: str = "",
        bump_level: str = "patch",
        dry_run: bool = False,
        set_version: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Start hotfix/<slug> from prod_branch after normalizing optional version/slug identifier."""
        norm_version, slug_err = self._normalize_start_id(version, "hotfix version or slug")
        if slug_err:
            return slug_err
        if not description or not self.audit.sanitize_text(description):
            return 2, "Missing mandatory DESCRIPTION (--description) for hotfix start."
        if err := self._validate_set_version(set_version):
            return err
        if not dry_run and (err := self.gw.preflight(repo_root)):
            return err
        try:
            prod = self.gw.detect_production_branch(repo_root)
        except ValueError as exc:
            return 1, str(exc)
        _, prod_ver, prod_sha = self._sync_read(repo_root, prod)
        if set_version:
            rc, m_ver = wv.resolve_override_for_start("hotfix", prod_ver, set_version, prod_ver, prod_ver)
            slug = norm_version or base_version_str(m_ver)
            err_msg = m_ver
        else:
            rc, slug, m_ver = wv.resolve_start_hotfix_plan(
                sanitize_terminal_text(prod_ver), prod, norm_version, bump_level
            )
            err_msg = slug
        if rc != 0:
            return rc, err_msg
        clean_ver = wv.compute_finish_hotfix_version(m_ver)
        tag_v, tag_b = f"v.{resolve_tag_version_3seg(clean_ver)}", f"hotfix/{slug}"
        if self.gw.tag_exists(repo_root, tag_v) or self.gw.tag_exists(repo_root, tag_b):
            return 2, f"Tag collision: '{tag_v}' or '{tag_b}' already exists."
        if dry_run:
            m_info = self.ver_engine.discover_manifest(repo_root)
            return (
                0,
                f"[DRY-RUN] [VERSION] {m_info.relative_path}: {prod_ver} -> {m_ver} (start-hotfix on {tag_b})",
            )
        return self._spawn_branch(
            repo_root, "hotfix", slug, prod_sha, m_ver, description, "start-hotfix",
            original_name=version,
        )

    # ---------------------------------------------------------------- finish-feature
    def finish_feature(
        self,
        repo_root: Path,
        feature_name: Optional[str] = None,
        bump_level: str = "patch",
        skip_tests_confirm: bool = False,
        notes: str = "",
        dry_run: bool = False,
        set_version: Optional[str] = None,
        orig_branch_ver: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Reverse-merge develop, increment suffix (Point 5), run gates, and merge into develop.

        ``orig_branch_ver`` is the pre-reverse-merge branch version persisted across a conflict
        pause; it keeps a clean develop version from being mistaken for a manual bump on resume.
        """
        rc, name = self._guard_finish(repo_root, "feature", feature_name)
        if rc != 0 or not validate_branch_slug(name):
            return (rc, name) if rc != 0 else (2, f"Invalid feature name '{sanitize_terminal_text(name)}'.")
        if err := self._validate_set_version(set_version):
            return err
        branch = f"feature/{name}"
        if dry_run:
            cur_ver = self.ver_engine.read_version(repo_root)
            target_ver = wv.compute_finish_feature_version(cur_ver, cur_ver, cur_ver, bump_level)
            if set_version:
                rc, res = wv.resolve_override_for_finish_feature(cur_ver, set_version, cur_ver, cur_ver)
                if rc != 0:
                    return rc, res
                target_ver = res
            m_info = self.ver_engine.discover_manifest(repo_root)
            return 0, f"[DRY-RUN] [VERSION] {m_info.relative_path}: {cur_ver} -> {target_ver} (finish-feature on {branch})"
        if err := self.gw.preflight(repo_root):
            return err
        ok, curr_dev_ver, _ = self._sync_read(repo_root, "develop", ensure_dev=True)
        if not ok:
            return 1, curr_dev_ver
        ok, msg = self.gw.checkout(repo_root, branch)
        if not ok:
            return 1, f"Failed to checkout {branch}: {msg}"
        orig_ver = orig_branch_ver or self.ver_engine.read_version(repo_root)
        start_dev_ver, base_err = self._start_parent_version(repo_root, "feature", name, "develop", curr_dev_ver)
        if base_err:
            return 1, base_err
        if err := self._sync_readme(repo_root, "feature", name):
            return err
        v_notes: List[str] = []
        ok_m, msg_m = self._merge_keeping_max_version(
            repo_root, "develop", f"merge: develop in {branch}", v_notes, curr_dev_ver
        )
        if not ok_m:
            self.state_store.save_pause(
                repo_root, "finish-feature", branch, "develop", "REVERSE_MERGE_PARENT",
                orig_ver=orig_ver, set_version=set_version,
            )
            return 10, f"Merge conflict reverse-merging develop into {branch}:\n{msg_m}"
        branch_ver = self.ver_engine.read_version(repo_root)
        if set_version:
            rc, target_ver = wv.resolve_override_for_finish_feature(
                branch_ver, set_version, max_semver(orig_ver, branch_ver), curr_dev_ver
            )
            if rc != 0:
                return rc, target_ver
        else:
            # Never below what is already on disk (manual bumps and conflict resolutions are kept).
            target_ver = max_semver(
                wv.compute_finish_feature_version(orig_ver, start_dev_ver, curr_dev_ver, bump_level), branch_ver
            )
        if target_ver != branch_ver:
            if err := self._write_and_notify(
                repo_root, target_ver, f"finish-feature suffix/baseline update on {branch}", v_notes
            ):
                return err
            self.gw.commit_if_changes(repo_root, f"chore: bump version {target_ver}")
            branch_ver = target_ver
        db_res = evaluate_dual_baseline(branch_ver, start_dev_ver, curr_dev_ver)
        if not db_res.valid or not (g_res := self.gate.run_gate(repo_root, skip_tests_confirm))[0]:
            return (1, db_res.error_message) if not db_res.valid else (1, f"Build and test gate failure: {g_res[1]}")
        if a_err := self._safe_finalize_audit(repo_root, "feature", name, branch_ver, notes):
            return a_err
        self.gw.commit_if_changes(repo_root, f"update: feature close information '{name}'")
        self.gw.ensure_develop(repo_root)
        ok_d, msg_d = self._merge_keeping_max_version(
            repo_root, f"refs/heads/{branch}", f"merge: {branch}", v_notes, branch_ver
        )
        if not ok_d:
            self.state_store.save_pause(
                repo_root, "finish-feature", branch, "develop", "MERGE_INTO_DEVELOP",
                orig_ver=orig_ver, set_version=set_version,
            )
            return 10, f"Merge conflict merging {branch} into develop:\n{msg_d}"
        rc, close_msg = self.complete_feature_close(repo_root, branch)
        v_notes.append(f"Feature '{name}' finished at {branch_ver} and merged into develop.")
        return rc, "\n".join(v_notes) if rc == 0 else close_msg

    def complete_feature_close(self, repo_root: Path, branch: str) -> Tuple[int, str]:
        """Push develop and delete the merged feature branch (also the --continue completion step)."""
        if self.gw.current_branch(repo_root) != "develop":
            return 1, "Checkout develop (with the feature merge committed) before --continue."
        self.gw.push_if_remote(repo_root, "develop")
        self.gw.delete_branch(repo_root, branch, force=True)
        return 0, f"Feature '{branch}' merged into develop and deleted."

    # ------------------------------------------------------- finish-release / finish-hotfix
    def _finish_prod_workflow(
        self,
        repo_root: Path,
        family: str,
        version: Optional[str],
        strip_fn: Callable[[str], str],
        propagate_release: bool,
        skip_tests_confirm: bool,
        notes: str,
        dry_run: bool,
        set_version: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Execute finish-release or finish-hotfix with pre-merge monotonic guard, dual tags, and Point 8 develop +1."""
        rc, slug = self._guard_finish(repo_root, family, version)
        if rc != 0 or not validate_branch_slug(slug):
            return (rc, slug) if rc != 0 else (2, f"Invalid {family} slug '{sanitize_terminal_text(slug)}'.")
        if err := self._validate_set_version(set_version):
            return err
        wf, branch = f"finish-{family}", f"{family}/{slug}"
        if dry_run:
            cur_ver = self.ver_engine.read_version(repo_root)
            final_ver = strip_fn(cur_ver)
            if set_version:
                try:
                    final_ver = wv.apply_version_override(cur_ver, set_version)
                except ValueError as exc:
                    return 2, str(exc)
            tag_v = f"v.{resolve_tag_version_3seg(final_ver)}"
            m_info = self.ver_engine.discover_manifest(repo_root)
            return (
                0,
                f"[DRY-RUN] [VERSION] {m_info.relative_path}: {cur_ver} -> {final_ver} ({wf} -> tags {tag_v} & {branch})",
            )
        if err := self.gw.preflight(repo_root):
            return err
        try:
            prod = self.gw.detect_production_branch(repo_root)
        except ValueError as exc:
            return 1, str(exc)
        _, pre_dev, _ = self._sync_read(repo_root, "develop", ensure_dev=True)
        _, prod_ver, _ = self._sync_read(repo_root, prod)
        ok, msg = self.gw.checkout(repo_root, branch)
        if not ok:
            return 1, f"Failed to checkout {branch}: {msg}"
        pre_branch_ver = self.ver_engine.read_version(repo_root)
        expected_final = strip_fn(pre_branch_ver)
        if set_version:
            rc, expected_final = wv.resolve_override_for_finish_prod(
                pre_branch_ver, set_version, expected_final, prod_ver
            )
            if rc != 0:
                return rc, expected_final
        if compare_semver(expected_final, prod_ver) <= 0:
            return (
                2,
                f"MONOTONIC VIOLATION: {branch} target version ({expected_final}) must be strictly greater than {prod} ({prod_ver}).",
            )
        tag_v_pre = f"v.{resolve_tag_version_3seg(expected_final)}"
        if self.gw.tag_exists(repo_root, tag_v_pre) or self.gw.tag_exists(repo_root, branch):
            return 2, f"Tag collision: '{tag_v_pre}' or '{branch}' already exists."
        if err := self._sync_readme(repo_root, family, slug):
            return err
        v_notes: List[str] = []
        ok_m, msg_m = self._merge_keeping_max_version(
            repo_root, prod, f"merge: {prod} in {branch}", v_notes, prod_ver
        )
        if not ok_m:
            self.state_store.save_pause(
                repo_root, wf, branch, prod, "REVERSE_MERGE_PARENT", prod, pre_dev,
                final_ver=expected_final, set_version=set_version, propagate=propagate_release,
            )
            return 10, f"Merge conflict reverse-merging {prod} into {branch}:\n{msg_m}"
        g_ok, g_msg = self.gate.run_gate(repo_root, skip_tests_confirm)
        if not g_ok:
            return 1, f"Build and test gate failure: {g_msg}"
        post_ver = self.ver_engine.read_version(repo_root)
        final_ver = expected_final if set_version else strip_fn(post_ver)
        if compare_semver(final_ver, post_ver) < 0:
            return 2, f"MONOTONIC VIOLATION: finalizing {branch} at {final_ver} would regress {post_ver}."
        if a_err := self._safe_finalize_audit(repo_root, family, slug, final_ver, notes):
            return a_err
        self.gw.commit_if_changes(repo_root, f"prepare for close {family}: {final_ver}")
        if err := self._write_and_notify(repo_root, final_ver, f"strip prerelease for {prod}", v_notes):
            return err
        self.gw.commit_if_changes(repo_root, f"chore: finalize {family} {final_ver}")
        self.gw.checkout(repo_root, prod)
        ok_p, msg_p = self._merge_keeping_max_version(
            repo_root, f"refs/heads/{branch}", f"{family}: {final_ver}", v_notes, final_ver
        )
        if not ok_p:
            self.state_store.save_pause(
                repo_root, wf, branch, prod, "MERGE_INTO_MAIN", prod, pre_dev,
                final_ver=final_ver, set_version=set_version, propagate=propagate_release,
            )
            return 10, f"Merge conflict merging {branch} into {prod}:\n{msg_p}"
        return self._finish_after_prod_merge(
            repo_root, family, slug, prod, pre_dev, final_ver, self.gw.get_head_sha(repo_root),
            propagate_release, set_version, v_notes,
        )

    def _finish_after_prod_merge(
        self,
        repo_root: Path,
        family: str,
        slug: str,
        prod: str,
        pre_dev: str,
        final_ver: str,
        prod_merge_sha: str,
        propagate_release: bool,
        set_version: Optional[str],
        v_notes: List[str],
        resume_phase: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Propagate, merge into develop (+1), delete the branch first, then dual-tag and push.

        Shared by the normal flow and ``--continue`` so a resume completes the pending steps
        (including tags and pushes) using the persisted ``finalized_version`` and ``prod_merge_sha``.
        """
        wf, branch = f"finish-{family}", f"{family}/{slug}"

        def _pause(parent: str, phase: str, pushed: bool) -> None:
            self.state_store.save_pause(
                repo_root, wf, branch, parent, phase, prod, pre_dev, pushed,
                final_ver=final_ver, merge_sha=prod_merge_sha, set_version=set_version,
                propagate=propagate_release,
            )

        if resume_phase != "MERGE_INTO_DEVELOP":
            if family == "hotfix" and propagate_release:
                for r_branch in self.gw.list_local_branches(repo_root, "release/"):
                    self.gw.checkout(repo_root, r_branch)
                    r_ver = self.ver_engine.read_version(repo_root)
                    ok_r, msg_r = self._merge_keeping_max_version(
                        repo_root, f"refs/heads/{branch}", f"merge: {branch} in {r_branch}", v_notes, final_ver
                    )
                    if not ok_r:
                        _pause(r_branch, "PROPAGATE_RELEASE", True)
                        return 10, f"Merge conflict propagating {branch} into {r_branch}:\n{msg_r}"
                    on_disk = self.ver_engine.read_version(repo_root)
                    next_rel = max_semver(wv.compute_propagated_release_version(r_ver, final_ver), on_disk)
                    if next_rel != on_disk:
                        if err := self._write_and_notify(
                            repo_root, next_rel, f"propagate hotfix to {r_branch}", v_notes
                        ):
                            return err
                    if err := self._sync_readme(repo_root, "release", r_branch.split("/", 1)[-1]):
                        return err
                    self.gw.commit_if_changes(repo_root, f"chore: restore release candidate manifest {next_rel}")
            self.gw.ensure_develop(repo_root)
            ok_d, msg_d = self._merge_keeping_max_version(
                repo_root, f"refs/heads/{branch}", f"merge: {branch} in develop", v_notes, final_ver
            )
            if not ok_d:
                _pause("develop", "MERGE_INTO_DEVELOP", True)
                return 10, f"Merge conflict merging {branch} into develop:\n{msg_d}"
        else:
            self.gw.ensure_develop(repo_root)
        effective_dev = max_semver(pre_dev, self.ver_engine.read_version(repo_root))
        post_dev = wv.compute_post_merge_develop_version(effective_dev, final_ver)
        if err := self._write_and_notify(repo_root, post_dev, f"post-{family} develop +1", v_notes):
            return err
        self.gw.commit_if_changes(repo_root, f"chore: advance develop to {post_dev} after {branch}")
        self.gw.delete_branch(repo_root, branch, force=True)
        tag_v = f"v.{resolve_tag_version_3seg(final_ver)}"
        for tag, label in ((tag_v, f"{family.capitalize()} {final_ver}"), (branch, f"{family.capitalize()} branch {branch} ({final_ver})")):
            if not self.gw.tag_exists(repo_root, tag):
                self.gw.create_tag(repo_root, tag, message=label, target=prod_merge_sha)
        self.gw.push_if_remote(repo_root, prod, tags=True)
        self.gw.push_if_remote(repo_root, "develop")
        v_notes.append(
            f"{family.capitalize()} '{final_ver}' finished, tagged '{tag_v}' & '{branch}', and develop advanced to {post_dev}."
        )
        return 0, "\n".join(v_notes)

    def resume_prod_workflow(self, repo_root: Path, state: Dict[str, Any]) -> Tuple[int, str]:
        """Resume finish-release/hotfix after the production merge using persisted state only."""
        family = "release" if state["workflow"] == "finish-release" else "hotfix"
        branch, phase = state["branch_name"], state["current_phase"]
        prod, pre_dev, final_ver = state.get("prod_branch"), state.get("pre_merge_develop_version"), state.get("finalized_version")
        if not (prod and pre_dev and final_ver):
            return 1, "Checkpoint state is incomplete (prod_branch, pre_merge_develop_version, finalized_version required)."
        if phase == "MERGE_INTO_MAIN":
            if self.gw.current_branch(repo_root) != prod:
                return 1, f"Checkout {prod} (with the merge committed) before --continue."
            prod_sha = self.gw.get_head_sha(repo_root)
        else:
            prod_sha = state.get("prod_merge_sha") or ""
            if not prod_sha or not self.gw.is_ancestor(repo_root, prod_sha, prod):
                return 1, "prod_merge_sha is missing or is not an ancestor of the production branch."
        return self._finish_after_prod_merge(
            repo_root, family, branch.split("/", 1)[-1], prod, pre_dev, final_ver, prod_sha,
            bool(state.get("propagate_release")), state.get("set_version"), [], resume_phase=phase,
        )

    def finish_release(
        self,
        repo_root: Path,
        version: Optional[str] = None,
        skip_tests_confirm: bool = False,
        notes: str = "",
        dry_run: bool = False,
        set_version: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Strip -rc<N>, merge/dual-tag prod_branch, and advance develop by +1."""
        return self._finish_prod_workflow(
            repo_root, "release", version, wv.compute_finish_release_version, False,
            skip_tests_confirm, notes, dry_run, set_version,
        )

    def finish_hotfix(
        self,
        repo_root: Path,
        version: Optional[str] = None,
        propagate_release: bool = False,
        skip_tests_confirm: bool = False,
        notes: str = "",
        dry_run: bool = False,
        set_version: Optional[str] = None,
    ) -> Tuple[int, str]:
        """Strip -beta<N>, merge/dual-tag prod_branch, optionally propagate to release/*, and advance develop by +1."""
        return self._finish_prod_workflow(
            repo_root, "hotfix", version, wv.compute_finish_hotfix_version, propagate_release,
            skip_tests_confirm, notes, dry_run, set_version,
        )

    def continue_workflow(self, repo_root: Path) -> Tuple[int, str]:
        """Resume an interrupted workflow after verifying conflict markers and state integrity."""
        return self.state_store.resume_checkpoint(repo_root, self)

    def abort_workflow(self, repo_root: Path) -> Tuple[int, str]:
        """Abort an interrupted workflow, protecting pushed production state."""
        return self.state_store.abort_checkpoint(repo_root, self.gw)
