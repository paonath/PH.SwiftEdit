---
name: repository-health-auditor
description: "Automates code health audits, dependency integrity checks, linting verification, and TokenSave doctor diagnostics. Triggers: repository-health-auditor, repo health, audit repo, tokensave doctor, check dependencies."
---

# Repository Health Auditor

## Purpose

Provides a structured automated routine to assess codebase health, verify dependency versions, check semantic knowledge graph integrity, and verify compliance with project rules.

## Procedure

1. **TokenSave Health Check**:
   - WHEN auditing semantic index health, the repository-health-auditor skill SHALL execute `tokensave doctor` to verify semantic index integrity.
   - The repository-health-auditor skill SHALL confirm indexed file count and freshness via `tokensave status` or TokenSave diagnostics.
2. **Dependency Audit**:
   - WHERE a .NET project is present, the repository-health-auditor skill SHALL execute `dotnet list package --outdated` to detect outdated packages.
   - WHERE an Angular or Node.js project is present, the repository-health-auditor skill SHALL execute `npm outdated` to identify vulnerable or outdated dependencies.
3. **Build and Test Verification**:
   - WHEN verifying project integrity, the repository-health-auditor skill SHALL execute the solution build (`dotnet build` or `npm run build`) and unit test suite (`dotnet test` or `npm test`).
4. **Rule Compliance Check**:
   - The repository-health-auditor skill SHALL verify the presence of project rules, skills, `AGENTS.md`, and `CHANGELOG.md` conforming to the `markdown-style-ai` rule.
   - IF any semantic index check, dependency audit, build, test suite, or rule check fails, THEN the repository-health-auditor skill SHALL report each failing gate with actionable remediation steps.

## Behavioral Scenarios

```gherkin
Feature: Repository Health Auditor
  @REQ-REPO-HEALTH-001
  Scenario: Healthy repository passes index, dependency, build, and rule checks
    Given a repository with a healthy TokenSave index, up-to-date dependencies, passing tests, and valid governance files
    When the repository-health-auditor runs a repository health audit
    Then the auditor reports passing status across all four verification gates

  @REQ-REPO-HEALTH-002
  Scenario: Failing build or missing governance files fail the health audit
    Given a repository has failing unit tests, outdated packages, or a missing AGENTS.md file
    When the repository-health-auditor runs a repository health audit
    Then the auditor flags each failing health gate with actionable remediation steps
```
