# Step 01: Author `proposal.md` and Conditional `manual-steps.md`

1. **`proposal.md`**:
   - Problem statement, scope, user impact, brief citations, security overview, optional uncommented `## Domain Carrier & Decision Ownership (BC-###)` section (declaring `- **BC-001**:`, `- **Owned Decisions**:`, `- **Forbidden Responsibilities**:`, and `- **External Decision References**:` for multi-context/DDD changes).
   - `## Metadata` containing:
     - `- Branch: <git-branch>` (detected via `git rev-parse --abbrev-ref HEAD`, or `detached:<short-sha>` / `n/a` fallback; recorded ONLY in the spec and NEVER in `index.yml`).
     - `- Manual-Steps: [none | manual-steps.md (lang: it|en)]` tracking.
     - `- Modifies-Specs: <prior-spec-ids-and-req-ids | none>` highlighting any consolidated specifications modified by this change.
     - `- Constitutional-Rules:` and `- Amends-Constitution:` when `<spec_root>/Constitution.md` exists.
2. **`manual-steps.md` (Conditional)**:
   - When manual user operations are required, author `<changes_dir>/<change-id>/manual-steps.md` as a minimal schematic runbook in the chosen language (Italian or English): numbered steps (`1..N`: `### Step N: <Title>` or `### Passaggio N: <Titolo>`), what to do (`- **Action**:` / `- **Cosa si fa**:`), and why it is needed (`- **Why**:` / `- **Motivo**:`, strictly bounded to at most 2 lines per step).

## Normative Requirements (EARS)
- WHERE manual user operations are required, the Proposal Author SHALL generate `manual-steps.md` with numbered steps limited to at most 2 rationale lines per step and record `- Manual-Steps:` in `proposal.md`.
