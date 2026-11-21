# Workflow 02: Record Memory (`agent-self-learning`)

## Memories: When and How

### Triggers
- An architectural constraint is confirmed
- A key platform-specific behavior is validated
- A recurring pitfall pattern is identified
- A design decision informs all future work in the area

### Required Sections
- **Metadata**: `PatternId`, `PatternVersion`, `Status`, `Supersedes`, `CreatedAt`, `LastValidatedAt`, `ValidationEvidence`
- **Source Context**: triggering task, scope/system, date/time
- **Memory**: key fact or decision, why it matters
- **Applicability**: when to reuse, preconditions/limitations
- **Actionable Guidance**: recommended future action, related files/services/components

Template: `examples/memory-template.md`

### Creation / Update Procedure (EARS)
1. The record-memory workflow SHALL search existing `.agents/Memories/` artifacts for an overlapping decision or scope before writing a new file.
2. WHEN a matching active memory exists, the record-memory workflow SHALL update that artifact in place and increment `PatternVersion`.
3. IF new evidence contradicts an active memory, THEN the record-memory workflow SHALL mark the older memory `deprecated` or `blocked` and create a replacement setting `Supersedes`.
4. WHEN no matching or conflicting memory exists, the record-memory workflow SHALL create `<short-kebab-title>.md` with `PatternVersion: 1` matching `examples/memory-template.md`.
