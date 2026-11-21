---
name: myspec-pipeline
description: Orchestrates an end-to-end feature lifecycle linking myspec-split, myspec-tdd-spec-reasoning, sql-schema-planner, stack architect skills (dotnet-architect, angular-architect, python-architect, shell-architect), and myspec-apply.
---

# MySpec Pipeline Skill (myspec-pipeline)

## Requirements

- WHEN starting a pipeline run, the myspec-pipeline skill SHALL read `<spec_root>/index.yml`, every `always_read` document including `<spec_root>/Constitution.md` under `Single-Reference Lock`, and prior specs.
- The myspec-pipeline skill SHALL orchestrate `myspec-split`, `myspec-tdd-spec-reasoning`, `sql-schema-planner`, matching stack architect skills and expert agents, and `myspec-apply` in sequence.
- IF database schema or stack boundaries are affected, THEN the myspec-pipeline skill SHALL engage `sql-schema-planner` and the corresponding stack expert agent before implementation.

## Execution Sequence

1. **Index, Always-Read & Constitution Consultation**: Read `<spec_root>/index.yml` (via `.myspec.config.json`, default: `openspec/index.yml`), load every `always_read:` entry (including `<spec_root>/Constitution.md` under `Single-Reference Lock`), and inspect prepend-ordered `specs:` entries.
2. Activate `myspec-split` to decompose complex requirements into change stubs under `<changes_dir>/` when needed.
3. Activate `myspec-tdd-spec-reasoning` to author validated 6-artifact OpenSpec changes under `<changes_dir>/<change-id>/` (recording `- Branch: <git-branch>` in `proposal.md` and prepending `<spec_root>/index.yml`).
4. Activate `sql-schema-planner` when database entities or DDL modifications are required.
5. Activate matching stack architect skill(s) (`dotnet-architect`, `angular-architect`, `python-architect`, `shell-architect`) and stack expert agent(s) (`dotnet-expert`, `angular-expert`, `python-expert`, `shell-expert`) to verify cross-stack consistency.
6. Activate `myspec-apply` to execute planned tasks step by step.

## Behavioral Scenarios

```gherkin
Feature: MySpec End-to-End Feature Pipeline

  @REQ-PIPELINE-001
  Scenario: Orchestrate a multi-stack feature through specification and implementation
    Given an initialized MySpec workspace with index.yml and always_read architecture context
    When the feature pipeline runs for a multi-stack capability request
    Then specifications, schema plans, stack architecture checks, and TDD implementation execute in sequence

  @REQ-PIPELINE-002
  Scenario: Halt pipeline execution when index consultation prerequisites are missing
    Given an initialized MySpec workspace with missing or unreadable index.yml context
    When the feature pipeline initializes
    Then the pipeline stops before scaffolding changes or editing source files
```

---
> [!TIP]
> **Recommended Next Step**: `/myspec-verify <change-id>` then `/myspec-archive <change-id>` (Claude Code: `/myspec:archive <change-id>`)
> **Rationale**: Pipeline execution complete via `/myspec-apply`; proceed to verify and archive.
---
