---
area: "03-ui-ux"
file: "design-system-and-tokens.md"
rules: ["UI-001", "UI-002", "UI-003", "UI-004"]
---

# 03-ui-ux/design-system-and-tokens (UI-001..UI-004)

## Context
- ui_stack: `{{FRONTEND_STACK}}`
- token_prefix: `{{CSS_TOKEN_PREFIX}}`

## Rules
- **UI-001**: All visual styles (colors, spacing, typography, elevation) SHALL consume semantic CSS variables (`{{CSS_TOKEN_PREFIX}}`) with zero hardcoded hex/px literals.
- **UI-002**: Layouts SHALL use responsive CSS Grid, Flexbox, and container queries supporting `320px` mobile through `1920px+` desktop without horizontal overflow.
- **UI-003**: Every asynchronous view SHALL render explicit `loading`, `empty`, `error`, and `populated` states with deterministic recovery actions.
- **UI-004**: Design tokens SHALL support dark/light and `prefers-contrast: more` themes without layout shifts.
