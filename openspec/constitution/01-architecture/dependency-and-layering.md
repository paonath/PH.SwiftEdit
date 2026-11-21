---
area: "01-architecture"
file: "dependency-and-layering.md"
rules: ["AR-006", "AR-007", "AR-008", "AR-009", "AR-010"]
---

# 01-architecture/dependency-and-layering (AR-006..AR-010)

## Context
- inner_ring: `SwiftEditCore (DocumentCore, MarkdownLintAndFormat, SearchDiffAndBracketEngine, WorkspaceAndTabSession)`
- outer_ring: `SwiftEditUI and Xcode App Shell`

## Rules
- **AR-006**: Source dependencies SHALL point strictly inward from the Xcode `.app` shell to `SwiftEditUI` and from `SwiftEditUI` to `SwiftEditCore` without cyclic imports.
- **AR-007**: The `SwiftEditCore` target SHALL abstract filesystem access, dotfile-inclusive folder enumeration, `SessionRecovery` snapshot storage, security-scoped bookmarks, and clocks behind narrow `Sendable` protocols (`FileSystemProviding`, `PreferencesProviding`, and Swift `Clock`).
- **AR-008**: Cross-target boundaries between `SwiftEditUI` and `SwiftEditCore` SHALL exchange immutable `Sendable` value types (`struct` or `enum`) tagged with monotonic `BufferRevision` identifiers.
- **AR-009**: Modules SHALL restrict protocol abstractions and Gang of Four polymorphic hierarchies to external I/O or `Clock` seams or boundaries with at least three concrete variants (`Rule of Three`).
- **AR-010**: The `SwiftEditUI` target SHALL confine all `AppKit`, `UIKit`, TextKit 2 layout, and `SwiftUI` view-state mutations to `@MainActor`, recovering unannotated synchronous main-thread overrides solely via `MainActor.assumeIsolated`.
