---
id: "brief-debug-hardening-usability-and-automated-qa"
change_id: "015-debug-hardening-usability-and-automated-qa"
capability: "debug-hardening-usability-and-automated-qa"
branch: "feature/FirstStub"
source_report: "docs/qa/debug-audit-report-2026-11-20.md"
modifies_specs:
  - "translucent-header-brand-submenu"
  - "editor-ux-highlighting-sidebar-pin-tabs-and-about"
  - "ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions"
  - "textkit2-gfm-editor-and-native-preview"
  - "comprehensive-markdown-linter-and-diagnostics-ui"
  - "markdown-lint-format-bracket-and-diff"
  - "document-core-and-spm-scaffold"
  - "notepadpp-tabs-session-recovery-and-dotfiles"
status: "approved-via-qa"
date: "2026-11-20"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `015-debug-hardening-usability-and-automated-qa`

## 1. Context & Scope

- **Request**: Consolidate **ALL** findings from [debug-audit-report-2026-11-20.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/docs/qa/debug-audit-report-2026-11-20.md) (`21` bugs `BUG-001..021`, `4` memory findings `MEM-001..004`, `7` performance findings `PERF-001..007`, `TEST-001`), targeted usability & WCAG 2.2 AA accessibility upgrades (including fixing the header brand logo submenu that disappeared before a human could click it), and a mandatory **automated 3x deep debug verification task** re-running [macos-debug-audit-playbook.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/.agents/Memories/macos-debug-audit-playbook.md) inside **one** OpenSpec change (`015-debug-hardening-usability-and-automated-qa`).
- **QA Decisions (Confirmed by User)**:
  1. **Header Brand Submenu (`BUG-006`)**: Switch to **click / keyboard only** (disable hover auto-open AND hover auto-close timers completely; sticky open until outside click, logo re-click, menu item click, `Escape`, or window resign-key; fix click-outside backdrop overlapping the trigger and align `toolbarBar` `topBarHeight` with panel offset; add hover/focus row highlight, arrow/Home/End/Return/Escape navigation, and VoiceOver `Expanded`/`Collapsed` traits).
  2. **Sidebar Escaping Symlinks (`BUG-017`)**: Preserve `DotfileFolderNavigator` default `.failClosed` contract (`SEC-003`) and add `.skipAndReport` for sidebar folder browsing so escaping child symlinks are rejected before `8 KiB` binary probing, excluded cleanly, and surfaced in a non-destructive UI banner while folder-root escapes still throw `DomainError.securityScopeViolation`.
- **Governing Rules**: `AR-006..010`, `BC-001..004`, `DATA-001..004`, `UI-009..012`, `TEST-001..004`, `SEC-001..004`, `SDD-001..004`.

## 2. Expert Notes (`swift-macos-expert` & `cyber-security-expert`)

- **Wave 1 — Crash, Data Loss & External Launch (`BUG-001`, `BUG-002`, `BUG-003`, `BUG-005`, `BUG-007`, `BUG-010`, `BUG-021`, `MEM-002`)**:
  - Give each tab `DocumentID` an isolated `NSUndoManager` via `NSTextViewDelegate.undoManager(for:)`, remove it on tab close, and implement `TextKit2EditorView.dismantleNSView` to clear delegate/validator/undo manager (`BUG-001`, `BUG-021`, eliminates `CWE-416` `_NSUndoStack` UAF crash).
  - Replace `textView.string = text` in programmatic updates (`Cmd+D`, SmartNewline, Format, Markdown commands) with undo-registered `shouldChangeText(in:replacementString:)` + `replaceCharacters(in:with:)` + `didChangeText()` preserving full `NSRange` (`location` + `length`) (`BUG-005`).
  - Add `@NSApplicationDelegateAdaptor(SwiftEditAppDelegate.self)` handling `application(_:open:)` (+ `.onOpenURL`) with a cold/warm pending-URL coordinator queue, and `applicationShouldTerminate(_:)` wired to an exhaustive multi-tab dirty prompt queue (`while` pending dirty tabs remain, replying `.terminateNow`/`.terminateCancel`) so Finder double-click, `Cmd+Q` multi-tab `.save`, and `NSRunningApplication.terminate()` all work deterministically (`BUG-002`, `BUG-003`, `BUG-010`).
  - Isolate binary read-only inspection (`isBinaryReadOnly == true`) into transient read-only presentation state (`activeBinaryInspection`) never retained in `sessionsByID` or `savedBaselineByID` after switch/close (`BUG-007`, `MEM-002`, `DATA-003`).
