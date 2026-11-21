# Rules: Workflow 03 — Prompt Disambiguation, Topic Breakdown & Plan Approval

1. **Mandatory Attachment Pre-Reading**:
   - WHERE the prompt attaches external files or repository links, the Guided Reasoning Orchestrator SHALL read every attachment in full before formulating any question.
2. **Strict `qa` Protocol (1 Question / Turn)**:
   - The Guided Reasoning Orchestrator SHALL conduct 4 to 6 non-trivial disambiguation questions (1 question per turn via `AskUserQuestion` for humans with `(Recommended)` and escape hatch, or `GIVEN-WHEN-THEN` for AI callers).
   - WHEN formulating human questions, the Guided Reasoning Orchestrator SHALL apply EARS and BDD behavioral schemas without lexical word-locking.
3. **Centralize Interview in `brief/`**:
   - The Guided Reasoning Orchestrator SHALL record every disambiguation question and answer in English inside `brief/00-prompt-disambiguation-qa.md`.
4. **Disambiguated Prompt Supremacy**:
   - The Guided Reasoning Orchestrator SHALL anchor all subsequent workflows strictly to the expanded disambiguated prompt and `TOPIC-NN` breakdown in `proposal.md`.
5. **Explicit `plan.md` Approval Gate**:
   - IF `plan.md` lacks activator approval, THEN the Guided Reasoning Orchestrator SHALL halt before entering Workflow 04.
