---
area: "03-ui-ux"
prefix: "UI"
status: "{{STATUS_UI_UX}}"
owners: ["angular-expert"]
---

# UI, UX, Accessibility & Core Web Vitals Mini-Index (`03-ui-ux/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `design-system-and-tokens.md` | `UI-001..UI-004` | CSS custom properties, `4px`/`rem` spacing & typography scale, responsive breakpoints/container queries, zero magic CSS |
| `component-state-and-forms.md` | `UI-005..UI-008` | Standalone Signals (`OnPush`/zoneless), Smart vs Presentational boundary, typed reactive forms, async/error feedback |
| `accessibility-and-cwv.md` | `UI-009..UI-012` | `WCAG 2.2 AA` contrast (`>= 4.5:1`), keyboard/focus `2.4.11`, target size `>= 24x24px` `2.5.8`, semantic HTML/ARIA, CWV budgets |
