---
area: "06-testing-fitness"
file: "tdd-and-unit-testing.md"
rules: ["TEST-001", "TEST-002", "TEST-003", "TEST-004"]
---

# 06-testing-fitness/tdd-and-unit-testing (TEST-001..TEST-004)

## Context
- test_runner: `swift test (Swift Testing @Suite, @Test, #expect, #require)`
- domain_test_style: `Parallel Mock-Free Value-Type Given-When-Then Specifications`

## Rules
- **TEST-001**: Every behavioral addition or defect fix in `SwiftEditCore` and `SwiftEditUI` SHALL follow an atomic `[RED] -> [GREEN] -> [REFACTOR]` triad recorded in `tasks.md` using `Swift Testing` (`@Suite`, `@Test`, `#expect`, `#require`).
- **TEST-002**: Every `@Test` function SHALL enforce a linear Arrange-Act-Assert (`GIVEN-WHEN-THEN`) body without `if`, `switch`, `for`, `while`, or `do/catch` control flow, using `@Test(arguments:)` for parameterized inputs and concrete behavioral `#expect` assertions.
- **TEST-003**: All `Swift Testing` suites SHALL execute safely in parallel using isolated `Sendable` value types and unique ephemeral `UserDefaults(suiteName:)` instances with zero shared mutable global state.
- **TEST-004**: Unit tests SHALL inject deterministic `Sendable` `FileSystemProviding` and Swift `Clock` fakes rather than invoking unisolated host disk I/O or wall-clock `Task.sleep` delays.
