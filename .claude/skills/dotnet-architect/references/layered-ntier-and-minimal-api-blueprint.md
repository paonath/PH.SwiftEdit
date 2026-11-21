---
name: layered-ntier-and-minimal-api-blueprint
description: "Layered N-Tier solution blueprint, Minimal API endpoint groups, EF Core/EF6 persistence, and generator skill integration."
---

# Layered N-Tier and Minimal API Blueprint

## Discovery and Solution Topology

- When an existing solution uses a layered N-Tier structure (or when scaffolding a pragmatic CRUD/line-of-business solution), organize projects with clear dependency flow:
  - `{Solution}.Models`: EF Core entities, enums, and immutable `{Entity}Dto` / `{Entity}CreateDto` record pairs (`csharp-record-patterns.md`).
  - `{Solution}.Services`: Business services (`I{Entity}Service`, `{Entity}Service`), `ServiceBase`, `ValidationResultFlow`, and `FluentValidation` validators (`fluent-validator-generator`, `crud-service-generator`).
  - `{Solution}.Web` (or `{Solution}.Api`): ASP.NET Core Minimal API endpoint groups (`MapGroup`), DI wiring, authentication/authorization policies (`dotnet-minimal-api.md`), and OpenAPI metadata.
  - `{Solution}.Tests`: Deterministic xUnit integration and service tests (`xunit-testing`).

## Minimal API Endpoint Group Pattern (`net8+`)

- Group endpoints per domain resource in `Endpoints/{Entity}Endpoints.cs` via `RouteGroupBuilder`:
  - Apply `.RequireAuthorization(policy)` at the group or endpoint level (`OWASP API1:2023` / `API5:2023`).
  - Return strongly-typed `Task<Results<Ok<TDto>, BadRequest<ValidationResultFlow>, NotFound>>` using `TypedResults`.
  - Forward `CancellationToken` to every service and `DbContext` call.
  - Map `ValidationResultFlow` failures deterministically to `TypedResults.BadRequest(validation)` or `ProblemDetails`.

## Legacy .NET Framework 4.8 (`net48`) Adaptation

- In `net48` solutions (`ApiController` Web API 2 or WCF `[ServiceContract]`), replace `record` DTOs with POCO classes, use traditional braced namespaces, and register dependencies in the project's established container (`Autofac`, `Unity`, or `SimpleInjector`).
- For EF6 (`DbContext` / `EDMX`), keep entity mappings isolated and use `AsNoTracking()` on read projections.

## Database and Generator Skill Integration

- Coordinate DDL schema creation with `sql-schema-planner` (`varchar(128)` app-assigned GUID primary keys, `Utc` datetime suffixes, numbered migration scripts instead of automatic EF Core Migrations when required by project rules).
- Delegate boilerplate generation to `csharp-dto-generator`, `fluent-validator-generator`, and `crud-service-generator`.
