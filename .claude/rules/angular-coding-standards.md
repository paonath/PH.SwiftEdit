---
description: "Angular and TypeScript coding standards and conventions for frontend projects"
paths:
  - "**/*.ts"
  - "**/*.html"
---

## Angular and TypeScript Coding Standards

### TypeScript Standards

- Enable and respect strict type checking.
- Prefer type inference when the type is obvious from the assignment.
- Avoid the `any` type; use `unknown` with type narrowing when the type is uncertain.
- Define explicit interfaces or types for all models and API payload contracts.
- Use readonly properties for immutable component inputs and states.

### Angular Architecture and Components

- Always use standalone components over legacy `NgModules`.
- Do NOT set `standalone: true` inside decorators when targeting modern Angular versions where standalone is default.
- Keep components small, modular, and focused on a single responsibility.
- Prefer inline templates and styles for small or atomic components per the `angular-component-patterns` rule.
- Implement lazy loading for all feature and page routes.
- Use `NgOptimizedImage` for static and critical images.
- Do NOT use `@HostBinding` and `@HostListener` decorators; declare host bindings inside the `host` configuration object of the `@Component` or `@Directive` decorator.
- Use standard CSS class bindings (`[class.is-active]="condition"`) and style bindings instead of `ngClass` and `ngStyle`.

### State Management and Signals

- Use Angular signals for local and shared component state management.
- Use `input()` and `output()` signal functions instead of legacy property decorator bindings.
- Use `computed()` for all derived or dependent state.
- Keep signal transformations pure and predictable.
- Do NOT call `mutate()` on signals; use `set()` or `update()` instead.

### Templates and Control Flow

- Keep templates simple and avoid heavy inline logic.
- Use native control flow blocks (`@if`, `@for`, `@switch`) instead of legacy structural directives (`*ngIf`, `*ngFor`, `*ngSwitch`).
- Specify a track expression in `@for` blocks (e.g. `@for (item of items(); track item.id)`).
- Use built-in pipes or imported custom pipes for template data transformations.
- Prefer reactive forms over template-driven forms for complex inputs.

### Services and Dependency Injection

- Design services around a single bounded responsibility.
- Register singleton services with `{ providedIn: 'root' }`.
- Use the `inject()` function instead of constructor parameter injection.
- Clean up long-lived observable subscriptions using `takeUntilDestroyed()` or convert observables to signals using `toSignal()`.

### Naming Conventions

- **PascalCase**: component classes, directive classes, pipe classes, services, interfaces.
- **camelCase**: signal names, properties, methods, local variables.
- **kebab-case**: component selectors, file basenames (e.g. `user-profile.component.ts`).
- **English**: all symbol names, comments, and variable names.

### Accessibility (WCAG 2.2 AA), Performance, and TSDoc Documentation

- Enforce **WCAG 2.2 AA** compliance: prefer native semantic HTML elements (`<button>`, `<nav>`, `<main>`, `<dialog>`), maintain deterministic keyboard focus order and visible `:focus-visible` states, bind valid ARIA attributes (`[attr.aria-expanded]`, `aria-live`), and meet contrast ratios (`4.5:1` normal text, `3:1` UI components).
- Use `ChangeDetectionStrategy.OnPush` (or zoneless signal change detection), `@defer` blocks for heavy below-the-fold views, and `takeUntilDestroyed()` to prevent memory leaks.
- Document public component `input()`/`output()` contracts, signal stores, and complex pipes with concise **TSDoc** (`/** ... */`) comments in English.

