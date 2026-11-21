---
description: "Angular component patterns and conventions for modern Angular projects"
paths:
  - "**/*.ts"
  - "**/*.component.ts"
---

## Component Architecture

### Standalone Components (Modern Angular)

- All components are standalone by default. Do NOT add explicit standalone declarations in decorator metadata.
- Use `inject()` function for dependency injection (avoid constructor injection).
- Use `ChangeDetectionStrategy.OnPush` for all components.
- Use the project-configured prefix for component selectors (check `angular.json` for `prefix`).

### Inline Templates and Styles

- Prefer inline templates (`template:` in `@Component`) and inline styles (`styles:` in `@Component`) for small, atomic, or focused presentational components.
- Keep templates concise, declarative, and readable.

### Component Communication and State

- Use `input()` and `output()` signal functions for component input/output contracts.
- Use `computed()` for derived state and signal transformations.
- **MUST NOT** inject parent components directly.
- **MUST NOT** use shared services for simple UI event propagation between parent and child.
- Keep presentational components pure and driven by signal inputs and outputs.

### RxJS Patterns and Signal Interop

- Convert long-lived observable streams to signals using `toSignal()`.
- Use `takeUntilDestroyed()` when managing active subscriptions in injection contexts.
- Use `switchMap` for cancellable search/request flows, `mergeMap` for parallel operations.
- Avoid nested subscriptions in component logic.

### UI Libraries

- Bootstrap 5 and FontAwesome MUST be used directly via standard CSS classes in HTML.
- Use NgBootstrap only when actual JavaScript behavior is required (modals, tooltips, datepickers).
- Import NgBootstrap symbols only in components that explicitly use them.

### Testing

- Use modern client test runners and Jasmine/Jest assertion suites.
- Use spies on injected services.
- Verify component signal state transitions and rendered DOM output.

### Anti-Patterns

- MUST NOT create component files manually: use `ng g c`.
- MUST NOT declare components in legacy NgModules.
- MUST NOT use legacy decorator-based input and output definitions.
- MUST NOT mutate signal input values directly.

### Component Layout and Consistency

- When planning new components, inspect existing project components to keep layout, padding, grids, and design tokens consistent.
- Initiate a QA session with the user when layout or architectural choices require clarification.
- All admin components MUST occupy the full horizontal space (`inline-size: 100%`) and fit inside the page shell grid layout.