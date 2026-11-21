# Capability: debug-hardening-usability-and-automated-qa

## Purpose
Consolidates all P0–P3 runtime hardening, per-tab undo isolation, AppDelegate lifecycle wiring, memory and performance ceilings, test-suite speed fixes, click-only accessible UX, and mandatory automated 3x debug verification across PH.SwiftEdit.

## Requirements

### Requirement: REQ-001 Per-Tab NSUndoManager Isolation Undo-Safe Programmatic Edits and Tear-Down
WHEN editing text, invoking programmatic commands, switching tabs, or dismantling views, the editor view coordinator SHALL assign one isolated `NSUndoManager` per `DocumentID`, apply programmatic edits via undo-registered TextKit 2 mutations preserving selection range, and detach delegates and validators in `dismantleNSView` [AR-010][BC-004][SEC-012][UI-012].

#### Scenario: P1 Isolated Per-Tab NSUndoManager Undoes Cmd+D and Restores Selection
- **Path**: P1
- **Trait**: positive
- **GIVEN** two open tabs `A` (`"alpha\nbeta"`, caret on `"alpha"`) and `B` (`"gamma"`) hosted in `TextKit2EditorView`
- **WHEN** `Cmd+D` duplicates line `1` on tab `A`, user edits occur in tab `B` and `FindBar`, tab `B` closes, and `Cmd+Z` triggers on tab `A`
- **THEN** tab `A` restores `"alpha\nbeta"` with exact selection range using only tab `A`'s `NSUndoManager`, leaving zero shared undo entries across tabs

#### Scenario: N1 Tear-Down Dismantles Delegates With Zero Nil-ContentManager Warnings
- **Path**: N1
- **Trait**: negative
- **GIVEN** a hosted `TextKit2EditorView` attached to an `NSWindow` with active layout attributes
- **WHEN** `dismantleNSView(_:coordinator:)` executes on tab close or window teardown and `Cmd+Z` is dispatched afterwards
- **THEN** the coordinator clears delegate, `renderingAttributesValidator`, and `undoManagerOverride` cleanly with zero `NSTextLayoutManagerBreakOnNilContentManager` diagnostics

#### Scenario: N2 Rapid Cross-Tab Close and Find-Bar Undo Never Dereferences Stale Stack Entries
- **Path**: N2
- **Trait**: security
- **GIVEN** rapid cycles opening multiple tabs, typing into `FindReplaceGoToLineBar`, applying `Format Markdown Section`, closing dirty tabs via `Don't Save`, and switching remaining tabs
- **WHEN** `Cmd+Z` executes repeatedly on surviving tabs under `MallocScribble`
- **THEN** zero `EXC_BAD_ACCESS` or `_NSUndoStack` use-after-free faults (`CWE-416`) occur and every undo target belongs strictly to the active `DocumentID`

### Requirement: REQ-002 AppDelegate Open-Doc Handoff Multi-Tab Dirty Quit and Clean Termination
WHEN Finder opens external documents or quit triggers termination, the app lifecycle delegate SHALL queue and validate incoming URLs via `DocumentLoader` in `SwiftEditAppDelegate`, iterate all dirty tabs sequentially during quit prompts before terminating, and complete clean quits within `2.0` seconds [AR-006][AR-010][DATA-004][SEC-002][SEC-003].

#### Scenario: P2 External Finder Open-Doc Loads Document and Multi-Tab Dirty Cmd+Q Saves All Tabs
- **Path**: P2
- **Trait**: positive
- **GIVEN** two dirty tabs (`tab1`, `tab2`) and an external Finder `application(_:open:)` URL pointing to `"sample.md"`
- **WHEN** Finder opens `"sample.md"` into an active tab and `Cmd+Q` runs selecting `.save` across the termination prompt sequence
- **THEN** `"sample.md"` activates cleanly in `TextKit2EditorView`, `Cmd+Q` saves both `tab1` and `tab2` sequentially (`remainingDirty == 0`) before replying `.terminateNow`, and clean termination finishes within `2.0` seconds

#### Scenario: N3 Canceling Any Dirty Quit Prompt Aborts App Termination Without Data Loss
- **Path**: N3
- **Trait**: negative
- **GIVEN** a workbench holding two dirty tabs `tab1` and `tab2` when `applicationShouldTerminate` initiates quit
- **WHEN** the user selects `.save` on `tab1` and `.cancel` on `tab2`
- **THEN** `SwiftEditAppDelegate` replies `.terminateCancel`, preserves all unsaved edits in `tab2`, and leaves the application window running

