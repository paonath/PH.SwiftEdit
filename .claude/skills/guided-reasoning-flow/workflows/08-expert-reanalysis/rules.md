# Rules: Workflow 08 — Technical Re-Analysis & Cross-Topic Sign-Off

1. **Per-TOPIC Closure Gate**:
   - The Guided Reasoning Orchestrator SHALL execute Step 01 after Workflow 07 for every `TOPIC-NN` before advancing to `TOPIC-(N+1)`.
2. **Mandatory Security Regression Check**:
   - IF the activator alters a decision or mitigation during Workflow 07 on an IT or software topic, THEN the cyber-security-expert agent SHALL verify that the Non-Simplification Security Floor and STRIDE controls remain intact.
3. **EARS & BDD Post-Review Verdict**:
   - WHEN conducting post-review re-analysis with experts, the Guided Reasoning Orchestrator SHALL load `the ears-syntax-standards skill` and `the bdd-gherkin-specifications skill`, enforce English canonical EARS and `GIVEN-WHEN-THEN` syntax, and update `brief/topic-[id]-consensus.md`.
4. **Bounded Cross-Topic Reconciliation (Max 3 Iterations)**:
   - IF a human override on `TOPIC-NN` invalidates an earlier `TOPIC-M`, THEN the Guided Reasoning Orchestrator SHALL re-run affected topic briefs across at most 3 iterations.
