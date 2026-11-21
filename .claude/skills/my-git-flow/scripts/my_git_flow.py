#!/usr/bin/env python3
"""CLI entry point for the my-git-flow skill.

Implements cross-platform GitFlow lifecycle automation with prerelease versioning,
plumbing production-branch detection, and finish branch-family guards.
"""

import argparse
import json
import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from my_git_flow_pkg.workflows import WorkflowOrchestrator  # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    """Construct argument parser for the GitFlow CLI."""
    parser = argparse.ArgumentParser(
        prog="my_git_flow.py",
        description="Cross-platform GitFlow lifecycle management engine.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Target repository root directory (default: current working directory).",
    )
    parser.add_argument("--json", action="store_true", help="Format output as JSON.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview version transitions and tags without mutating Git state or files.",
    )
    parser.add_argument(
        "--continue",
        dest="continue_workflow",
        action="store_true",
        help="Resume an interrupted workflow after conflict resolution.",
    )
    parser.add_argument(
        "--abort",
        dest="abort_workflow",
        action="store_true",
        help="Abort an interrupted workflow and clean up checkpoint state.",
    )

    subparsers = parser.add_subparsers(dest="subcommand", help="GitFlow subcommands")
    set_version_help = (
        "Additive version override (never lower than the current/parent version; "
        "preserves NBGV {height}). Distinct from --version, which names the branch slug."
    )

    p_sf = subparsers.add_parser("start-feature", help="Start a new feature branch (+1 -alpha1)")
    p_sf.add_argument("--set-version", dest="set_version", default=None, help=set_version_help)
    p_sf.add_argument("name", help="Feature branch identifier")
    p_sf.add_argument(
        "--bump", choices=["patch", "minor", "major"], default="patch", help="Numeric bump level"
    )
    p_sf.add_argument("--description", default="", help="Feature description")

    p_ff = subparsers.add_parser("finish-feature", help="Finish a feature branch")
    p_ff.add_argument("--set-version", dest="set_version", default=None, help=set_version_help)
    p_ff.add_argument("name", nargs="?", default=None, help="Feature branch identifier")
    p_ff.add_argument(
        "--bump",
        choices=["patch", "minor", "major"],
        default="patch",
        help="Version bump level if realignment is required by Dual-Baseline Gate",
    )
    p_ff.add_argument(
        "--skip-tests-confirm",
        action="store_true",
        help="Explicitly confirm skipping tests if no suite exists",
    )
    p_ff.add_argument("--notes", default="", help="Closure notes")

    p_sr = subparsers.add_parser("start-release", help="Start a release branch (-rc1)")
    p_sr.add_argument("--set-version", dest="set_version", default=None, help=set_version_help)
    p_sr.add_argument("version", nargs="?", default=None, help="Optional explicit release version")
    p_sr.add_argument("--version", dest="version_opt", default=None, help="Explicit release version")
    p_sr.add_argument(
        "--override",
        action="store_true",
        help="Allow explicit version diverging from an advancing develop branch",
    )
    p_sr.add_argument("--description", default="", help="Release description")

    p_fr = subparsers.add_parser("finish-release", help="Finish a release branch")
    p_fr.add_argument("--set-version", dest="set_version", default=None, help=set_version_help)
    p_fr.add_argument("version", nargs="?", default=None, help="Optional release branch version")
    p_fr.add_argument(
        "--skip-tests-confirm",
        action="store_true",
        help="Explicitly confirm skipping tests if no suite exists",
    )
    p_fr.add_argument("--notes", default="", help="Closure notes")

    p_sh = subparsers.add_parser("start-hotfix", help="Start a hotfix branch (+1 -beta1)")
    p_sh.add_argument("--set-version", dest="set_version", default=None, help=set_version_help)
    p_sh.add_argument("version", nargs="?", default=None, help="Optional explicit hotfix version")
    p_sh.add_argument("--version", dest="version_opt", default=None, help="Explicit hotfix version")
    p_sh.add_argument(
        "--bump", choices=["patch", "minor", "major"], default="patch", help="Numeric bump level"
    )
    p_sh.add_argument("--description", default="", help="Hotfix description")

    p_fh = subparsers.add_parser("finish-hotfix", help="Finish a hotfix branch")
    p_fh.add_argument("--set-version", dest="set_version", default=None, help=set_version_help)
    p_fh.add_argument("version", nargs="?", default=None, help="Optional hotfix branch version")
    p_fh.add_argument(
        "--propagate-release",
        nargs="?",
        const="yes",
        choices=["yes", "no"],
        default="no",
        help="Propagate hotfix to active release/* branches",
    )
    p_fh.add_argument(
        "--skip-tests-confirm",
        action="store_true",
        help="Explicitly confirm skipping tests if no suite exists",
    )
    p_fh.add_argument("--notes", default="", help="Closure notes")

    return parser


def main() -> int:
    """CLI execution entry point."""
    parser = build_parser()
    args = parser.parse_args()
    orch = WorkflowOrchestrator()
    repo_root = args.repo_root.resolve()

    if args.abort_workflow:
        exit_code, message = orch.abort_workflow(repo_root)
    elif args.continue_workflow:
        exit_code, message = orch.continue_workflow(repo_root)
    elif args.subcommand == "start-feature":
        exit_code, message = orch.start_feature(
            repo_root, args.name, args.description, args.bump, args.dry_run, args.set_version
        )
    elif args.subcommand == "finish-feature":
        exit_code, message = orch.finish_feature(
            repo_root, args.name, args.bump, args.skip_tests_confirm, args.notes, args.dry_run,
            args.set_version,
        )
    elif args.subcommand == "start-release":
        rel_ver = args.version_opt or args.version
        exit_code, message = orch.start_release(
            repo_root, rel_ver, args.description, args.override, args.dry_run, args.set_version
        )
    elif args.subcommand == "finish-release":
        exit_code, message = orch.finish_release(
            repo_root, args.version, args.skip_tests_confirm, args.notes, args.dry_run, args.set_version
        )
    elif args.subcommand == "start-hotfix":
        hf_ver = args.version_opt or args.version
        exit_code, message = orch.start_hotfix(
            repo_root, hf_ver, args.description, args.bump, args.dry_run, args.set_version
        )
    elif args.subcommand == "finish-hotfix":
        prop = args.propagate_release == "yes"
        exit_code, message = orch.finish_hotfix(
            repo_root, args.version, prop, args.skip_tests_confirm, args.notes, args.dry_run,
            args.set_version,
        )
    else:
        parser.print_help()
        return 2

    if args.json:
        print(json.dumps({"exit_code": exit_code, "message": message}))
    else:
        stream = sys.stdout if exit_code == 0 else sys.stderr
        print(message, file=stream)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
