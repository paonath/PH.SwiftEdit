---
area: "03-ui-ux"
file: "component-state-and-forms.md"
rules: ["UI-005", "UI-006", "UI-007", "UI-008"]
---

# 03-ui-ux/component-state-and-forms (UI-005..UI-008)

## Context
- state_model: `@MainActor @Observable Coordinators + TextKit 2 NSTextContentStorage Single Source of Truth`
- inspection_and_diff: `Native swift-markdown Preview/Lint, (){}[] Bracket Highlighting, VS Code Side-by-Side/Inline Diff, Binary Warning Banner`

## Rules
- **UI-005**: The `SwiftEditUI` target SHALL annotate every `@Observable` view model, tab session coordinator, diff coordinator, and `NSViewRepresentable` or `UIViewRepresentable` coordinator class with explicit `@MainActor` isolation.
- **UI-006**: The TextKit 2 editor and preview adapters SHALL keep live text inside `NSTextContentStorage` without per-keystroke SwiftUI `String` copies while projecting `swift-markdown` AST previews natively with raw HTML displayed as inert plain text.
- **UI-007**: WHEN syntax highlights, Markdown lint markers, live `(){}[]` bracket-pair highlights, search matches, or Side-by-Side and Inline diff highlights update, the TextKit 2 adapter SHALL apply mutations exclusively to dirty paragraph or visible `NSTextViewportLayoutController` ranges inside `NSTextContentStorage.performEditingTransaction`.
- **UI-008**: WHEN a file is classified as binary or contains Unicode bidirectional control characters (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`), `SwiftEditUI` SHALL render a transient read-only binary inspection view with a prominent warning banner (disabling Save, Format, and Pin Tab) or inline BiDi control-code badges while requiring canonical URI confirmation before opening external links.
