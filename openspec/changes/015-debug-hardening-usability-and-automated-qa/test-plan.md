# Test Plan: Debug Hardening, Click-Only Accessible Usability & Automated 3x QA Verification

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `PerTabUndoAndTextKit2Lifecycle` | P1: isolated per-tab `NSUndoManager` undoes `Cmd+D` preserving exact selection range | N1: `dismantleNSView` teardown emits zero `NSTextLayoutManagerBreakOnNilContentManager`; N2 [Security]: rapid close + FindBar + undo never dereferences freed undo stack (`CWE-416`) |
| `AppDelegateOpenDocAndDirtyTermination` | P2: Finder `open-doc` activates opened file; `Cmd+Q` saves ALL dirty tabs sequentially before exiting; clean `terminate()` <= 2s | N3: `Cancel` on multi-tab dirty `Cmd+Q` cancels termination preserving unsaved buffers; N4 [Security]: Finder `open-doc` blocks `> 64 MiB` / escaping symlink |
| `TransientBinaryInspectionLifecycle` | P3: binary file opens transient read-only inspection and frees completely on tab switch/close | N5: reopening binary deduplicates without adding writable/pinned tab; N6 [Security]: zero retention in `sessionsByID`/`savedBaselineByID`/`SessionRecovery` |
| `ClickOnlyAccessibleHeaderSubmenu` | P4: click/keyboard toggles open in `0 ms`, stays sticky `>= 1000 ms`, supports `↑`/`↓`/`Home`/`End`/`Return` & VoiceOver `Expanded`/`Collapsed`, `0.0 pt` shift | N7: prolonged pointer hover over brand trigger or trailing controls (`>= 700 ms`) or active drag never opens/closes menu; `Escape`/outside-click/resign-key closes immediately |
| `ShortcutsFindReplaceFocusAndGutterSync` | P5: `Opt+Cmd+F` auto-focuses without hiding app, single `Replace` updates 1 match, `programmaticSelectionToken` scrolls Find/GoToLine, synced gutter & wrapped active-line highlight, `CheatSheet` + `alpha5` About | N8: `Cmd+H` triggers macOS Hide only; single `Redo` tracks tab state; out-of-range GoToLine & zero-width gutter degrade cleanly |
| `PreviewProjectionImageCapDiffAndLineEndings` | P6: ordered numerals `1., 2.`, adjacent HTML+GFM table renders, CR `Cmd+D` leaves `hasRawCR == false`, `previewSourceLine` handles CR, `.modified` diff highlights LHS red & RHS green | N9 [Security]: `70`-image document caps strictly at `64` (`CWE-400`); same-length `BufferRevision` invalidates `MarkdownLineIndex`; HTML `<script>` stays inert |
| `ConfinedSidebarSymlinksAndTerminalPreference` | P7: `.skipAndReport` returns valid siblings + `skippedExternalSymlinkCount` warning banner; `PreferredTerminalApp` respects `.terminal`/`.iTerm2`/`.auto` | N10 [Security]: escaping child symlinks never receive `8 KiB` reads; `.failClosed` & root escape throw `securityScopeViolation`; unallowlisted bundles blocked |
| `AsyncLintSecurityFastPathAndViewportCaching` | P8: P99 typing (`50L..20kL`) & caret (`10kL`) stay `<= 16 ms`; viewport-only styling; async thumbnails/12MB open non-blocking; idle `<= 50 MB`, post-sweep `< 80 MB`, `survivingModels == 0` | N11 [Security]: `5kL`/`20kL` docs preserve `.unsafeLinkScheme`/`.unsafeImagePath` errors (`lint > 0`); newer `BufferRevision` discards stale async workers |
| `PreferencesSeamAndBuildHygiene` | P9: `InMemoryKeyValueStore` keeps all `3x` `swift test` runs `< 10 s`; clean Debug `xcodebuild` has zero `ALWAYS_SEARCH_USER_PATHS` / script warnings | N12: malformed recents JSON and out-of-range persisted zoom clamp/reset safely under `PreferencesProviding` |
| `AutomatedDebugAuditVerification` | P10: full 3x replay of `.agents/Memories/macos-debug-audit-playbook.md` passes Debug `.app`, AX GUI, `QAHarness --bench`, `footprint`, `/usr/bin/leaks --atExit` (`0` leaks), and `.tmp/` cleanup | N13 [Security]: threshold failure (`> 16 ms`, `0` XSS lint on 20kL, leak `> 0`, submenu self-close, forbidden entitlement) fails gate non-zero |

## 2. Test Automation Strategy & Commands
- **Unit & Integration Test Suite (`< 10 s` per run x 3)**:
  - `swift test --parallel`
  - Targeted trait filter: `swift test --filter "PerTabUndo|AppDelegate|HeaderSubmenu|FindReplace|GutterSync|Diff|Preview|Dotfile|LintPerformance|BracketCache|PreferencesSeam"`
- **Automated 3x Playbook Verification Gate (`.agents/Memories/macos-debug-audit-playbook.md`)**:
  - Build & Sign: `./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData`, `codesign -dvvv --entitlements -`, `otool -L`, `swift Scripts/verify-design-assets.swift`
  - Live AX/CGEvent GUI (`axdriver` x3): cold start, Finder `open-doc`, click-only logo submenu sticky `>= 1000 ms`, `Opt+Cmd+F`, `Cmd+H` Hide check, single `Replace`, `Cmd+D -> Cmd+Z`, multi-tab close+undo crash stress, `Cmd+Q` dirty quit loop, clean `terminate()`
  - Stress & Telemetry (`QAHarness` x3): `--functional`, `--bench` (`50L..20kL` typing `<= 16 ms` + `.unsafeLinkScheme > 0`; `10kL` caret `<= 16 ms`; `12 MB` non-blocking open; 20-tab churn `survivingModels == 0`), `footprint`, `vmmap --summary`, `/usr/bin/leaks --atExit` (`0 leaks`), `.tmp/` cleanup.

## 3. Testability Seams & Test Doubles
- **Real collaborators**: `DocumentSession`, `DocumentCodec`, `MarkdownLintAndFormatEngine`, `MarkdownPreviewProjector`, `SearchDiffAndBracketEngine`, `WorkspaceTabSession`, `SwiftEditWorkbenchModel`, `HeaderSubmenuStateMachine`, hosted `TextKit2EditorView`.
- **Injection Seams (`[TEST-003]`, `[TEST-004]`)**: `PreferencesProviding` (`InMemoryKeyValueStore` in tests eliminating `cfprefsd`), `FileSystemProviding` (`InMemoryFileSystemFake`), deterministic `Clock`, recording `DesktopWorkspaceIntegrating` & `ItemTrashing` fakes, and compiled `axdriver` AX/CGEvent runner.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Single-`SHALL` active-voice EARS requirements (`<= 500` chars) across 1 added and 8 modified specs (`[SDD-001]`) |
| Path coverage completeness | Verified | All `10` units map `P1..P10` positive paths and `N1..N13` negative/security paths (`[TEST-001]`, `[TEST-002]`) |
| Security traits tagged | Verified | `N2`, `N4`, `N6`, `N8`, `N9`, `N10`, `N11`, `N13` and modified security scenarios tagged `- **Trait**: security` (`[SEC-001..012]`) |
| Automated post-fix QA loop | Verified | Unit 10 encodes full 3x live Debug, AX GUI, benchmark, and leak verification per `MEMORY-001` |
