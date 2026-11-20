# Tasks: Debug Hardening, Click-Only Accessible Usability & Automated 3x QA Verification

## 1. Unit: PerTabUndoAndTextKit2Lifecycle
<!-- Addresses BUG-001, BUG-005, BUG-021 -->

- [ ] 1.1 [PHASE: RED] TASK-001-RED: Write failing Swift Testing assertions covering `P1` and `N1` (per-tab `NSUndoManager` isolation, `Cmd+D`/programmatic edit Undo restoring exact `NSRange`, and `dismantleNSView` zero nil-contentManager diagnostics); verify failure on assertions (`paths: [P1, N1]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 1.2 [PHASE: GREEN] TASK-001-GREEN: Implement `PerTabUndoManagerRegistry`, `NSTextViewDelegate.undoManager(for:)`, undo-registered `shouldChangeText`/`replaceCharacters`/`didChangeText` mutations preserving selection, and `TextKit2EditorView.dismantleNSView`; verify `P1` and `N1` pass (`paths: [P1, N1]`) [Const: AR-010 (01-architecture/dependency-and-layering.md)]
- [ ] 1.3 [PHASE: REFACTOR] TASK-001-REFACTOR: Extract shared undo-safe TextKit 2 transaction helper across `updateNSView` and `doCommandBy` and confirm full suite green (`paths: [P1, N1]`) [Const: BC-004 (02-domain/bounded-context-ownership.md)]
- [ ] 1.4 [PHASE: DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) explaining per-tab undo ownership and teardown ordering (`paths: [P1, N1]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 1.5 [PHASE: RED] [SECURITY] TASK-001-SEC-RED: Write failing `CWE-416` stress test covering `N2` (rapid multi-tab edit, FindBar focus, Format, `Don't Save` close, and `Cmd+Z` under `MallocScribble`); verify failure (`paths: [N2] · tags: security · priority: critical`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 1.6 [PHASE: GREEN] [SECURITY] TASK-001-SEC-GREEN: Purge closed `DocumentID` undo managers deterministically on tab close and window dismantle so `N2` passes cleanly (`paths: [N2] · tags: security · priority: critical`) [Const: AR-010 (01-architecture/dependency-and-layering.md)]
- [ ] 1.7 [PHASE: REFACTOR] [SECURITY] TASK-001-SEC-REFACTOR: Audit coordinator weak references and undo cleanup hooks (`paths: [N2] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 1.8 [PHASE: DOC] [SECURITY] TASK-001-SEC-DOC: Document why shared `NSWindow.undoManager` causes cross-tab use-after-free and how per-tab isolation prevents it (`paths: [N2]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 2. Unit: AppDelegateOpenDocAndDirtyTermination
<!-- Addresses BUG-002, BUG-003, BUG-010 -->

- [ ] 2.1 [PHASE: RED] TASK-002-RED: Write failing tests covering `P2` and `N3` (cold/warm Finder `open-doc` queue activation, exhaustive multi-tab `.save` termination prompt across `>= 2` dirty tabs, `.cancel` abort, and `<= 2.0 s` clean quit); verify failure (`paths: [P2, N3]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 2.2 [PHASE: GREEN] TASK-002-GREEN: Implement `SwiftEditAppDelegate` (`@NSApplicationDelegateAdaptor`, `application(_:open:)`, `applicationShouldTerminate(_:)`, `.onOpenURL`), shared `AppLifecycleBridge`, and exhaustive multi-tab dirty prompt queue with `NSApp.reply(toApplicationShouldTerminate:)`; verify `P2` and `N3` pass (`paths: [P2, N3]`) [Const: AR-006 (01-architecture/dependency-and-layering.md)]
- [ ] 2.3 [PHASE: REFACTOR] TASK-002-REFACTOR: Unify single-tab close and app-wide dirty-tab queue helpers without duplicating save/cancel transitions (`paths: [P2, N3]`) [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
- [ ] 2.4 [PHASE: DOC] TASK-002-DOC: Write concise English documentation on `SwiftEditAppDelegate` lifecycle ordering and pending cold-launch URL draining (`paths: [P2, N3]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 2.5 [PHASE: RED] [SECURITY] TASK-002-SEC-RED: Write failing confinement tests covering `N4` (Finder `open-doc` rejecting `> 64 MiB` payloads and escaping symlinks); verify failure (`paths: [N4] · tags: security · priority: critical`) [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 2.6 [PHASE: GREEN] [SECURITY] TASK-002-SEC-GREEN: Enforce `DocumentLoader` size, NUL, and symlink gates identically on `AppDelegate` external opens (`paths: [N4] · tags: security · priority: critical`) [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 2.7 [PHASE: REFACTOR] [SECURITY] TASK-002-SEC-REFACTOR: Audit sandbox scope lifecycle on external Finder opens (`startAccessing`/`defer { stopAccessing }`) (`paths: [N4] · tags: security`) [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 2.8 [PHASE: DOC] [SECURITY] TASK-002-SEC-DOC: Document external URL validation guarantees in English (`paths: [N4]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 3. Unit: TransientBinaryInspectionLifecycle
<!-- Addresses BUG-007, MEM-002 -->

- [ ] 3.1 [PHASE: RED] TASK-003-RED: Write failing tests covering `P3` and `N5` (opening `0x00`-bearing file shows inspectable transient banner/view, switching or dismissing drops buffer count to `0`, pinning forbidden); verify failure (`paths: [P3, N5]`) [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
- [ ] 3.2 [PHASE: GREEN] TASK-003-GREEN: Replace early return retaining `sessionsByID`/`savedBaselineByID` in `openFile` with `BinaryInspectionPresentation` released cleanly on switch/close; verify `P3` and `N5` pass (`paths: [P3, N5]`) [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
- [ ] 3.3 [PHASE: REFACTOR] TASK-003-REFACTOR: Consolidate quarantine banner evaluation and ensure zero orphan dictionary keys (`paths: [P3, N5]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 3.4 [PHASE: DOC] TASK-003-DOC: Document transient binary quarantine ownership and immediate release semantics (`paths: [P3, N5]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 3.5 [PHASE: RED] [SECURITY] TASK-003-SEC-RED: Write failing tests covering `N6` (binary buffers excluded from `SessionRecovery/`, MRU, and mutating Save/Format/Duplicate commands); verify failure (`paths: [N6] · tags: security · priority: critical`) [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
- [ ] 3.6 [PHASE: GREEN] [SECURITY] TASK-003-SEC-GREEN: Enforce fail-closed binary command lockouts and zero `sessionsByID` / `SessionRecovery` persistence (`paths: [N6] · tags: security · priority: critical`) [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
- [ ] 3.7 [PHASE: REFACTOR] [SECURITY] TASK-003-SEC-REFACTOR: Audit binary close/switch paths across tab activation (`paths: [N6] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 3.8 [PHASE: DOC] [SECURITY] TASK-003-SEC-DOC: Document why transient inspection bypasses `sessionsByID` map storage (`paths: [N6]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 4. Unit: ClickOnlyAccessibleHeaderSubmenu
<!-- Addresses BUG-006, PERF-004, Human UX & WCAG 2.2 AA Accessibility -->

- [ ] 4.1 [PHASE: RED] TASK-004-RED: Write failing tests covering `P4` and `N7` (click/keyboard toggle stays open `>= 1000 ms`, prolonged hover `>= 700 ms` never opens or auto-closes menu, arrow/Home/End/Return/Escape navigation, `topBarHeight` equals panel offset, backdrop below trigger, VoiceOver `Expanded`/`Collapsed`, zero `.task` polling); verify failure (`paths: [P4, N7]`) [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 4.2 [PHASE: GREEN] TASK-004-GREEN: Refactor `HeaderSubmenuStateMachine` to click/keyboard-only transitions (`isOpen`, `selectedCommandIndex`, `moveSelection`, `activateSelected`, `escapePressed`, `windowResignedKey`), remove dwell/grace timers and 20 ms `.task` polling in `SwiftEditRootView`, align exact `topBarHeight` + below-bar shield, add hover/focus row highlight & VoiceOver traits (`paths: [P4, N7]`) [Const: UI-010 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 4.3 [PHASE: REFACTOR] TASK-004-REFACTOR: Simplify `HeaderSubmenuStateMachine` and `HeaderBrandSubmenuView` removing all dead hover-timer code and preserving Reduce Transparency/Motion compliance (`paths: [P4, N7]`) [Const: UI-011 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 4.4 [PHASE: DOC] TASK-004-DOC: Document click-only WCAG 2.2 persistence rules and geometry alignment between `toolbarBar` and `headerSubmenuOverlay` (`paths: [P4, N7]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 5. Unit: ShortcutsFindReplaceFocusAndGutterSync
<!-- Addresses BUG-004, BUG-008, BUG-009, BUG-011, BUG-012, BUG-013, BUG-018 -->

- [ ] 5.1 [PHASE: RED] TASK-005-RED: Write failing tests covering `P5` and `N8` (`Opt+Cmd+F` Find & Replace preserving `Cmd+H` macOS Hide, single tab-aware `Redo` `Shift+Cmd+Z`, `@FocusState` auto-focus, single `Replace`, `programmaticSelectionToken` jump + scroll, focus return on Esc/sheet/DF dismiss, synced gutter scroll/wrap positions, multi-fragment wrapped active line, CheatSheet parity, About `"0.0.1-alpha5"` fallback); verify failure (`paths: [P5, N8]`) [Const: UI-009 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 5.2 [PHASE: GREEN] TASK-005-GREEN: Rebind `Find and Replace…` to `Opt+Cmd+F`, remove duplicate `Redo`, implement `executeReplaceSingle()`, `applyProgrammaticSelection(_:)`, `@FocusState` + focus restoration, `LineNumberGutterView` scroll/wrap fragment synchronization, wrapped `currentLineFullWidthRect()`, CheatSheet expansion, and `AboutSheetDescriptor` `"0.0.1-alpha5"` fallback (`paths: [P5, N8]`) [Const: UI-009 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 5.3 [PHASE: REFACTOR] TASK-005-REFACTOR: Extract unified selection-jump & focus-restoration helpers in `SwiftEditWorkbenchModel` and deduplicate gutter/editor layout geometry (`paths: [P5, N8]`) [Const: AR-010 (01-architecture/dependency-and-layering.md)]
- [ ] 5.4 [PHASE: DOC] TASK-005-DOC: Document shortcut single-source ownership (`Opt+Cmd+F`, `Cmd+H`) and TextKit 2 gutter/fragment synchronization invariants (`paths: [P5, N8]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 6. Unit: PreviewProjectionImageCapDiffAndLineEndings
<!-- Addresses BUG-014, BUG-015, BUG-016, BUG-019, BUG-020 -->

- [ ] 6.1 [PHASE: RED] TASK-006-RED: Write failing tests covering `P6` and `N9` (document-wide 64-image cap across 70 paragraphs, ordered list numerals `1., 2.`, HTML block terminating before adjacent GFM table, CR `Cmd+D` zero raw `\r` & `previewSourceLine` CR/CRLF support, `(DocumentID, BufferRevision)` `MarkdownLineIndex` invalidation on same-length edits, and LHS `.removed` / RHS `.inserted` modified diff rows); verify failure (`paths: [P6, N9]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 6.2 [PHASE: GREEN] TASK-006-GREEN: Implement cumulative `remainingImageBudget` (`64`), ordered list indices, HTML-before-table boundary stop, clean `activeSeparator` + multi-separator `previewSourceLine`, revision-keyed `MarkdownLineIndex`, and `DiffHunkKind`/`SideBySideDiffRow` paired `.removed`/`.inserted` highlights (`paths: [P6, N9]`) [Const: BC-003 (02-domain/bounded-context-ownership.md)]
- [ ] 6.3 [PHASE: REFACTOR] TASK-006-REFACTOR: Streamline separator scanning and block-boundary helpers eliminating duplicated loops (`paths: [P6, N9]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 6.4 [PHASE: DOC] TASK-006-DOC: Document preview budget propagation, CR normalization invariants, and side-by-side modified diff semantics (`paths: [P6, N9]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 6.5 [PHASE: RED] [SECURITY] TASK-006-SEC-RED: Write failing `CWE-400` and XSS tests asserting `70`-image multi-paragraph docs cap at `64` and adjacent `<script>...</script>\n|Table|` keeps script inert (`paths: [N9] · tags: security · priority: critical`) [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 6.6 [PHASE: GREEN] [SECURITY] TASK-006-SEC-GREEN: Enforce document-wide `64`-image counter and strict `.inertHTML` table separation (`paths: [N9] · tags: security · priority: critical`) [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 6.7 [PHASE: REFACTOR] [SECURITY] TASK-006-SEC-REFACTOR: Audit preview admission and separator parsers for adversarial inputs (`paths: [N9] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 6.8 [PHASE: DOC] [SECURITY] TASK-006-SEC-DOC: Document cumulative `64`-image resource bound rationale (`paths: [N9]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 7. Unit: ConfinedSidebarSymlinksAndTerminalPreference
<!-- Addresses BUG-017 -->

- [ ] 7.1 [PHASE: RED] TASK-007-RED: Write failing tests covering `P7` (`.skipAndReport` returning valid siblings + `skippedExternalSymlinkCount`, sidebar UI warning banner, and `PreferredTerminalApp` `.auto`/`.iTerm2`/`.terminal`); verify failure (`paths: [P7]`) [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 7.2 [PHASE: GREEN] TASK-007-GREEN: Implement `EscapingSymlinkPolicy` (`.failClosed` default, `.skipAndReport` for sidebar browsing + warning banner) and `PreferredTerminalApp` option in `DesktopWorkspaceIntegrating`; verify `P7` passes (`paths: [P7]`) [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 7.3 [PHASE: REFACTOR] TASK-007-REFACTOR: Deduplicate symlink containment verification between `.failClosed` and `.skipAndReport` paths (`paths: [P7]`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 7.4 [PHASE: DOC] TASK-007-DOC: Document `EscapingSymlinkPolicy` contracts and Terminal preference allowlist (`paths: [P7]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 7.5 [PHASE: RED] [SECURITY] TASK-007-SEC-RED: Write failing security tests covering `N10` (spy `FileSystemProviding` asserting zero `8 KiB` reads on escaping child symlinks, folder-root escape throwing `securityScopeViolation`, unallowlisted terminal bundle rejected); verify failure (`paths: [N10] · tags: security · priority: critical`) [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 7.6 [PHASE: GREEN] [SECURITY] TASK-007-SEC-GREEN: Enforce pre-probe symlink resolution check and strict bundle allowlist (`paths: [N10] · tags: security · priority: critical`) [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 7.7 [PHASE: REFACTOR] [SECURITY] TASK-007-SEC-REFACTOR: Audit `defer { stopAccessing() }` balance across early skips and throws (`paths: [N10] · tags: security`) [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 7.8 [PHASE: DOC] [SECURITY] TASK-007-SEC-DOC: Document pre-probe `resolvingSymlinksInPath()` ordering invariant (`paths: [N10]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 8. Unit: AsyncLintSecurityFastPathAndViewportCaching
<!-- Addresses PERF-001, PERF-002, PERF-005, PERF-006, PERF-007, MEM-001, MEM-003, MEM-004 -->

- [ ] 8.1 [PHASE: RED] TASK-008-RED: Write failing performance & memory tests covering `P8` (typing `<= 16 ms` at `500L..20kL`, caret `<= 16 ms` at `10kL`, single viewport layout/attribute pass, async thumbnail cache & `12 MiB` off-MainActor load, and sheet/preview eviction keeping idle `<= 50 MB` and post-sweep `< 80 MB`); verify failure (`paths: [P8]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 8.2 [PHASE: GREEN] TASK-008-GREEN: Move full `swift-markdown` AST linting to debounced background `Task` guarded by `(DocumentID, BufferRevision)`, cache bracket pairs per `(DocumentID, BufferRevision)`, optimize `CursorMetricsCalculator`/`LineNumberGutterProjection` eliminating `Array(text.utf16)`/`Array(1...N)` copies, deduplicate TextKit 2 `layoutViewport()`, add off-`@MainActor` `NSCache` thumbnails + async `>= 2 MiB` file decode & cache eviction; verify `P8` passes (`paths: [P8]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 8.3 [PHASE: REFACTOR] TASK-008-REFACTOR: Consolidate revision-guarded async worker cancellation across lint, preview, and large-file loaders (`paths: [P8]`) [Const: AR-008 (01-architecture/dependency-and-layering.md)]
- [ ] 8.4 [PHASE: DOC] TASK-008-DOC: Document two-stage async lint architecture, bracket cache keys, and memory eviction policy (`paths: [P8]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 8.5 [PHASE: RED] [SECURITY] TASK-008-SEC-RED: Write failing tests covering `N11` (`5kL`/`20kL` docs containing `[xss](javascript:alert(1))` and `../../etc/passwd` still surface `.unsafeLinkScheme`/`.unsafeImagePath` errors; superseded `BufferRevision` discards stale async results); verify failure (`paths: [N11] · tags: security · priority: critical`) [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 8.6 [PHASE: GREEN] [SECURITY] TASK-008-SEC-GREEN: Implement bounded linear URI/image security fast-path retained on status & diagnostics popover + strict `(DocumentID, BufferRevision)` commit guard (`paths: [N11] · tags: security · priority: critical`) [Const: DATA-002 (04-data-persistence/storage-and-migrations.md)]
- [ ] 8.7 [PHASE: REFACTOR] [SECURITY] TASK-008-SEC-REFACTOR: Audit obfuscated URI/BiDi parity between full AST rules and security fast-path (`paths: [N11] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 8.8 [PHASE: DOC] [SECURITY] TASK-008-SEC-DOC: Document why security URI rules never silently degrade to `0` on non-degraded large documents (`paths: [N11]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 9. Unit: PreferencesSeamAndBuildHygiene
<!-- Addresses PERF-003, TEST-001, BUG-018 Xcode warnings -->

- [ ] 9.1 [PHASE: RED] TASK-009-RED: Write failing tests covering `P9` and `N12` (`PreferencesProviding` with `InMemoryKeyValueStore` for `EditorPreferencesStore` and `RecentFilesStore`, corrupted recents fail-closed behavior, zero `removePersistentDomain` across `Tests/SwiftEditTests/`); verify failure (`paths: [P9, N12]`) [Const: AR-007 (01-architecture/dependency-and-layering.md)]
- [ ] 9.2 [PHASE: GREEN] TASK-009-GREEN: Introduce `PreferencesProviding` + `InMemoryKeyValueStore`, migrate all `31` `removePersistentDomain` call sites across `11` test files, align production suite to container domain, set `ALWAYS_SEARCH_USER_PATHS = NO` & deterministic `Stamp Info.plist` build phase outputs in `project.pbxproj` (`paths: [P9, N12]`) [Const: TEST-003 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 9.3 [PHASE: REFACTOR] TASK-009-REFACTOR: Clean up test fixture setup helpers ensuring full parallel execution determinism in `< 10 s` (`paths: [P9, N12]`) [Const: TEST-004 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 9.4 [PHASE: DOC] TASK-009-DOC: Document `PreferencesProviding` seam and why tests forbid `removePersistentDomain` (`paths: [P9, N12]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]

## 10. Unit: AutomatedDebugAuditVerification
<!-- Mandatory post-fix automated 3x Debug Verification Gate executing .agents/Memories/macos-debug-audit-playbook.md -->

- [ ] 10.1 [PHASE: RED] TASK-010-RED: Define executable automated regression gate assertions in `QAHarness`/playbook script for `P10` and `N10` (0 crashes, 0 leaks, `<= 16 ms` typing/caret, click-only submenu `>= 1000 ms`, Finder `open-doc`, `Cmd+Q` dirty loop, gutter sync, `swift test < 10 s`); confirm baseline/threshold failure detection (`paths: [P10, N10]`) [Const: TEST-001 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 10.2 [PHASE: GREEN] TASK-010-GREEN: Replay complete 3x Debug Audit Playbook (`.agents/Memories/macos-debug-audit-playbook.md`): clean Debug `.app` build (0 target warnings), `swift Scripts/verify-design-assets.swift`, 3x `swift test`, 3x compiled Swift `axdriver` live GUI sweep across all features, 3x `QAHarness --functional` & `--bench` (`50L..20kL`), and `/usr/bin/leaks --atExit` + `footprint` verifying 100% of 33 findings closed (`paths: [P10, N10]`) [Const: UI-012 (03-ui-ux/accessibility-and-cwv.md)]
- [ ] 10.3 [PHASE: REFACTOR] TASK-010-REFACTOR: Archive post-fix telemetry comparison under `docs/qa/` and wipe `.tmp/{DerivedData,logs,output,qa-workspace,qa-harness,gui-driver}` leaving zero stray processes or temporary files (`paths: [P10]`) [Const: SDD-001 (08-sdd-governance/artifact-traceability.md)]
- [ ] 10.4 [PHASE: DOC] TASK-010-DOC: Update `.agents/Memories/macos-debug-audit-playbook.md` `LastValidatedAt` and verified baseline thresholds after full pass (`paths: [P10]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]
- [ ] 10.5 [PHASE: RED] [SECURITY] TASK-010-SEC-RED: Add failing gate assertions covering `N11`/`N13` (missing sandbox keys, unexpected `WebKit`/`Network` linkage, `.unsafeLinkScheme` `== 0` on `5kL`/`20kL` docs, or symlink escape bytes read); verify detection (`paths: [N13] · tags: security · priority: critical`) [Const: SEC-001 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 10.6 [PHASE: GREEN] [SECURITY] TASK-010-SEC-GREEN: Run security portion of automated 3x Debug audit (`codesign -dvvv --entitlements -`, `otool -L`, `.unsafeLinkScheme` on `20kL`, symlink zero-read check, `CWE-416` `leaks --atExit`) passing all assertions (`paths: [N13] · tags: security · priority: critical`) [Const: SEC-004 (07-security-privacy/authn-authz-and-boundaries.md)]
- [ ] 10.7 [PHASE: REFACTOR] [SECURITY] TASK-010-SEC-REFACTOR: Verify deterministic exit code failure on any security or memory threshold violation (`paths: [N13] · tags: security`) [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
- [ ] 10.8 [PHASE: DOC] [SECURITY] TASK-010-SEC-DOC: Record verified post-fix security gate evidence in `.agents/Memories/macos-debug-audit-playbook.md` (`paths: [N13]`) [Const: SDD-002 (08-sdd-governance/artifact-traceability.md)]

## 11. Unit: LivingSpecificationReconciliation

- [ ] 11.1 [SYNC] TASK-011-SYNC: Execute `/myspec-sync 015-debug-hardening-usability-and-automated-qa` to reconcile all `MODIFIED` and `RENAMED` capability deltas into `openspec/specs/` (automatically marked `[x]` by `myspec_sync.py`) [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