- **Wave 2 — Usability, Accessibility, Shortcuts & Hot-Path Latency (`BUG-004`, `BUG-006`, `BUG-008`, `BUG-009`, `BUG-011..013`, `PERF-004`, `PERF-006`, `PERF-007`)**:
  - Click-only `HeaderSubmenuStateMachine` eliminates `dwellDuration`, `exitGraceDuration`, and `SwiftEditRootView`'s 20ms `.task` polling (`BUG-006`, `PERF-004`). Keep `toolbarBar` fixed at `topBarHeight` and confine click-outside backdrop below `topBarHeight`.
  - Move `Find and Replace…` to `Opt+Cmd+F` (`BUG-004`), keep a single active-tab-aware `Redo` (`Shift+Cmd+Z`) item (`BUG-011`), add `@FocusState` auto-focus + single `Replace` / `Replace & Find` + `programmaticSelectionToken` scroll-to-selection + editor focus restoration on close/Esc (`BUG-008`, `BUG-009`).
  - Synchronize `LineNumberGutterView` with `NSScrollView` clip bounds and TextKit 2 visual line fragments (`BUG-012`), and highlight every `textLineFragment` of a soft-wrapped active paragraph (`BUG-013`).
  - Move `swift-markdown` AST linting to a debounced off-`@MainActor` `Task` guarded by `(DocumentID, BufferRevision)` AND execute a bounded synchronous/linear URI & image safety fast-path so P99 typing stays `<= 16 ms` up to `20,000` lines while `.unsafeLinkScheme` / `.unsafeImagePath` security rules NEVER silently drop to `0` (`PERF-006`).
  - Cache matched bracket pairs per `(DocumentID, BufferRevision)` and replace `Array(text.utf16)` / `Array(1...totalLines)` allocations in `CursorMetricsCalculator` & `LineNumberGutterProjection` (`PERF-007`, P99 caret move `<= 16 ms` at `10,000L`).
- **Wave 3 — Preview, Diff, CR Endings, Sidebar Security & Memory (`BUG-014..017`, `BUG-019`, `BUG-020`, `PERF-001`, `PERF-002`, `PERF-005`, `MEM-001`, `MEM-003`, `MEM-004`)**:
  - Enforce document-wide `64`-image counter + ordered list numerals in `MarkdownNativePreviewView` (`BUG-014`), stop HTML blocks before adjacent block constructs (`isTableStart`, heading, fence) (`BUG-019`), count `\r\n|\n|\r` in `previewSourceLine`, normalize `activeSeparator` cleanly on single-line CR `Cmd+D` (`BUG-016`), and invalidate `MarkdownLineIndex` by `(DocumentID, BufferRevision)` (`BUG-015`).
  - Add `.modified` pair representation in `SideBySideDiffRow` / `DiffHunkKind` so LHS displays red removed highlight and RHS displays green inserted highlight (`BUG-020`).
  - Add `EscapingSymlinkPolicy` (`.failClosed` default, `.skipAndReport` for sidebar browsing) and `PreferredTerminalApp` (`.auto`/`.iTerm2`/`.terminal`, strictly allowlisted) (`BUG-017`).
  - Single-pass TextKit 2 viewport/dirty attributes (`PERF-001`), async `NSCache` thumbnails (`PERF-002`), off-`@MainActor` decoding/projection for `>= 2 MiB` / `3000L` inputs (`PERF-005`), and aggressive cache/sheet eviction keeping idle footprint `<= 50 MB` (`MEM-001`, `MEM-003`, `MEM-004`).
- **Wave 4 — Build Hygiene, Fast Tests & Automated 3x Verification (`BUG-018`, `PERF-003`, `TEST-001`, Automated Verification)**:
  - Inject `PreferencesProviding` seam (container-aligned `UserDefaults` in prod; `InMemoryKeyValueStore` across the 11 test files replacing 31 `removePersistentDomain` calls -> `swift test` `< 10 s`) (`PERF-003`, `TEST-001`).
  - Align `AboutSheetDescriptor` fallback `"0.0.1-alpha5"`, update CheatSheet (`Opt+Cmd+F`, Diff, Markdown authoring), set `ALWAYS_SEARCH_USER_PATHS = NO` & deterministic plist stamp outputs in `project.pbxproj` (`BUG-018`).
  - Re-execute the full 3x automated debug verification playbook (`AutomatedDebugAuditVerification`) as the final gating unit before `/myspec-sync`.

