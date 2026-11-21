# Step 02: Activator Disambiguation Interview (`qa` Mode)

## Actions
1. Build a concise checklist of 4 to 6 questions covering:
   - Language confirmation (Interaction: Italian default / English; Final `README.md`: Italian default / English; Internal AI & `README.ai.md`: Strictly English).
   - Unclear functional boundaries, constraints, target environment, and any additional deliverables requested.
2. Execute the interview adhering to the `qa` skill:
   - **Human Activator**: Call `AskUserQuestion` with **1 question per turn**, concrete options formatted as direct user responses, `(Recommended)` on the first option, and a skip/escape option.
   - **AI Agent Activator**: Send concise `GIVEN-WHEN-THEN` disambiguation queries or escalate residual strategic ambiguities to the human via `AskUserQuestion` (Hybrid Mode).
3. Record all questions, chosen answers, and architectural impacts in `brief/00-prompt-disambiguation-qa.md` (in English).
4. Mark `T03-02` as `[x]` in `task.md`.
