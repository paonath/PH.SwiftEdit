---
name: tdd-testing-and-tsdoc-documentation
description: "Deterministic Angular and TypeScript TDD with Vitest, TestBed, HttpTestingController, Playwright E2E/a11y, and TSDoc documentation."
---

# TDD Testing and TSDoc Documentation in Angular and TypeScript

## Red-Green-Refactor Frontend TDD

- Execute strict TDD triads (`[PHASE: RED] -> [PHASE: GREEN] -> [PHASE: REFACTOR] -> [PHASE: DOC]`) using the project's configured test runner (`Vitest`, `Karma`/`Jasmine`, or `Jest`) and `webapp-testing` for Playwright E2E verification.
- Test observable user behavior and DOM accessibility roles (`getByRole('button', { name: /save/i })`) rather than internal private methods or CSS class implementation details.

## Frontend Test Pyramid

| Test Level | Target Artifact | Primary Tooling | Key Verification Focus |
| :--- | :--- | :--- | :--- |
| Pure Unit Test | Pipes, validators, pure state reducers, utility functions | `Vitest` / `Jasmine` (no `TestBed`) | Fast `< 5ms` execution across boundary and invalid inputs |
| Service & HTTP Test | Data-access services, Signal stores, functional interceptors | `TestBed.configureTestingModule` + `provideHttpClientTesting()` | Request URL/method/headers, `HttpTestingController.verify()`, error mapping |
| Component DOM Test | Standalone UI and feature components | `TestBed.createComponent(Comp)` + `ComponentRef.setInput()` | Signal input rendering, `output()` emissions, ARIA attributes, keyboard events |
| E2E & A11y Test | Critical user journeys and WCAG 2.2 AA compliance | Playwright (`webapp-testing`) + `@axe-core/playwright` | Multi-page flows, focus traps, zero critical accessibility violations |

## Deterministic Component Testing Rules

- Set signal inputs using `fixture.componentRef.setInput('item', mockItem)` followed by `fixture.detectChanges()` (or `await fixture.whenStable()`).
- Avoid arbitrary `setTimeout` delays in tests; use fake timers (`vi.useFakeTimers()` / `fakeAsync` + `tick`) or deterministic signal flushes (`TestBed.flushEffects()`).
- Always call `httpTestingController.verify()` in `afterEach` to guarantee zero unexpected outbound HTTP requests.

## TSDoc Documentation Standards (`/** ... */`)

- Document exported component `input()`/`output()` signals, public store methods, custom RxJS operators, and shared utility functions using standard **TSDoc** tags (`@param`, `@returns`, `@throws`, `@example`) in concise English.
- Explain behavioral contracts, accessibility expectations (e.g., required ARIA labels), and side effects rather than restating TypeScript types.
