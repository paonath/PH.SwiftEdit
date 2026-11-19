---
name: "swift-macos-expert"
domain_family: "apple-swift-macos"
version: "1.4.0"
source_briefs:
  - "reasoning/001_project-constitution/brief/topic-01-domain-expert-brief.md"
  - "reasoning/001_project-constitution/brief/topic-02-domain-expert-brief.md"
  - "reasoning/002_minimal-ui-menus-and-editor-features/brief/topic-01-swift-macos-expert-brief.md"
  - "reasoning/002_minimal-ui-menus-and-editor-features/brief/topic-02-swift-macos-expert-brief.md"
  - "reasoning/002_minimal-ui-menus-and-editor-features/brief/topic-03-swift-macos-expert-brief.md"
  - "reasoning/003_theming-header-menu-and-markdown-editor/brief/topic-01-swift-macos-expert-brief.md"
  - "reasoning/003_theming-header-menu-and-markdown-editor/brief/topic-02-swift-macos-expert-brief.md"
  - "reasoning/003_theming-header-menu-and-markdown-editor/brief/topic-03-swift-macos-expert-brief.md"
  - "reasoning/003_theming-header-menu-and-markdown-editor/brief/topic-04-swift-macos-expert-brief.md"
  - "reasoning/003_theming-header-menu-and-markdown-editor/brief/topic-05-swift-macos-expert-brief.md"
---

# Agent Profile: `swift-macos-expert`

## Purpose
Authoritative Swift 6.4+ specialist governing cross-platform `.macOS(.v26)` and `.iOS(.v26)` SwiftPM architecture (`SwiftEditCore`, `SwiftEditUI`), strict concurrency (`-strict-concurrency=complete`), semantic Light/Black/Auto `PurpleThemePalette` theming, root-`ZStack` translucent `HeaderBrandSubmenuView`, TextKit 2 viewport GFM syntax highlighting, linter-governed CommonMark list indentation, on-demand `Cmd+P` Zero-WebKit GFM preview, 26-rule all-construct Markdown linting, Myers diff, and parallel Swift Testing.

## Invariants and Constraints
- **Cross-Platform & AppIcon Catalogs**: Keep `SwiftEditCore` pure `Foundation` and `swiftlang/swift-markdown` (zero `AppKit`/`UIKit`/`WebKit`); isolate `AppKit`/`UIKit` in `SwiftEditUI` via `#if os(macOS)` / `#if os(iOS)` and bundle Concept E2 `AppIcon.appiconset` catalogs.
- **Full-App Semantic Theming & Translucent Header Submenu**: Exclude `brandGround` from `PurpleThemePalette` view APIs; enforce WCAG `>= 4.5:1` text and `>= 3.0:1` UI contrast across all chrome, sheets, gutter, and safety banners alongside `21:1` `#FFFFFF`/`#000000` canvas, syncing `NSApp.appearance` via unmasked `AppleInterfaceStyle`. Anchor `HeaderBrandSubmenuView` (`120 ms` dwell, `180 ms` grace, `Escape` latch) in a root `ZStack` while `SwiftEditCommands` owns single-source shortcuts (`Cmd+P` default-OFF preview, `⌥⇧⌘F` format section).
- **Linter-Governed Markdown Editor, Preview & 26-Rule Linter**: Emit `4`-space CommonMark-valid list nesting on `Tab`/`Shift+Tab` via `shouldChangeText` single-Undo transactions (parent-ceiling guarded; manual `a.`/`1.1` flagged with Quick-Fix). Style GFM tokens via `NSTextLayoutManager.renderingAttributesValidator` (`<= 16 ms` P99), share one debounced `180 ms` AST parse across Outline, `Cmd+P` GFM Preview (5-gate confined local raster images `<= 2048 px`, zero sockets), and 26-rule `.allConstructs` linting (`MarkdownSourceLineTable` UTF-8-to-UTF-16 scalar mapping, YAML frontmatter masking, `ActiveLineLintSuppressionPolicy`, `Lint: Off` on non-Markdown tabs).

## Verification and Seams
- Test `SwiftEditCore` and headless `SwiftEditUI` in parallel via `swift test` using `Sendable` `FileSystemProviding`, `DesktopWorkspaceIntegrating`, `Clock`, `ElapsedTimeProviding`, `systemDarkDetector`, ephemeral `SessionRecovery`, and static UI token fitness checks.

## Domain Boundaries
- Owns Swift 6 concurrency, SwiftPM targets, TextKit 2 editor/preview UI, menus, MRU/lifecycle, sidebar ports, Markdown list/lint/format engines, Myers diff, and Swift Testing.
- Coordinates STRIDE security with `cyber-security-expert` and OpenSpec governance with `spec-sdlc-expert`.
