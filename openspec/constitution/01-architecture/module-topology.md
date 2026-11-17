---
area: "01-architecture"
file: "module-topology.md"
rules: ["AR-001", "AR-002", "AR-003", "AR-004", "AR-005"]
---

# 01-architecture/module-topology (AR-001..AR-005)

## Context
- spm_targets: `SwiftEditCore (.macOS(.v26), .iOS(.v26)), SwiftEditUI, SwiftEditTests`
- platform_baseline: `Swift 6 (-strict-concurrency=complete) across macOS 26+ and optional future iOS 26+`
- allowlisted_packages: `swiftlang/swift-markdown`

## Rules
- **AR-001**: The `Package.swift` manifest SHALL declare `.macOS(.v26)` and `.iOS(.v26)` deployment targets on `SwiftEditCore` while restricting production targets to `SwiftEditCore` and `SwiftEditUI` alongside `SwiftEditTests` and a thin Xcode `.app` shell bundling the official Concept E2 `AppIcon.appiconset` catalogs (`macos/` and `ios/`).
- **AR-002**: The `SwiftEditCore` target SHALL import exclusively the Swift standard library, `Foundation`, and `Markdown` (`swiftlang/swift-markdown`) without importing `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, or `Combine`.
- **AR-003**: The `SwiftEditUI` target SHALL isolate macOS `AppKit` and future iOS `UIKit` text and window bridges behind `#if os(macOS)` and `#if os(iOS)` compilation blocks while compiling all targets in Swift 6 mode with `-strict-concurrency=complete`.
- **AR-004**: The `SwiftEditCore` target SHALL model buffer snapshots, encodings, line endings, Markdown AST lint diagnostics, formatting edits, Myers diff hunks, `(){}[]` bracket spans, tab states, and binary detection results as immutable `Sendable` structs or enums.
- **AR-005**: IF an external SwiftPM package outside the single allowlisted `swiftlang/swift-markdown` parser is proposed, THEN the architecture gate SHALL reject the dependency unless ratified via constitutional amendment.