#### Scenario: N4 External Open-Doc Rejects Binary Quarantine Oversized Files and Escaping Symlinks
- **Path**: N4
- **Trait**: security
- **GIVEN** an incoming `application(_:open:)` URL resolving to a `> 64 MiB` file or an escaping symlink outside granted scope
- **WHEN** `SwiftEditAppDelegate` forwards the URL through `SwiftEditWorkbenchModel.openFile`
- **THEN** the loader aborts with `DomainError.fileTooLarge` or `DomainError.securityScopeViolation` without opening any writable document session

### Requirement: REQ-003 Transient Binary Read-Only Inspection State With Immediate Release
WHEN a binary file containing NUL within its first `8 KiB` is opened or dismissed, the workbench model SHALL present transient read-only inspection without retaining sessions in `sessionsByID` or `savedBaselineByID` after switch or closure [DATA-003][SEC-011][SEC-012][UI-010].

#### Scenario: P3 Opening and Switching Away From Binary File Releases Transient Inspection Buffer
- **Path**: P3
- **Trait**: positive
- **GIVEN** a clean workbench with tab `"notes.md"` open and a `2 MiB` binary file `"archive.bin"`
- **WHEN** `"archive.bin"` opens in transient read-only inspection mode and the user switches back to `"notes.md"` or closes inspection
- **THEN** transient inspection displays up to `1 MiB` read-only hex/text inspection (`safetyBanner.canSave == false`) and subsequent switch/dismiss leaves zero binary entries in `sessionsByID` and `savedBaselineByID`

#### Scenario: N5 Reopening Identical Binary File Deduplicates Transient State Without Creating Writable Tab
- **Path**: N5
- **Trait**: negative
- **GIVEN** an active transient binary inspection for `"archive.bin"`
- **WHEN** `"archive.bin"` is opened again or `togglePinTab` runs
- **THEN** pinning fails closed, zero writable tabs are added, and binary exclusion metrics stay `tabsLeft == 0` for the binary document

#### Scenario: N6 Binary Inspection Never Persists Recovery Snapshots or Enables Mutating Commands
- **Path**: N6
- **Trait**: security
- **GIVEN** a quarantined `0x00`-bearing file loaded for inspection in `SwiftEditWorkbenchModel`
- **WHEN** `saveActiveDocument()`, `saveActiveDocumentAsViaPanel()`, `performCommandD()`, `formatActiveDocument()`, and `persistRecoveryState()` are invoked
- **THEN** all mutating commands remain disabled and fail closed while `SessionRecovery/` contains zero `.recovery` artifacts for the binary file

### Requirement: REQ-004 Off-MainActor Large-File Load Bounded Caches and Memory Ceiling
WHILE loading `>= 2 MiB` files, projecting `3,000`-line previews, or closing modal sheets, previews, and tabs, the workbench SHALL offload decode and projection work off `@MainActor`, evict transient caches promptly, and sustain idle `<= 50 MB` and post-sweep `< 80 MB` physical footprint [AR-010][DATA-002][SEC-012][UI-012].

#### Scenario: P4 Large-File Off-MainActor Load Meets Blocking Budget and Idle/Post-Sweep Memory Targets
- **Path**: P4
- **Trait**: positive
- **GIVEN** a `12 MiB` text file, a `3,000`-line Markdown document, and a 3x modal/preview/diff/tab sweep
- **WHEN** the file opens asynchronously, preview projects on background worker tasks, and `20` tabs/modals open and close
- **THEN** main-thread open block stays `<= 50 ms`, `survivingModels == 0/20`, idle `phys_footprint` stays `<= 50 MB`, and post-sweep footprint stays `< 80 MB`

#### Scenario: N7 Rapid Tab Switch Cancels In-Flight Background Decode Without Corrupting State
- **Path**: N7
- **Trait**: negative
- **GIVEN** an in-flight asynchronous decode for `fileA` (`12 MiB`) interrupted immediately by opening `fileB` (`"short.md"`)
- **WHEN** `fileA` finishes decoding after `activeTabID` moved to `fileB`
- **THEN** the stale `fileA` completion discards UI projection safely without overwriting `fileB`'s active text buffer

#### Scenario: N8 Greater-Than-64-MiB File Fails Pre-Allocation Before Spawning Async Buffer Read
- **Path**: N8
- **Trait**: security
- **GIVEN** an inbound file whose size attribute equals `64 MiB + 1` byte
- **WHEN** `SwiftEditWorkbenchModel.openFile` begins size validation before async decode
- **THEN** `DomainError.fileTooLarge` fails immediately with `CWE-400` pre-allocation protection and zero heap buffer growth

