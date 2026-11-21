# Rules: Workflow 07 — Interactive Human / Activator Review

1. **Per-TOPIC Execution & Pro/Con Validation**:
   - The Guided Reasoning Orchestrator SHALL run Workflow 07 on every `TOPIC-NN` to validate the `Systematic Pro/Con & Trade-Off Analysis` produced in Workflow 06.
2. **Strict `qa` Mode (1 Question / Turn)**:
   - The Guided Reasoning Orchestrator SHALL present review choices one question per turn via `AskUserQuestion` in the human interaction language with `(Recommended)` on the consensus option and an escape hatch.
3. **Centralize Review Record in `brief/`**:
   - The Guided Reasoning Orchestrator SHALL save all review questions, selected options, and overrides in English inside `brief/topic-[id]-human-review.md` without creating root-level `qa-human-review.md` files.
4. **Mandatory Transition to Workflow 08**:
   - WHEN Workflow 07 completes for `TOPIC-NN`, the Guided Reasoning Orchestrator SHALL transition to Workflow 08 (`expert-reanalysis`) before advancing to the next topic.
