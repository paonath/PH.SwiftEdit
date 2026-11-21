# Workflow 04: Execute Tests & Verify Quality Gate (`xunit-testing`)

## Execution Steps

1. Run focused tests for the new or modified test class.
2. Run the broader suite after focused tests pass.

## Optional xUnit Features

- Use `Trait` for coarse categorization when useful, `ITestOutputHelper` for diagnostics, and conditional skip only with an explicit reason.

## Anti-Patterns

- Do not test multiple unrelated behaviors in one test method or test private implementation details directly.
- Do not use ambiguous names like `Test1` or `ShouldWork`, couple tests via shared mutable state, or hide arrange complexity inside assertions.

## Quality Gate

- [ ] Test class ends with `Tests` and method names follow `Verb_Scenario_ExpectedResult`.
- [ ] `AAA` sections are explicit and `Fact` vs `Theory` choice is intentional.
- [ ] Assertions are semantic and dependencies are real or concrete stubs/fakes.
- [ ] Zero deterministic risks (time/order/shared state) and error/authorization paths are covered when applicable.

## Behavioral Requirements

- WHEN verifying new or updated tests, the xunit-testing execution workflow SHALL run focused class tests before running the broader test suite.
- The xunit-testing execution workflow SHALL return changed files, behavior-grouped tests, validation commands, execution summary, and residual coverage risks.
- IF any Quality Gate check fails or an anti-pattern is detected, THEN the xunit-testing execution workflow SHALL block completion until corrected.

## Output Contract & Reuse Notes

When executing this skill, return:
- Changed files.
- Added/updated tests grouped by behavior.
- Commands used to validate tests.
- Test execution summary.
- Residual risks or missing coverage.

Keep domain terms generic unless the target repository requires specific terminology.
