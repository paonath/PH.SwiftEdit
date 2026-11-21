# Rules: Workflow 06 — Systematic Pro/Con & Trade-Off Analysis

1. **Mandatory Pre-Review Execution**:
   - The Guided Reasoning Orchestrator SHALL execute Workflow 06 before Workflow 07 (`human-review`) on every `TOPIC-NN`.
2. **KISS & SOLID Risk Assessment**:
   - The Enrolled Experts SHALL evaluate every proposed decision for over-engineering (KISS and Rule of Three), tight coupling (SOLID), performance overhead, and security risks.
3. **Actionable Mitigation per Risk**:
   - WHEN logging risks in `brief/tradeoffs-pro-cons.md`, the Enrolled Experts SHALL pair every negative trade-off with a concrete technical mitigation.
4. **Pre-Mortem Failure Stress-Testing**:
   - The Guided Reasoning Orchestrator SHALL include a **Pre-Mortem Stress-Testing & Blind-Spot Challenge** in `brief/tradeoffs-pro-cons.md` for every `TOPIC-NN` simulating failure at 6 months with architectural mitigations before human review.
5. **Strictly English Table Format**:
   - The Guided Reasoning Orchestrator SHALL maintain `brief/tradeoffs-pro-cons.md` in concise English tabular format.
