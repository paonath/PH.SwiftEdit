---
area: "03-ui-ux"
file: "design-system-and-tokens.md"
rules: ["UI-001", "UI-002", "UI-003", "UI-004"]
---

# 03-ui-ux/design-system-and-tokens (UI-001..UI-004)

## Context
- brand_identity: `Concept E2 Feather-in-Inverted-Triangle Logo (logo-e2-refined.svg: #0B0614 Ground, #A78BFA Stroke, #C4B5FD->#7C3AED Gradient) + macOS/iOS AppIcon.appiconset`
- ui_stack: `Zed-Minimal Purple (Viola) Workspace Chrome + Pure #FFFFFF/#000000 Inverted TextKit 2 Editor Canvas + 50%..300% Zoom Mode`

## Rules
- **UI-001**: The `SwiftEditUI` workspace shell and `Assets.xcassets` catalog SHALL adopt the Concept E2 Feather-in-Triangle brand icon (`macos/AppIcon.appiconset` 10 PNGs `16..1024 px` with outer alpha and `ios/AppIcon.appiconset` 8 opaque `#0B0614` PNGs `40..1024 px`) and render a Zed-minimal layout styled with semantic Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome across `Light`, `Black`, and `Auto` modes.
- **UI-002**: The `SwiftEditUI` file editor canvas SHALL enforce a pure white (`#FFFFFF`) background with pure black (`#000000`) primary text in `Light` mode and an inverted pure black (`#000000`) background with pure white (`#FFFFFF`) primary text in `Black` (Dark) mode using monospaced typography on a `4pt` chrome grid.
- **UI-003**: WHEN the appearance switches between `Light`, `Black`, `Auto`, or Increased Contrast modes, `SwiftEditUI` SHALL update all Purple chrome tokens and invert the `#FFFFFF`/`#000000` editor canvas dynamically without reloading open buffers.
- **UI-004**: The `SwiftEditUI` editor viewport SHALL support Zoom Mode scaling buffer font rendering from `50%` to `300%` via `Cmd++`, `Cmd+-`, `Cmd+0`, and trackpad pinch gestures alongside distraction-free pane focus zoom without mutating document text.
