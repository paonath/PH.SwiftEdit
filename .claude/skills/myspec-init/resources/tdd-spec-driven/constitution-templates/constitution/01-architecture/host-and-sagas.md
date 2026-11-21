---
area: "01-architecture"
file: "host-and-sagas.md"
rules: ["AR-011", "AR-012", "AR-013", "AR-014"]
---

# 01-architecture/host-and-sagas (AR-011..AR-014)

## Context
- module_bootstrap_contract: `{{MODULE_REGISTRATION_CONTRACT}}`
- clock_abstraction: `{{CLOCK_ABSTRACTION}}`

## Rules
- **AR-011**: The Host application SHALL act strictly as composition root registering modules via `{{MODULE_REGISTRATION_CONTRACT}}` with zero business rules.
- **AR-012**: Sagas/Process Managers SHALL coordinate cross-module workflows solely via published events and public commands without owning domain state.
- **AR-013**: Domain and application logic SHALL obtain time, GUIDs, and randomness through `{{CLOCK_ABSTRACTION}}` rather than static `DateTime.Now`/`UtcNow`.
- **AR-014**: Cross-cutting concerns (logging, correlation, auth, exception mapping) SHALL run in pipeline middleware outside `Domain` aggregates.
