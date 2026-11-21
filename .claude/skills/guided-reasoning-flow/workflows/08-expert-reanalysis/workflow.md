# Workflow 08: Technical Re-Analysis & Cross-Topic Sign-Off (Per TOPIC + Global)

## Purpose
Submit the activator's review choices (`brief/topic-[id]-human-review.md` and `brief/tradeoffs-pro-cons.md`) back to the enrolled domain experts and `cyber-security-expert` for technical re-analysis and regression verification on `TOPIC-NN`, loop to the next TOPIC if any remain, and consolidate the final global sign-off in `brief/consensus-matrix.md`.

## Progressive Disclosure Step Index
Load and execute one step file at a time under `Single-Reference Lock`:

| Step | File | Description | Condition |
|---|---|---|---|
| **01** | `steps/01-topic-expert-reanalysis.md` | Re-analyze `TOPIC-NN` post-review choices; loop to Workflow 04 if more TOPICs remain. | Always (Per TOPIC) |
| **02** | `steps/02-global-cross-topic-signoff.md` | Verify cross-topic consistency across all `TOPIC-01..NN` & finalize `brief/consensus-matrix.md`. | After last TOPIC |

## Exit Criteria & Memory Compaction
- The Workflow 08 Orchestrator SHALL record post-review verdicts for each `TOPIC-NN` in `brief/topic-[id]-*.md` and check `TOPIC-[id]-WF08` `[x]` in `task.md`.
- After all topics: `brief/consensus-matrix.md`, `T08-01`, and `T08-02` checked `[x]` in `task.md`.
- Execute context compaction (`/compact`) after each TOPIC cycle and before transitioning to `workflows/09-final-validation-persistence/`.
