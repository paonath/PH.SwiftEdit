---
name: mcp-server-architect
description: "Progressive-disclosure Model Context Protocol (MCP) server architecture, feature, model-guidance, TDD, and anti-Prompt-Injection skill for C#/.NET (primary: ModelContextProtocol & ModelContextProtocol.AspNetCore) and Python (secondary: mcp / FastMCP)."
---

# MCP Server Architect Skill

## Core Engineering Pillars

- **Primary Stack — C# / .NET (`net8.0`/`net9.0`/`net10.0`)**: Build production MCP servers with `ModelContextProtocol` and `ModelContextProtocol.AspNetCore` (`AddMcpServer`, `WithStdioServerTransport`, `WithHttpTransport`, `MapMcp`, `options.ServerInstructions`, `[McpServerToolType]`, `[McpServerResourceType]`, `[McpServerPromptType]`, `WithRequestFilters`, and `System.IO.Pipelines.Pipe` xUnit TDD).
- **Secondary Stack — Python (`3.10-3.13+`)**: Build Python MCP servers with the official `mcp` SDK (`FastMCP(instructions=...)`, `@asynccontextmanager` lifespan, `stdio`/`streamable-http`, Pydantic v2, and in-memory `pytest`).
- **KISS-First & Pragmatic SOLID**: Consult `kiss-and-solid-principles` (`Single-Reference Lock`) to keep handlers as thin adapters delegating to `1:1` DI services (`TimeProvider`, `IHttpClientFactory`, `typing.Protocol`), forbid interfaces on DTOs, apply Rule of Three `>= 3`, and write flat `Arrange-Act-Assert` tests.
- **Zero Inline Coding Rules**: Delegate normative language rules to `csharp-coding-standards`, `csharp-record-patterns`, `dotnet-minimal-api`, `dotnet-logging`, `fluent-validation-csharp`, `python-coding-standards`, and `security-secrets-policy`.

## Discovery-First Existing Project Rule

1. WHEN planning an MCP server, the mcp-server-architect skill SHALL query TokenSave (`tokensave_context`, `tokensave_search`) and inspect `.sln`/`.slnx`, `.csproj`, `pyproject.toml`, `AGENTS.md`, and living specifications before proposing a layout.
2. WHERE a repository establishes a hosting model (`stdio` or `Streamable HTTP`), DI container, or test framework (`xUnit`, `MSTest`, or `pytest`), the mcp-server-architect skill SHALL preserve those conventions.

## Non-Simplification MCP Security Floor (`Prompt-Injection` & Threat Defense)

- WHEN an external Tool or Resource returns untrusted output, the mcp-server-architect skill SHALL wrap payloads in nonce Data Spotlighting delimiters (`<untrusted_mcp_data_{nonce}>`) via `.WithRequestFilters` (`AddCallToolFilter`, `AddReadResourceFilter`) or `@spotlight_untrusted` (`OWASP LLM01:2025`, `SEC-MCP-01`).
- The mcp-server-architect skill SHALL define tool/resource names, `[Description]` attributes, `ServerInstructions` (`<= 450` words), and JSON Schemas statically at compile time while returning stack-trace-free domain errors (`McpException`, `IsError = true`, `CWE-209`, `SEC-MCP-02`, `SEC-MCP-06`).
- IF tool metadata contains covert cross-server instructions, hidden directives (`<IMPORTANT>`, `"Do not tell the user"`), or runtime schema mutation, THEN the mcp-server-architect skill SHALL reject the design as Tool Poisoning.
- The mcp-server-architect skill SHALL enforce OAuth 2.1 `aud` validation (`RFC 8707`), forbid upstream Token Passthrough (`RFC 8693`), enforce `CWE-22` path canonicalization, `CWE-78` shell-free argument arrays, `CWE-918` SSRF IP blocking, `MaxOutputBytes` caps (`CWE-400`), `stderr`-only `stdio` logging (`CWE-532`), and HITL confirmation (`ElicitAsync` or `HMACSHA256` + `TimeProvider` on `Stateless = true` HTTP, `SEC-MCP-03..05`).

## Progressive-Disclosure 5-Folder Routing Index (`Single-Reference Lock`)

The mcp-server-architect skill SHALL load at most ONE module across `architecture/`, `features/`, `examples/`, `resources/`, or `guidance/` per turn or sub-agent invocation.

