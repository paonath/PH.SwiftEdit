---
name: clean-ddd-and-hexagonal-architecture
description: "Clean Architecture, Hexagonal Ports and Adapters, Vertical Slices, and DDD tactical boundaries in C# and .NET."
---

# Clean, DDD, and Hexagonal Architecture in .NET

## Dependency Direction and Ring Boundaries

- Enforce inward-pointing dependencies: `Domain` (zero external dependencies) <- `Application` (use cases, ports, commands/queries) <- `Infrastructure` / `Presentation` (EF Core, HTTP, messaging adapters).
- Keep `Domain` entities, Value Objects (`readonly record struct` or `record`), Domain Events, and Aggregate Roots free of ORM attributes, framework base classes, and I/O concerns.
- Align tactical boundaries with `domain-driven-design` (`references/tactical-aggregates-and-clean-architecture.md`) and Gang of Four patterns (`oop-design-patterns__oop-design-patterns`).

## Tactical DDD Building Blocks in C#

| Building Block | Idiomatic C# Implementation | Boundary Invariant |
| :--- | :--- | :--- |
| Aggregate Root | `public sealed class Order : AggregateRoot<OrderId>` | Mutates state only via domain command methods; guards invariants before emitting Domain Events |
| Value Object | `public readonly record struct Money( decimal Amount, Currency Code )` | Structural equality, self-validating constructor/factory, zero identity |
| Strongly Typed ID | `public readonly record struct OrderId( string Value )` | Prevents primitive obsession across service and repository signatures |
| Domain Event | `public sealed record OrderPlacedEvent( OrderId Id, DateTimeOffset OccurredAtUtc ) : IDomainEvent` | Raised in-memory by Aggregate Root; dispatched post-commit via Outbox or unit-of-work |
| Repository Port | `public interface IOrderRepository` in `Domain`/`Application` | Accepts and returns Aggregate Roots only; one repository per Aggregate Root |

## Architectural Styles Comparison

- **Clean / Hexagonal (Ports & Adapters)**: Best for complex core domains with strict invariant isolation and replaceable infrastructure adapters.
- **Vertical Slice Architecture**: Organizes code by feature folder (`Features/Orders/PlaceOrder/`), co-locating endpoint, request/response record, `FluentValidation` validator, and handler to minimize cross-layer friction.
- **Modular Monolith**: Enforces strict module boundaries via separate assemblies (`Modules.Ordering.Contracts`, `Modules.Ordering.Internal`) with `InternalsVisibleTo` restricted to module unit tests and inter-module communication limited to public contracts or integration events.

## Persistence Ignorance and Outbox Pattern

- Map domain aggregates to persistence models using EF Core `IEntityTypeConfiguration<T>` inside `Infrastructure` without polluting domain constructors.
- Persist integration events atomically within the same `DbContext` transaction (`OutboxMessages` table) and publish asynchronously via a `BackgroundService` worker to guarantee at-least-once delivery.
