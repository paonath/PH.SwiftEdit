# Step 03: Generate `README.ai.md` (AI-Oriented Deliverable)

## Actions
1. Capture the repository git state (`git rev-parse HEAD`, `git branch --show-current`, commit UTC date, `git status --porcelain`) for the `repository_baseline` YAML frontmatter.
2. Write `README.ai.md` **STRICTLY IN ENGLISH**, ultra-concise, with zero preamble, containing:
   - `## Repository Baseline & Staleness Guard`: Full 40-char commit SHA, branch, timestamp, and instructions for downstream agents to detect codebase drift.
   - `## Spec Generation & Implementation Task List`: Updatable checklist (`- [ ] **TASK-01**: ...`) with `Target Scope / Files`, `Assigned Expert / Stack`, `Suggested Spec Slug`, `Prerequisites / Dependencies`, and `Core Contract` (`GIVEN-WHEN-THEN`).
   - `## Reasoning Tree & Progressive Disclosure Map`: Every file in `reasoning/[NNN]_[slug]/` (including `plan.md`, `proposal.md`, `design.md`, `task.md`, `brief/*`, `attachments/*`, and any additional deliverables) mapped with a 1-line semantic descriptor.
3. Mark `T10-03` as `[x]` in `task.md`.
