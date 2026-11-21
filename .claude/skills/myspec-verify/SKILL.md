---
name: myspec-verify
description: Verifies task completion, test suite pass status, scenario path coverage, and security traits for an implemented OpenSpec change.
---

# MySpec Verify Skill (myspec-verify)

## Requirements

- The myspec-verify skill SHALL remain runtime-neutral and halt immediately if no change identifier is specified.
- WHEN verifying a change, the myspec-verify skill SHALL require 100% completed checkboxes in tasks.md, passing automated tests, positive and negative scenario coverage, and security trait tagging.
- WHERE <spec_root>/Constitution.md exists, the myspec-verify skill SHALL run myspec_validate.py --change <change-id> --strict and audit cited constitution micro-files under Single-Reference Lock (SDD-009).
- WHILE executing --converge, the myspec-verify skill SHALL enforce One-Way Specification Authority (Spec > Code) and append Convergence_<GapSlug> remediation units without altering specifications.

## Hard Stops

- **No change identifier specified** -> stop and ask: *"Please provide the change ID (under `<changes_dir>/`, default: `openspec/changes/`) to verify."*

## Verification Phases

1. **Task Checklist (`tasks.md`)**: Resolve `<changes_dir>/<change-id>/tasks.md` via `.myspec.config.json`; verify 100% of items are `- [x]` (or `- [X]`). If any `- [ ]` remains, halt and instruct `/myspec-apply`.
2. **Test Suite Green Check**: Execute automated unit and integration tests (`dotnet test`, `npm test`, `python3 -m unittest`); require 100% pass rate with zero failures before proceeding.
3. **Scenario, Security & Constitution Audit**: Scan `<changes_dir>/<change-id>/specs/**/spec.md` for `#### Scenario:` coverage across positive ($P\#$) and negative ($N\#$) paths, verify `[Trait: security]` or `tags: security` on abuse tests, and audit cited `<spec_root>/constitution/<NN-area>/<micro-file>.md` rules under `Single-Reference Lock` (`SDD-009`) when `<spec_root>/Constitution.md` exists.
4. **Convergence Audit (`--converge`)**: Compare code against specs under **One-Way Specification Authority** (`Spec > Code`). Classify drift as `missing`, `partial`, `contradicts`, or `unrequested`, and append `## <N>. Unit: Convergence_<GapSlug>` with `- [ ] <N>.<M> [RED] [CONVERGENCE: <category>] <description>` tasks to `tasks.md`.
5. **Verification Matrix & Next-Step (Decision D10)**: Report Task Completion (100%), Test Suite status, Capability Coverage, Security Audit, and Convergence status. Recommend `/myspec-apply <change-id>` on drift, or `/myspec-archive <change-id>` (Claude Code: `/myspec:archive <change-id>`) when 100% converged.

## Behavioral Scenarios

```gherkin
Feature: MySpec Change Verification and Convergence

  @REQ-VERIFY-001
  Scenario: Pass verification for completed tasks, green tests, and security coverage
    Given an OpenSpec change with 100% completed tasks, passing tests, and security traits
    When verification runs for the change identifier
    Then the verification matrix confirms compliance and recommends archival

  @REQ-VERIFY-002
  Scenario: Halt verification and append drift remediation tasks on divergence
    Given an OpenSpec change with incomplete tasks or implementation contradicting the specification
    When verification runs with convergence auditing enabled
    Then verification halts and appends convergence remediation tasks to the task checklist
```
