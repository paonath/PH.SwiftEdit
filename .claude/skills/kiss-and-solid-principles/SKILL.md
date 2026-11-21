---
name: kiss-and-solid-principles
description: Progressive-disclosure engineering governance skill for the KISS (Keep It Simple, Stupid) and SOLID OOP principles across production code, architecture, TDD testing, and technical documentation.
---

# KISS and SOLID Principles Skill (kiss-and-solid-principles)

## Runtime Neutrality & Progressive Disclosure
- This skill is agent-runtime agnostic and operates under a strict **Single-Reference Lock**: load at most **1** `references/<module>.md` file per active reasoning, review, coding, testing, or documentation step. Never bulk-load all reference files simultaneously.
- Refer to ecosystem skills, rules, and agents by canonical name only (zero hardcoded physical paths).

## Core Mandate: KISS-First + Pragmatic SOLID Hierarchy
1. **KISS-First Default**: Always prefer the simplest, most direct design that passes all tests and clearly expresses intent (Kent Beck's 4 Rules of Simple Design & YAGNI). Eliminate accidental complexity before introducing multi-class hierarchies.
2. **Keep Architectural Patterns KISS-Compliant**: When applying Domain-Driven Design (DDD), Layered/Clean Architecture, or Gang of Four (GoF) patterns, use the minimum structural ceremony required by the domain boundary.
3. **Always Apply SOLID in OOP**: Whenever writing Object-Oriented Programming (OOP) code in backend or frontend stacks (C#/.NET, Angular/TypeScript, Python), enforce `SRP`, `OCP`, `LSP`, `ISP`, and `DIP` pragmatically:
   - **Permissive 1:1 DI Service Uniformity**: `1:1` interfaces (`IFooService` / `FooService`) ARE permitted on DI-registered Application/Domain Services, Repositories, and I/O or Infrastructure Ports (`TimeProvider`, `IFileSystem`) for Dependency Injection container uniformity.
   - **Speculative Bloat Forbidden**: Never create interfaces for DTOs, Entities, Value Objects, Records, or pure static helpers. Require the **Rule of Three (`>= 3` variants)**, an **I/O Seam**, or **Runtime Volatility** before introducing multi-class GoF hierarchies (`Factory`, `Strategy` families, `Bridge`, `Mediator`).

## Non-Simplification Security Floor (Mandatory Guardrail)
- **Never Oversimplify Critical Systems**: KISS removes *accidental implementation complexity* (reflection, dynamic `eval`, deep inheritance), NEVER *essential security controls*.
- Citing KISS to omit boundary input validation (`CWE-20`), parameterized queries (`CWE-89`), authentication/authorization checks (`BOLA`/`BOPLA`), cryptographic integrity (`AES-GCM`), GDPR Art. 5/17 audit redaction (`CWE-532`), or STRIDE negative test scenarios (`- **Trait**: security` and `the myspec-tdd-spec-reasoning skill` Rule G3) is strictly forbidden (`A04:2021 Insecure Design`).

## Single-Reference Lock Routing Table

| Active Task | Reference Module | Key Guardrails |
| :--- | :--- | :--- |
| Writing/refactoring code, avoiding over-engineering, breaking the Complexity Cycle, applying KISS guidelines | `references/kiss-code-and-architecture.md` | AlgoMaster KISS (U.S. Navy 1960s origin, Complexity Cycle, Calculator comparison, 4 Dangers, 7 Violation Signs, 5 Guidelines, 3 Guardrails), Beck's 4 Rules, YAGNI, Security Floor |
| Authoring unit/integration tests (`[RED]`/`[GREEN]`) or technical documentation & docstrings (`[DOC]`, READMEs, specs) | `references/kiss-testing-and-technical-docs.md` | Linear `Arrange-Act-Assert` (`GIVEN-WHEN-THEN`), zero test branching, real objects/fakes over heavy mocks, Minimum Viable Documentation, high-density tables/Mermaid, *why*-focused docstrings |
| Designing or reviewing OOP classes, interfaces, inheritance/composition, and dependency injection across backend/frontend | `references/solid-oop-principles.md` | Wikipedia SOLID (`SRP`, `OCP`, `LSP` per Liskov & Wing 1994, `ISP`, `DIP`), Robert C. Martin (2000) & Michael Feathers (2004), idiomatic C#/.NET, Angular v20+, and Python OOP |
| Resolving tension between KISS and SOLID, deciding on `1:1` interfaces vs. concrete types, or gating GoF/DDD patterns | `references/kiss-vs-solid-balance-and-patterns.md` | Permissive `1:1` DI Service Uniformity vs. DTO/Entity/helper simplicity, Rule of Three (`>= 3`) pattern gate, keeping GoF & DDD patterns KISS-compliant |

## Specialist Handoff Contracts
- **GoF Pattern Realization**: After verifying the Rule of Three (`>= 3` variants) or I/O seam gate in `references/kiss-vs-solid-balance-and-patterns.md`, delegate idiomatic pattern structure to `the oop-design-patterns skill` and `the oop-architecture-expert agent`.
- **DDD Strategic & Tactical Modelling**: Delegate bounded context decomposition, EventStorming, and aggregate boundaries to `the domain-driven-design skill` and `the ddd-expert agent` while enforcing KISS inside domain methods.
- **Stack Architecture & Security**: Coordinate stack conventions with `the dotnet-architect skill`, `the angular-architect skill`, `the python-architect skill`, and `the shell-architect skill`, and security boundaries with `the security-expertise skill` and `the cyber-security-expert agent`.

## Self-Evolution Reference Proposal Gate
- Do not autonomously create or modify files under `references/`.
- If a durable new KISS/SOLID pattern emerges, pause and invoke `AskUserQuestion` presenting the proposed slug (validated strictly against `^[a-z0-9]+(-[a-z0-9]+)*\.md$` with zero `..` segments or path separators, `< 150` lines) and require explicit human approval before writing.

## Behavioral Contracts (EARS & BDD)

- The kiss-and-solid-principles skill SHALL enforce Single-Reference Lock by loading at most one reference module per step.
- WHERE a design involves fewer than three variants and no I/O seam, the kiss-and-solid-principles skill SHALL defer multi-class GoF hierarchies in favor of KISS simplicity.
- IF a proposed simplification omits input validation, authorization, cryptography, or security negative tests, THEN the kiss-and-solid-principles skill SHALL reject the change under the Non-Simplification Security Floor.

```gherkin
Feature: KISS and SOLID Engineering Governance
  @REQ-KS-001
  Scenario: Apply KISS-First with permissive 1:1 DI service uniformity
    Given a single application service registered in dependency injection
    When the developer evaluates structural abstractions
    Then one service interface is permitted without creating interfaces for DTOs
    And speculative multi-class hierarchies are deferred until three variants exist

  @REQ-KS-002
  Scenario: Reject security omission justified as KISS simplification
    Given an endpoint change that proposes removing boundary input validation
    When the Non-Simplification Security Floor evaluates the change
    Then the simplification is rejected to preserve security controls
```
