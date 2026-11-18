---
area: "03-ui-ux"
file: "design-system-and-tokens.md"
rules: ["UI-001", "UI-002", "UI-003", "UI-004"]
---

# 03-ui-ux/design-system-and-tokens (UI-001..UI-004)

## Context
- brand_identity: `Concept E2 Feather-in-Inverted-Triangle Logo (logo-e2-refined.svg: #0B0614 Ground, #A78BFA Stroke, #C4B5FD->#7C3AED Gradient) + macOS/iOS AppIcon.appiconset`
- ui_stack: `Zed-Minimal Purple Chrome + Collapsed Sidebar + Right-Column EditorTabStrip + Left LineNumberGutterView + #FFFFFF/#000000 Canvas + 50%..300% Zoom`

## Rules
- **UI-001**: The `SwiftEditUI` workspace shell and `Assets.xcassets` catalog SHALL bundle the Concept E2 macOS and iOS `AppIcon.appiconset` catalogs with Purple (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome across `Light`, `Black`, and `Auto` modes while defaulting the left sidebar to collapsed until `Open Folder`, placing `EditorTabStrip` strictly above the right editor column, rendering a left 1-based `LineNumberGutterView`, and showing `Line`, `Column`, `Character count`, `UTF-8`, and `LF`/`CRLF`/`CR` in the status bar.
- **UI-002**: The `SwiftEditUI` file editor canvas SHALL enforce a pure white (`#FFFFFF`) background with pure black (`#000000`) primary text in `Light` mode and an inverted pure black (`#000000`) background with pure white (`#FFFFFF`) primary text in `Black` (Dark) mode using monospaced typography on a `4pt` chrome grid.
- **UI-003**: WHEN the appearance switches between `Light`, `Black`, `Auto`, or Increased Contrast modes, `SwiftEditUI` SHALL update all Purple chrome tokens and invert the `#FFFFFF`/`#000000` editor canvas dynamically without reloading open buffers.
- **UI-004**: The `SwiftEditUI` editor viewport SHALL support Zoom Mode scaling buffer font rendering from `50%` to `300%` via `Cmd++`, `Cmd+-`, `Cmd+0`, and trackpad pinch gestures alongside distraction-free pane focus zoom without mutating document text.
