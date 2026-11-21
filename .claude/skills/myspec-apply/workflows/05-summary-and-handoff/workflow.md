# Workflow 05: Execution Summary & Next-Step Guidance (`myspec-apply`)

1. **Execution Summary**:
   - Print a comprehensive summary of all implemented files, updated checkboxes in `tasks.md`, and test pass metrics.
   - Declare target status: `COMPLETE` (100% tasks `- [x]`, all tests green) or `INCOMPLETE`.
2. **Next-Step Handoff (Decision D10)**:
   - If target was an OpenSpec change and is `COMPLETE`:
     ```markdown
     ---
     > [!TIP]
     > **Recommended Next Step**: `/myspec-verify <change-id>` (Claude Code: `/myspec:verify <change-id>`)
     > **Rationale**: TDD tasks in `tasks.md` completed; verify requirement and path compliance before archiving.
     ---
     ```
   - If target was a legacy specification and is `COMPLETE`:
     ```markdown
     ---
     > [!TIP]
     > **Recommended Next Step**: `/myspec-archive @specs/<filename>.md` (Claude Code: `/myspec:archive @specs/<filename>.md`)
     > **Rationale**: All legacy spec tasks completed; proceed to archive in `specs/implemented/` and update CHANGELOG.md.
     ---
     ```

## Normative Requirements (EARS)
- WHEN all tasks and verification gates pass, the Summary Handoff SHALL report `COMPLETE` and recommend `/myspec-verify <change-id>` or `/myspec-archive @specs/<filename>.md`.
