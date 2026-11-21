# Step 01: Mode Detection & Attachment Identification

## Actions
1. Inspect the activator's trigger prompt and caller context (human user vs peer AI agent).
2. Select operational mode:
   - **Mode A (New Session)**: Prompt introduces a new topic without referencing an existing `reasoning/[NNN]_[slug]/` folder. Derive a concise kebab-case `<session-slug>`.
   - **Mode B (Rework Mode)**: Prompt references an existing `reasoning/[NNN]_[slug]/` directory or asks to revise/rework an existing reasoning session.
     - Check whether the prompt explicitly requests `new-major` or a major version bump (`2.0`, `3.0`).
     - **Proactive Major Proposal Seam**: If the session is at `semantic_version >= 1.3` or has revision count >= 3, proactively prompt the user via `AskUserQuestion` suggesting consolidation into a new major version via `new-major` (Workflow 12). If accepted, route execution directly into `workflows/12-major-consolidation/`.
3. Identify any external files attached or referenced by path in the prompt so they can be passed via `--attachment` in Step 02.
