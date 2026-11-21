#!/usr/bin/env python3
"""CLI engine to move reasoning sessions and notes into the Obsidian SecondBrain vault."""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

DEFAULT_VAULT_ENV = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents"
EXCLUDED_NAMES = frozenset({".git", "bin", "obj", "node_modules", "__pycache__", ".DS_Store"})
CRITICAL_REPO_PATHS = frozenset(
    {".git", ".agents", ".claude", "openspec/Constitution.md", "specs/Constitution.md", ".myspec.config.json"}
)
STATE_FILENAME = ".second-brain-state.json"
MOC_SECTION_HEADER = "## 🧠 Sessioni di Ragionamento & Note Archiviate (SecondBrain)"
_STATUS_RE = re.compile(r'^status:\s*["\']?([A-Za-z0-9_-]+)["\']?\s*$', re.MULTILINE)
_PREFIX_RE = re.compile(r"^(\d{3})_")


@dataclass(frozen=True, slots=True)
class MoveItem:
    """Single source-to-destination file mapping."""

    source: Path
    destination: Path
    root_group: Path
    repo_rel_group: str
    vault_rel_group: str
    session_id: str | None = None


@dataclass(frozen=True, slots=True)
class MoveReport:
    """Structured summary emitted by move_reasoning_to_second_brain."""

    dry_run: bool
    project_name: str
    vault_path: str
    files_planned: int
    files_copied: int
    files_skipped_identical: int
    files_deleted_local: int
    sessions_selected: list[str]
    sources_selected: list[str]
    last_prefix: int
    hub_moc_updated: bool
    git_vault_committed: bool
    git_repo_committed: bool


def compute_sha256(file_path: Path) -> str:
    """Stream SHA-256 digest of file_path."""
    digest = hashlib.sha256()
    with file_path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def reject_symlinks(root: Path, target: Path) -> None:
    """Reject symlinks on root and every path segment down to target (CWE-59).

    Args:
        root: Canonical confinement root directory.
        target: Descendant path inside ``root``.

    Raises:
        ValueError: If ``root`` or any segment along ``target`` is a symbolic link.
    """
    if root.is_symlink():
        raise ValueError(f"Symlink root is forbidden (CWE-59): {root}")
    rel = target.relative_to(root)
    cur = root
    for part in rel.parts:
        cur = cur / part
        if cur.is_symlink():
            raise ValueError(f"Symlink detected in path (CWE-59): {cur}")


def resolve_confined(root: Path, rel_str: str) -> Path:
    """Resolve rel_str inside canonical root and block traversal or symlinks (CWE-22/CWE-59).

    Args:
        root: Canonical confinement root directory.
        rel_str: Untrusted relative path string.

    Returns:
        Validated path confined inside ``root``.

    Raises:
        ValueError: If ``rel_str`` is empty, absolute, contains ``..``, or traverses a symlink.
    """
    cleaned = rel_str.strip()
    if not cleaned:
        raise ValueError("Empty relative path is invalid.")
    raw_rel = Path(cleaned)
    if raw_rel.is_absolute() or ".." in raw_rel.parts:
        raise ValueError(f"Path escapes confinement root (CWE-22): '{rel_str}'")
    candidate = root / raw_rel
    resolved_root = root.resolve()
    resolved_cand = candidate.resolve(strict=False)
    if not resolved_cand.is_relative_to(resolved_root):
        raise ValueError(f"Path escapes confinement root (CWE-22): '{rel_str}'")
    reject_symlinks(resolved_root, resolved_root / raw_rel)
    return resolved_root / raw_rel


def guard_critical_paths(rel_posix: str, *, force: bool) -> None:
    """Block moving critical repository infrastructure paths unless --force is set.

    Args:
        rel_posix: Repository-relative POSIX path string.
        force: Override guard for non-``.git`` protected governance paths.

    Raises:
        ValueError: If ``rel_posix`` targets ``.git`` or a protected path without ``force``.
    """
    norm = rel_posix.strip("/")
    if norm == ".git" or norm.startswith(".git/"):
        raise ValueError("Moving '.git' is strictly forbidden.")
    if force:
        return
    for protected in CRITICAL_REPO_PATHS:
        if norm == protected or norm.startswith(f"{protected}/"):
            raise ValueError(
                f"Critical repository path '{norm}' is protected; pass --force to override."
            )


