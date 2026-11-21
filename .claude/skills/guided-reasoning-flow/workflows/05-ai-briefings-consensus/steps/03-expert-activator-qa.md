# Step 03: Domain Expert Questions to Activator (Max 3 / Expert)

## Actions
1. Collect any high-value questions raised by the enrolled experts for the active `TOPIC-NN` (maximum 3 questions per expert; filter out any trivial or already-evident questions).
2. Check activator type (`plan.md` -> `activator_type`):
   - **Human Activator**: Ask 1 question at a time via `AskUserQuestion` (`qa` skill rules: concrete options, `(Recommended)` prefix, skip option).
   - **AI Agent Activator**: Query the calling agent in English `GIVEN-WHEN-THEN` format, or escalate strategic business trade-offs to the human via `AskUserQuestion` (Hybrid Mode).
3. Record every question, activator answer, and derived `GIVEN-WHEN-THEN` invariant in `brief/topic-[id]-expert-activator-qa.md` and feed the answers back to the expert brief.
