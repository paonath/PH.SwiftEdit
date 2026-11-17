---
area: "03-ui-ux"
file: "accessibility-and-cwv.md"
rules: ["UI-009", "UI-010", "UI-011", "UI-012"]
---

# 03-ui-ux/accessibility-and-cwv (UI-009..UI-012)

## Context
- a11y_target: `macOS NSAccessibility / VoiceOver and WCAG 2.2 AA Contrast (>= 4.5:1)`
- performance_budgets: `Cold Start <= 150 ms, P99 Keystroke <= 16 ms, Idle RSS <= 50 MB`

## Rules
- **UI-009**: The `SwiftEditUI` target SHALL enforce a minimum luminance contrast ratio of `4.5:1` for editor and preview text and `3.0:1` for interactive controls across standard and Increased Contrast modes.
- **UI-010**: The `SwiftEditUI` target SHALL expose full keyboard navigation, `NSPasteboard` access restricted to explicit Cut/Copy/Paste commands, and VoiceOver `NSAccessibility` roles, labels, and selection notifications across all views.
- **UI-011**: WHILE `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is enabled, `SwiftEditUI` SHALL suppress non-essential view transitions and animated scroll interpolations.
- **UI-012**: The application SHALL sustain cold-start-to-first-responder latency at or below `150` milliseconds, P99 keystroke-to-glyph latency at or below `16` milliseconds, idle `1 MiB` document RSS at or below `50 MB`, and zero whole-document `NSTextLayoutManager.ensureLayout` calls.
