---
name: angular-architect
description: "Progressive-disclosure Angular v20+, TypeScript, JavaScript, and Node.js architecture skill covering Standalone Signals, DDD frontend boundaries, WCAG 2.2 AA accessibility, SSR/hydration performance, client TDD, and TSDoc documentation."
---

# Angular Architect Skill

## Core Engineering Pillars

- **Efficiency, Readability, and Performance**: Optimize rendering and memory (`ChangeDetectionStrategy.OnPush` or zoneless signals, `@defer`, `NgOptimizedImage`, `takeUntilDestroyed()`, bundle tree-shaking) while maintaining clean, human-readable TypeScript and HTML.
- **TDD and DDD Native**: Drive frontend and Node.js modules via RED-GREEN-REFACTOR TDD (Vitest, TestBed, Playwright) and feature-bounded DDD (`domain-driven-design`).
- **Web Accessibility (`WCAG 2.2 AA`)**: Enforce semantic HTML landmarks, keyboard navigation, focus management, ARIA contracts, and contrast ratios across the presentation layer (`chrome-devtools-plugin__a11y-debugging`, `modern-web-guidance-plugin__modern-web-guidance`).
- **GoF and Reactive Patterns**: Apply idiomatic TypeScript/Angular design patterns via `oop-design-patterns__oop-design-patterns` when decoupling state, facades, or adapters.
- **KISS-First & Pragmatic SOLID**: Consult `the kiss-and-solid-principles skill` (`Single-Reference Lock`) to prefer **KISS** before over-engineering, keep architectural patterns KISS-compliant, and apply **SOLID** across all TypeScript/Angular OOP code (`1:1` DI service contracts permitted; Rule of Three `>= 3` for multi-class GoF hierarchies; linear AAA tests; Non-Simplification Security Floor).
- **Zero Inline Coding Rules**: Normative coding rules live exclusively in `the angular-coding-standards rule`, `the angular-component-patterns rule`, and `the angular-cli-usage rule`.

## Discovery-First Existing Project Rule

1. **Inspect Existing Topology First**: Query TokenSave (`tokensave_context`, `tokensave_search`) and inspect `package.json`, `angular.json`, `tsconfig.json`, `AGENTS.md`, and living specifications before proposing any structure.
2. **Respect Established Architecture**: Always conform to the frontend architecture already present in an existing repository (Nx monorepo, feature-sliced standalone folders, SignalStore, NgRx, or existing service facades). Never force a rigid template onto an existing codebase.
3. **Greenfield Selection**: Only propose a new directory layout when scaffolding a greenfield frontend or when explicitly requested by the user.

## Progressive-Disclosure Reference Index (`Single-Reference Lock`)

Load **at most ONE** `references/<file>.md` per turn or sub-agent invocation based on the active architectural concern:

| Reference File | Architectural Scope |
| :--- | :--- |
| `references/standalone-signals-and-ddd-frontend.md` | Feature-bounded DDD directories, smart vs presentational components, Signal stores (`signal`, `computed`, `linkedSignal`, `resource`), route lazy loading |
| `references/accessibility-wcag-and-presentation-ui.md` | Pure frontend presentation layer, WCAG 2.2 AA semantics, ARIA live regions, focus traps, keyboard navigation, responsive CSS, and `chrome-devtools-plugin__a11y-debugging` |
| `references/performance-ssr-hydration-and-memory.md` | Zoneless change detection, incremental hydration, `@defer` triggers, Core Web Vitals (`LCP`, `INP`, `CLS`), and RxJS/Signal memory leak prevention |
| `references/typescript-nodejs-and-state-patterns.md` | Strict TypeScript 5.x type modeling, discriminated unions, RxJS interop (`toSignal`, `toObservable`), HTTP interceptors, and Node.js BFF/tooling scripts |
| `references/tdd-testing-and-tsdoc-documentation.md` | Deterministic Vitest/Karma/TestBed unit tests, `HttpTestingController`, Playwright E2E/a11y verification (`webapp-testing`), and TSDoc standards |

## Self-Evolution Reference Proposal Gate

When recurring project patterns reveal an architectural domain not covered by the existing `references/*.md` catalog:
1. Formulate a structured proposal specifying the candidate filename (`references/<slug>.md`), target scope, and key architectural invariants.
2. Validate that `<slug>.md` matches `^[a-z0-9]+(-[a-z0-9]+)*\.md$`, contains no `..` or path separators (`CWE-22`), and stays `< 150` lines.
3. Prompt the user via `AskUserQuestion` for explicit confirmation before creating or modifying any file inside `references/`. Never auto-create or overwrite reference files autonomously.

## Behavioral Contracts (EARS & BDD)

- WHEN a frontend architecture task begins, the angular-architect skill SHALL inspect repository topology via TokenSave before proposing any structure.
- The angular-architect skill SHALL enforce Single-Reference Lock by loading at most one reference module per invocation.
- IF a candidate reference slug fails regex validation or lacks AskUserQuestion approval, THEN the angular-architect skill SHALL block the file write.

```gherkin
Feature: Angular Architect Progressive Disclosure
  @REQ-ANG-001
  Scenario: Discover topology and load a single reference
    Given an existing Angular repository with Standalone Signals
    When the architect reviews component state architecture
    Then repository topology is inspected before structural recommendations
    And at most one reference module is loaded into context

  @REQ-ANG-002
  Scenario: Reject unapproved or traversal reference proposals
    Given a proposed reference filename with invalid traversal segments
    When the self-evolution gate evaluates the proposal without human confirmation
    Then the reference file creation is blocked
```
