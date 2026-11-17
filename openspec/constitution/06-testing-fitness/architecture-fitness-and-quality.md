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
- **TEST-005**: Parameterized `SwiftEditCore` suites SHALL verify encoding/BOM/LF/CRLF fidelity, `8 KiB` `0x00` binary rejection (`DomainError.binaryFileSaveForbidden`), `SessionRecovery` close-unlink and startup orphan GC, `Cmd+D` duplication branches, `(){}[]` bracket matching, Myers diffs, dotfile listing, and `swift-markdown` AST lint and formatting.
- **TEST-006**: Automated architecture fitness tests in `SwiftEditTests` SHALL parse `swift package dump-package` JSON and scan `Sources/SwiftEditCore/**/*.swift` to verify zero dependencies or `import` statements referencing `SwiftEditUI`, `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, `Combine`, or `Network`.
- **TEST-007**: The Xcode `.app` UI test target SHALL restrict `XCTest` and `XCUITest` usage to App Sandbox file/folder flows, Concept E2 `AppIcon.appiconset` asset completeness, Purple chrome and `#FFFFFF`/`#000000` `Light`/`Black` contrast checks, `50%..300%` Zoom Mode, VoiceOver navigation, and `XCTMetric` cold-start and keystroke latency gates.
- **TEST-008**: Continuous verification SHALL pass `swift test --parallel` with zero compiler warnings under Swift 6 `-strict-concurrency=complete`, verify `nbgv` `Info.plist` version stamping, and enforce at least `85%` line coverage across `SwiftEditCore`.
