---
name: test-driven-development
description: 'Enforces disciplined red-green-refactor TDD, loading dotnet-test-suite plugin when needed for .NET and polyglot testing practices.'
---

# Test-Driven Development

TDD is a design discipline: write a failing behavioral test first, watch it fail, write minimal code to pass, and refactor afterward.

## The Cycle: Red -> Green -> Refactor

1. **Red (`[PHASE: RED]`)**: Write one behavioral test, run it via `dotnet-test-suite__run-tests` or native runner, confirm failure for missing behavior, and audit with `dotnet-test-suite__assertion-quality`.
2. **Green (`[PHASE: GREEN]`)**: Write minimal production code to pass that test (iterate on .NET with `dotnet-test-suite__mtp-hot-reload`) and confirm green.
3. **Refactor (`[PHASE: REFACTOR]`)**: Improve internal structure without altering behavior, audit with `dotnet-test-suite__test-anti-patterns` or `dotnet-test-suite__crap-score`, and verify the full suite stays green.

## Behavioral Rules

- The test-driven-development skill SHALL emit [PHASE: RED], [PHASE: GREEN], or [PHASE: REFACTOR] at the start of every cycle turn.
- WHEN executing [PHASE: RED], the test-driven-development skill SHALL observe the new behavioral test fail before authoring production code.
- WHEN executing [PHASE: GREEN], the test-driven-development skill SHALL implement only the minimal production code required to pass the active failing test.
- WHEN executing [PHASE: REFACTOR], the test-driven-development skill SHALL preserve external behavior and verify the full test suite stays green.
- IF production code is written without an observed failing test, THEN the test-driven-development skill SHALL halt implementation and enforce [PHASE: RED] first.
- IF a test failure is resolved by loosening assertions, commenting out, or skipping tests, THEN the test-driven-development skill SHALL reject the change.

## Writing Tests & References

- Test public behavioral contracts with explicit Arrange, Act, Assert sections; prefer real domain models and small fakes over mocks except for external non-deterministic I/O.
- Philosophy and tool catalog: [tdd-philosophy.md](references/tdd-philosophy.md) and [test-suite-tools.md](references/test-suite-tools.md).

## Mandatory Completion Checklist

- [ ] Every new or changed behavior has a test personally watched fail before implementation.
- [ ] Full test suite passes via `dotnet-test-suite__run-tests` or native runner with zero skipped tests or loosened assertions.
- [ ] Refactoring ran as a dedicated post-green step and passed anti-pattern and shallow-assertion checks.

## Behavioral Scenarios

```gherkin
Feature: Red-Green-Refactor Test-Driven Development
  @REQ-TDD-001
  Scenario: Complete a compliant Red-Green-Refactor cycle
    Given a new domain rule lacking implementation
    When the engineer executes [PHASE: RED], [PHASE: GREEN], and [PHASE: REFACTOR] in sequence
    Then the test fails before implementation, passes with minimal code, and remains green after refactoring

  @REQ-TDD-002
  Scenario: Reject production code authored without a prior failing test
    Given an engineer attempting to write production logic directly
    When no failing behavioral test has been observed for that logic
    Then the test-driven-development skill blocks production edits
    And enforces establishing [PHASE: RED] failure first
```
