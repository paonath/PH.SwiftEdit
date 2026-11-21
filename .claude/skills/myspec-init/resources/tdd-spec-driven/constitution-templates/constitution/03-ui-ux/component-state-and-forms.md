---
area: "03-ui-ux"
file: "component-state-and-forms.md"
rules: ["UI-005", "UI-006", "UI-007", "UI-008"]
---

# 03-ui-ux/component-state-and-forms (UI-005..UI-008)

## Context
- reactivity_model: `{{UI_REACTIVITY_MODEL}}`
- form_pattern: `{{UI_FORM_PATTERN}}`

## Rules
- **UI-005**: UI components SHALL be standalone and manage local/derived state via `{{UI_REACTIVITY_MODEL}}` without manual subscription leaks.
- **UI-006**: Smart/Container components SHALL orchestrate facade/store calls while Presentational components bind strictly via pure inputs and outputs.
- **UI-007**: Data-entry forms SHALL enforce `{{UI_FORM_PATTERN}}`, disable duplicate submit while pending, and bind validation errors via `aria-describedby`.
- **UI-008**: Components SHALL NOT invoke raw `HttpClient`/`fetch` directly; all API calls SHALL flow through typed domain client services.
