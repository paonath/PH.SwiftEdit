# Rules: Workflow 01 — Operational Mode Selection & Scaffolding

1. **Mandatory Python Scaffolder**:
   - The Guided Reasoning Orchestrator SHALL invoke `scripts/scaffold_reasoning.py` instead of creating session folders or root documents manually.
2. **Immediate Raw Prompt Capture**:
   - WHEN scaffolding completes, the Guided Reasoning Orchestrator SHALL record the unmodified trigger prompt verbatim in `proposal.md`.
3. **External Attachment Ingestion**:
   - WHERE external files are referenced in the prompt, the Guided Reasoning Orchestrator SHALL pass `--attachment <path>` to `scaffold_reasoning.py` to copy and index them in `attachments/INDEX.md`.
4. **Fail-Closed Rework Backup**:
   - WHERE Mode B (`--rework-from`) runs, the Guided Reasoning Orchestrator SHALL back up all prior root documents and `brief/` files into `attachments/history/rev-[REV]/` before editing.
5. **Un-numbered `plan.md`**: Always use `plan.md` (never legacy `000-plan.md`).
6. **Strict Superseded and Old File Exclusion**:
   - WHILE executing Mode B rework or re-analysis, the Guided Reasoning Orchestrator SHALL exclude `superseded/` directories and `.old` files (`*.md.old`) from context ingestion and annotation parsing.
