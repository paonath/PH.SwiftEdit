---
area: "03-ui-ux"
file: "accessibility-and-cwv.md"
rules: ["UI-009", "UI-010", "UI-011", "UI-012"]
---

# 03-ui-ux/accessibility-and-cwv (UI-009..UI-012)

## Context
- a11y_target: `NSAccessibility / VoiceOver and WCAG 2.2 AA Contrast (>= 4.5:1 on Chrome, 21:1 on Editor Canvas)`
- performance_budgets: `Cold Start <= 150 ms (including SessionRecovery GC), P99 Keystroke <= 16 ms, Idle RSS <= 50 MB`

## Rules
- **UI-009**: The `SwiftEditUI` command layer SHALL bind `Cmd+D` smart duplication, Markdown `Format Section`, Markdown `Format Document`, and non-destructive error banners while enforcing a minimum contrast ratio of `4.5:1` on Purple chrome and `21:1` on the `#FFFFFF`/`#000000` editor canvas.
- **UI-010**: The `SwiftEditUI` target SHALL expose full keyboard navigation, pasteboard access restricted to explicit Cut/Copy/Paste commands, and VoiceOver accessibility roles, labels, lint and binary warnings, and selection notifications across tabs, the dotfile Folder Navigator, editor panes, diff views, and Markdown previews.
- **UI-011**: WHILE system Reduce Motion (`accessibilityDisplayShouldReduceMotion`) is enabled, `SwiftEditUI` SHALL suppress non-essential sidebar, pane-zoom, and scroll animations.
- **UI-012**: The application SHALL sustain cold-start-to-first-responder latency (including `SessionRecovery` restore and orphan cleanup) at or below `150` milliseconds, P99 keystroke-to-glyph latency at or below `16` milliseconds, idle `1 MiB` document RSS at or below `50 MB`, and zero whole-document `NSTextLayoutManager.ensureLayout` calls.
