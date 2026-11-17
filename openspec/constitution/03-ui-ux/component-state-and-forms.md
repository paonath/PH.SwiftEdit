---
area: "03-ui-ux"
file: "component-state-and-forms.md"
rules: ["UI-005", "UI-006", "UI-007", "UI-008"]
---

# 03-ui-ux/component-state-and-forms (UI-005..UI-008)

## Context
- state_model: `@MainActor @Observable Coordinators + NSTextContentStorage Single Source of Truth`
- markdown_renderer: `Native swift-markdown AST -> SwiftUI / AttributedString (Raw HTML as Inert Plain Text)`

## Rules
- **UI-005**: The `SwiftEditUI` target SHALL annotate every `@Observable` view model, document coordinator, and `NSViewRepresentable.Coordinator` class with explicit `@MainActor` isolation.
- **UI-006**: The `NSTextView` and preview adapters SHALL keep live text inside `NSTextContentStorage` without per-keystroke SwiftUI `String` copies while projecting `swift-markdown` AST nodes natively with raw HTML rendered as inert plain text.
- **UI-007**: WHEN syntax highlighting or search match attributes update, the TextKit 2 adapter SHALL apply mutations exclusively to dirty paragraph or visible `NSTextViewportLayoutController` ranges inside `NSTextContentStorage.performEditingTransaction` after verifying `BufferRevision` equality.
- **UI-008**: WHEN a buffer contains Unicode bidirectional control characters (`U+202A..U+202E`, `U+2066..U+2069`, `U+061C`) or an external Markdown link is activated, `SwiftEditUI` SHALL display inline control-code badges with a warning banner and require canonical URI confirmation before `NSWorkspace.shared.open`.
