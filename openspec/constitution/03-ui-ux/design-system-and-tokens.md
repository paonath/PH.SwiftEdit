---
area: "03-ui-ux"
file: "design-system-and-tokens.md"
rules: ["UI-001", "UI-002", "UI-003", "UI-004"]
---

# 03-ui-ux/design-system-and-tokens (UI-001..UI-004)

## Context
- ui_stack: `Native macOS 26+ SwiftUI Shell + AppKit NSTextView / TextKit 2`
- spacing_and_typography: `4pt Grid and NSFont.monospacedSystemFont`

## Rules
- **UI-001**: The `SwiftEditUI` target SHALL resolve all surface, text, selection, and gutter colors exclusively through semantic AppKit `NSColor` and SwiftUI `Color` tokens.
- **UI-002**: The `SwiftEditUI` target SHALL render editor buffers with `NSFont.monospacedSystemFont` or user-configured monospaced fonts while aligning window chrome on a `4pt` spacing grid.
- **UI-003**: WHEN macOS switches between Light, Dark, or Increased Contrast appearances, `SwiftEditUI` SHALL update all semantic chrome and syntax theme tokens dynamically without reloading open document buffers.
- **UI-004**: IF raw hex or RGB color literals appear outside centralized syntax theme definitions, THEN the architectural review gate SHALL reject the change.
