# Workflow 01: Record Lesson (`agent-self-learning`)

## Lessons: When and How

### Triggers
- Incorrect output was generated and corrected
- A tool call failed in an unexpected or repeatable way
- A process step was skipped or mis-ordered

### Required Sections
- **Metadata**: `PatternId`, `PatternVersion`, `Status`, `Supersedes`, `CreatedAt`, `LastValidatedAt`, `ValidationEvidence`
- **Task Context**: triggering task, date/time, impacted area
- **Mistake**: what went wrong, expected vs actual behavior
- **Root Cause**: primary cause, contributing factors, detection gap
- **Resolution**: fix implemented, why it works, verification performed
- **Preventive Actions**: guardrails added, tests/checks, process updates
- **Reuse Guidance**: how to apply this lesson in future tasks

Template: `examples/lesson-template.md`

### Creation / Update Procedure (EARS)
1. The record-lesson workflow SHALL search existing `.agents/Lessons/` artifacts for a duplicate root cause before creating a new file.
2. WHEN a matching active lesson exists, the record-lesson workflow SHALL update that artifact in place and increment `PatternVersion`.
3. IF new evidence contradicts an active lesson, THEN the record-lesson workflow SHALL mark the older lesson `deprecated` or `blocked` and create a replacement setting `Supersedes`.
4. WHEN no matching or conflicting lesson exists, the record-lesson workflow SHALL create `YYYY-MM-DD-<short-kebab-title>.md` with `PatternVersion: 1` matching `examples/lesson-template.md`.