def extract_session_status(session_dir: Path) -> str:
    """Read session status from plan.md or README.md frontmatter."""
    for candidate in ("plan.md", "README.md"):
        fp = session_dir / candidate
        if fp.is_file() and not fp.is_symlink():
            match = _STATUS_RE.search(fp.read_text(encoding="utf-8", errors="replace"))
            if match:
                return match.group(1).strip().lower()
    return ""


def _iter_clean_files(root_limit: Path, base_dir: Path) -> list[Path]:
    """Enumerate non-excluded files under base_dir while rejecting any nested symlinks."""
    reject_symlinks(root_limit, base_dir)
    collected: list[Path] = []
    for cur_root, dirs, files in os.walk(base_dir, topdown=True, followlinks=False):
        cur_path = Path(cur_root)
        kept_dirs: list[str] = []
        for dname in sorted(dirs):
            if dname in EXCLUDED_NAMES:
                continue
            dpath = cur_path / dname
            if dpath.is_symlink():
                raise ValueError(f"Symlink directory detected (CWE-59): {dpath}")
            kept_dirs.append(dname)
        dirs[:] = kept_dirs

        for fname in sorted(files):
            if fname in EXCLUDED_NAMES or fname == STATE_FILENAME:
                continue
            fpath = cur_path / fname
            if fpath.is_symlink():
                raise ValueError(f"Symlink file detected (CWE-59): {fpath}")
            collected.append(fpath)
    return collected


def _matches_session_query(dir_name: str, query: str) -> bool:
    """Return True when dir_name matches an exact session folder name or 3-digit prefix."""
    q = query.strip()
    if not q:
        return False
    if dir_name == q:
        return True
    if q.isdigit() and dir_name.startswith(f"{int(q):03d}_"):
        return True
    return dir_name.startswith(f"{q}_")


def discover_targets(
    repo_root: Path,
    vault_root: Path,
    *,
    sessions: list[str],
    status_filter: str | None,
    move_all: bool,
    sources: list[str] | None = None,
    dest_folder: str | None = None,
    force: bool = False,
) -> tuple[list[MoveItem], list[str], list[str]]:
    """Discover reasoning sessions and/or arbitrary repository sources to move.

    Args:
        repo_root: Canonical local repository root directory.
        vault_root: Canonical Obsidian SecondBrain vault root directory.
        sessions: Explicit session slugs or 3-digit numeric prefixes.
        status_filter: Optional frontmatter ``status:`` value (e.g. ``completed``).
        move_all: When True, selects every directory inside ``reasoning/``.
        sources: Optional repository-relative files or directories to move.
        dest_folder: Optional vault-relative target subfolder override.
        force: Allow moving protected non-``.git`` repository paths.

    Returns:
        Tuple of ``(file_move_items, selected_session_names, selected_source_rels)``.

    Raises:
        ValueError: On confinement/symlink violations, protected paths, or missing targets.
    """
    project_name = repo_root.name
    if dest_folder is not None:
        resolve_confined(vault_root, dest_folder)

    items: list[MoveItem] = []
    selected_session_names: list[str] = []
    selected_sources: list[str] = []

    if sessions or status_filter or move_all:
        reasoning_dir = resolve_confined(repo_root, "reasoning")
        if not reasoning_dir.is_dir():
            raise ValueError(f"Reasoning directory not found: {reasoning_dir}")
        session_dirs: list[Path] = []
        for entry in sorted(reasoning_dir.iterdir()):
            if entry.name in EXCLUDED_NAMES or entry.name == STATE_FILENAME:
                continue
            if entry.is_symlink():
                raise ValueError(f"Symlink entry detected in reasoning/ (CWE-59): {entry}")
            if entry.is_dir():
                session_dirs.append(entry)

        chosen_dirs: list[Path] = []
        if move_all:
            chosen_dirs = session_dirs
        else:
            for query in sessions:
                matched = [d for d in session_dirs if _matches_session_query(d.name, query)]
                if not matched:
                    raise ValueError(f"Unknown reasoning session selector: '{query}'")
                for d in matched:
                    if d not in chosen_dirs:
                        chosen_dirs.append(d)
            if status_filter:
                wanted = status_filter.strip().lower()
                for d in session_dirs:
                    if extract_session_status(d) == wanted and d not in chosen_dirs:
                        chosen_dirs.append(d)

        reasoning_vault_sub = (
            dest_folder.strip("/")
            if dest_folder
            else f"50-Projects/{project_name}/reasoning"
        )
        dest_root = resolve_confined(vault_root, reasoning_vault_sub)
        for sdir in chosen_dirs:
            selected_session_names.append(sdir.name)
            v_rel_grp = f"{reasoning_vault_sub}/{sdir.name}"
            dest_base = dest_root / sdir.name
            reject_symlinks(vault_root, dest_base)
            for src_file in _iter_clean_files(repo_root, sdir):
                rel = src_file.relative_to(sdir)
                dst_file = dest_base / rel
                reject_symlinks(vault_root, dst_file)
                items.append(
                    MoveItem(
                        source=src_file,
                        destination=dst_file,
                        root_group=sdir,
                        repo_rel_group=f"reasoning/{sdir.name}",
                        vault_rel_group=v_rel_grp,
                        session_id=sdir.name,
                    )
                )

    for raw_src in sources or []:
        src_path = resolve_confined(repo_root, raw_src)
        rel_posix = src_path.relative_to(repo_root).as_posix()
        guard_critical_paths(rel_posix, force=force)
        if not src_path.exists():
            raise ValueError(f"Source path does not exist: '{raw_src}'")
        selected_sources.append(rel_posix)
        notes_sub = (
            dest_folder.strip("/")
            if dest_folder
            else f"50-Projects/{project_name}/notes"
        )
        dest_sub_root = resolve_confined(vault_root, notes_sub)
        if src_path.is_file():
            dst_file = dest_sub_root / src_path.name
            reject_symlinks(vault_root, dst_file)
            items.append(
                MoveItem(
                    source=src_path,
                    destination=dst_file,
                    root_group=src_path,
                    repo_rel_group=rel_posix,
                    vault_rel_group=f"{notes_sub}/{src_path.name}",
                )
            )
        else:
            dest_dir = dest_sub_root / src_path.name
            v_rel_grp = f"{notes_sub}/{src_path.name}"
            for src_file in _iter_clean_files(repo_root, src_path):
                inner_rel = src_file.relative_to(src_path)
                dst_file = dest_dir / inner_rel
                reject_symlinks(vault_root, dst_file)
                items.append(
                    MoveItem(
                        source=src_file,
                        destination=dst_file,
                        root_group=src_path,
                        repo_rel_group=rel_posix,
                        vault_rel_group=v_rel_grp,
                    )
                )

    return items, selected_session_names, selected_sources


