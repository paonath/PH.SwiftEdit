# Workflow 12: Major Version Consolidation & Delta Purge

## Purpose
Consolidate an iterative reasoning session from minor revisions (e.g. 1.1, 1.3, 2.4) into a clean new Major version (e.g. 2.0, 3.0), execute fail-closed snapshotting to `superseded/<version>/` with recursive `.md.old` renaming, purge all historical delta meta-narrative, and rewrite live documents into cohesive single-truth specifications.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-archive-and-snapshot.md` | Invoke `scaffold_reasoning.py --session-dir <dir> --new-major` for snapshotting and `.md.old` rename. | Always |
| **02** | `steps/02-analyze-and-purge.md` | Analyze prior documents starting from `README.md` and `README.ai.md` and extract consolidated invariants. | Always |
| **03** | `steps/03-rewrite-root-and-brief.md` | Rewrite all live root files and `brief/` files reflecting solely the new Major version. | Always |
| **04** | `steps/04-verify-single-truth.md` | Verification pass ensuring zero historical delta phrasing, inline `[[...]]`, or superseded markers remain. | Always |

## Exit Criteria & Memory Compaction
- The Workflow 12 Orchestrator SHALL verify the fail-closed snapshot in `superseded/<prior_version>/` with all `.md.old` files and confirm single-truth 2.0+ live documents with zero delta phrasing or `.old` references.
- Execute context compaction (`/compact`) and complete session or transition to `/myspec-tdd-spec-reasoning`.
