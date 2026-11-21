---
area: "05-api-contracts"
file: "integration-and-events.md"
rules: ["API-005", "API-006", "API-007", "API-008"]
---

# 05-api-contracts/integration-and-events (API-005..API-008)

## Context
- validation_boundary: `UTF-8 Byte-Length Bounds and App Sandbox Security-Scoped Bookmarks`
- compatibility_policy: `Additive Evolution with MAJOR Increment on Breaking Contract Changes`

## Rules
- **API-005**: WHERE `05-api-contracts` is activated by constitutional amendment, boundary decoders SHALL validate payload byte-length bounds, UTF-8 well-formedness, and App Sandbox security-scoped bookmarks before invoking `SwiftEditCore`.
- **API-006**: IF an activated IPC, CLI, or `AppIntent` request violates input or sandbox constraints, THEN the boundary adapter SHALL return a typed `LocalizedError` code without exposing host filesystem paths or stack traces.
- **API-007**: WHERE `05-api-contracts` is activated by constitutional amendment, external macOS framework payloads SHALL pass through an Anti-Corruption Layer mapper before entering `SwiftEditCore`.
- **API-008**: IF a proposed change removes or incompatibly alters an activated IPC, CLI, or `AppIntent` parameter, THEN the author SHALL record a `MAJOR` contract increment and migration path in `design.md`.
