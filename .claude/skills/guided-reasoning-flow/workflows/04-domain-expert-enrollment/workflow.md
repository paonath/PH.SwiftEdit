# Workflow 04: Domain Expert Enrollment & Distributed Online Research (Per TOPIC)

## Purpose
For the active `TOPIC-NN`, scan `specs/agents/*.agent.md` and `openspec/agents/*.agent.md` (dual-directory discovery with active spec_root precedence) for cache-recall matches, enroll stack/domain specialists and `cyber-security-expert`, execute distributed online research (`search_web`) with 2-source cross-validation, and persist web research documents in `attachments/` + `attachments/INDEX.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-scan-and-match-experts.md` | Match `specs/agents/` and `openspec/agents/`, enroll stack/domain experts + `cyber-security-expert` for `TOPIC-NN`. | Always (Per TOPIC) |
| **02** | `steps/02-distributed-web-research.md` | 2-source validated web research; save results in `attachments/` and update `attachments/INDEX.md`. | When external research needed |

## Exit Criteria & Memory Compaction
- The Workflow 04 Orchestrator SHALL record active `TOPIC-NN` experts in `plan.md` and `design.md`.
- Any web research saved in `attachments/web-research-topic-[id].md` and indexed in `attachments/INDEX.md`.
- Task `TOPIC-[id]-WF04` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/05-ai-briefings-consensus/` for the active `TOPIC-NN`.