def _prune_empty_dirs(target_dir: Path, stop_at: Path) -> None:
    """Remove empty directories bottom-up including excluded noise artifacts."""
    if not target_dir.exists() or target_dir.is_file():
        return
    for cur_root, dirs, files in os.walk(target_dir, topdown=False, followlinks=False):
        cur = Path(cur_root)
        for fname in list(files):
            if fname in EXCLUDED_NAMES:
                (cur / fname).unlink(missing_ok=True)
        for dname in list(dirs):
            if dname in EXCLUDED_NAMES:
                shutil.rmtree(cur / dname, ignore_errors=True)
        if cur != stop_at and cur.is_dir() and not any(cur.iterdir()):
            cur.rmdir()


def copy_verify_delete(
    source: Path,
    destination: Path,
    *,
    overwrite: bool,
    dry_run: bool,
    _hash_fn: Callable[[Path], str] = compute_sha256,
) -> tuple[bool, bool, bool]:
    """Copy source verbatim to destination, verify SHA-256 parity, and delete source.

    Performs zero content modification or secret scrubbing so private SecondBrain
    artifacts retain exact byte-for-byte fidelity.

    Args:
        source: Local file to move.
        destination: Target file path inside the Obsidian vault.
        overwrite: Allow overwriting an existing destination with a differing SHA-256.
        dry_run: Compute plan and idempotency without mutating disk.
        _hash_fn: Injectable SHA-256 function seam for deterministic fault testing.

    Returns:
        Tuple ``(copied, skipped_identical, deleted_local)``.

    Raises:
        FileExistsError: If ``destination`` exists with a differing digest and ``not overwrite``.
        RuntimeError: If post-copy ``SHA-256`` verification disagrees with ``source``.
    """
    src_sha = _hash_fn(source)
    if destination.exists():
        dst_sha = _hash_fn(destination)
        if dst_sha == src_sha:
            if dry_run:
                return False, True, False
            source.unlink()
            return False, True, True
        if not overwrite:
            raise FileExistsError(
                f"Destination collision with differing SHA-256 (pass --overwrite): {destination}"
            )

    if dry_run:
        return False, False, False

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    verified_sha = _hash_fn(destination)
    if verified_sha != src_sha:
        raise RuntimeError(
            f"SHA-256 verification mismatch after copy for '{source}' -> '{destination}'."
        )
    source.unlink()
    return True, False, True


