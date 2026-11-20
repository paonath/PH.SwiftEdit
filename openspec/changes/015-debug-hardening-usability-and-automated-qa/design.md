# Design: Debug Hardening, Click-Only Accessible Usability & Automated 3x QA Verification

## Context
Baseline 3x live Debug audit ([debug-audit-report-2026-11-20.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/docs/qa/debug-audit-report-2026-11-20.md)) exposed critical runtime bugs across shared AppKit undo stacks (`BUG-001` crash), missing Finder `open-doc`/termination AppDelegate hooks (`BUG-002`, `BUG-003`, `BUG-010`), `180 ms` auto-dismissing header submenu (`BUG-006`), `964 ms` main-thread AST linting that silently disables `.unsafeLinkScheme` XSS detection (`PERF-006`), `71 ms` caret lags (`PERF-007`), `41–91 s` `cfprefsd`-stalled `swift test` runs (`TEST-001`), and rendering/lifecycle defects (`BUG-004..021`, `MEM-001..004`, `PERF-001..005`).

## Goals / Non-Goals
- Goals:
  - Resolve all `33` cataloged defects (`BUG-001..021`, `MEM-001..004`, `PERF-001..007`, `TEST-001`) cleanly inside existing Bounded Contexts (`KISS-First + Pragmatic SOLID`, `[AR-006]..[AR-010]`).
  - Deliver human-usable **click/keyboard-only** header brand submenu navigation, synchronized gutter/wrap highlighting, `@FocusState` FindBar + single `Replace`, `Opt+Cmd+F`, focus restoration, and WCAG 2.2 AA semantics (`[UI-009]..[UI-012]`).
  - Guarantee automated post-fix verification re-running [macos-debug-audit-playbook.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/.agents/Memories/macos-debug-audit-playbook.md) `3x` with zero crashes, zero leaks, `<= 16 ms` P99 typing/caret, active large-doc XSS lint, and `<= 50 MB` idle footprint.
- Non-Goals:
  - Adding WebKit/network dependencies (`[SEC-001]`, `[SEC-004]`), changing the `12%..65%` sidebar ratio range, or modifying `014-markdown-document-navigator-and-distraction-free` semantics.

