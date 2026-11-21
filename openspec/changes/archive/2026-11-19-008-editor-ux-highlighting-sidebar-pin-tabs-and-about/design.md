# Design: PH.SwiftEdit Editor UX, Highlighting, Percentage-Resized Collapsible Sidebar, Tab Reordering & Help About Integrations

## Context
`PH.SwiftEdit` is a Swift 6 (`-strict-concurrency=complete`) minimalist sandboxed macOS/iOS-ready text and Markdown editor composed of `SwiftEditCore` (`Foundation` + `swiftlang/swift-markdown` only) and `SwiftEditUI` (`SwiftUI` + `#if os(macOS)` `AppKit`/TextKit 2). Following changes `000..007`, all foundational storage, gutter, menu, and sidebar-action engines exist, but 13 concrete UX gaps and bugs remain across appearance switching, Markdown editing ergonomics, visual TextKit 2 decorations, percentage-based sidebar layout, tab reordering, brand logo integration, and the `Help -> About` dialog.

## Goals / Non-Goals
- Goals:
  - Fix the Light / Dark / Auto appearance selector so all 3 modes are always visible, selectable, and dynamically synchronized with live macOS `@Environment(\.colorScheme)` (`[UI-001]`, `[UI-003]`).
  - Deliver deterministic Markdown Enter continuation (`-`, `*`, `+`, `- [ ]`, incremented `N.`/`N)`, `>`) with empty-marker exit and fenced-block suppression (`[BC-004]`, `[BC-006]`).
  - Render non-mutating visual highlights in TextKit 2 for the current line (`#161224` Dark / `#F3F0FA` Light), nested depth-colored brackets (`{}`, `[]`, `()`), active/unbalanced brackets, and inline/multiline backticks (`[AR-012]`, `[UI-002]`, `[UI-005]`, `[UI-006]`).
  - Upgrade the left sidebar with manual `pin`/collapse + reopen handle, **strictly percentage-based** width ratio (`12%..65%` of container width, zero hardcoded pixel min/max caps across displays), zoom scaling (`50%..300%`), disabled gray binary rows (`#9CA3AF` Dark / `#52525B` Light), and right-click Create File/Folder prompts on both items and empty space (`[DATA-003]`, `[SEC-003]`, `[UI-001]`, `[UI-004]`).
  - Support left/right tab reordering in `WorkspaceTabSession` and `EditorTabStrip`, hover-revealed top-bar command buttons with persistent Logo/Zoom/Theme, pure SwiftUI Concept E2 vector logo, and `Help -> About PH.SwiftEdit` including validated repository and MIT License links (`[AR-014]`, `[BC-008]`, `[SEC-004]`, `[UI-001]`).
