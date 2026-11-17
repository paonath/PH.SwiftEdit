---
area: "01-architecture"
file: "module-topology.md"
rules: ["AR-001", "AR-002", "AR-003", "AR-004", "AR-005"]
---

# 01-architecture/module-topology (AR-001..AR-005)

## Context
- spm_targets: `SwiftEditCore, SwiftEditUI, SwiftEditTests`
- platform_baseline: `.macOS(.v26), Swift 6 (-strict-concurrency=complete)`
- allowlisted_packages: `swiftlang/swift-markdown`

## Rules
- **AR-001**: The `Package.swift` manifest SHALL restrict production SwiftPM targets to `SwiftEditCore` and `SwiftEditUI` alongside `SwiftEditTests`.
- **AR-002**: The Xcode macOS `.app` target SHALL operate exclusively as the composition root wiring `App` lifecycle, entitlements, and `XCUITest` smoke bundles without business logic.
- **AR-003**: All `Package.swift` targets and the Xcode `.app` shell SHALL require `.macOS(.v26)` or newer and compile in Swift 6 language mode with `-strict-concurrency=complete` and zero `#available` legacy shims.
- **AR-004**: The application runtime SHALL execute 100% offline inside the macOS App Sandbox without importing `WebKit`, `JavaScriptCore`, `Network`, `URLSession`, `Foundation.Process`, database, or telemetry frameworks.
- **AR-005**: IF an external SwiftPM package outside the single allowlisted `swiftlang/swift-markdown` parser is proposed, THEN the architecture gate SHALL reject the dependency unless ratified via constitutional amendment.
