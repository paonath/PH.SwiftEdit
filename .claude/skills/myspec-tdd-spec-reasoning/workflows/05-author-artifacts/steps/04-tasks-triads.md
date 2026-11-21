# Step 04: Author `tasks.md` TDD Triads & Auxiliary Phases

- Group tasks under one `## N. Unit: <UnitName>` header per unit under test (required by the validator).
- Format all tasks as markdown checkboxes organized in strict `[RED]` -> `[GREEN]` -> `[REFACTOR]` triads for every unit.
- **MANDATORY In-Code Documentation Task (`[DOC]`) Post-REFACTOR**:
  - Whenever the specification involves code implementation (i.e. not documentation-only / `mode: doc-align`), an explicit in-code documentation task MUST be planned immediately after the `[REFACTOR]` phase for every unit:
    - `- [ ] X.4 [DOC] TASK-001-DOC: write concise, formally valid in-code documentation in English for <UnitName>` (`paths: [P1, N1]`)
  - **Documentation Quality Standards**: 1. Concise; 2. English Language; 3. Formally Valid (XML doc / TSDoc / PEP 257 / shell header); 4. Exhaustive; 5. Development-Oriented Only; 6. Non-Trivial (explain *why* per `the kiss-and-solid-principles skill`).
  - **Exemption**: Documentation-only changes (`mode: doc-align` or zero source code files) are exempt from `[DOC]` tasks.
- **MANDATORY Living-Spec Reconciliation Task (`[SYNC]`) When Modifying Consolidated Specs**:
  - Whenever any capability delta contains `## MODIFIED Requirements`, `## REMOVED Requirements`, or `## RENAMED Requirements`, `tasks.md` MUST include a final `[SYNC]` task:
    - `- [ ] N.1 [SYNC] TASK-NNN-SYNC: Execute /myspec-sync <change-id> to reconcile delta changes into <specs_dir>/<capability>/spec.md`
- **Conditional Manual Operations Task (`[MANUAL]`)**:
  - When manual operations are required (`manual-steps.md` and `- Manual-Steps:` in `proposal.md`), include `- [ ] X.Y [MANUAL] TASK-NNN-MANUAL: Execute manual operations listed in manual-steps.md and confirm completion via qa` after `[REFACTOR]`/`[DOC]` or in `## N. Unit: ManualOperations` before `[SYNC]`.
- **Task Checkbox Structure**:
  - `- [ ] X.1 [RED] TASK-001-RED: write ... tests; verify they fail on assertions` (`paths: [P1, N1] · tags: security · priority: critical`)
  - `- [ ] X.2 [GREEN] TASK-001-GREEN: minimum implementation; verify path tests pass` (`paths: [P1, N1]`)
  - `- [ ] X.3 [REFACTOR] TASK-001-REFACTOR: refactor; verify suite remains green` (`paths: [P1, N1]`)
  - `- [ ] X.4 [DOC] TASK-001-DOC: write concise, formally valid in-code documentation in English; verify docstrings and comments` (`paths: [P1, N1]`)
- **Zero stray checkboxes**: Checkbox markers (`- [ ]`) MUST NOT appear outside tracked implementation tasks.

## Normative Requirements (EARS)
- WHERE the change modifies production code, the Task Author SHALL append a `[DOC]` task immediately after `[REFACTOR]` for each unit under test.
- WHERE any delta contains modified, removed, or renamed requirements, the Task Author SHALL append a final `[SYNC]` task to reconcile living specifications.
