# Workflow 06: Systematic Pro/Con & Trade-Off Analysis (Per TOPIC)

## Purpose
Execute a systematic Pro/Con and trade-off analysis for the active `TOPIC-NN` *before* the interactive review (Workflow 07), mapping benefits, KISS/SOLID/Security risks, and concrete expert mitigations in `brief/tradeoffs-pro-cons.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-evaluate-topic-tradeoffs.md` | Map Decisions, Pros, and Cons/Risks (KISS, SOLID, Security) for `TOPIC-NN`. | Always (Per TOPIC) |
| **02** | `steps/02-design-expert-mitigations.md` | Pair every risk with a KISS-compliant mitigation in `brief/tradeoffs-pro-cons.md`. | Always (Per TOPIC) |

## Exit Criteria & Memory Compaction
- The Workflow 06 Orchestrator SHALL verify that `brief/tradeoffs-pro-cons.md` contains complete Pro/Con and mitigation rows for `TOPIC-NN`.
- Task `TOPIC-[id]-WF06` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/07-human-review/` for the active `TOPIC-NN`.