- Non-Goals:
  - Full Language Server Protocol (LSP), multi-language syntax tree highlighting beyond brackets and backticks, WebKit rendering, database persistence, or external SwiftPM packages outside `swiftlang/swift-markdown` (`[AR-005]`, `[BC-005]`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: Pure scanning, Markdown continuation, tab reordering, and confined binary probing reside exclusively in `SwiftEditCore` (`Foundation` + `Markdown` only, zero `AppKit`/`SwiftUI`). Visual TextKit 2 highlighting (`SwiftEditNSTextView`), percentage sidebar geometry, hover toolbar, vector Concept E2 logo, and `Help -> About` reside in `SwiftEditUI` isolated behind `#if os(macOS)` where `AppKit` is used (`[AR-001]`, `[AR-002]`, `[AR-003]`).
- **AR-018**: `SwiftEditWorkbenchModel` acts strictly as a `@MainActor` presentation coordinator invoking pure `SwiftEditCore` value types and injecting `FileSystemProviding`/`DesktopWorkspaceIntegrating` seams without duplicating domain validation logic or mutating disk directly (`[BC-001]`, `[BC-004]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**:
  - `openspec/constitution/01-architecture/module-topology.md` (`[AR-001]..[AR-005]`)
  - `openspec/constitution/02-domain/bounded-context-ownership.md` (`[BC-001]..[BC-004]`)
  - `openspec/constitution/03-ui-ux/design-system-and-tokens.md` (`[UI-001]..[UI-004]`)
  - `openspec/constitution/06-testing-fitness/tdd-and-unit-testing.md` (`[TEST-001]..[TEST-004]`)
  - `openspec/constitution/07-security-privacy/authn-authz-and-boundaries.md` (`[SEC-001]..[SEC-004]`)
  - `openspec/constitution/08-sdd-governance/artifact-traceability.md` (`[SDD-001]..[SDD-004]`)
- **Bounded Context Classification (`[BC-002]`)**:
  - `MarkdownLintAndFormat` — **Core**: adds `MarkdownSmartNewlineEngine` (pure value-type Enter continuation).
  - `SearchDiffAndBracketEngine` — **Supporting**: extends `BracketMatcher` (`nestingDepth`, `enclosingPairs`) and adds `BacktickHighlightScanner` (inline + multiline backtick spans).
  - `WorkspaceAndTabSession` — **Supporting**: extends `WorkspaceTabSession` (`moveTab*`) and `DotfileFolderNavigator` (`FolderEntryDescriptor.isBinary`).
  - `SwiftEditUI` — **Presentation Shell**: theme selector, visual TextKit 2 highlighter, percentage sidebar layout, hover topbar, vector brand logo, and `Help -> About`.

## Decisions
- **KISS-First Pure Scanners Without Backtracking Regexes (`[BC-011]`, `[SEC-012]`)**: Both `BacktickHighlightScanner` and `MarkdownSmartNewlineEngine` are implemented as single-pass UTF-16 value-type state machines in `SwiftEditCore`. This avoids regex ReDoS risk, guarantees `< 1 ms` evaluation on typical buffers, and makes unit testing completely deterministic and parallel-safe (`[TEST-002]`, `[TEST-003]`).
- **Additive Backward-Compatible `BracketPairSpan` & `FolderEntryDescriptor` Extensions (`[AR-004]`)**: Adding `nestingDepth: Int = 0` to `BracketPairSpan`, `enclosingPairs: [BracketPairSpan] = []` to `BracketBalanceResult`, and `isBinary: Bool = false` to `FolderEntryDescriptor` preserves source compatibility across all existing `SwiftEditTests` suites while exposing rich metadata for UI rendering.
- **Explicit 3-Button Appearance Selector + Live `@Environment(\.colorScheme)` Sync (`[UI-001]`, `[UI-003]`)**: Replacing the fixed-width SwiftUI segmented `Picker` (which clipped on macOS 26 when unlabeled inside an `HStack`) with an explicit 3-segment button group (`Light`, `Dark`, `Auto`) styled with Concept E2 Purple tokens guarantees visibility and immediate responsiveness. `SwiftEditRootView` observes `@Environment(\.colorScheme)` via `.onAppear`/`.onChange` calling `model.updateSystemColorScheme(prefersDark:)` and applies `.preferredColorScheme` when `.light` or `.black` is selected.
- **Non-Mutating TextKit 2 Visual Highlighting (`[UI-002]`, `[UI-005]`, `[UI-006]`, `[UI-012]`)**: `SwiftEditNSTextView` (subclassing `NSTextView` constructed with `usingTextLayoutManager: true`) draws the full-width current-line highlight in `drawBackground(in:)` (`#161224` Dark / `#F3F0FA` Light) and applies bracket/backtick colors via `textLayoutManager?.setRenderingAttributes(...)` (never mutating `NSTextStorage` string content or polluting undo history). Base canvas remains strictly `#FFFFFF`/`#000000` (`[UI-002]`).
- **Strictly Percentage-Based Sidebar Geometry (`SidebarLayoutGeometry`, `[UI-001]`)**: Instead of fixed pixel `.frame(minWidth: 190, maxWidth: 320)` bounds that break across Retina/external displays, `SidebarLayoutGeometry` stores `sidebarWidthRatio: Double` clamped to `0.12...0.65` (default `0.22`) and computes `resolvedWidth = containerWidth * clampedRatio` inside `GeometryReader` with a custom draggable percentage divider. A manual `pin` button in the sidebar header collapses/expands the sidebar cleanly while exposing a compact left-edge reopen button when collapsed.
- **Pure SwiftUI Vector Concept E2 Logo (`SwiftEditBrandLogoView`, `[UI-001]`)**: Rendering the exact `docs/design/assets/logo-e2-refined.svg` geometry natively via SwiftUI `Canvas`/`Shape` guarantees razor-sharp scaling at `20pt` (top bar) and `84pt` (About sheet) across both SwiftPM headless tests and the bundled `.app` without runtime image-asset lookup fragility.
- **Hover-Revealed Top Bar Respecting Reduce Motion (`[UI-001]`, `[UI-011]`)**: The top bar uses `.onHover` to toggle `isToolbarHovered`, revealing the middle command buttons (`Folder…`, `File…`, `New`, `Save`, `Cmd+D`, `Format`, `Preview`, `Compare Diff`, `Shortcuts`) while keeping Logo + `PH.SwiftEdit` (left) and Zoom + `Light`/`Dark`/`Auto` (right) permanently visible. Transitions honor `@Environment(\.accessibilityReduceMotion)` (`[UI-011]`).

## Risks / Trade-offs
- **TextKit 2 Rendering Attributes vs Large Files** -> Cap scanning at `4096` UTF-16 code units per line and skip highlighting on degraded (`> 10 MiB`) or binary snapshots to protect the `<= 16 ms` P99 keystroke budget (`[UI-012]`).
- **Shallow Listing I/O Overhead From Binary Probing** -> Read strictly at most `DocumentCodec.binaryProbeBytes` (`8 KiB`) per regular file using `FileHandle`/bounded `readData(maxBytes:)` only after symlink confinement passes; skip directories immediately.
- **Custom Percentage Divider vs `HSplitView` Fixed Pixel Constraints** -> Replace `HSplitView` for the outer sidebar/editor split with a `GeometryReader`-driven `HStack` + draggable divider updating `sidebarWidthRatio` directly in percentage terms, eliminating AppKit's fixed pixel clamp quirks when moving windows across displays.
- **Tab Drag-and-Drop Accessibility** -> Provide BOTH `.draggable`/`.dropDestination` drag-and-drop AND explicit Move Left / Move Right context-menu/keyboard actions so tab reordering works with mouse, keyboard, VoiceOver, and headless unit tests (`[UI-010]`).

## Migration Plan
1. Implement and test `SwiftEditCore` pure engines first (`BracketMatcher` depth, `BacktickHighlightScanner`, `MarkdownSmartNewlineEngine`, `WorkspaceTabSession` reorder, `DotfileFolderNavigator` binary probe) via parallel `swift test`.
2. Implement and test `SwiftEditUI` value-type projections and theme/zoom/layout/about descriptors (`PurpleThemePalette`, `EditorZoomController`, `SidebarLayoutGeometry`, `SwiftEditBrandLogoGeometry`, `AboutSheetDescriptor`, `SwiftEditWorkbenchModel`) via headless parallel `swift test`.
3. Wire `SwiftEditRootView`, `SwiftEditNSTextView`, `SwiftEditBrandLogoView`, `AboutSheetView`, `KeyboardShortcutsCheatSheetView`, and `SwiftEditCommands` (`Help -> About`).
4. Run full `swift test` regression suite + `ArchitectureFitnessTests` + `ConstitutionFitnessTests` to confirm zero regressions across all 24+ suites.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-19
- Verdict: approved
- Open items: none