## 3. Finding Traceability Matrix (All 33 Audit Items)

| Finding IDs | Severity | Root Target | Unit in `tasks.md` |
| :--- | :---: | :--- | :--- |
| `BUG-001`, `BUG-005`, `BUG-021` | P0/P1/P2 | `TextKit2EditorView`, `PerTabUndoManagerRegistry` | Unit 1 (`PerTabUndoAndTextKit2Lifecycle`) |
| `BUG-002`, `BUG-003`, `BUG-010` | P0/P1 | `SwiftEditApp`, `SwiftEditAppDelegate`, `SwiftEditWorkbenchModel` | Unit 2 (`AppDelegateOpenDocAndDirtyTermination`) |
| `BUG-007`, `MEM-002` | P1/Mem | `SwiftEditWorkbenchModel`, `BinaryInspectionPresentation` | Unit 3 (`TransientBinaryInspectionLifecycle`) |
| `BUG-006`, `PERF-004`, WCAG 2.2 | P1/UX | `HeaderBrandSubmenuView`, `HeaderSubmenuStateMachine`, `SwiftEditRootView` | Unit 4 (`ClickOnlyAccessibleHeaderSubmenu`) |
| `BUG-004`, `BUG-008`, `BUG-009`, `BUG-011`, `BUG-012`, `BUG-013`, `BUG-018` | P1/P2/P3 | `SwiftEditCommands`, `FindReplaceGoToLineBar`, `LineNumberGutterView`, `AboutSheetView`, `CheatSheet` | Unit 5 (`ShortcutsFindReplaceFocusAndGutterSync`) |
| `BUG-014`, `BUG-015`, `BUG-016`, `BUG-019`, `BUG-020` | P2 | `MarkdownPreviewProjector`, `MarkdownNativePreviewView`, `DocumentSession`, `WorkspaceEditorAndDiffCoordinators` | Unit 6 (`PreviewProjectionImageCapDiffAndLineEndings`) |
| `BUG-017` | P2/Sec | `DotfileFolderNavigator`, `DesktopWorkspaceIntegrating` | Unit 7 (`ConfinedSidebarSymlinksAndTerminalPreference`) |
| `PERF-001`, `PERF-002`, `PERF-005`, `PERF-006`, `PERF-007`, `MEM-001`, `MEM-003`, `MEM-004` | P1/Perf/Mem | `MarkdownLintAndFormatEngine`, `BracketMatcher`, `CursorMetricsCalculator`, `TextKit2EditorView`, `DocumentLoader` | Unit 8 (`AsyncLintSecurityFastPathAndViewportCaching`) |
| `PERF-003`, `TEST-001`, `BUG-018` | Perf/Test/Build | `PreferencesProviding`, `EditorPreferencesStore`, `RecentFilesStore`, 11 test files, `project.pbxproj` | Unit 9 (`PreferencesSeamAndBuildHygiene`) |
| All 33 + 3x Debug Audit Gate | QA Gate | `.agents/Memories/macos-debug-audit-playbook.md` | Unit 10 (`AutomatedDebugAuditVerification`) |

## 4. Path Coverage Matrix