## Architecture Memory & Module Boundaries (AR-###)
- **AR-006**: Dependency flow stays strictly inward: `XcodeApp` (`SwiftEditApp`, `SwiftEditAppDelegate`) -> `SwiftEditUI` (`SwiftEditWorkbenchModel`, `TextKit2EditorView`, `HeaderBrandSubmenuView`, `FindReplaceGoToLineBar`, `LineNumberGutterView`, `MarkdownNativePreviewView`, `DiffPaneCoordinator`) -> `SwiftEditCore` (`DocumentCore`, `MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, `WorkspaceAndTabSession`).
- **AR-018**: `SwiftEditWorkbenchModel` and coordinators exchange immutable `DocumentSnapshot`, `BufferRevision`, `DocumentID`, and `TextRange` values and never bypass `DocumentSession` mutation invariants (`[BC-001]`, `[BC-003]`, `[BC-004]`).

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **Single-Reference Lock**: Consulted `01-architecture/dependency-and-layering.md` (`AR-006..010`), `02-domain/bounded-context-ownership.md` (`BC-001..004`), `03-ui-ux/accessibility-and-cwv.md` (`UI-009..012`), `04-data-persistence/storage-and-migrations.md` (`DATA-001..004`), `06-testing-fitness/tdd-and-unit-testing.md` (`TEST-001..004`), `07-security-privacy/authn-authz-and-boundaries.md` (`SEC-001..004`), and `08-sdd-governance/artifact-traceability.md` (`SDD-001..004`).
- **Bounded Context Classification**: `DocumentCore` (**Core**), `MarkdownLintAndFormat` (**Core**), `SearchDiffAndBracketEngine` (**Supporting**), `WorkspaceAndTabSession` (**Supporting**), `SwiftEditUI` / `XcodeApp` (**Outer Presentation & App Shell**).

## Decisions
- **D1 — Per-Tab `NSUndoManager` & Undo-Safe TextKit 2 Edits (`BUG-001`, `BUG-005`, `BUG-021`)**:
  - Maintain `[DocumentID: NSUndoManager]` inside `TextKit2EditorView.Coordinator`, returned via `NSTextViewDelegate.undoManager(for:)` and purged when closing tabs; implement `dismantleNSView` to clear `delegate`, `renderingAttributesValidator`, and `undoManager` cleanly (stopping `NSTextLayoutManagerBreakOnNilContentManager` & `CWE-416`).
  - Route programmatic buffer updates (`Cmd+D`, SmartNewline, Format, Markdown commands) via undo-registered `shouldChangeText(in:replacementString:)` + `textStorage?.replaceCharacters(in:with:)` + `didChangeText()` while restoring full `NSRange` (`location` + `length`) instead of overwriting `textView.string`.
- **D2 — `SwiftEditAppDelegate` Open-Doc & Exhaustive Dirty Termination (`BUG-002`, `BUG-003`, `BUG-010`)**:
  - Register `@NSApplicationDelegateAdaptor(SwiftEditAppDelegate.self)` wired via a weak/shared `AppLifecycleBridge` on `@MainActor`: `application(_:open:)` (+ `.onOpenURL`) buffers cold-start URLs and forwards to the active workbench; `applicationShouldTerminate(_:)` drives an exhaustive queue across **every** dirty tab (fixing `.save` clearing `isPendingTerminationPrompt` after only tab `1`), replying `.terminateNow`/`.terminateCancel` asynchronously (`[DATA-004]`, `[SEC-003]`).
- **D3 — Transient Binary Inspection Lifecycle (`BUG-007`, `MEM-002`)**:
  - Represent binary quarantine views with dedicated transient state `activeBinaryInspection: BinaryInspectionPresentation?` instead of persisting into `sessionsByID` / `savedBaselineByID` before early `return`. Closing inspection or switching tabs deallocates the `1 MiB` inspection slice immediately (`[DATA-003]`).
- **D4 — Click-and-Keyboard-Only Accessible Header Submenu (`BUG-006`, `PERF-004`)**:
  - Simplify `HeaderSubmenuStateMachine` to click/keyboard-only state (`isOpen`, `selectedCommandIndex`, `clickToggle()`, `escapePressed()`, `dismissAfterCommand()`, `moveSelection(delta:)`, `activateSelected()`, `windowResignedKey()`). Delete hover timers (`dwellDuration`, `exitGraceDuration`) and delete `SwiftEditRootView`'s 20ms `.task` polling loop completely (`KISS`, `PERF-004`).
  - Fix two root geometry bugs: (a) enforce `toolbarBar` fixed frame height equal to `HeaderSubmenuStateMachine.topBarHeight` applied **after** padding so overlay `offset(y:)` aligns cleanly with zero gap (`0.0 pt` shift), and (b) position the `.zIndex(99)` click-outside shield below `topBarHeight` so it never intercepts or hides the header logo trigger. Add pointer hover/keyboard focus row highlights, arrow/`Home`/`End`/`Return`/`Escape` navigation, and VoiceOver `Expanded`/`Collapsed` traits (`[UI-010]`).
- **D5 — Shortcuts, FindBar `@FocusState`, Gutter Sync & Wrapped Active Line (`BUG-004`, `BUG-008`, `BUG-009`, `BUG-011..013`)**:
  - Rebind `Find and Replace…` to `Opt+Cmd+F` (`BUG-004`), consolidate to one active-tab-aware `Redo` (`Shift+Cmd+Z`) item (`BUG-011`), add `@FocusState` auto-focus + single `Replace` + `programmaticSelectionToken` increments via `applyProgrammaticSelection(_:)` (`BUG-008`, `BUG-009`) + focus restoration back to `SwiftEditNSTextView` on Bar/`CheatSheet`/`About`/`Navigator`/`Distraction-Free` dismissal.
  - Bridge `NSScrollView.contentView.boundsDidChangeNotification` and TextKit 2 fragment Y/heights into `LineNumberGutterView` (`BUG-012`), and unify `textLineFragments` bounding rects across wrapped paragraphs in `currentLineFullWidthRect()` (`BUG-013`).
- **D6 — Preview Boundaries, Aggregate Image Cap, Diff Row Alignment & CR Endings (`BUG-014..016`, `BUG-019`, `BUG-020`)**:
  - Track a mutable document-wide `remainingImageBudget = 64` across all `MarkdownNativePreviewView` blocks plus ordered list index numbers `1., 2.` (`BUG-014`); terminate `.inertHTML` blocks cleanly on single-line close or block-start transitions (`isTableStart`, heading, fence) (`BUG-019`); count `\r\n`, `\n`, `\r` in `previewSourceLine` and keep `DocumentSession.activeSeparator` clean without injecting `\r` on single-line CR `Cmd+D` (`BUG-016`); key `Coordinator.lineIndex` on `(DocumentID, BufferRevision)` (`BUG-015`).
  - Represent paired edits in `SideBySideDiffRow` with independent `lhsKind` (`.removed`) and `rhsKind` (`.inserted`) or `.modified` variant so modified lines preserve red LHS and green RHS highlights (`BUG-020`).
- **D7 — Sidebar Escaping Symlink Policy & Configurable Terminal (`BUG-017`)**:
  - Introduce `EscapingSymlinkPolicy` (`.failClosed` default preserving `SEC-003` unit expectations, `.skipAndReport` for sidebar browsing checking `resolvingSymlinksInPath()` PRIOR to `8 KiB` probing and reporting `skippedExternalSymlinkCount` via a non-destructive UI warning banner; folder-root escapes still throw `securityScopeViolation`).
  - Introduce `PreferredTerminalApp` (`.auto`, `.iTerm2`, `.terminal`) over strict allowlist (`com.apple.Terminal`, `com.googlecode.iterm2`) instead of unconditionally forcing `iTerm2`.
- **D8 — Async Revision-Guarded Lint + Security Fast-Path, Bracket Cache & Viewport Styling (`PERF-001`, `PERF-002`, `PERF-005..007`, `MEM-001`, `MEM-003`, `MEM-004`)**:
  - Run full 26-rule `swift-markdown` AST linting in a debounced off-`@MainActor` `Task` guarded by `(DocumentID, BufferRevision)` while executing a linear bounded URI/image safety fast-path so P99 keystrokes stay `<= 16 ms` at `20,000` lines and `.unsafeLinkScheme`/`.unsafeImagePath` never silently drop to `0` (`PERF-006`).
  - Cache `BracketMatcher` pair spans per `(DocumentID, BufferRevision)` with binary search for `activePair` and eliminate repeated `Array(text.utf16)` / `Array(1...totalLines)` allocations in `CursorMetricsCalculator` & `LineNumberGutterProjection` (`PERF-007`).
  - Remove duplicate `layoutViewport()`, reset rendering attributes only over dirty/visible ranges (`PERF-001`), move thumbnail decode off `@MainActor` with bounded `NSCache` (`PERF-002`), decode `>= 2 MiB` opens / `3000L` projections off `@MainActor` (`PERF-005`), and purge preview/sheet caches when closed (`MEM-001`, `MEM-003`, `MEM-004`).
- **D9 — `PreferencesProviding` Seam, Test Speed & Xcode Hygiene (`PERF-003`, `TEST-001`, `BUG-018`)**:
  - Inject narrow `PreferencesProviding` (`InMemoryKeyValueStore` in tests across all `11` suites replacing 31 `removePersistentDomain` calls; container-aligned suite in prod -> `swift test < 10 s`, zero `cfprefsd` stalls).
  - Set `AboutSheetDescriptor` fallback `"0.0.1-alpha5"`, expand `KeyboardShortcutsCheatSheetCatalog`, fix `ALWAYS_SEARCH_USER_PATHS = NO` and deterministic script outputs in `project.pbxproj` (`BUG-018`).

## Risks / Trade-offs
- Off-`@MainActor` AST lint could briefly lag behind rapid keystrokes -> Mitigated by linear security fast-path preserving security errors immediately and discarding stale `Task` outputs whenever `(DocumentID, BufferRevision)` advances.
- Replacing `removePersistentDomain` in tests might mask disk `UserDefaults` serialization bugs -> Mitigated by keeping dedicated codec serialization tests against `InMemoryKeyValueStore` plus live `.app` smoke verification of `UserDefaults.standard` / suite persistence in Unit 10.
- `dismantleNSView` ordering against SwiftUI NSTextView teardown -> Mitigated by explicitly verifying under `MallocScribble` and `/usr/bin/leaks --atExit` with `window.isReleasedWhenClosed = false`.

## Migration Plan
1. Execute Wave 1–4 units (`## 1`–`## 9` in `tasks.md`) strictly TDD Red -> Green -> Refactor -> Doc.
2. Execute `## 10. Unit: AutomatedDebugAuditVerification` running [macos-debug-audit-playbook.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/.agents/Memories/macos-debug-audit-playbook.md) 3x end-to-end and cleaning `.tmp/`.
3. Execute `/myspec-sync 015-debug-hardening-usability-and-automated-qa` (`## 11. Unit: LivingSpecificationReconciliation`).

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
