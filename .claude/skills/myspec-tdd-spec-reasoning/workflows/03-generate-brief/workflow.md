# Workflow 03: Generate Standardized TDD Brief (`myspec-tdd-spec-reasoning`)

1. Ensure the configured briefs directory `<briefs_dir>/` exists (resolving `spec_root` via `.myspec.config.json`, default `openspec/briefs/`, with fallback to `specs/briefs/`).
2. Write `<briefs_dir>/brief-[slug].md` (and mirror to `specs/briefs/brief-[slug].md`) containing:
   - Feature context, current Git branch (`branch: "<git-branch>"`), consolidated specs modified (`modifies_specs:`), Domain Expert notes, and Pillar breakdowns.
   - Given/When/Then behavior contracts and Path Coverage Matrix (`P1..Pn`, `N1..Nm`).
   - If in `doc-align` mode: mark `mode: doc-align` in the brief header.

## Normative Requirements (EARS)
- WHEN Phase 2 concludes, the Brief Generator SHALL write `<briefs_dir>/brief-[slug].md` containing branch metadata, consolidated spec references, and a path coverage matrix.
