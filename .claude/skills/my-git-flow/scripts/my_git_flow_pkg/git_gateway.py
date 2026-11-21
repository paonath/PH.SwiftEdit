"""Git CLI gateway providing plumbing-verified repository operations.

Executes hermetic subprocess commands (shell=False) with argument-injection
guards (-- separators, git check-ref-format) and plumbing production branch detection.
"""

import re
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple

CONFLICT_MARKERS = (b"<<<<<<<", b"=======", b">>>>>>>")
_ANSI_ESCAPE_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")


def sanitize_terminal_text(text: str) -> str:
    """Strip ANSI CSI escape sequences and unsafe control characters from diagnostic text."""
    stripped = _ANSI_ESCAPE_RE.sub("", text or "")
    return "".join(
        ch for ch in stripped if ch in ("\n", "\t") or (32 <= ord(ch) < 127) or ord(ch) > 127
    )


class GitGateway:
    """Wrapper around Git CLI executing hermetic plumbing and porcelain operations."""

    def run_git(
        self, repo_root: Path, args: List[str], check: bool = False
    ) -> subprocess.CompletedProcess:
        """Execute a git command with shell=False inside repo_root."""
        return subprocess.run(
            ["git"] + args, cwd=str(repo_root), capture_output=True, text=True, check=check, shell=False
        )

    def _run_ok_out(self, repo_root: Path, args: List[str]) -> Tuple[bool, str]:
        """Run git command and return (succeeded, stderr_or_stdout)."""
        res = self.run_git(repo_root, args)
        return res.returncode == 0, res.stderr or res.stdout

    def validate_ref_name(self, repo_root: Path, ref: str) -> None:
        """Reject leading-dash flags, control characters, traversal, and invalid Git ref syntax."""
        if not ref or ref.startswith("-") or ".." in ref or any(c in ref for c in ("\n", "\r", "\x00")):
            raise ValueError(f"Unsafe or malformed Git reference: '{sanitize_terminal_text(ref)}'")
        if self.run_git(repo_root, ["check-ref-format", "--allow-onelevel", ref]).returncode != 0:
            raise ValueError(f"Invalid Git ref format: '{sanitize_terminal_text(ref)}'")

    def ref_exists(self, repo_root: Path, full_ref: str) -> bool:
        """Verify an exact fully-qualified Git reference (e.g. refs/heads/main) via plumbing."""
        if not full_ref or full_ref.startswith("-"):
            return False
        return self.run_git(repo_root, ["show-ref", "--verify", "--quiet", "--", full_ref]).returncode == 0

    def tag_exists(self, repo_root: Path, tag_name: str) -> bool:
        """Return True if refs/tags/<tag_name> exists."""
        return self.ref_exists(repo_root, f"refs/tags/{tag_name}")

    def detect_production_branch(self, repo_root: Path) -> str:
        """Resolve 'main' or 'master' strictly via plumbing refs, failing closed on ambiguity or absence.

        Queries only refs/heads/{main,master} and refs/remotes/origin/{main,master} so
        forged tags or foreign remotes cannot spoof the production branch.
        """
        has_main = self.ref_exists(repo_root, "refs/heads/main") or self.ref_exists(
            repo_root, "refs/remotes/origin/main"
        )
        has_master = self.ref_exists(repo_root, "refs/heads/master") or self.ref_exists(
            repo_root, "refs/remotes/origin/master"
        )
        if has_main and has_master:
            raise ValueError("Ambiguous production branches detected: both 'main' and 'master' exist.")
        if not has_main and not has_master:
            raise ValueError("No production branch ('main' or 'master') found in repository.")
        return "main" if has_main else "master"

    def list_local_branches(self, repo_root: Path, prefix: str = "") -> List[str]:
        """List local branch short names via git for-each-ref plumbing."""
        if prefix and (prefix.startswith("-") or ".." in prefix):
            raise ValueError(f"Invalid branch prefix: '{sanitize_terminal_text(prefix)}'")
        target = f"refs/heads/{prefix.rstrip('/')}" if prefix else "refs/heads"
        res = self.run_git(repo_root, ["for-each-ref", "--format=%(refname:short)", "--", target])
        if res.returncode != 0:
            return []
        branches = [line.strip() for line in res.stdout.splitlines() if line.strip()]
        return [b for b in branches if b.startswith(prefix)] if prefix else branches

    def status_porcelain(self, repo_root: Path) -> str:
        """Retrieve porcelain v1 status of the working tree."""
        return self.run_git(repo_root, ["status", "--porcelain=v1"]).stdout.strip()

    def is_clean_working_tree(self, repo_root: Path) -> bool:
        """Return True when the working tree has zero modified or untracked entries."""
        return len(self.status_porcelain(repo_root)) == 0

    def is_detached_head(self, repo_root: Path) -> bool:
        """Return True if HEAD is detached rather than symbolic."""
        return self.run_git(repo_root, ["symbolic-ref", "-q", "HEAD"]).returncode != 0

    def current_branch(self, repo_root: Path) -> str:
        """Return the currently checked out short branch name."""
        return self.run_git(repo_root, ["branch", "--show-current"]).stdout.strip()

    def has_remote_origin(self, repo_root: Path) -> bool:
        """Return True when a remote named 'origin' is configured."""
        return "origin" in self.run_git(repo_root, ["remote"]).stdout.split()

    def get_head_sha(self, repo_root: Path) -> str:
        """Return the full commit SHA of HEAD."""
        return self.run_git(repo_root, ["rev-parse", "HEAD"], check=True).stdout.strip()

    def get_write_tree_sha(self, repo_root: Path) -> str:
        """Return the current index tree SHA via git write-tree."""
        return self.run_git(repo_root, ["write-tree"], check=True).stdout.strip()

    def is_ancestor(self, repo_root: Path, ancestor_sha: str, descendant_ref: str = "HEAD") -> bool:
        """Return True when ancestor_sha is in the commit ancestry of descendant_ref."""
        self.validate_ref_name(repo_root, ancestor_sha)
        self.validate_ref_name(repo_root, descendant_ref)
        return self.run_git(repo_root, ["merge-base", "--is-ancestor", ancestor_sha, descendant_ref]).returncode == 0

    def merge_base(self, repo_root: Path, ref_a: str, ref_b: str) -> Optional[str]:
        """Return the best common ancestor SHA of two refs, or None when none exists."""
        self.validate_ref_name(repo_root, ref_a)
        self.validate_ref_name(repo_root, ref_b)
        res = self.run_git(repo_root, ["merge-base", "--", ref_a, ref_b])
        sha = res.stdout.strip()
        return sha if res.returncode == 0 and sha else None

    def cat_file_at_commit(self, repo_root: Path, commit_sha: str, rel_path: str) -> Optional[str]:
        """Read a repository-relative file at commit_sha without touching the working tree."""
        self.validate_ref_name(repo_root, commit_sha)
        res = self.run_git(repo_root, ["show", f"{commit_sha}:{Path(rel_path).as_posix()}"])
        return res.stdout if res.returncode == 0 else None

    def checkout(
        self, repo_root: Path, branch: str, create: bool = False, base: Optional[str] = None
    ) -> Tuple[bool, str]:
        """Switch to branch or create it from optional base after validating ref safety."""
        self.validate_ref_name(repo_root, branch)
        args = ["checkout", "-b", branch] if create else ["checkout", branch]
        if create and base:
            self.validate_ref_name(repo_root, base)
            args.append(base)
        return self._run_ok_out(repo_root, args + ["--"])

    def pull_ff_only(self, repo_root: Path, remote: str, branch: str) -> Tuple[bool, str]:
        """Pull remote branch strictly fast-forward."""
        self.validate_ref_name(repo_root, remote)
        self.validate_ref_name(repo_root, branch)
        return self._run_ok_out(repo_root, ["pull", "--ff-only", "--", remote, branch])

    def merge(
        self, repo_root: Path, source: str, no_ff: bool = True, message: Optional[str] = None
    ) -> Tuple[bool, str]:
        """Merge source branch into current HEAD."""
        self.validate_ref_name(repo_root, source)
        args = ["merge"] + (["--no-ff"] if no_ff else []) + (["-m", message] if message else []) + ["--", source]
        return self._run_ok_out(repo_root, args)

    def commit(self, repo_root: Path, message: str, allow_empty: bool = False) -> Tuple[bool, str]:
        """Create a commit from staged index entries."""
        return self._run_ok_out(repo_root, ["commit", "-m", message] + (["--allow-empty"] if allow_empty else []))

    def add(self, repo_root: Path, paths: Optional[List[str]] = None) -> Tuple[bool, str]:
        """Stage specified paths (or entire workspace when omitted) using -- separator."""
        return self._run_ok_out(repo_root, ["add", "--"] + (paths if paths else ["."]))

    def create_tag(
        self, repo_root: Path, tag_name: str, message: Optional[str] = None, target: Optional[str] = None
    ) -> Tuple[bool, str]:
        """Create an annotated or lightweight tag on HEAD or target after validating refs."""
        self.validate_ref_name(repo_root, tag_name)
        if target:
            self.validate_ref_name(repo_root, target)
        args = ["tag", "-a", tag_name, "-m", message] if message else ["tag", "--", tag_name]
        if target:
            args.append(target)
        return self._run_ok_out(repo_root, args)

    def push(self, repo_root: Path, remote: str, branch: str, tags: bool = False) -> Tuple[bool, str]:
        """Push branch and optional tags to remote."""
        self.validate_ref_name(repo_root, remote)
        self.validate_ref_name(repo_root, branch)
        return self._run_ok_out(repo_root, ["push"] + (["--tags"] if tags else []) + ["--", remote, branch])

    def delete_branch(self, repo_root: Path, branch: str, force: bool = False) -> Tuple[bool, str]:
        """Delete local branch safely."""
        self.validate_ref_name(repo_root, branch)
        return self._run_ok_out(repo_root, ["branch", "-D" if force else "-d", "--", branch])

    def preflight(self, repo_root: Path) -> Optional[Tuple[int, str]]:
        """Verify clean working tree and attached HEAD (exit 20 on violation)."""
        if not self.is_clean_working_tree(repo_root):
            return 20, "Working tree is dirty. Run git stash push -u or git commit first."
        if self.is_detached_head(repo_root):
            return 20, "Detached HEAD detected. Checkout a valid branch first."
        return None

    def ensure_develop(self, repo_root: Path) -> Tuple[bool, str]:
        """Check out develop via plumbing ref lookup, creating it from HEAD only if absent."""
        if self.ref_exists(repo_root, "refs/heads/develop") or self.ref_exists(repo_root, "refs/remotes/origin/develop"):
            return self.checkout(repo_root, "develop")
        return self.checkout(repo_root, "develop", create=True)

    def commit_if_changes(self, repo_root: Path, message: str) -> None:
        """Stage and commit only when working tree has pending modifications."""
        self.add(repo_root)
        if not self.is_clean_working_tree(repo_root):
            self.commit(repo_root, message)

    def pull_if_remote(self, repo_root: Path, branch: str) -> Tuple[bool, str]:
        """Fast-forward pull from origin when origin and remote branch exist."""
        if self.has_remote_origin(repo_root) and self.ref_exists(repo_root, f"refs/remotes/origin/{branch}"):
            return self.pull_ff_only(repo_root, "origin", branch)
        return True, ""

    def push_if_remote(self, repo_root: Path, branch: str, tags: bool = False) -> Tuple[bool, str]:
        """Push branch (and tags) when origin is configured."""
        if self.has_remote_origin(repo_root):
            return self.push(repo_root, "origin", branch, tags=tags)
        return True, ""

    def safe_merge(self, repo_root: Path, branch: str, message: str) -> Tuple[bool, str]:
        """Perform non-fast-forward merge, treating 'Already up to date' as success."""
        ok, out = self.merge(repo_root, branch, no_ff=True, message=message)
        return (True, "") if ok or "Already up to date" in out else (False, out)

    def merge_resolving_manifest(self, repo_root: Path, branch: str, message: str, manifest_rel: str) -> Tuple[bool, str]:
        """Merge branch, auto-resolving ours when the version manifest is the sole conflict."""
        ok, out = self.safe_merge(repo_root, branch, message)
        if ok:
            return True, ""
        unmerged = [u.strip() for u in self.run_git(repo_root, ["diff", "--name-only", "--diff-filter=U"]).stdout.splitlines() if u.strip()]
        if unmerged and set(unmerged) <= {manifest_rel}:
            self.run_git(repo_root, ["checkout", "--ours", "--", manifest_rel])
            self.run_git(repo_root, ["add", "--", manifest_rel])
            return self._run_ok_out(repo_root, ["commit", "-m", message])
        return False, out

    def has_unmerged_entries(self, repo_root: Path) -> bool:
        """Return True if the Git index still contains unmerged conflict stages."""
        res = self.run_git(repo_root, ["diff", "--name-only", "--diff-filter=U"])
        return bool(res.stdout.strip())

    def scan_for_conflict_markers(self, repo_root: Path) -> List[str]:
        """Scan tracked workspace files for unresolved <<<<<<< / ======= / >>>>>>> markers."""
        ls_res = self.run_git(repo_root, ["ls-files"])
        if ls_res.returncode != 0:
            return []
        conflicted: List[str] = []
        for rel_file in ls_res.stdout.splitlines():
            fpath = repo_root / rel_file
            if fpath.is_file() and not fpath.is_symlink():
                try:
                    blob = fpath.read_bytes()
                    if any(marker in blob for marker in CONFLICT_MARKERS):
                        conflicted.append(rel_file)
                except OSError:
                    continue
        return conflicted
