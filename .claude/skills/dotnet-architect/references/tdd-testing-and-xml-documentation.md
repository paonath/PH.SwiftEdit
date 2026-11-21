---
name: tdd-testing-and-xml-documentation
description: "Deterministic xUnit/MSTest TDD workflows, fake-over-mock seams, WebApplicationFactory integration testing, and XML documentation in C#."
---

# TDD Testing and XML Documentation in .NET

## Red-Green-Refactor TDD Workflow

- Follow strict TDD triads (`[PHASE: RED] -> [PHASE: GREEN] -> [PHASE: REFACTOR] -> [PHASE: DOC]`) in coordination with `xunit-testing` and the `dotnet-test-suite` plugin (`dotnet-test-suite__code-testing-agent`, `dotnet-test-suite__run-tests`, `dotnet-test-suite__coverage-analysis`, `dotnet-test-suite__crap-score`).
- **Real Dependencies and Fakes Over Mocks**: Per `csharp-coding-standards.md`, do NOT use `Moq` or `FluentAssertions`; use `Assert.*` methods and inject real service instances, in-memory/SQLite/Testcontainers `DbContext` fixtures, or lightweight deterministic fakes (`FakeTimeProvider`).
- **Ambient Seam Migration**: Abstract static dependencies (`DateTime.UtcNow`, `File.*`, `Environment.*`, `HttpClient`) behind `TimeProvider`, `IFileSystem`, and `IHttpClientFactory` (`dotnet-test-suite__detect-static-dependencies`, `dotnet-test-suite__migrate-static-to-wrapper`).

## Test Pyramid and Naming Matrix

| Test Layer | Target Scope | Recommended Fixture | Naming Pattern |
| :--- | :--- | :--- | :--- |
| Domain Unit Test | Aggregates, Value Objects, Validators | Zero I/O, pure in-memory instantiation | `{Method}_{Scenario}_{ExpectedResult}` |
| Service Integration Test | Application services + EF Core `DbContext` | Isolated per-test database context + real validators | `{ServiceMethod}_{StateUnderTest}_{ExpectedOutcome}` |
| Endpoint Contract Test | Minimal API / Controller HTTP pipeline | `WebApplicationFactory<Program>` + test auth handler | `{Endpoint}_{RoleOrInput}_{ExpectedStatusCode}` |
| Security Abuse Test | `BOLA`, `BOPLA`, injection, auth bypass | Unauthenticated / cross-tenant `HttpClient` | `{Endpoint}_{AttackVector}_ReturnsForbiddenOrBadRequest` |

## XML Documentation Standards (`///`)

- Enable `<GenerateDocumentationFile>true</GenerateDocumentationFile>` on library, model, and API projects so undocumented public symbols surface at compile time.
- Author concise, developer-oriented English XML comments on public types, methods, records, and properties:
  - `<summary>`: Explain *what* the member guarantees and any domain invariant enforced.
  - `<param>` / `<returns>`: Document non-obvious units, nullability semantics, or empty-collection behavior.
  - `<exception cref="...">`: Document domain or validation exceptions thrown to callers.
- Integrate XML comments with ASP.NET Core OpenAPI (`Microsoft.AspNetCore.OpenApi`) so Minimal API endpoints expose accurate schema descriptions automatically.