| Folder | Module (<150 Lines) | Trigger Signals |
| :--- | :--- | :--- |
| `architecture` | `architecture/dotnet-host-transports-and-di.md` | C# `AddMcpServer`, `stdio` (`stderr` logging) vs. `Streamable HTTP` (`Stateless` vs. stateful), `1:1` DI lifetimes |
| `architecture` | `architecture/trust-boundaries-and-defense-in-depth.md` | 4-zone MCP trust model, `.WithRequestFilters` pipeline, OAuth 2.1 `RFC 8707`, Token Passthrough ban, `CWE-22`/`78`/`918` |
| `architecture` | `architecture/python-fastmcp-and-async-lifecycle.md` | Secondary Python `FastMCP`, `@asynccontextmanager` lifespan DI, `stdio`/`streamable-http`, `CWE-22`/`78` & `@spotlight_untrusted` |
| `features` | `features/tools-resources-and-prompts-dotnet.md` | C# `[McpServerToolType]`, `[McpServerResourceType]`, `[McpServerPromptType]`, `McpServerTool.Create`, annotations, pagination |
| `features` | `features/advanced-sampling-elicitation-completions.md` | C# `SampleAsync`, `ElicitAsync` (`ClientCapabilities`), `HMACSHA256` stateless HITL token, `WithCompleteHandler`, `ProgressToken` |
| `features` | `features/prompt-injection-and-tool-poisoning-defense.md` | Deep anti-Prompt-Injection: nonce Data Spotlighting, Untrusted Source Classification, `SEC-MCP-02`/`06` preconditions vs. Poisoning |
| `examples` | `examples/dotnet-stdio-and-http-server-blueprint.md` | Copy-ready C# `stdio` + `Streamable HTTP` `Program.cs`, DI tool/resource classes, `FluentValidation`, and Spotlighting filter |
| `examples` | `examples/dotnet-xunit-tdd-and-security-tests.md` | Deterministic C# `System.IO.Pipelines.Pipe` (`StreamServerTransport`/`StreamClientTransport`) xUnit positive & security tests |
| `examples` | `examples/python-fastmcp-server-and-pytest.md` | Copy-ready secondary Python `FastMCP` server (`@spotlight_untrusted`, Pydantic, `is_relative_to`) and in-memory `pytest` suite |
| `resources` | `resources/capability-extension-guide.md` | Blueprint and markdown templates for extending capabilities across the 5 folders with mandatory Prompt-Injection review |
| `resources` | `resources/prompt-injection-and-security-checklist.md` | Pre-release MCP Security, Prompt-Injection (`LLM01:2025`), Tool Poisoning, Contract (`SEC-MCP-01..06`), and STRIDE audit gate |
| `resources` | `resources/sdk-packages-and-protocol-matrix.md` | NuGet (`ModelContextProtocol*`) & PyPI (`mcp`) matrix, JSON-RPC 2.0 error codes, and transport compatibility table |
| `guidance` | `guidance/control-modes-and-server-instructions.md` | 6-channel model-guidance matrix (`User`/`Application`/`Model`-controlled), Golden Rule, `ServerInstructions` (`150-400` words) |
| `guidance` | `guidance/prompts-resources-and-bridge-tools.md` | `[McpServerPrompt]` 6-part workflow, `[McpServerResource]` concrete vs. RFC 6570 URIs, `ResourceLinkBlock`, `get_guide` bridge |
| `guidance` | `guidance/domain-workflow-case-study-dotnet.md` | C# Requirements & Commercial Offers blueprint: `RequirementTypeCatalog`, `SearchResult<T>(HasMore)`, `create_*` invariants, `force` gate |
| `guidance` | `guidance/contract-budget-tests-and-antipatterns.md` | xUnit `ToolContractTests`, `InstructionsBudgetTests` (`<= 450` words), `DuplicateRulesTests`, 9-point checklist, 9 anti-patterns |

## Self-Evolution Capability Proposal Gate

- WHEN extending `architecture/`, `features/`, `examples/`, `resources/`, or `guidance/`, the mcp-server-architect skill SHALL follow `resources/capability-extension-guide.md` with a `## Prompt-Injection & Security Invariants` review.
- The mcp-server-architect skill SHALL validate that new module filenames match `^[a-z0-9]+(-[a-z0-9]+)*\.md$`, forbid `..` or separators (`CWE-22`), stay `< 150` lines, and confirm via `AskUserQuestion` before writing.

## Behavioral Scenarios

```gherkin
Feature: MCP Server Architect Governance
  @REQ-MCP-001
  Scenario: Stateful C# MCP server spotlights untrusted output and respects instruction budgets
    Given a .NET repository with an existing Streamable HTTP host and xUnit test suite
    When the mcp-server-architect designs a server under Single-Reference Lock
    Then handlers delegate to 1:1 DI services with ServerInstructions under 450 words
    And external tool outputs are wrapped in nonce Data Spotlighting delimiters

  @REQ-MCP-002
  Scenario: Tool poisoning, Token Passthrough, or shell execution violates security floor
    Given an MCP server proposal forwards upstream OAuth tokens or executes shell strings
    When the mcp-server-architect enforces SEC-MCP-01 through SEC-MCP-06 invariants
    Then the proposal is rejected for Token Passthrough, CWE-78, and Prompt-Injection violations
```
