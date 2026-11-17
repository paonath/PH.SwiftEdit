---
area: "01-architecture"
prefix: "AR"
status: "active"
owners: ["swift-macos-expert", "oop-architecture-expert"]
---

# Architecture & Module Topology Mini-Index (`01-architecture/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `module-topology.md` | `AR-001..AR-005` | 2-target SwiftPM (`SwiftEditCore`, `SwiftEditUI`), `.macOS(.v26)` Swift 6 baseline, `swiftlang/swift-markdown` ceiling |
| `dependency-and-layering.md` | `AR-006..AR-010` | Inward dependency graph, pure `Foundation` `SwiftEditCore`, `Sendable` value types, `Rule of Three >= 3` |
| `host-and-sagas.md` | `AR-011..AR-014` | `FileSystemProviding` & Swift `Clock` seams, `@MainActor` UI confinement, cooperative cancellation, typed errors |
