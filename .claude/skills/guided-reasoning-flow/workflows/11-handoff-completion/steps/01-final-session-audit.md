# Step 01: Final Session Validation Checklist

## Actions
Verify every item before concluding:
- [ ] Session directory created with 3-digit prefix via `scripts/scaffold_reasoning.py`: `reasoning/[NNN]_[slug]/`.
- [ ] If Mode B (Rework), prior revision backed up in `attachments/history/rev-[REV]/` and `[[...]]` annotations parsed.
- [ ] `plan.md` (un-numbered), `proposal.md`, `design.md` (minimal), and `task.md` are complete and up to date.
- [ ] External attachments and web research dossiers are stored in `attachments/` and indexed in `attachments/INDEX.md`.
- [ ] All interviews (`00-prompt-disambiguation-qa.md`, `topic-[id]-[expert]-brief.md`, `topic-[id]-expert-activator-qa.md`, `topic-[id]-human-review.md`) reside inside `brief/` in English `GIVEN-WHEN-THEN` format.
- [ ] Every `TOPIC-NN` completed Workflows 04 → 08 (`consensus-matrix.md` and `tradeoffs-pro-cons.md` signed off in `<= 3` iterations).
- [ ] Any `specs/agents/<slug>.agent.md` persistence was explicitly confirmed by the human via `AskUserQuestion`.
- [ ] `README.md` is Human-Oriented, max 3-4 lines/paragraph, zero meta-narrative, with author, explicit `UTC` timestamp, and revision (`1.0`, `1.1`...).
- [ ] `README.ai.md` is Strictly English AI-Oriented, containing `repository_baseline`, `Spec Generation & Implementation Task List`, and `Reasoning Tree & Progressive Disclosure Map`.
- [ ] Zero project source code files outside `reasoning/` were modified.
- Mark `T11-01` as `[x]` in `task.md`.
