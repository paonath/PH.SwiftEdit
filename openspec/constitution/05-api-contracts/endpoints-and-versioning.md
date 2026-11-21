---
area: "05-api-contracts"
file: "endpoints-and-versioning.md"
rules: ["API-001", "API-002", "API-003", "API-004"]
---

# 05-api-contracts/endpoints-and-versioning (API-001..API-004)

## Context
- api_style: `Dormant macOS IPC Guardrails (05-api-contracts status: not-applicable)`
- reactivation_gate: `Constitutional MINOR Amendment Required Before AppIntents/XPC/NSServices/CLI IPC`

## Rules
- **API-001**: WHILE `05-api-contracts` retains `status: "not-applicable"`, `SwiftEditCore` and `SwiftEditUI` SHALL expose zero external HTTP, GraphQL, gRPC, WebSocket, XPC, CLI socket, or `AppIntents` programmatic endpoints.
- **API-002**: IF an OpenSpec proposal introduces `AppIntents`, macOS `NSServices`, XPC services, AppleEvents scripting suites, or a companion CLI IPC channel, THEN the author SHALL ratify a `MINOR` constitutional amendment activating `05-api-contracts` before `myspec-apply`.
- **API-003**: WHERE `05-api-contracts` is activated by constitutional amendment, every external IPC, CLI, or `AppIntent` contract SHALL declare an explicit semantic schema version.
- **API-004**: WHERE `05-api-contracts` is activated by constitutional amendment, boundary adapters SHALL exchange immutable `Sendable` Swift `struct` or `enum` payloads decoupled from internal `SwiftEditCore` buffer types.
