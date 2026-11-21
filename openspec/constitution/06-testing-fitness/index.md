---
area: "06-testing-fitness"
prefix: "TEST"
status: "active"
owners: ["swift-macos-expert", "test-quality-auditor", "spec-sdlc-expert"]
---

# Swift Testing TDD & Architecture Fitness Mini-Index (`06-testing-fitness/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `tdd-and-unit-testing.md` | `TEST-001..TEST-004` | `[RED]->[GREEN]->[REFACTOR]` via `swift test` (`Swift Testing`), branch-free AAA, parallel isolation, `FileSystemProviding`/`Clock` fakes |
| `architecture-fitness-and-quality.md` | `TEST-005..TEST-008` | Round-trip parameterized codecs, static `swift package dump-package` & import fitness, thin `XCUITest` smoke, `>= 85%` coverage |
