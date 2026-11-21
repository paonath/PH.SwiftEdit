# Proposal: Two-Speed GFM TextKit 2 Editor, Markdown CommandMenu, GFM Table Tab and Cmd+P Zero-WebKit Native Preview

## Why
Markdown editing in `PH.SwiftEdit` lacks GFM highlighting, authoring shortcuts, table navigation, and a preview, while the editor suffers six per-keystroke stalls (eager gutter `VStack`, immediate `SessionRecovery` writes, transient coordinator allocation in `body`). The preview must stay offline and inert (`[SEC-004]`, `[UI-002]`, `[UI-012]`).

## What Changes
- Add pure `MarkdownSyntaxHighlighter` in `SwiftEditCore` tokenizing 12 GFM constructs for the visible range only with an `O(log F)` fence index, zero regex, and a `4096` UTF-16 line cap; `21:1` prose is preserved (`[AR-002]`, `[BC-004]`, `[SEC-012]`).
- Add `MarkdownAuthoringCommands` and `GFMTableEditEngine`: Bold, Italic, Strike, Code, Fence, Link, Image, Task, Quote, Headings, Insert Table as single edit batches; table `Tab`/`Shift+Tab` pads columns and navigates cells (`[BC-006]`, `[UI-007]`).
- Add `MarkdownPreviewProjector` producing a `GFMPreviewDocument` only while `showMarkdownPreview == true`, with inert raw HTML (`[SEC-004]`).
- Add `PreviewResourceAndLinkGate`: local raster images confined through `FileSystemProviding` (5 gates, downsampled), remote/`data:`/SVG blocked, links mediated by `prepareExternalURIConfirmation` (`[SEC-002]`, `[SEC-003]`, `[SEC-004]`).
- Wire `TextKit2EditorView` (`renderingAttributesValidator`, Tab chain `Ctrl+Tab` > fence > table > list > default), `CommandMenu("Markdown")`, `MarkdownNativePreviewView` with `sourceLine` scroll sync, `LazyVStack` gutter, `500 ms` debounced `SessionRecovery`, and remove the transient coordinator allocation (`[AR-003]`, `[UI-005]`, `[UI-012]`).

## Capabilities
- New Capabilities: `textkit2-gfm-editor-and-native-preview`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `MarkdownLintAndFormat` (`SwiftEditCore`, Core) owns GFM tokenization, authoring edits, table edits, preview projection, and resource/link admission; `SwiftEditUI` (Presentation) only renders attributes and views and applies returned edits.
- **Owned Decisions**: Which spans a construct receives, which edit a shortcut yields, table cell navigation, which images/links are admitted, and when projection runs.
- **Forbidden Responsibilities**: The engines MUST NEVER open sockets, decode SVG/PDF, read outside the granted scope, mutate binary or degraded buffers, interpret raw HTML, or import `AppKit`/`UIKit`/`SwiftUI`/`WebKit` in `SwiftEditCore` (`[AR-002]`, `[BC-011]`, `[DATA-003]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `TextRange`, `grantedScopeRootURL`.

## Impact
- **Production Modules (`SwiftEditCore`)**:
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownSyntaxHighlighter.swift` (new)
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAuthoringCommands.swift` (new, includes `GFMTableEditEngine`)
  - `Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownPreviewProjector.swift` (new, includes resource and link gate)
- **Production Modules (`SwiftEditUI`)**:
  - `Sources/SwiftEditUI/Views/TextKit2EditorView.swift` (extracted from `SwiftEditRootView.swift`)
  - `Sources/SwiftEditUI/Views/MarkdownNativePreviewView.swift` (new)
  - `Sources/SwiftEditUI/Views/SwiftEditCommands.swift`, `SwiftEditRootView.swift`, `LineNumberGutterView.swift`
  - `Sources/SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift`
- **Test Suites**: new `MarkdownSyntaxHighlighterTests`, `MarkdownAuthoringAndTableTests`, `MarkdownPreviewProjectorAndGateTests`; updated `TextKit2EditorAndDiffCoordinatorTests.swift`.
- **External Dependencies**: `swift-markdown` (already present), system `ImageIO`; no new packages (`[AR-005]`).

## Security Impact
- **Zero Socket (`[SEC-004]`)**: remote and `data:` images never load; `AsyncImage` is banned.
- **Confinement (`[SEC-002]`, `[SEC-003]`)**: local images resolve through `FileSystemProviding` inside the granted scope; traversal and symlink escapes raise `securityScopeViolation`.
- **Resource Bounds (`CWE-400`, `[SEC-012]`)**: line, table, image-size, pixel, and image-count caps.
- **Inert Content (`CWE-79` analogue, `CWE-451`)**: raw HTML renders as monospaced text; links need user confirmation.

## Metadata
- Owner: swift-macos-expert
- Domain: apple-swift-macos
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: AR-002, AR-003, AR-005, AR-006, AR-008, AR-009, BC-001, BC-004, BC-006, BC-011, DATA-003, SEC-002, SEC-003, SEC-004, SEC-009, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, UI-002, UI-005, UI-007, UI-012, SDD-001, SDD-002, SDD-003
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`, active)
- `openspec/changes/archive/2026-11-20-011-adaptive-markdown-lists-tab-indentation` (archived; `Tab` list engine)
- `openspec/changes/archive/2026-11-20-010-translucent-header-brand-submenu` (archived; `Cmd+P` binding)
- `openspec/changes/archive/2026-11-19-009-full-app-semantic-theming-and-window-sync` (archived; palette tokens)
- `openspec/briefs/brief-textkit2-gfm-editor-and-native-preview.md`
