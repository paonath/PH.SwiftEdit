---
name: xunit-testing
description: |
  Reusable skill for creating, reviewing, and updating xUnit tests in .NET projects.
  Use when: (1) adding tests for services, handlers, validators, or repositories,
  (2) improving naming, assertions, and determinism, (3) designing data-driven tests,
  (4) validating authorization and error paths, (5) reducing flaky tests without mocks.
---

# xUnit Testing Skill (`xunit-testing` — Progressive Disclosure Router)

## Overview

- Produces deterministic xUnit tests in .NET projects with explicit `Verb_Scenario_ExpectedResult` intent.
- Prefers real dependencies and concrete stubs or fakes over mocking frameworks.
- Enforces `Single-Reference Lock`: load one `workflows/NN-*/workflow.md` phase file (and at most one `references/*.md` guide) at a time.

## Triggers

- Create tests for a class, service, endpoint handler, validator, or repository.
- Refactor existing tests for readability, determinism, and coverage across `[Fact]` and `[Theory]` cases.

## Core Rules

- The xunit-testing skill SHALL enforce Single-Reference Lock by loading one phase workflow and at most one reference guide per step.
- WHEN authoring xUnit tests, the xunit-testing skill SHALL apply Verb_Scenario_ExpectedResult naming, explicit Arrange-Act-Assert sections, and Fact or Theory attributes.
- WHEN isolating dependencies, the xunit-testing skill SHALL prefer real DI or concrete stubs and fixtures over mocking frameworks.
- WHEN implementing coverage for a target, the xunit-testing skill SHALL order tests by success path, validation path, authorization path, and boundary edge cases.
- IF shared mutable state or non-deterministic time dependencies are detected, THEN the xunit-testing skill SHALL replace them with unique seeded data and isolated fixtures.

## Execution Workflow

| Phase | Workflow / Reference | Scope |
|---|---|---|
| **01** | [01-research-and-strategy](workflows/01-research-and-strategy/workflow.md) | Input contract triage, helper discovery, dependency/fixture strategy ([di-patterns.md](references/di-patterns.md)). |
| **02** | [02-author-unit-and-theory-tests](workflows/02-author-unit-and-theory-tests/workflow.md) | Naming, AAA, determinism, `InlineData`/`MemberData`/`ClassData`, Pattern A & B ([naming-conventions.md](references/naming-conventions.md)). |
| **03** | [03-author-integration-and-handler-tests](workflows/03-author-integration-and-handler-tests/workflow.md) | Lifecycle (`IDisposable`/`IAsyncLifetime`), assertions, Pattern C, D & E ([assertions-guide.md](references/assertions-guide.md), [patterns.md](references/patterns.md)). |
| **04** | [04-execute-and-quality-gate](workflows/04-execute-and-quality-gate/workflow.md) | Focused/suite test execution, anti-patterns, 8-point Quality Gate, and Output Contract. |

## Behavioral Scenarios

```gherkin
Feature: Deterministic xUnit Test Authoring
  @REQ-XUNIT-001
  Scenario: Author deterministic unit and handler tests in coverage order
    Given a .NET service or minimal API handler requiring xUnit test coverage
    When the engineer executes workflow phases 01 through 04 under Single-Reference Lock
    Then the xunit-testing skill generates Arrange-Act-Assert tests across success, validation, authorization, and boundary paths

  @REQ-XUNIT-002
  Scenario: Reject shared mutable state and ambiguous test naming
    Given a proposed xUnit test suite containing static shared state or generic test names
    When the Quality Gate evaluates the test files
    Then the xunit-testing skill blocks completion
    And enforces Verb_Scenario_ExpectedResult naming with isolated per-test data
```