def _atomic_write_text(target: Path, content: str) -> None:
    """Write UTF-8 text atomically using a sibling temporary file and os.replace."""
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(target.parent), prefix=".tmp-", suffix=".swp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.replace(tmp_name, target)
    except Exception:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise


def update_state_file(
    repo_root: Path, moved_sessions: list[tuple[str, str]]
) -> int:
    """Atomically update reasoning/.second-brain-state.json with last_prefix and moved sessions.

    Args:
        repo_root: Canonical local repository root directory.
        moved_sessions: Sequence of ``(session_id, vault_relative_path)`` pairs.

    Returns:
        Monotonic integer ``last_prefix`` persisted in the state file.

    Raises:
        ValueError: If the state file is a symbolic link.
    """
    reasoning_dir = repo_root / "reasoning"
    state_path = reasoning_dir / STATE_FILENAME
    if state_path.is_symlink():
        raise ValueError(f"Symlinked state file forbidden (CWE-59): {state_path}")

    existing_last = 0
    history_map: dict[str, dict[str, str]] = {}
    if state_path.is_file():
        data = json.loads(state_path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            existing_last = int(data.get("last_prefix", 0))
            for entry in data.get("sessions_moved", []):
                if isinstance(entry, dict) and "id" in entry:
                    history_map[str(entry["id"])] = entry

    max_prefix = existing_last
    if reasoning_dir.is_dir():
        for child in reasoning_dir.iterdir():
            if child.is_dir():
                m = _PREFIX_RE.match(child.name)
                if m:
                    max_prefix = max(max_prefix, int(m.group(1)))

    now_utc = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for sess_id, vault_rel in moved_sessions:
        m = _PREFIX_RE.match(sess_id)
        if m:
            max_prefix = max(max_prefix, int(m.group(1)))
        history_map[sess_id] = {
            "id": sess_id,
            "vault_path": vault_rel,
            "moved_at_utc": now_utc,
        }

    if moved_sessions or state_path.is_file():
        payload = {
            "schema_version": 1,
            "last_prefix": max_prefix,
            "sessions_moved": [history_map[k] for k in sorted(history_map)],
        }
        _atomic_write_text(state_path, json.dumps(payload, indent=2) + "\n")
    return max_prefix


def update_hub_moc(
    vault_root: Path,
    project_name: str,
    repo_root: Path,
    vault_rel_groups: list[str],
) -> tuple[str, bool]:
    """Create or update 50-Projects/<ProjectName>.md with archived SecondBrain links.

    Args:
        vault_root: Canonical Obsidian SecondBrain vault root directory.
        project_name: Repository directory name used as project identifier.
        repo_root: Canonical local repository root directory.
        vault_rel_groups: Vault-relative destination paths to register as wikilinks.

    Returns:
        Tuple of ``(hub_vault_rel_path, was_modified)``.
    """
    hub_rel = f"50-Projects/{project_name}.md"
    hub_path = resolve_confined(vault_root, hub_rel)
    today = datetime.date.today().isoformat()

    bullets = [f"- `[[{v_rel}|{Path(v_rel).name}]]`" for v_rel in sorted(set(vault_rel_groups))]
    if not bullets:
        return hub_rel, False

    if not hub_path.is_file():
        content = (
            f"---\n"
            f'type: "project"\n'
            f'project: "[[{project_name}]]"\n'
            f"status: active\n"
            f'repo_path: "{repo_root.as_posix()}"\n'
            f"date: {today}\n"
            f"---\n\n"
            f"# Progetto: {project_name}\n\n"
            f"{MOC_SECTION_HEADER}\n"
            + "\n".join(bullets)
            + "\n"
        )
        _atomic_write_text(hub_path, content)
        return hub_rel, True

    existing = hub_path.read_text(encoding="utf-8")
    updated = existing
    if MOC_SECTION_HEADER in existing:
        before, after = existing.split(MOC_SECTION_HEADER, 1)
        next_sec_match = re.search(r"\n## ", after)
        if next_sec_match:
            sec_body = after[: next_sec_match.start()]
            rest = after[next_sec_match.start() :]
        else:
            sec_body = after
            rest = ""
        existing_lines = [ln.strip() for ln in sec_body.splitlines() if ln.strip().startswith("- ")]
        merged = sorted(set(existing_lines) | set(bullets))
        updated = f"{before}{MOC_SECTION_HEADER}\n" + "\n".join(merged) + "\n" + rest
    else:
        sep = "" if existing.endswith("\n") else "\n"
        updated = f"{existing}{sep}\n{MOC_SECTION_HEADER}\n" + "\n".join(bullets) + "\n"

    if updated != existing:
        _atomic_write_text(hub_path, updated)
        return hub_rel, True
    return hub_rel, False


def git_commit_scoped(cwd: Path, scoped_rels: list[str], message: str) -> bool:
    """Stage and commit scoped relative paths with shell=False when cwd is a Git repo.

    Args:
        cwd: Git working tree root (local repository or Obsidian Vault).
        scoped_rels: Relative pathspecs isolated via ``--`` separator.
        message: Conventional commit summary message.

    Returns:
        True when a commit was created; False if non-Git or no staged diff existed.
    """
    if not scoped_rels or not (cwd / ".git").exists():
        return False
    clean_rels = sorted({r.strip("/") for r in scoped_rels if r.strip("/")})
    if not clean_rels:
        return False
    add_res = subprocess.run(
        ["git", "add", "-A", "--", *clean_rels],
        cwd=str(cwd),
        shell=False,
        check=False,
        capture_output=True,
        text=True,
    )
    if add_res.returncode != 0:
        return False
    diff_res = subprocess.run(
        ["git", "diff", "--cached", "--quiet", "--", *clean_rels],
        cwd=str(cwd),
        shell=False,
        check=False,
        capture_output=True,
        text=True,
    )
    if diff_res.returncode == 0:
        return False
    commit_res = subprocess.run(
        ["git", "commit", "-m", message, "--", *clean_rels],
        cwd=str(cwd),
        shell=False,
        check=False,
        capture_output=True,
        text=True,
    )
    return commit_res.returncode == 0


def _find_first_collision(items: list[MoveItem]) -> Path | None:
    """Return the first destination path whose existing SHA-256 differs from source."""
    for item in items:
        if item.destination.exists() and compute_sha256(item.destination) != compute_sha256(item.source):
            return item.destination
    return None


def build_parser() -> argparse.ArgumentParser:
    """Build CLI argument parser."""
    parser = argparse.ArgumentParser(
        prog="move_reasoning_to_second_brain.py",
        description="Move reasoning sessions or repository notes verbatim into the Obsidian SecondBrain vault.",
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd(), help="Repository root path.")
    parser.add_argument(
        "--vault-path",
        type=str,
        default=os.environ.get("OBSIDIAN_VAULT_PATH", DEFAULT_VAULT_ENV),
        help="Target Obsidian vault root path.",
    )
    parser.add_argument(
        "--session",
        action="append",
        default=[],
        help="Reasoning session directory name or 3-digit prefix (repeatable).",
    )
    parser.add_argument("--status", default=None, help="Filter reasoning sessions by frontmatter status.")
    parser.add_argument("--all", dest="move_all", action="store_true", help="Move all reasoning sessions.")
    parser.add_argument(
        "--source",
        action="append",
        default=[],
        help="Arbitrary repository-relative file or folder to move (repeatable).",
    )
    parser.add_argument(
        "--dest-folder",
        default=None,
        help="Vault-relative destination folder override (e.g. 40-Notes/Archive).",
    )
    parser.add_argument("--force", action="store_true", help="Allow moving protected repository paths.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite differing files in Vault.")
    parser.add_argument("--dry-run", action="store_true", help="Simulate move without modifying files or Git.")
    parser.add_argument("--no-vault-commit", action="store_true", help="Skip Git commit in Obsidian Vault.")
    parser.add_argument("--no-repo-commit", action="store_true", help="Skip Git commit in local repository.")
    parser.add_argument("--json", action="store_true", help="Emit JSON summary to stdout.")
    return parser


def _resolve_existing_root(raw_path: str | Path, label: str) -> Path:
    """Validate that a root directory exists and is not a symlink."""
    cand = Path(raw_path).expanduser()
    if cand.is_symlink():
        raise ValueError(f"Symlink {label} path is forbidden (CWE-59): {cand}")
    resolved = cand.resolve()
    if not resolved.is_dir():
        raise ValueError(f"{label} does not exist: {resolved}")
    return resolved


def main(argv: list[str] | None = None) -> int:
    """CLI entry point returning deterministic exit codes (0, 1, 2)."""
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exc:
        return int(exc.code) if isinstance(exc.code, int) else 2

    if not (args.session or args.status or args.move_all or args.source):
        print(
            "Error: specify at least one selector (--session, --status, --all, or --source).",
            file=sys.stderr,
        )
        return 2

    try:
        repo_root = _resolve_existing_root(args.repo_root, "repository root")
        vault_root = _resolve_existing_root(args.vault_path, "vault path")
    except ValueError as err:
        print(f"Error: {err}", file=sys.stderr)
        return 2

    try:
        items, selected_sessions, selected_sources = discover_targets(
            repo_root,
            vault_root,
            sessions=args.session,
            status_filter=args.status,
            move_all=args.move_all,
            sources=args.source,
            dest_folder=args.dest_folder,
            force=args.force,
        )
    except ValueError as err:
        print(f"Error: {err}", file=sys.stderr)
        return 2

    if not args.overwrite:
        collision = _find_first_collision(items)
        if collision is not None:
            print(f"Error: destination collision on '{collision}' (pass --overwrite).", file=sys.stderr)
            return 1

    copied = skipped = deleted = 0
    touched_groups: set[Path] = set()
    repo_rels: set[str] = set()
    vault_rels: set[str] = set()
    moved_session_pairs: dict[str, str] = {}

    try:
        for item in items:
            c, s, d = copy_verify_delete(
                item.source, item.destination, overwrite=args.overwrite, dry_run=args.dry_run
            )
            copied += int(c)
            skipped += int(s)
            deleted += int(d)
            touched_groups.add(item.root_group)
            repo_rels.add(item.repo_rel_group)
            vault_rels.add(item.vault_rel_group)
            if item.session_id is not None:
                moved_session_pairs[item.session_id] = item.vault_rel_group
    except (FileExistsError, RuntimeError, OSError) as err:
        print(f"Error: {err}", file=sys.stderr)
        return 1

    last_prefix = 0
    hub_updated = False
    git_vault_committed = False
    git_repo_committed = False

    if not args.dry_run:
        for grp in touched_groups:
            if grp.exists() and grp.is_dir():
                stop_dir = (repo_root / "reasoning") if grp.parent == (repo_root / "reasoning") else repo_root
                _prune_empty_dirs(grp, stop_dir)

        if selected_sessions:
            try:
                last_prefix = update_state_file(
                    repo_root, sorted(moved_session_pairs.items())
                )
            except (ValueError, OSError) as err:
                print(f"Error: failed to update state file: {err}", file=sys.stderr)
                return 1
            repo_rels.add(f"reasoning/{STATE_FILENAME}")

        hub_rel, hub_updated = update_hub_moc(
            vault_root, repo_root.name, repo_root, sorted(vault_rels)
        )
        if hub_updated:
            vault_rels.add(hub_rel)

        if not args.no_vault_commit:
            git_vault_committed = git_commit_scoped(
                vault_root,
                sorted(vault_rels),
                f"feat(projects): move {repo_root.name} items to SecondBrain",
            )
        if not args.no_repo_commit:
            git_repo_committed = git_commit_scoped(
                repo_root,
                sorted(repo_rels),
                "chore(reasoning): move sessions and notes to SecondBrain",
            )

    report = MoveReport(
        dry_run=args.dry_run,
        project_name=repo_root.name,
        vault_path=str(vault_root),
        files_planned=len(items),
        files_copied=copied,
        files_skipped_identical=skipped,
        files_deleted_local=deleted,
        sessions_selected=selected_sessions,
        sources_selected=selected_sources,
        last_prefix=last_prefix,
        hub_moc_updated=hub_updated,
        git_vault_committed=git_vault_committed,
        git_repo_committed=git_repo_committed,
    )
    if args.json:
        print(json.dumps(asdict(report), indent=2))
    else:
        mode = "[DRY-RUN] " if args.dry_run else ""
        print(
            f"{mode}Moved {len(selected_sessions)} session(s) and {len(selected_sources)} source(s) "
            f"({copied} copied, {skipped} identical skipped)."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
