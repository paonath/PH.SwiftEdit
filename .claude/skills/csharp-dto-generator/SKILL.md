---
name: csharp-dto-generator
description: |
  Generates C# DTO record pairs (EntityCreateDto + EntityDto) from EF Core entity classes following the project record patterns.
  Use when: (1) a user asks to generate a DTO from an entity class, (2) a user says "create DTO for [entity]",
  (3) a user adds a new entity and needs its DTO counterpart, (4) a user asks to "convert entity to DTO record".
---

# C# DTO Generator

Generate immutable `record` DTO pairs from an EF Core entity following `csharp-record-patterns` and `dotnet-architect` layer boundaries.

## Output Structure

Place both records in `{Entity}Dto.cs` under the `Models/` project:
- `{Entity}Dto`: Full read model, inherits `{Entity}CreateDto` and adds `Id`.
- `{Entity}CreateDto`: Input payload containing owned scalar properties.

## Property Classification Rules

- **Primary Key**: Place only in `{Entity}Dto` with `<remarks>This is the primary key.</remarks>`.
- **Scalar Properties**: Place all public non-virtual properties in `{Entity}CreateDto` with `init` accessors.
- **Navigations**: Exclude all `virtual`, `ICollection<T>`, and reference navigation properties from both DTOs.
- **Enums**: Declare a mirrored `{Enum}Dto` in the same file when entity enums are out of scope.
- **Implementation**: Follow dual-constructor and `Deconstruct` patterns in [dto-patterns.md](references/dto-patterns.md) and [articolo-dto-example.md](examples/articolo-dto-example.md).

## Verification Checklist

- [ ] Placed in Models project as `{Entity}Dto.cs` with file-scoped namespace.
- [ ] `{Entity}Dto` declared first, `{Entity}CreateDto` second, zero navigations or collections.
- [ ] `init` accessors used (never `set`), XML docs on all records, properties, and constructors.
- [ ] Chained empty constructor and `Deconstruct` methods implemented.

## Behavioral Requirements

- The csharp-dto-generator skill SHALL align generated records with csharp-record-patterns and dotnet-architect layer boundaries.
- WHEN generating DTO records for an entity, the csharp-dto-generator skill SHALL emit {Entity}Dto before {Entity}CreateDto in {Entity}Dto.cs with init accessors, file-scoped namespace, empty constructor, Deconstruct methods, and XML docs.
- WHERE entity enums are inaccessible in DTO scope, the csharp-dto-generator skill SHALL declare a mirrored {Enum}Dto enum in the same file.
- IF an entity defines virtual, ICollection<T>, or reference navigation properties, THEN the csharp-dto-generator skill SHALL exclude those navigation properties from both DTO records.

## Behavioral Scenarios

```gherkin
Feature: C# Immutable DTO Record Generation
  @REQ-DTO-001
  Scenario: Generate single-file DTO record pair from an EF Core entity
    Given an EF Core entity with scalar properties and a primary key
    When the developer requests DTO record generation
    Then the csharp-dto-generator skill emits {Entity}Dto and {Entity}CreateDto in {Entity}Dto.cs
    And enforces init accessors, Deconstruct methods, and XML documentation

  @REQ-DTO-002
  Scenario: Exclude navigation properties and mutable setters from DTOs
    Given an EF Core entity containing virtual navigation collections
    When the developer generates DTO records for that entity
    Then the csharp-dto-generator skill excludes navigation properties from both records
    And omits mutable set accessors across all DTO properties
```
