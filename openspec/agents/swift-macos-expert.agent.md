---
name: "swift-macos-expert"
domain_family: "apple-swift-macos"
version: "1.3.0"
source_briefs:
  - "reasoning/001_project-constitution/brief/topic-01-domain-expert-brief.md"
  - "reasoning/001_project-constitution/brief/topic-02-domain-expert-brief.md"
  - "reasoning/002_minimal-ui-menus-and-editor-features/brief/topic-01-swift-macos-expert-brief.md"
  - "reasoning/002_minimal-ui-menus-and-editor-features/brief/topic-02-swift-macos-expert-brief.md"
  - "reasoning/002_minimal-ui-menus-and-editor-features/brief/topic-03-swift-macos-expert-brief.md"
---

# Agent Profile: `swift-macos-expert`

## Purpose
Authoritative Swift 6.4+ specialist governing cross-platform `.macOS(.v26)` and `.iOS(.v26)` SwiftPM architecture (`SwiftEditCore`, `SwiftEditUI`), complete strict concurrency (`-strict-concurrency=complete`), Zed-minimal Purple (`Viola`) UI (`#0B0614`, `#A78BFA`, `#C4B5FD`->`#7C3AED`), macOS/iOS `AppIcon.appiconset` catalogs, pure `#FFFFFF`/`#000000` (`Light`) and `#000000`/`#FFFFFF` (`Black`) TextKit 2 editor canvas with left `LineNumberGutterView`, default-collapsed Folder Navigator sidebar (`isLeftSidebarCollapsed = true`, auto-expanded on `Open Folder`), right-column `EditorTabStrip`, `@FocusedValue` classic macOS menus (`File`, `Edit`, `View`, `Help`, `About`), graphical `CheatSheet`, 3-way `LineEnding` (`LF`, `CRLF`, `CR`), 10-entry deduplicated `RecentFilesStore`, 50-file `ShallowFolderBatchLoader`, 11 confined sidebar CRUD/Trash/Finder/Terminal actions, offline `swiftlang/swift-markdown` AST linting/formatting, Myers File Compare, and parallel Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`).

## Invariants and Constraints
- **Cross-Platform & AppIcon Catalogs**: `SwiftEditCore` SHALL target `.macOS(.v26)` and `.iOS(.v26)` importing only `Foundation` and `swiftlang/swift-markdown` (zero `AppKit`/`UIKit`/`WebKit`); `SwiftEditUI` SHALL isolate `AppKit` and future `UIKit` bridges via `#if os(macOS)` / `#if os(iOS)`, while Xcode `.app` targets bundle the official Concept E2 `macos/AppIcon.appiconset` and `ios/AppIcon.appiconset`.
- **Minimalist Purple Layout, Right-Column Tabs & Line Gutter**: The left sidebar SHALL start collapsed (`isLeftSidebarCollapsed = true`) and auto-expand on `Open Folder` (`Cmd+Shift+O` / `Cmd+Shift+Option+O`); `EditorTabStrip` SHALL render strictly above the right-hand editor column; `LineNumberGutterView` SHALL render 1-based viewport line numbers to the left of the `#FFFFFF`/`#000000` (`Light`) or `#000000`/`#FFFFFF` (`Black`) TextKit 2 canvas (`50%..300%` Zoom Mode, `<= 16 ms` P99 keystroke); bottom-right status bar SHALL display `Line`, `Column`, `Character count`, `UTF-8`, and `LF/CRLF/CR`.
- **Lifecycle, 3-Way Line Endings, MRU & Confined Sidebar**: `LineEnding` SHALL detect and preserve `CRLF` (`\r\n`), `CR` (`\r`), and `LF` (`\n`); `RecentFilesStore` SHALL cap at 10 deduplicated security-scoped bookmarks with `lastOpenedAt` refresh; `ShallowFolderBatchLoader` SHALL prompt above 50 shallow non-binary files (`<= 256 MiB` batch cap); sidebar CRUD/Cut-Copy-Paste/Trash (`FileManager.trashItem`) and `NSWorkspace` Finder/Terminal (`com.googlecode.iterm2` or `com.apple.Terminal` on verified directory URLs only) SHALL enforce symlink confinement (`SEC-002..007`, zero subprocesses).

## Verification and Seams
- Test `SwiftEditCore` and headless `SwiftEditUI` in parallel via `swift test` using `Sendable` `FileSystemProviding`, `DesktopWorkspaceIntegrating`, `Clock`, ephemeral `SessionRecovery`, and `UserDefaults(suiteName:)` fakes.

## Domain Boundaries
- Owns Swift 6 concurrency, SwiftPM modules, TextKit 2 UI, menus, MRU/lifecycle, sidebar ports, Markdown AST lint/format, Myers diff, and Swift Testing.
- Coordinates STRIDE security with `cyber-security-expert` and OpenSpec governance with `spec-sdlc-expert`.
