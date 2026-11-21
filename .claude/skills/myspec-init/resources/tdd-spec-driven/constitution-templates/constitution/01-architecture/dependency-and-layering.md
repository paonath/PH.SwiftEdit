---
area: "01-architecture"
file: "dependency-and-layering.md"
rules: ["AR-006", "AR-007", "AR-008", "AR-009", "AR-010"]
---

# 01-architecture/dependency-and-layering (AR-006..AR-010)

## Context
- inner_ring: `{{DOMAIN_RING_NAME}}`
- outer_ring: `{{ADAPTER_RING_NAMES}}`

## Rules
- **AR-006**: Source code dependencies SHALL point exclusively inward toward `{{DOMAIN_RING_NAME}}`.
- **AR-007**: Ring 1 `Domain` SHALL NOT reference HTTP, ORM, database, message broker, or UI framework packages.
- **AR-008**: Cross-module communication SHALL occur exclusively via `SharedKernel` contracts or integration events, never via internal `Domain`/`Infrastructure` references.
- **AR-009**: Application/DI services MAY use `1:1` interface-to-class contracts for testability; GoF multi-class patterns SHALL require `>= 3` concrete variants (`Rule of Three`).
- **AR-010**: Every public handler or service method SHALL enforce a single responsibility and acyclic dependency graph (`SRP`/`DIP`).
