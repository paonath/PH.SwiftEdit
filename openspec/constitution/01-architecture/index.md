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
| `module-topology.md` | `AR-001..AR-005` | `SwiftEditCore` (`.macOS(.v26), .iOS(.v26)`), `SwiftEditUI` (`#if os`), Swift 6, `swift-markdown`, value types |
| `dependency-and-layering.md` | `AR-006..AR-010` | Inward dependency graph, pure `Foundation` `SwiftEditCore`, `Sendable` seams, `Rule of Three >= 3`, `MainActor.assumeIsolated` |
| `host-and-sagas.md` | `AR-011..AR-014` | Offline Markdown lint/format, `Cmd+D` & `(){}[]` engine, App Sandbox zero-network, `nbgv` `Info.plist` stamping |
