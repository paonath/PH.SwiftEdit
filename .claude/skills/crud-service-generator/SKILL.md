---
name: crud-service-generator
description: |
  Generates a complete C# CRUD service class following layered service patterns.
  Use when: (1) a user asks to create a service for an entity,
  (2) a user says "generate CRUD service for [Entity]",
  (3) adding a new domain area that needs Create/Read/Update/Delete operations,
  (4) a user asks "how do I structure a service in this project",
  (5) implementing a service layer over an existing EF Core entity.
---

# CRUD Service Generator

Generate a C# service class implementing **Create, Read, Update, and Delete** operations following layered architecture with EF Core and FluentValidation.

## Return Types Reference

| Operation | Return Type | Description |
| :--- | :--- | :--- |
| `GetAllAsync` | `Task<TDto?[]>` | Read-only array, no validation |
| `GetByIdAsync` | `Task<TDto?>` | Single read, returns `null` if not found |
| `CreateAsync` | `Task<(ValidationResultFlow, TDto?)>` | Returns validation result and created DTO |
| `EditAsync` | `Task<(ValidationResultFlow, TDto?)>` | Returns validation result and updated DTO |
| `DeleteAsync` | `Task<(ValidationResultFlow, bool)>` | Returns validation result and boolean status |

## Generation Workflow

1. **Locate Entity & Base Classes**:
   - Inspect entity class via `tokensave_search`.
   - Identify base service class: see [service-base-classes.md](references/service-base-classes.md).
   - Review validation wrapper: see [validation-result-flow.md](references/validation-result-flow.md).
2. **Define Service Interface**:
   - Prefix with `I`, declare `GetAllAsync`, `GetByIdAsync`, `CreateAsync`, `EditAsync`, and `DeleteAsync` with `CancellationToken ct = default`.
3. **Implement Service Class**:
   - Inherit from `ServiceBase`, inject `DbContext`, `IValidator<T>`, and `ILogger<T>`, and follow [service-template.md](references/service-template.md) and [ProductService.cs](examples/ProductService.cs).
4. **Logging, Architecture & Validation Rules**:
   - Log method entry and failures per `dotnet-logging`, apply rules per `fluent-validation-csharp`, and align boundaries with `dotnet-architect`.

## Behavioral Requirements

- The crud-service-generator skill SHALL align generated service boundaries with dotnet-architect, logging per dotnet-logging, and validation per fluent-validation-csharp.
- WHEN generating a service interface, the crud-service-generator skill SHALL declare GetAllAsync, GetByIdAsync, CreateAsync, EditAsync, and DeleteAsync with CancellationToken ct = default.
- WHEN implementing a service class, the crud-service-generator skill SHALL inherit ServiceBase and inject DbContext, IValidator<T>, and ILogger<T>.
- IF validation fails during CreateAsync, EditAsync, or DeleteAsync, THEN the crud-service-generator skill SHALL return ValidationResultFlow errors without persisting changes.
- IF the target entity symbol is missing from the workspace, THEN the crud-service-generator skill SHALL halt generation and report the missing entity.

## Behavioral Scenarios

```gherkin
Feature: C# CRUD Service Generation
  @REQ-CRUD-001
  Scenario: Generate CRUD service and interface for an existing EF Core entity
    Given an existing EF Core entity and DTO pair aligned with dotnet-architect
    When the developer requests a CRUD service for the entity
    Then the crud-service-generator skill creates the I-prefixed async interface with CancellationToken support
    And generates a ServiceBase subclass injecting DbContext, IValidator, and ILogger

  @REQ-CRUD-002
  Scenario: Reject invalid mutation payload without persisting entity changes
    Given a generated CRUD service validating a CreateAsync or EditAsync payload
    When the injected FluentValidation validator reports input failures
    Then the service returns ValidationResultFlow errors with no persisted DTO
    And leaves database state unchanged
```
