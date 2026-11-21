"""Cross-platform build and test execution gate.

Runs only the stacks that own concrete build/test targets (bounded repository scan),
resolves tools on a CWD-stripped PATH (CWE-426), and never uses a shell (CWE-78).
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

MAX_SCAN_DEPTH = 4
_PRUNED_DIRS = frozenset({"bin", "obj", "node_modules", "dist", "venv", "__pycache__"})
_NPM_PLACEHOLDER = "no test specified"
_PY_PATTERNS = ("test_*.py", "*_test.py")


def _iter_repo_files(repo_root: Path, max_depth: int = MAX_SCAN_DEPTH) -> List[Path]:
    """Return files under repo_root up to max_depth, pruning dot-directories and build output.

    Dot-directories (``.git``, ``.agents``, ``.claude``, ``.tmp``, ...) are pruned so mirrored
    or tooling folders never create false-positive stacks; symlinked directories are skipped.
    """
    found: List[Path] = []
    root_depth = len(repo_root.parts)
    for current, dirs, files in os.walk(repo_root, followlinks=False):
        depth = len(Path(current).parts) - root_depth
        dirs[:] = sorted(
            d for d in dirs
            if not d.startswith(".") and d not in _PRUNED_DIRS and not Path(current, d).is_symlink()
        )
        if depth >= max_depth:
            dirs[:] = []
        found.extend(Path(current, f) for f in sorted(files))
    return found


def _rel(repo_root: Path, path: Path) -> str:
    """Return a POSIX path of path relative to repo_root ('.' for the root itself)."""
    rel = path.relative_to(repo_root).as_posix()
    return rel if rel else "."


class BuildTestGate:
    """Manages pre-closure build and test suite execution across technology stacks."""

    def sanitize_path(self, raw_path: str, repo_root: Path) -> str:
        """Strip current working directory and relative path entries from PATH."""
        resolved_root = str(repo_root.resolve())
        sanitized = []
        for p in raw_path.split(os.pathsep):
            p_strip = p.strip()
            if not p_strip or p_strip == ".":
                continue
            try:
                if str(Path(p_strip).resolve()) == resolved_root:
                    continue
            except Exception:
                pass
            sanitized.append(p_strip)
        return os.pathsep.join(sanitized)

    def resolve_tool(self, tool_name: str, repo_root: Path) -> Optional[str]:
        """Locate tool executable on the sanitized system PATH."""
        clean_path = self.sanitize_path(os.environ.get("PATH", ""), repo_root)
        return shutil.which(tool_name, path=clean_path)

    def _node_packages(self, repo_root: Path) -> List[Tuple[Path, bool, bool]]:
        """Return (dir, has_build, has_real_test) for the root package.json or immediate children."""
        candidates = [repo_root / "package.json"]
        if not candidates[0].is_file():
            candidates = [
                d / "package.json" for d in sorted(repo_root.iterdir())
                if d.is_dir() and not d.name.startswith(".") and d.name not in _PRUNED_DIRS and not d.is_symlink()
            ]
        packages: List[Tuple[Path, bool, bool]] = []
        for pkg in candidates:
            if not pkg.is_file() or pkg.is_symlink():
                continue
            try:
                scripts = json.loads(pkg.read_text(encoding="utf-8")).get("scripts") or {}
            except (OSError, ValueError, AttributeError):
                continue
            has_build = bool(str(scripts.get("build", "")).strip())
            test_cmd = str(scripts.get("test", "")).strip()
            has_test = bool(test_cmd) and _NPM_PLACEHOLDER not in test_cmd
            if has_build or has_test:
                packages.append((pkg.parent, has_build, has_test))
        return packages

    def _dotnet_targets(self, repo_root: Path, files: List[Path]) -> Tuple[List[str], Optional[str]]:
        """Resolve explicit .NET targets: one root solution, else every .csproj; error on ambiguity."""
        root_slns = sorted(
            f.name for f in files if f.parent == repo_root and f.suffix.lower() in (".sln", ".slnx")
        )
        if len(root_slns) > 1:
            return [], f"Ambiguous .NET solutions at repository root: {', '.join(root_slns)}."
        if root_slns:
            return root_slns, None
        return sorted(_rel(repo_root, f) for f in files if f.suffix.lower() == ".csproj"), None

    def _python_targets(self, repo_root: Path, files: List[Path]) -> List[Tuple[str, str]]:
        """Return sorted (relative_dir, pattern) pairs for directories holding Python test files."""
        pairs = set()
        for f in files:
            for pattern in _PY_PATTERNS:
                if f.match(pattern):
                    pairs.add((_rel(repo_root, f.parent), pattern))
        return sorted(pairs)

    def _bats_dirs(self, repo_root: Path, files: List[Path]) -> List[str]:
        """Return sorted relative directories containing *.bats files."""
        return sorted({_rel(repo_root, f.parent) for f in files if f.suffix == ".bats"})

    def detect_test_suites(self, repo_root: Path) -> Dict[str, bool]:
        """Detect which stacks own concrete build/test targets.

        ``Directory.Build.props`` alone never activates .NET; a ``tests/`` folder alone never
        activates Python; a ``package.json`` without a build or real test script never activates Node.
        """
        files = _iter_repo_files(repo_root)
        has_dotnet = any(f.suffix.lower() in (".sln", ".slnx", ".csproj") for f in files)
        has_shell = bool(self._bats_dirs(repo_root, files)) and self.resolve_tool("bats", repo_root) is not None
        return {
            "dotnet": has_dotnet,
            "node": bool(self._node_packages(repo_root)),
            "python": bool(self._python_targets(repo_root, files)),
            "shell": has_shell,
        }

    def _run(self, cmd: List[str], cwd: Path, env: Dict[str, str]) -> subprocess.CompletedProcess:
        """Execute cmd with shell=False capturing output."""
        return subprocess.run(cmd, cwd=str(cwd), env=env, shell=False, capture_output=True, text=True)

    def _run_dotnet(self, repo_root: Path, targets: List[str], env: Dict[str, str]) -> Optional[str]:
        """Build then test every explicit .NET target; return an error message or None."""
        dotnet = self.resolve_tool("dotnet", repo_root)
        if not dotnet:
            return "dotnet CLI not found on sanitized PATH."
        for target in targets:
            res = self._run([dotnet, "build", target, "/nr:false"], repo_root, env)
            if res.returncode != 0:
                return f"dotnet build {target} failed (exit {res.returncode}):\n{res.stderr or res.stdout}"
        for target in targets:
            res = self._run([dotnet, "test", target, "--no-build"], repo_root, env)
            if res.returncode != 0:
                return f"dotnet test {target} failed (exit {res.returncode}):\n{res.stderr or res.stdout}"
        return None

    def _run_node(self, repo_root: Path, env: Dict[str, str]) -> Optional[str]:
        """Run the defined npm build/test scripts of every package; return an error or None."""
        npm = self.resolve_tool("npm", repo_root)
        if not npm:
            return "npm CLI not found on sanitized PATH."
        for pkg_dir, has_build, has_test in self._node_packages(repo_root):
            steps = ([("run build", [npm, "run", "build"])] if has_build else []) + (
                [("test", [npm, "test"])] if has_test else []
            )
            for label, cmd in steps:
                res = self._run(cmd, pkg_dir, env)
                if res.returncode != 0:
                    return f"npm {label} failed in {_rel(repo_root, pkg_dir)} (exit {res.returncode})"
        return None

    def _run_python(self, repo_root: Path, targets: List[Tuple[str, str]], env: Dict[str, str]) -> Optional[str]:
        """Run unittest discovery per test directory; exit 5 (no tests collected) is tolerated."""
        for rel, pattern in targets:
            cmd = [sys.executable, "-m", "unittest", "discover", "-s", rel, "-p", pattern]
            res = self._run(cmd, repo_root, env)
            if res.returncode not in (0, 5):
                return f"Python tests failed in {rel} (exit {res.returncode}):\n{res.stderr or res.stdout}"
        return None

    def _run_shell(self, repo_root: Path, dirs: List[str], env: Dict[str, str]) -> Optional[str]:
        """Run bats per directory containing *.bats files."""
        bats = self.resolve_tool("bats", repo_root)
        if not bats:
            return "bats CLI not found on sanitized PATH."
        for rel in dirs:
            res = self._run([bats, rel], repo_root, env)
            if res.returncode != 0:
                return f"bats failed in {rel} (exit {res.returncode}):\n{res.stderr or res.stdout}"
        return None

    def run_gate(self, repo_root: Path, skip_tests_confirm: bool = False) -> Tuple[bool, str]:
        """Execute every concrete build/test suite, failing closed on errors or ambiguity."""
        files = _iter_repo_files(repo_root)
        suites = self.detect_test_suites(repo_root)
        if not any(suites.values()):
            if skip_tests_confirm:
                return True, "No test suites detected; skipped by explicit confirmation."
            return False, "No build or test suite detected. Pass --skip-tests-confirm to bypass."

        dotnet_targets: List[str] = []
        if suites["dotnet"]:
            dotnet_targets, err = self._dotnet_targets(repo_root, files)
            if err:
                return False, err

        env = dict(os.environ)
        env["PATH"] = self.sanitize_path(env.get("PATH", ""), repo_root)
        env["MSBUILDDISABLENODEREUSE"] = "1"
        env["DOTNET_CLI_DO_NOT_USE_MSBUILD_SERVER"] = "1"
        env["CI"] = "true"

        runners = (
            (suites["dotnet"], lambda: self._run_dotnet(repo_root, dotnet_targets, env)),
            (suites["node"], lambda: self._run_node(repo_root, env)),
            (suites["python"], lambda: self._run_python(repo_root, self._python_targets(repo_root, files), env)),
            (suites["shell"], lambda: self._run_shell(repo_root, self._bats_dirs(repo_root, files), env)),
        )
        for active, runner in runners:
            if active and (failure := runner()):
                return False, failure
        return True, "All build and test suites passed successfully."
