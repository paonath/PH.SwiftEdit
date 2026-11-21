---
name: accessibility-wcag-and-presentation-ui
description: "WCAG 2.2 AA web accessibility, semantic HTML landmarks, keyboard focus management, ARIA contracts, and presentation UI architecture."
---

# Web Accessibility (WCAG 2.2 AA) and Presentation UI Architecture

## Semantic HTML First Rule

- Prefer native HTML elements (`<button type="button">`, `<a href="...">`, `<nav>`, `<main>`, `<header>`, `<section>`, `<dialog>`, `<table>`) over generic `<div>` or `<span>` wrappers with synthetic click handlers.
- When extending native elements in Angular, use attribute selectors (`button[appPrimaryButton]`, `a[appNavLink]`) so native keyboard activation (`Enter` / `Space`), focusability, and screen-reader roles remain intact.
- Coordinate modern CSS/HTML layout primitives (`popover`, `<dialog>`, container queries, `:has()`, `:focus-visible`, View Transitions) with `modern-web-guidance-plugin__modern-web-guidance` and audit live DOM trees with `chrome-devtools-plugin__a11y-debugging`.

## WCAG 2.2 Level AA Verification Matrix

| WCAG 2.2 Criterion | Presentation Layer Requirement | Angular Implementation Pattern |
| :--- | :--- | :--- |
| `1.1.1` Non-text Content | Informative images require descriptive `alt`; decorative icons require `alt=""` or `aria-hidden="true"` | `<img ngSrc="..." [alt]="imageAlt()" />` |
| `1.4.3` / `1.4.11` Contrast | Text contrast `>= 4.5:1` (`3:1` large text); interactive UI boundaries and focus rings `>= 3:1` | CSS custom property design tokens supporting light, dark, and `prefers-contrast: more` |
| `2.1.1` / `2.1.2` Keyboard & No Trap | All interactive controls operable via keyboard (`Tab`, `Shift+Tab`, arrow keys); modals trap and restore focus | Angular CDK `CdkTrapFocus` (`cdkTrapFocusAutoCapture`) and `FocusKeyManager` |
| `2.4.7` / `2.4.11` Focus Visible & Not Obscured | Visible `:focus-visible` outline (`>= 2px solid`); sticky headers/footers must not obscure focused element | `scroll-padding-top` / `scroll-padding-bottom` matching sticky bar heights |
| `2.5.8` Target Size (Minimum) | Interactive pointer/touch targets at least `24x24` CSS pixels (`44x44` recommended for primary actions) | Enforce `min-width: 1.5rem; min-height: 1.5rem` or equivalent hit-area padding |
| `3.3.1` / `4.1.3` Error Identification & Status | Form errors linked via `aria-describedby` and `aria-invalid="true"`; async toasts use `aria-live="polite"` | CDK `LiveAnnouncer` service or `<div role="status" aria-live="polite">` |

## Reactive Forms and Accessible Validation

- Every `<input>`, `<select>`, and `<textarea>` must have an explicit programmatic label (`<label [for]="id">` or `aria-labelledby`). Never rely on `placeholder` alone as a label.
- Bind `[attr.aria-invalid]="control.invalid && control.touched"` and `[attr.aria-describedby]="control.invalid ? errorId : hintId"` so assistive technologies announce validation failures immediately.
- Respect `prefers-reduced-motion: reduce` by disabling non-essential scroll or view-transition animations.
