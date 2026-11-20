# Proposal: Debug Hardening, Click-Only Accessible Usability & Automated 3x QA Verification

## Why
A full 3x live Debug `.app`, Swift Testing, AX/CGEvent GUI, microbenchmark, and `/usr/bin/leaks` audit recorded in [debug-audit-report-2026-11-20.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/docs/qa/debug-audit-report-2026-11-20.md) uncovered 33 concrete defects: a P0 live `SIGSEGV` use-after-free in `-[_NSUndoStack popAndInvoke]` (`BUG-001`), ignored external Finder `open-doc` launches (`BUG-002`), silent data loss on `Cmd+Q` with dirty tabs (`BUG-003`), broken Undo on `Cmd+D`/programmatic edits (`BUG-005`), a `180 ms` auto-dismissing header logo submenu impossible for humans or keyboard users to click reliably (`BUG-006`), `964 ms` main-thread freezes at `20,000` lines that silently drop `.unsafeLinkScheme` XSS lint errors (`PERF-006`), `71 ms` caret lags (`PERF-007`), `41–91 s` test suite runs (`TEST-001`), and rendering/lifecycle bugs across preview, diff, gutter, CR line endings, binary tabs, and symlink handling (`[BC-001]`, `[DATA-003]`, `[SEC-003]`, `[UI-012]`).

## What Changes
- **Wave 1 — Stability & Data Integrity (`P0`/`P1`)**: Assign an isolated `NSUndoManager` per tab `DocumentID` with `TextKit2EditorView.dismantleNSView` teardown (`BUG-001`, `BUG-021`); convert programmatic text mutations (`Cmd+D`, SmartNewline, Format, Markdown authoring) to undo-safe `shouldChangeText`/`replaceCharacters`/`didChangeText` preserving full `NSRange` (`BUG-005`); add `@NSApplicationDelegateAdaptor` (`SwiftEditAppDelegate`) handling Finder `application(_:open:)`, multi-tab exhaustive dirty `Cmd+Q` prompting, and clean `NSRunningApplication.terminate()` (`BUG-002`, `BUG-003`, `BUG-010`); isolate transient binary inspection outside persistent tab/baseline retention (`BUG-007`, `MEM-002`).
- **Wave 2 — Usability, Accessibility & Hot-Path Latency (`P1`/`PERF-004`/`PERF-006`/`PERF-007`)**: Convert `HeaderSubmenuStateMachine` and `HeaderBrandSubmenuView` to **click/keyboard-only** activation (zero hover auto-open, zero hover auto-close timers, zero 20ms `.task` polling, trigger-non-occluding backdrop below exact `topBarHeight`, hover/focus row highlight, arrow/Home/End/Return/Escape navigation, VoiceOver `Expanded`/`Collapsed` traits) (`BUG-006`, `PERF-004`); move `Find and Replace…` from `Cmd+H` to `Opt+Cmd+F` (`BUG-004`), remove duplicate `Redo` (`BUG-011`), add `@FocusState` auto-focus + single `Replace` + `programmaticSelectionToken` jump + editor focus return (`BUG-008`, `BUG-009`); synchronize `LineNumberGutterView` scroll/soft-wrap positions and highlight full wrapped paragraphs (`BUG-012`, `BUG-013`); offload full AST linting to revision-guarded background tasks with a bounded security URI/image pass so typing/caret P99 stay `<= 16 ms` without silently disabling `.unsafeLinkScheme` (`PERF-006`, `PERF-007`).
- **Wave 3 — Preview, Diff, CR Endings, Sidebar Security & Memory (`P2`/`PERF-001`/`PERF-002`/`PERF-005`/`MEM-001..004`)**: Enforce document-wide `64`-image preview cap + ordered numerals (`BUG-014`), stop HTML blocks before adjacent GFM tables (`BUG-019`), invalidate `MarkdownLineIndex` by `(DocumentID, BufferRevision)` (`BUG-015`), normalize `activeSeparator` + multi-separator `previewSourceLine` (`BUG-016`), add `DiffHunkKind.modified` LHS/RHS highlighting (`BUG-020`), add `.skipAndReport` child-symlink sidebar policy (rejecting before `8 KiB` probe + warning banner while preserving `.failClosed` default) + configurable `PreferredTerminalApp` (`BUG-017`), single-pass viewport rendering attributes (`PERF-001`), async bounded `NSCache` thumbnails (`PERF-002`), off-MainActor large-file loading (`PERF-005`), and idle/post-sweep memory ceiling controls (`MEM-001`, `MEM-003`, `MEM-004`).
- **Wave 4 — Build Hygiene, Fast Tests & Automated 3x Verification (`P3`/`PERF-003`/`TEST-001`)**: Inject `PreferencesProviding` seam (`InMemoryKeyValueStore` across 11 test suites eliminating 31 `removePersistentDomain` `cfprefsd` stalls; container-aligned suite in prod) (`PERF-003`, `TEST-001`), align `About` fallback `"0.0.1-alpha5"`, expand CheatSheet, fix 3 Xcode build warnings (`BUG-018`), and execute a final mandatory **Automated Debug Audit Verification** re-running the full 3x playbook in [macos-debug-audit-playbook.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/.agents/Memories/macos-debug-audit-playbook.md).

