# Workflow 02: Silent Codebase Exploration (`tokensave`)

## Purpose
Conduct a silent, non-invasive exploration of the repository using `tokensave` before asking any questions to the activator, pre-filling evident facts and recording only the target references to investigate in `design.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-semantic-graph-probe.md` | Query `tokensave_status`, `tokensave_context`, `tokensave_files`, and `tokensave_search`. | Always |
| **02** | `steps/02-record-minimal-references.md` | Log only minimal reference pointers to investigate in `design.md` and check `task.md`. | Always |

## Exit Criteria & Memory Compaction
- The Workflow 02 Orchestrator SHALL populate `design.md` with concise reference pointers under `## Riferimenti Codebase (tokensave) & Fonti Esterne`.
- Tasks `T02-01`..`T02-03` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/03-prompt-disambiguation/`.
