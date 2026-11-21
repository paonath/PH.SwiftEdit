---
area: "01-architecture"
file: "module-topology.md"
rules: ["AR-001", "AR-002", "AR-003", "AR-004", "AR-005"]
---

# 01-architecture/module-topology (AR-001..AR-005)

## Context
- module_path: `{{MODULE_ROOT_PATH}}`
- core_projects: `{{CORE_MODULE_PROJECTS}}`
- kiss_lite_projects: `{{KISS_LITE_PROFILE}}`

## Rules
- **AR-001**: Every in-scope authority SHALL map to an explicit module under `{{MODULE_ROOT_PATH}}` scaffolded before adding behavior.
- **AR-002**: Each module `SharedKernel` SHALL own only its `DomainIds`, `Commands`, `DomainEvents`, and shared `Enums`/`CustomTypes`.
- **AR-003**: The `Domain` layer SHALL encapsulate Aggregates, Entities, Value Objects, Command Handlers, and Domain Services.
- **AR-004**: WHERE a context is `Core` (`BC-002`) it SHALL use `{{CORE_MODULE_PROJECTS}}`; `Supporting`/`Generic` CRUD contexts SHALL use `{{KISS_LITE_PROFILE}}`.
- **AR-005**: Modules SHALL NOT expose internal ORM/persistence entities or internal `Domain` types across public boundaries.