## Capabilities
- New Capabilities: `debug-hardening-usability-and-automated-qa`
- Modified Capabilities: `translucent-header-brand-submenu`, `editor-ux-highlighting-sidebar-pin-tabs-and-about`, `ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`, `textkit2-gfm-editor-and-native-preview`, `comprehensive-markdown-linter-and-diagnostics-ui`, `markdown-lint-format-bracket-and-diff`, `document-core-and-spm-scaffold`, `notepadpp-tabs-session-recovery-and-dotfiles`

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: Each domain policy stays confined to its authoritative context: `DocumentCore` owns line endings, cursor metrics, and single-revision edits; `MarkdownLintAndFormat` owns AST rules, security URI/image fast-paths, preview projection, and bounded image budgeting; `SearchDiffAndBracketEngine` owns bracket cache topology and `.modified` Myers alignment; `WorkspaceAndTabSession` owns symlink policies and preferences; `SwiftEditUI`/`XcodeApp` own AppDelegate lifecycle, per-tab `NSUndoManager`, focus, and click-only header menu state.
- **Owned Decisions**: Per-tab undo ownership, click-only menu visibility transitions, multi-tab dirty quit resolution order, async lint revision validity, modified diff classification, and escaping child symlink skipping with audit warning count.
- **Forbidden Responsibilities**: UI and coordinator layers MUST NEVER hold retained binary snapshots in `sessionsByID` after switch/close, MUST NEVER suppress `.unsafeLinkScheme`/`.unsafeImagePath` errors, MUST NEVER probe escaping symlink bytes, and `SwiftEditCore` MUST NEVER import `AppKit`, `UIKit`, `SwiftUI`, or `WebKit` (`[AR-002]`, `[BC-011]`).
- **External Decision References**: `DocumentID`, `BufferRevision`, `TextRange`.

## Impact
- **Target Apps & Packages**: `XcodeApp/` (`SwiftEditApp.swift`, `project.pbxproj`), `Sources/SwiftEditCore/` (`DocumentCore`, `MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, `WorkspaceAndTabSession`), `Sources/SwiftEditUI/` (`Views`, `Coordinators`, `Workspace`), `Tests/SwiftEditTests/` (new & updated suites, including replacing 31 `removePersistentDomain` calls across 11 files).
- **Dependencies**: None external (`swift-markdown` only, `[AR-005]`).

## Security Impact
- Eliminates heap use-after-free crash `CWE-416` (`BUG-001`) via isolated per-tab `NSUndoManager` and deterministic `dismantleNSView` teardown.
- Restores `.unsafeLinkScheme` / `.unsafeImagePath` XSS and traversal detection on large `5kL–20kL` Markdown documents where synchronous timeout previously discarded all diagnostics (`PERF-006`).
- Closes `CWE-400` resource cap bypass (`BUG-014` 70/64 preview images) and guarantees zero `8 KiB` byte reads on escaping child symlinks (`BUG-017`, `CWE-59`, `SEC-003`) plus immediate quarantine disposal of binary inspection buffers (`MEM-002`, `DATA-003`).
- Validates sandboxed Finder `open-doc` inputs (`BUG-002`) and preserves strict Terminal bundle allowlisting (`com.googlecode.iterm2`, `com.apple.Terminal`, `SEC-004`).

## Metadata
- Owner: swift-macos-expert
- Domain: Debug Hardening, Accessibility, Performance, Memory & Automated QA
- Reviewer: cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: translucent-header-brand-submenu (REQ-001, REQ-002), editor-ux-highlighting-sidebar-pin-tabs-and-about (REQ-006, REQ-007), ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions (REQ-001, REQ-003, REQ-004, REQ-005), textkit2-gfm-editor-and-native-preview (REQ-004, REQ-005, REQ-006), comprehensive-markdown-linter-and-diagnostics-ui (REQ-001, REQ-003), markdown-lint-format-bracket-and-diff (REQ-003, REQ-004), document-core-and-spm-scaffold (REQ-004), notepadpp-tabs-session-recovery-and-dotfiles (REQ-004)
- Constitutional-Rules: AR-006, AR-007, AR-008, AR-009, AR-010, BC-001, BC-002, BC-003, BC-004, DATA-001, DATA-002, DATA-003, DATA-004, UI-009, UI-010, UI-011, UI-012, TEST-001, TEST-002, TEST-003, TEST-004, SEC-001, SEC-002, SEC-003, SEC-004, SDD-001, SDD-002, SDD-003, SDD-004
- Amends-Constitution: none

## Prerequisites
- `openspec/Constitution.md` (`v1.3.0`)
- [debug-audit-report-2026-11-20.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/docs/qa/debug-audit-report-2026-11-20.md)
- [macos-debug-audit-playbook.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/.agents/Memories/macos-debug-audit-playbook.md)
- `openspec/briefs/brief-debug-hardening-usability-and-automated-qa.md`
