---
name: dotnet-architect
description: "Progressive-disclosure C# and .NET architecture skill covering Clean/Hexagonal/DDD, N-Tier Minimal API blueprints, memory/speed optimization, Blazor/MVC UI, xUnit TDD, and XML documentation across Modern .NET (net8/9/10) and Legacy .NET Framework 4.8."
---

# .NET Architect Skill

## Core Engineering Pillars

- **Efficiency, Readability, and Performance**: Optimize CPU and memory allocation (`Span<T>`, `ReadOnlySpan<T>`, `ArrayPool<T>`, `IAsyncEnumerable<T>`, `AsNoTracking()`, `CancellationToken`) while keeping C# code clear and human-readable.
- **TDD and DDD Native**: Drive implementation via RED-GREEN-REFACTOR TDD (`xunit-testing`, `dotnet-test-suite`) and tactical/strategic DDD (`domain-driven-design`).
- **GoF and Architectural Patterns**: Apply idiomatic Gang of Four patterns via `oop-design-patterns__oop-design-patterns` when structural decoupling is needed.
- **KISS-First & Pragmatic SOLID**: Consult `the kiss-and-solid-principles skill` (`Single-Reference Lock`) to prefer **KISS** before over-engineering, keep architectural patterns KISS-compliant, and apply **SOLID** across all C#/.NET OOP code (`1:1` `IFooService`/`FooService` DI service/repository interfaces permitted; no DTO/Entity interfaces; Rule of Three `>= 3` for multi-class GoF hierarchies; flat AAA tests; Non-Simplification Security Floor).
- **Zero Inline Coding Rules**: Normative coding rules live exclusively in `the csharp-coding-standards rule`, `the csharp-record-patterns rule`, `the dotnet-minimal-api rule`, `the dotnet-logging rule`, `the fluent-validation-csharp rule`, and `the dotnet-cli-usage rule`.

## Discovery-First Existing Project Rule

1. **Inspect Existing Topology First**: Query TokenSave (`tokensave_context`, `tokensave_search`) and inspect `.sln`/`.slnx`, `.csproj` (`TargetFramework`), `AGENTS.md`, and living specifications before proposing any structure.
2. **Respect Established Architecture**: Always conform to the architecture already present in an existing repository (Clean, Hexagonal, Vertical Slice, Modular Monolith, N-Tier Minimal API, or Legacy `net48` WCF/Web API). Never force a rigid template onto an existing codebase.
3. **Greenfield Selection**: Only propose a new architectural topology when scaffolding a greenfield solution or when explicitly requested by the user.

## Progressive-Disclosure Reference Index (`Single-Reference Lock`)

Load **at most ONE** `references/<file>.md` per turn or sub-agent invocation based on the active architectural concern:

| Reference File | Architectural Scope |
| :--- | :--- |
| `references/clean-ddd-and-hexagonal-architecture.md` | Clean Architecture, Hexagonal Ports & Adapters, Vertical Slices, Modular Monolith, DDD aggregates, CQRS, Domain Events |
| `references/layered-ntier-and-minimal-api-blueprint.md` | Layered N-Tier (`Models`/`Services`/`Web`/`Tests`), Minimal API endpoint groups, EF Core/EF6 persistence, `sql-schema-planner` integration |
| `references/performance-memory-and-async-patterns.md` | High-throughput async/await, `ValueTask`, `Span<T>`, `ArrayPool<T>`, `System.Threading.Channels`, EF Core query optimization, GC tuning |
| `references/blazor-mvc-and-fullstack-ui.md` | Blazor Server/WASM/SSR (`net8+`), ASP.NET Core MVC, Razor Pages, SignalR real-time hubs, and BFF integration |
| `references/tdd-testing-and-xml-documentation.md` | Deterministic xUnit/MSTest TDD, `WebApplicationFactory<T>`, fake-over-mock seams (`TimeProvider`), CRAP score reduction, XML docs |

## Self-Evolution Reference Proposal Gate

When recurring project patterns reveal an architectural domain not covered by the existing `references/*.md` catalog:
1. Formulate a structured proposal specifying the candidate filename (`references/<slug>.md`), target scope, and key architectural invariants.
2. Validate that `<slug>.md` matches `^[a-z0-9]+(-[a-z0-9]+)*\.md$`, contains no `..` or path separators (`CWE-22`), and stays `< 150` lines.
3. Prompt the user via `AskUserQuestion` for explicit confirmation before creating or modifying any file inside `references/`. Never auto-create or overwrite reference files autonomously.

## Behavioral Contracts (EARS & BDD)

- WHEN a .NET architecture task begins, the dotnet-architect skill SHALL inspect solution topology via TokenSave before proposing any structure.
- The dotnet-architect skill SHALL enforce Single-Reference Lock by loading at most one reference module per invocation.
- IF a candidate reference slug fails regex validation or lacks AskUserQuestion approval, THEN the dotnet-architect skill SHALL block the file write.

```gherkin
Feature: DotNet Architect Progressive Disclosure
  @REQ-NET-001
  Scenario: Discover solution topology and load a single reference
    Given an existing .NET solution with Clean Architecture boundaries
    When the architect evaluates async persistence performance
    Then solution topology is inspected before structural recommendations
    And at most one reference module is loaded into context

  @REQ-NET-002
  Scenario: Reject unapproved or traversal reference proposals
    Given a proposed reference filename containing parent traversal characters
    When the self-evolution gate evaluates the proposal without human confirmation
    Then the reference file creation is blocked
```
