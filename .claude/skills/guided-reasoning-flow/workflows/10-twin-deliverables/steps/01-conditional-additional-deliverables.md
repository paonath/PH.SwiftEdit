# Step 01: Conditional Additional Deliverables Co-Creation

## Actions
1. Check `plan.md` for any `additional_deliverables` requested by the caller (e.g., an ADR, migration blueprint, schema draft, or prototype folder inside the reasoning directory).
2. If present:
   - If specific parameters remain open, the assigned domain expert asks 1 focused question at a time via `AskUserQuestion` (`qa` mode).
   - Generate the requested deliverable(s) inside `reasoning/[NNN]_[slug]/` (or `attachments/` if secondary), formatted according to the caller's target audience (human or AI).
3. Mark `T10-01` as `[x]` in `task.md`.
