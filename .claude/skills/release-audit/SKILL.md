---
name: release-audit
description: Executes pre-release verification including build, test suite, security secret scan, changelog update, and documentation check.
---

# Release Audit

## Procedure

1. Execute solution build (`dotnet build` or `npm run build`) to confirm clean compilation.
2. Execute automated test suite (`dotnet test` or `npm test`).
3. Activate the `security-secret-scanner` skill to inspect workspace files and uncommitted diffs for secret leaks.
4. Activate the `changelog-reconciler` skill to update `CHANGELOG.md` from git commit history.
5. Verify documentation currency following `documentation-generation.md`.

## Requirements (EARS)

- WHEN pre-release verification runs, the release-audit skill SHALL execute the project build (`dotnet build` or `npm run build`) to confirm clean compilation.
- WHEN compilation passes, the release-audit skill SHALL execute the automated test suite (`dotnet test` or `npm test`).
- The release-audit skill SHALL invoke the `security-secret-scanner` skill to inspect workspace files and uncommitted diffs for exposed secrets.
- The release-audit skill SHALL invoke the `changelog-reconciler` skill to update `CHANGELOG.md` from git commit history.
- The release-audit skill SHALL verify documentation currency against `documentation-generation.md`.
- IF compilation, automated tests, or secret scanning fails, THEN the release-audit skill SHALL halt the release audit and report the blocking failure.

## Behavioral Scenarios

```gherkin
Feature: Pre-Release Verification Audit

  @REQ-RAUD-001
  Scenario: Complete pre-release audit when all checks pass
    Given a workspace with passing build, passing tests, zero exposed secrets, and current documentation
    When the agent runs the release-audit skill
    Then build, test suite, secret scan, changelog reconciliation, and documentation verification complete cleanly

  @REQ-RAUD-002
  Scenario: Halt release audit on secret exposure or test failure
    Given the workspace contains a failing test or an exposed credential in uncommitted changes
    When the agent runs the release-audit skill
    Then the audit halts immediately and reports the blocking failure
```
