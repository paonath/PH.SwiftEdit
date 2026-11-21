---
area: "01-architecture"
prefix: "AR"
status: "{{STATUS_ARCHITECTURE}}"
owners: ["dotnet-expert", "python-expert", "shell-expert", "oop-architecture-expert"]
---

# Architecture & Module Topology Mini-Index (`01-architecture/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `module-topology.md` | `AR-001..AR-005` | Physical module directories, `SharedKernel` contract ownership, `Core` vs `KISS-Lite` module profiles |
| `dependency-and-layering.md` | `AR-006..AR-010` | Inward dependency direction, Ring 1 `Domain` purity, Permissive `1:1` DI Uniformity, `Rule of Three >= 3` |
| `host-and-sagas.md` | `AR-011..AR-014` | Explicit `IModule` composition root, Saga non-authority coordinator rule, `TimeProvider` deterministic clocks |
