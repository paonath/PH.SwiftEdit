---
area: "05-api-contracts"
prefix: "API"
status: "not-applicable"
owners: ["spec-sdlc-expert", "swift-macos-expert", "cyber-security-expert"]
---

# Dormant macOS IPC & Extension Contract Guardrails Mini-Index (`05-api-contracts/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `endpoints-and-versioning.md` | `API-001..API-004` | Zero external endpoints while `not-applicable`, `MINOR` amendment trigger for `AppIntents`/`XPC`/CLI, `Sendable` DTOs |
| `integration-and-events.md` | `API-005..API-008` | Scoped bookmark & byte-length validation, sanitized `LocalizedError` codes, `ACL` mapping, `MAJOR` breaking evolution |
