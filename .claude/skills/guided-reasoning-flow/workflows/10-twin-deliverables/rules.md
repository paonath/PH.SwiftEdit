# Rules: Workflow 10 — Additional Deliverables & Twin Deliverables Generation

1. **Human-Oriented `README.md` Invariant**:
   - The Guided Reasoning Orchestrator SHALL generate `README.md` in Human-Oriented format (even for AI callers) in the deliverable language with YAML frontmatter, header table (`Redattore`, `Data Creazione` in `UTC`, `Revisione`), maximum 3-4 lines per paragraph, and zero meta-narrative.
2. **Strictly English AI-Oriented `README.ai.md` Invariant**:
   - The Guided Reasoning Orchestrator SHALL generate `README.ai.md` in concise English without preamble, following `the markdown-style-ai rule`, containing `repository_baseline`, `Spec Generation & Implementation Task List`, and `Reasoning Tree & Progressive Disclosure Map`.
3. **Caller-Oriented Additional Deliverables**:
   - WHERE `additional_deliverables` appear in `plan.md`, the Guided Reasoning Orchestrator SHALL generate those artifacts strictly inside `reasoning/[NNN]_[slug]/`.
4. **No Hardcoded Physical Paths to Customizations**:
   - The Guided Reasoning Orchestrator SHALL reference skills, rules, and agents solely by logical names without physical file paths.
