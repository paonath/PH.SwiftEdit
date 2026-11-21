# Workflow 01: Operational Mode Selection & Automated Scaffolding

## Purpose
Assess whether the trigger prompt initiates a brand-new reasoning session (Mode A) or reworks an existing session (Mode B), invoke `scripts/scaffold_reasoning.py` to generate the spec-oriented workspace (`plan.md`, `proposal.md`, `design.md`, `task.md`, `brief/`, `attachments/`), and perform preventive backup plus delta analysis in rework mode.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-mode-detection.md` | Detect Mode A (New) vs Mode B (Rework), determine slug & external attachments. | Always |
| **02** | `steps/02-run-scaffolder.md` | Execute `scripts/scaffold_reasoning.py` directly to scaffold files & copy attachments. | Always |
| **03** | `steps/03-rework-delta-analysis.md` | Categorize `[[...]]` annotations & delta changes; mandate security regression check. | Mode B Only |

## Exit Criteria & Memory Compaction
- The Workflow 01 Orchestrator SHALL confirm that `plan.md`, `proposal.md` (with verbatim raw prompt), `design.md`, `task.md`, `brief/`, and `attachments/INDEX.md` exist.
- Tasks `T01-01`..`T01-03` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/02-codebase-exploration/`.
