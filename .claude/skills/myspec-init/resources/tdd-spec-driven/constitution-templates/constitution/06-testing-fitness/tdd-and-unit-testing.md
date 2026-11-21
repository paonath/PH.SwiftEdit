---
area: "06-testing-fitness"
file: "tdd-and-unit-testing.md"
rules: ["TEST-001", "TEST-002", "TEST-003", "TEST-004"]
---

# 06-testing-fitness/tdd-and-unit-testing (TEST-001..TEST-004)

## Context
- test_runner: `{{TEST_FRAMEWORK}}`
- domain_test_style: `Mock-Free Given-When-Then Specification`

## Rules
- **TEST-001**: Every production code change SHALL follow strict `[RED] -> [GREEN] -> [REFACTOR]` TDD triads recorded in `tasks.md`.
- **TEST-002**: Domain aggregate and handler tests SHALL use mock-free `Given-When-Then` specifications or in-memory fakes rather than heavy mocking frameworks.
- **TEST-003**: Unit tests SHALL be 100% deterministic (`FakeTimeProvider`, seeded RNG, zero `Thread.Sleep`, zero live network/filesystem I/O).
- **TEST-004**: Every test method SHALL assert concrete domain state, emitted events, or error codes; assertion-free or tautological tests are forbidden.
