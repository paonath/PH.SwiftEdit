---
area: "03-ui-ux"
prefix: "UI"
status: "active"
owners: ["swift-macos-expert"]
---

# Native macOS UI, TextKit 2 & Accessibility Mini-Index (`03-ui-ux/`)

## Micro-Files

| Micro-File | Rule IDs | Scope & Inspection Triggers |
| :--- | :--- | :--- |
| `design-system-and-tokens.md` | `UI-001..UI-004` | Semantic `NSColor`/SwiftUI `Color` tokens, monospaced typography, `4pt` grid, Light/Dark/Increased-Contrast |
| `component-state-and-forms.md` | `UI-005..UI-008` | Explicit `@MainActor` `@Observable` state, `NSTextContentStorage` buffer truth, viewport transactions, Trojan Source badges |
| `accessibility-and-cwv.md` | `UI-009..UI-012` | `>= 4.5:1` contrast, VoiceOver & keyboard navigation, Reduce Motion, `<= 150 ms` cold start & `<= 16 ms` keystroke budget |
