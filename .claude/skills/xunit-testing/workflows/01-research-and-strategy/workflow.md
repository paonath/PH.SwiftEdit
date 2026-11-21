# Workflow 01: Research Existing Helpers & Dependency Strategy (`xunit-testing`)

## Input Contract

- Target under test: file path or symbol name.
- Test level: `unit`, `integration`, `handler-direct`.
- Coverage intent: happy path, invalid input, authorization, boundary conditions.
- Constraints: allowed libraries, execution time, fixture availability.

## Dependency Strategy

- Prefer real DI and real implementations when practical without requiring mocking frameworks.
- Use minimal concrete stubs or fakes only when isolation is necessary.
- Use `IClassFixture<T>` for shared setup per test class; use `ICollectionFixture<T>` only when cross-class sharing is required.
- Consult [di-patterns.md](../../references/di-patterns.md) on demand for advanced DI and fixture patterns.

## Behavioral Requirements

- The xunit-testing research workflow SHALL search existing test patterns, fixtures, and helpers under the tokensave-first rule before writing or editing tests.
- WHEN shared fixture setup is scoped to a single test class, the xunit-testing research workflow SHALL select IClassFixture over ICollectionFixture.
- IF dependency isolation is required, THEN the xunit-testing research workflow SHALL select concrete stubs or fakes instead of heavy mocking frameworks.

## Execution Workflow — Step 1..4 (Discovery & Setup)

1. Search the test project for existing patterns, fixtures, or helpers (`tokensave-first` rule) to avoid duplicating shared fixtures.
2. Identify the behavior contract and expected outcomes.
3. Choose test style: `unit`, `integration`, or `handler-direct`.
4. Build minimal setup using fixture/scope or concrete stub/fake.