| Unit | Path | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `PerTabUndoAndTextKit2Lifecycle` | `P1` | positive | Isolated per-tab `NSUndoManager` undoes `Cmd+D` cleanly preserving selection |
| `PerTabUndoAndTextKit2Lifecycle` | `N1` | negative | Window/tab close runs `dismantleNSView` with zero `NSTextLayoutManagerBreakOnNilContentManager` warnings |
| `PerTabUndoAndTextKit2Lifecycle` | `N2` | security | Cross-tab close + FindBar edits never share or dereference dangling undo targets (`CWE-416`) |
| `AppDelegateOpenDocAndDirtyTermination` | `P2` | positive | Finder `open-doc` loads file into tab; `Cmd+Q` saves ALL dirty tabs sequentially before terminating; clean quit <= 2s |
| `AppDelegateOpenDocAndDirtyTermination` | `N3` | negative | `Cancel` during multi-tab dirty `Cmd+Q` aborts termination and keeps all edits intact |
| `AppDelegateOpenDocAndDirtyTermination` | `N4` | security | External `open-doc` enforces `64 MiB`, NUL quarantine, and symlink confinement (`SEC-003`) |
| `TransientBinaryInspectionLifecycle` | `P3` | positive | Binary file opens inspectable read-only state and releases buffer completely on tab switch/close |
| `TransientBinaryInspectionLifecycle` | `N5` | negative | Mutating actions stay disabled; reopening same URL deduplicates |
| `TransientBinaryInspectionLifecycle` | `N6` | security | Quarantined binary buffer never enters `sessionsByID`/`savedBaselineByID` retention or `SessionRecovery` (`DATA-003`) |
| `ClickOnlyAccessibleHeaderSubmenu` | `P4` | positive | Logo click/keyboard opens menu sticky (`>= 1000 ms`), arrow/Return navigation + VoiceOver traits, `0.0 pt` shift |
| `ClickOnlyAccessibleHeaderSubmenu` | `N7` | negative | Hovering logo/controls never opens or auto-closes submenu; `Esc`/outside click/resign-key closes immediately; 0 polling |
| `ShortcutsFindReplaceFocusAndGutterSync` | `P5` | positive | `Opt+Cmd+F` auto-focuses without hiding app, single `Replace` decrements match count, Go-to-Line scrolls & bumps selection, synchronized gutter + wrapped highlight |
| `ShortcutsFindReplaceFocusAndGutterSync` | `N8` | negative | Single `Redo` item tracks active tab, `Cmd+H` stays macOS Hide, out-of-range Go-to-Line & CheatSheet/About fallback verified |
| `PreviewProjectionImageCapDiffAndLineEndings` | `P6` | positive | Document-wide 64-image cap enforced, ordered numerals `1., 2.`, HTML stops before table, CR `Cmd+D` has no raw `\r`, `.modified` diff highlights both LHS & RHS |
| `PreviewProjectionImageCapDiffAndLineEndings` | `N9` | negative | Stale same-length line index invalidated; 70-image document caps at 64 (`CWE-400` security) |
| `ConfinedSidebarSymlinksAndTerminalPreference` | `P7` | positive | `.skipAndReport` loads valid siblings + reports external symlink warning banner; `PreferredTerminalApp` respects `.terminal`/`.iTerm2`/`.auto` |
| `ConfinedSidebarSymlinksAndTerminalPreference` | `N10` | security | Escaping child symlinks never receive `8 KiB` reads; `.failClosed` & folder-root escapes throw `securityScopeViolation`; unallowlisted Terminal bundles blocked |
| `AsyncLintSecurityFastPathAndViewportCaching` | `P8` | positive | Typing (`<= 20kL`) & caret (`10kL`) `<= 16 ms` P99; viewport-only rendering attributes; async thumbnail cache & large-file open; idle RSS `<= 50 MB` |
| `AsyncLintSecurityFastPathAndViewportCaching` | `N11` | security | Bounded security scanner preserves `.unsafeLinkScheme` / `.unsafeImagePath` errors on `5kL`/`20kL` docs without silent `lint=0`; stale revisions cancel async tasks |
| `PreferencesSeamAndBuildHygiene` | `P9` | positive | `InMemoryKeyValueStore` keeps 3x `swift test` `< 10 s`; container suite eliminates `cfprefsd` stalls; zero `ALWAYS_SEARCH_USER_PATHS`/plist Xcode warnings |
| `PreferencesSeamAndBuildHygiene` | `N12` | negative | Out-of-bounds persisted zoom/recents clamp/fail closed safely under injected `PreferencesProviding` |
| `AutomatedDebugAuditVerification` | `P10` | positive | Replays `.agents/Memories/macos-debug-audit-playbook.md` 3x cleanly (`0` crashes, `0` leaks, `<= 16 ms`, `<= 50 MB` idle, click-only submenu) |
| `AutomatedDebugAuditVerification` | `N13` | security | Verifies sandbox entitlements, zero WebKit/Network linkage, `.unsafeLinkScheme` on 20kL docs, Finder/symlink confinement |
