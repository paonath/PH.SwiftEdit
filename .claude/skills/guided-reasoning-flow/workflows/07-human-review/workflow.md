# Workflow 07: Interactive Human / Activator Review (Per TOPIC)

## Purpose
Present the `TOPIC-NN` consensus and the pre-computed `Systematic Pro/Con & Trade-Off Analysis` (Workflow 06) to the human/activator in `qa` mode, validate choices and mitigations, and record the review in `brief/topic-[id]-human-review.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-conduct-topic-review-qa.md` | Present `TOPIC-NN` consensus & Pro/Con trade-offs via `AskUserQuestion` (1 Q/turn). | Always (Per TOPIC) |
| **02** | `steps/02-record-review-and-route.md` | Log review in `brief/topic-[id]-human-review.md` & hand off to Workflow 08. | Always (Per TOPIC) |

## Exit Criteria & Memory Compaction
- The Workflow 07 Orchestrator SHALL update `brief/topic-[id]-human-review.md` and the `Review Verdict` column of `brief/tradeoffs-pro-cons.md`.
- Task `TOPIC-[id]-WF07` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) and transition to `workflows/08-expert-reanalysis/` for the active `TOPIC-NN`.
