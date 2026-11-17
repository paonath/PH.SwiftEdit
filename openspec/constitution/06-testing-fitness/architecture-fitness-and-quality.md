---
area: "06-testing-fitness"
file: "architecture-fitness-and-quality.md"
rules: ["TEST-005", "TEST-006", "TEST-007", "TEST-008"]
---

# 06-testing-fitness/architecture-fitness-and-quality (TEST-005..TEST-008)

## Context
- fitness_tool: `swift package dump-package + SwiftEditCore Import Scanner + myspec_validate.py`
- quality_budget: `Swift 6 Zero Warnings, SwiftEditCore Line Coverage >= 85%, Thin XCUITest Smoke`

## Rules
- **TEST-005**: Parameterized `SwiftEditCore` suites SHALL verify byte-identical round-trip persistence across `UTF-8`, `UTF-8 BOM`, `UTF-16 LE`, `UTF-16 BE`, `LF`, `CRLF`, `10 MiB` degraded-mode transitions, and `64 MiB` `DomainError.fileTooLarge` boundaries.
- **TEST-006**: Automated architecture fitness tests in `SwiftEditTests` SHALL parse `swift package dump-package` JSON and scan `Sources/SwiftEditCore/**/*.swift` to verify zero dependencies or `import` statements referencing `SwiftEditUI`, `AppKit`, `SwiftUI`, `WebKit`, `Combine`, or `Network`.
- **TEST-007**: The Xcode `.app` UI test target SHALL restrict `XCTest` and `XCUITest` usage to macOS App Sandbox open-and-save lifecycles, VoiceOver accessibility smoke checks, and `XCTMetric` cold-start and keystroke latency gates.
- **TEST-008**: Continuous verification SHALL pass `swift test --parallel` with zero compiler warnings under Swift 6 `-strict-concurrency=complete`, `@REQ-<CAP>-<NNN>` BDD traceability tags, and at least `85%` line coverage across `SwiftEditCore`.
