---
description: "C# coding standards and conventions for .NET projects"
paths:
  - "**/*.cs"
---

## C# Coding Standards

### Type Declarations and Variables

- Use `var` when the type is obvious from the right-hand side of the assignment.
- Use explicit types when the type is not obvious.
- Use `string.Empty` over `""` for initializing strings.
- Use expression-bodied members for simple property getters and methods.
- Use `record` types for immutable data structures (DTOs, requests, responses) in Modern .NET (net8+); in Legacy .NET Framework (net48 / C# <= 7.3), use standard POCO classes with explicit getters/setters instead.
- Use `readonly` modifier for fields not intended to be modified after construction.

### Target Framework and Language Version Compatibility

- **Modern .NET (net8.0+)**: Use `record` types, primary constructors, and modern C# 12+ capabilities.
- **Legacy .NET Framework (net48 / C# <= 7.3)**:
  - Do NOT use `record` or `init` accessors; implement standard POCO classes with explicit `{ get; set; }` properties.
  - Do NOT use file-scoped namespaces; use traditional braced namespace declarations (`namespace Foo { ... }`).
  - Do NOT use class primary constructors, collection expressions (`[...]`), or raw string literals.
  - Do NOT reference BCL types absent in .NET Framework without explicit compatibility packages.

### Async and Control Flow

- Use `async`/`await` for all I/O operations.
- Use `Task` and `Task<T>` for asynchronous methods.
- Use braces `{}` for all control statements, including single-line bodies.
- Use `switch` expressions for complex conditional logic where appropriate.
- Use pattern matching for type checks and casts.

### Null Safety and Strings

- Use null-conditional operators (`?.`) to avoid null reference exceptions.
- Use string interpolation for constructing strings (not concatenation).
- Use `nameof` operator instead of hardcoding strings for member names.

### Collections and LINQ

- Use LINQ for collections and data manipulation.
- Prefer arrays over `List<T>` for fixed-size collections.
- Prefer `foreach` loops over `for` loops when iterating through collections.

### Access Modifiers and Organization

- Use explicit access modifiers for all classes and members.
- Prefer `private` or `internal` access modifier unless wider accessibility is required.
- Use `using` statements/declarations to ensure proper disposal of resources.

### Naming Conventions

- **PascalCase**: classes, methods, properties, records, public fields.
- **camelCase**: local variables, parameters.
- **_camelCase**: private fields.
- **SCREAMING_SNAKE_CASE**: constants and static readonly error messages.
- **English**: all symbol names (classes, methods, enums, variables).
- **Language**: comments, documentation, and commit messages should follow the project's established language convention.
- Avoid magic numbers: use named constants or enums instead.

### Services and Components

- **Interfaces**: prefixed with `I`, suffixed with `Service` (e.g., `IOrderService`).
- **Implementations**: suffixed with `Service` (e.g., `OrderService`).
- Follow SOLID principles for all service design.
- Use `ILogger<T>` for logging; reference `dotnet-logging.md` for details.

### Testing

- Use **xUnit** exclusively for unit tests.
- Use `Assert.*` assertions only (Assert.Equal, Assert.NotNull, Assert.True, Assert.Throws).
- **MUST NOT** use FluentAssertions.
- **MUST NOT** use Moq: inject real instances of dependencies instead.
- Always look for DI maps that can be used or replicated for test setup.
- Provide at least one positive and one negative test case per code example.

### Serialization

- Enums use `[JsonConverter(typeof(JsonStringEnumConverter))]` when serialized as strings — **MUST NOT** serialize as integers.

### Database

- PK: `varchar(128)` app-assigned with `Guid.NewGuid().ToString()`.
- No EF Core Migrations: schema changes go to numbered migration scripts in the project's designated diff/migration folder.
- Hierarchy path fields (e.g., `ParentId`, `Path`, `ParentPath`) follow the project's established field convention.

### Performance, Memory, and XML Documentation

- Pass `CancellationToken` through all asynchronous I/O, HTTP, and database call chains.
- Use `AsNoTracking()` on read-only EF Core queries and `IAsyncEnumerable<T>` for streaming large result sets.
- Prefer `Span<T>`, `ReadOnlySpan<T>`, and `ArrayPool<T>` on hot parsing or buffer-processing paths to minimize LOH and GC allocations.
- Author concise XML documentation comments (`/// <summary>`) in English on public APIs, domain contracts, and non-trivial algorithms.