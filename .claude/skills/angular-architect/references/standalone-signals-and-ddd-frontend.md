---
name: standalone-signals-and-ddd-frontend
description: "Standalone Angular v20+ component architecture, Signal state management, and Domain-Driven Design frontend boundaries."
---

# Standalone Signals and DDD Frontend Architecture

## Feature-Bounded DDD Directory Topology

- Organize large Angular applications by bounded domain feature (`domains/<feature>/` or `features/<feature>/`) rather than technical file type:
  - `data-access/`: Signal stores, HTTP gateway services, and immutable DTO interfaces.
  - `feature-<use-case>/`: Smart routable container components orchestrating state and user workflows.
  - `ui/`: Pure presentational standalone components (`input()`, `output()`, `model()`) with zero service dependencies.
  - `models/` or `util/`: Domain value types, validators, and pure transformation pipes.
- Enforce unidirectional dependency flow: `feature` -> `ui` and `feature` -> `data-access`; `ui` components never import `data-access` stores directly.

## Signal State Architecture (`Angular v20+`)

| Signal Primitive | Architectural Role | Usage Invariant |
| :--- | :--- | :--- |
| `signal<T>(initial)` | Writable local or store state | Mutate exclusively via `.set()` or `.update()` inside store/component methods |
| `computed(() => ...)` | Derived view state and filtering | Must remain pure, synchronous, and free of side effects |
| `linkedSignal(() => ...)` | Writable state that resets when a source signal changes | Ideal for selection or draft form state tied to an active `input()` entity ID |
| `resource()` / `rxResource()` | Asynchronous data fetching tied to reactive parameters | Exposes `.value()`, `.isLoading()`, and `.error()` signals with automatic request cancellation |
| `effect(() => ...)` | DOM synchronization, logging, or `localStorage` persistence | Avoid using `effect()` to propagate state between signals; use `computed()` or `linkedSignal()` |

## Smart vs Presentational Component Split

- **Smart (Container) Components**: Inject feature stores or facades via `inject()`, handle route parameters (`withComponentInputBinding()`), coordinate side effects, and pass state down via signal inputs.
- **Presentational (UI) Components**: Declare `input.required<T>()`, `output<T>()`, and `host: { ... }` bindings (`angular-component-patterns.md`). Keep templates declarative with `@if`, `@for (...; track item.id)`, and `@switch`.
