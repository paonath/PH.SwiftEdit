---
area: "03-ui-ux"
file: "accessibility-and-cwv.md"
rules: ["UI-009", "UI-010", "UI-011", "UI-012"]
---

# 03-ui-ux/accessibility-and-cwv (UI-009..UI-012)

## Context
- a11y_target: `WCAG 2.2 Level AA`
- cwv_budgets: `LCP <= 2.5s, INP <= 200ms, CLS <= 0.1`

## Rules
- **UI-009**: All views SHALL satisfy `WCAG 2.2 AA`: semantic landmarks, `>= 4.5:1` text contrast (`>= 3:1` UI/large text), and `>= 24x24px` interactive targets.
- **UI-010**: All interactive flows, modals (`<dialog>`), and menus SHALL support full keyboard navigation (`Tab`, `Escape`, focus trap) and visible `:focus-visible` rings.
- **UI-011**: Animations and transitions SHALL honor `@media (prefers-reduced-motion: reduce)` by disabling non-essential motion.
- **UI-012**: Production bundles SHALL meet Core Web Vitals budgets (`LCP <= 2.5s`, `INP <= 200ms`, `CLS <= 0.1`) via route lazy-loading and explicit image dimensions.
