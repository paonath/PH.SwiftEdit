---
area: "01-architecture"
file: "host-and-sagas.md"
rules: ["AR-011", "AR-012", "AR-013", "AR-014"]
---

# 01-architecture/host-and-sagas (AR-011..AR-014)

## Context
- io_seams: `FileSystemProviding, PreferencesProviding`
- clock_abstraction: `Swift Clock (ContinuousClock / TestClock)`

## Rules
- **AR-011**: The `SwiftEditCore` target SHALL isolate non-deterministic filesystem, preference, and time access behind narrow `Sendable` seams (`FileSystemProviding`, `PreferencesProviding`, and Swift `Clock`).
- **AR-012**: The `SwiftEditUI` target SHALL confine all `AppKit` `NSTextView`, TextKit 2 layout, and `SwiftUI` view-state mutations to `@MainActor`, recovering unannotated main-thread AppKit overrides solely via `MainActor.assumeIsolated`.
- **AR-013**: WHEN syntax tokenization, search evaluation, or Markdown AST parsing executes off `@MainActor`, the worker SHALL enforce cooperative `Task` cancellation deadlines against an injected Swift `Clock`.
- **AR-014**: Diagnostic `os.Logger` adapters outside domain types SHALL mark dynamic interpolations `.private` by default without recording raw document buffers or `NSPasteboard` payloads.
