---
name: myspec-archive
description: Executes fail-closed validation, security review, delta merge into living specs, archive relocation, and isolated conventional changelog commit.
---

# MySpec Archive Skill (myspec-archive)

Governs final closure of completed OpenSpec changes or legacy specifications via a 6-stage fail-closed gating pipeline.

## Requirements

- The myspec-archive skill SHALL remain runtime-neutral across host environments and execute all archival gating stages in exact sequential order.
- IF validation fails, a secret leaks, Security Review Verdict is not approved, or unchecked non-[SYNC] tasks remain, THEN the myspec-archive skill SHALL abort immediately before relocating artifacts.
- WHEN all gating checks pass, the myspec-archive skill SHALL merge living specs, relocate the change to archive, update index.yml, and commit CHANGELOG.md.

## Fail-Closed Gating Pipeline

### Path A: OpenSpec Change Archival (`<changes_dir>/<change-id>/`)
Execute Stages 1–6 in exact order (Stages 1–5 also run atomically via `python3 ../myspec-sync/scripts/myspec_sync.py --archive --change <change-id>`):
1. **Stage 1 — Validation Gate**: Run `python3 ../myspec-validate/scripts/myspec_validate.py --change <change-id> --strict` (including 6-artifact `[<PREFIX>-###]` traceability and `Sync Impact Report` checks when `<spec_root>/Constitution.md` exists); halt on non-zero exit.
2. **Stage 2 — Secret Scan Gate**: Scan `<changes_dir>/<change-id>/` for unredacted credentials (AWS keys, GitHub tokens, private RSA keys); halt on any match.
3. **Stage 3 — Security Review Gate**: Confirm `Verdict: approved` in `design.md` or `threat-model.md` under `## Security Review` or `## Security Review Verdict`.
4. **Stage 4 — Living Spec Merge & Task Gate**: Run `python3 ../myspec-sync/scripts/myspec_sync.py --change <change-id>` to merge `specs/**/spec.md` into `<specs_dir>/<capability>/spec.md` (`RENAMED -> REMOVED -> MODIFIED -> ADDED`), strip `- **REMOVED-SCENARIO**:` / `- **RENAMED-SCENARIO**:` directives, auto-close `[SYNC]` tasks, and abort if any `- [ ]` task remains.
5. **Stage 5 — Archival Relocation & Index Update**: Record branch provenance in `proposal.md` (`- Branch:`), move change to `<archive_dir>/YYYY-MM-DD-<change-id>/`, set `status: implemented` at index `0` of `<spec_root>/index.yml` preserving `always_read:`, and verify `<changes_dir>` is cleared.
6. **Stage 6 — Changelog & Isolated Commit**: Update `CHANGELOG.md` (`changelog-format` rule) and commit ONLY `CHANGELOG.md`, `<spec_root>/index.yml`, `<specs_dir>`, and `<archive_dir>` updates.

### Path B: Legacy Specification Archival (`specs/*.md`)
1. Confirm 100% of Section 12 tasks pass tests, move `specs/<file>.md` to `specs/implemented/<file>.md`, update `CHANGELOG.md`, and execute a dedicated conventional commit.

## Behavioral Scenarios

```gherkin
Feature: MySpec Fail-Closed Change Archival

  @REQ-ARCHIVE-001
  Scenario: Archive a validated and security-approved OpenSpec change
    Given an OpenSpec change passing strict validation, secret scans, approved security verdict, and 100% completed tasks
    When archival executes for the change identifier
    Then living specs merge, the change moves to archive, index.yml updates, and CHANGELOG.md commits cleanly

  @REQ-ARCHIVE-002
  Scenario: Abort archival when security review lacks approval or secrets leak
    Given an OpenSpec change with an unapproved security verdict or unredacted secret pattern
    When archival executes for the change identifier
    Then the pipeline aborts at the failing gate without relocating files or modifying living specs
```

## Next-Step Guidance (Decision D10)

---
> [!TIP]
> **Recommended Next Step**: `/myspec-status` (Claude Code: `/myspec:status`) or `/myspec-tdd-spec-reasoning`
> **Rationale**: Change archived and living specs updated; verify workspace health or start next specification.
---
