# Workflow 11: Session Audit, Conclusion & Optional `myspec-*` Handoff

## Purpose
Audit 100% completion of the reasoning session against the validation checklist, output a concise summary with clickable links to `README.md` and `README.ai.md`, and offer an optional handoff to `myspec-tdd-spec-reasoning` for planning while strictly forbidding direct source code execution.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-final-session-audit.md` | Verify all session files, `task.md` checkboxes, and write-isolation boundaries. | Always |
| **02** | `steps/02-summary-and-myspec-handoff.md` | Output summary links & present `AskUserQuestion` handoff to `myspec-tdd-spec-reasoning`. | Always |

## Exit Criteria & Memory Compaction
- The Workflow 11 Orchestrator SHALL verify that all checkboxes in `task.md` (`T01-01`..`T11-02` and all `TOPIC-NN` sub-tasks) are `[x]` and confirm the handoff choice with the human user.
- Execute final context compaction (`/compact`) and close the session.