### Requirement: REQ-005 Injected PreferencesProviding Seam Eliminating cfprefsd Stalls and Build Warnings
WHEN persisting preferences or recent files and building Xcode targets, the persistence stores and app project SHALL inject `PreferencesProviding` (`InMemoryKeyValueStore` in tests, container-aligned suite in production) while eliminating `ALWAYS_SEARCH_USER_PATHS` and script warnings [AR-007][AR-009][TEST-003][TEST-004].

#### Scenario: P5 InMemoryKeyValueStore Runs Full Test Suite Under 10 Seconds Across 3 Consecutive Runs
- **Path**: P5
- **Trait**: positive
- **GIVEN** `EditorPreferencesStore`, `RecentFilesStore`, and all `11` test suites migrated off `removePersistentDomain` onto `PreferencesProviding`
- **WHEN** `swift test --parallel` runs `3` consecutive times alongside clean Debug `xcodebuild`
- **THEN** every `swift test` run finishes in `< 10 s` with zero `cfprefsd` stalls and `xcodebuild` emits zero `ALWAYS_SEARCH_USER_PATHS` or `Stamp Info.plist` warnings

#### Scenario: N9 Corrupted Preference Payloads Fail Closed Under InMemoryKeyValueStore
- **Path**: N9
- **Trait**: negative
- **GIVEN** an `InMemoryKeyValueStore` seeded with malformed `recentFiles` JSON and out-of-range zoom (`999`)
- **WHEN** `RecentFilesStore.entries()` and `EditorPreferencesStore.load()` execute
- **THEN** recents return `[]` while clearing the corrupted key and zoom clamps to `300` without touching disk `UserDefaults`

### Requirement: REQ-006 Automated 3x Debug Audit Verification Playbook and Release Gate
WHEN all production and test fixes complete, the verification workflow SHALL execute every step in `macos-debug-audit-playbook.md` three consecutive times to prove zero crashes, zero Swift/ObjC leaks, `<= 16 ms` P99 latency, sticky click-only logo submenu, active large-doc XSS lint, and clean `.tmp/` removal [SEC-001][SEC-004][SDD-001][TEST-001][UI-012].

#### Scenario: P6 Full 3x Automated Debug Telemetry GUI and Benchmark Sweep Passes All Thresholds
- **Path**: P6
- **Trait**: positive
- **GIVEN** a clean Debug build of `PH.SwiftEdit.app`, compiled `axdriver` GUI CLI, and `QAHarness` inside `.tmp/`
- **WHEN** `3x` `swift test`, live GUI AX/CGEvent feature sweeps, `QAHarness --bench` (`50L..20kL`), and `/usr/bin/leaks --atExit` run and clean up
- **THEN** crash count equals `0`, Swift/ObjC leaks equal `0`, idle `phys_footprint <= 50 MB`, P99 typing (`<= 20kL`) and caret (`10kL`) stay `<= 16 ms`, `clickToggle()` stays open `>= 1000 ms`, `swift test < 10 s`, and `.tmp/` is cleanly removed

#### Scenario: N10 Threshold Regression Fails Verification Gate and Blocks Sign-Off
- **Path**: N10
- **Trait**: negative
- **GIVEN** a simulated regression causing `clickToggle()` self-dismiss, `P99 > 16 ms`, or residual `/usr/bin/leaks` objects
- **WHEN** the automated debug audit verification suite evaluates recorded telemetry metrics
- **THEN** the verification runner exits non-zero identifying the failing check ID (`BUG-006`, `PERF-006`, or `MEM-003`) before cleanup

#### Scenario: N11 Automated Audit Verifies Sandbox Isolation Zero WebKit Linkage and Large-Doc XSS Parity
- **Path**: N11
- **Trait**: security
- **GIVEN** `PH.SwiftEdit.app` binary plus a `20,000`-line Markdown benchmark containing `[xss](javascript:alert(1))`
- **WHEN** `codesign -dvvv --entitlements -`, `otool -L`, symlink escape GUI/harness checks, and `QAHarness --bench` execute
- **THEN** entitlements exclude network/`files.all`, `otool -L` excludes `WebKit`/`Network`, escaping child symlinks never leak bytes, and `.unsafeLinkScheme` diagnostics remain `> 0` on `5kL` and `20kL` inputs
