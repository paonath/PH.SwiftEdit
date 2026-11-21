# Proposal: SwiftEditCore 3-Way LineEnding (CR), Cursor Metrics, 10-Entry MRU, Shallow Batch Open, Literal Search and Confined Sidebar File Operations

## Why
Guided reasoning session `002_minimal-ui-menus-and-editor-features` (`TASK-02` in `README.ai.md`) ratified the engine-level behavior behind the minimal editor feature list (`funzionalita-minime-editor.md`): Classic Mac `CR` line endings, live `Line`/`Column`/`Character count` metrics, a 10-entry deduplicated `Open Recent` list, `Open All Files in Folder`, `Find`/`Replace`/`Go to Line`, and the sidebar file and folder actions. Constitution `v1.3.0` (change `005`) already mandates `LF`/`CRLF`/`CR` preservation (`DATA-004`) and confined handoffs (`SEC-004`). This change delivers all of it inside `SwiftEditCore` (pure `Foundation`, zero `AppKit`) so `TASK-03` (`SwiftEditUI`) can bind to tested value types and ports.

## What Changes
- `DocumentPrimitives.swift`: add `LineEnding.cr`; detect `\r\n` before bare `\r`; serialize `.cr` as `\r`; add `DomainError` cases `batchLimitExceeded`, `invalidItemName`, `destinationAlreadyExists`, `invalidPasteTarget`, and `DegradedEvaluationReason.matchLimitExceeded` (`[DATA-004]`, `[BC-012]`).
- `DocumentCore/CursorMetricsCalculator.swift`: `CursorMetrics` and `CursorMetricsCalculator` (1-based line and UTF-16 column, scalar count).
- `WorkspaceAndTabSession/RecentFilesStore.swift`: `RecentFileEntry`, `SecurityScopedBookmarkCoding` seam, `RecentFilesStore` (dedupe by standardized path, cap `10`, balanced security-scoped access, erase on clear, fail-closed decode) (`[DATA-007]`, `[DATA-008]`, `[SEC-002]`, `[SEC-011]`, `[SEC-012]`).
- `WorkspaceAndTabSession/ShallowFolderBatchLoader.swift`: `BatchOpenPlan` and `ShallowFolderBatchLoader` (first-level regular non-binary files, `>50` confirmation, `64 MiB` per file, `256 MiB` cumulative ceiling, escaping symlink abort) (`[BC-011]`, `[SEC-003]`).
- `SearchDiffAndBracketEngine/DocumentSearchEngine.swift`: `SearchOptions` and `DocumentSearchEngine` (`find`, `replaceAll`, `goToLine`; literal only; query and match caps) (`[BC-011]`).
- `DocumentCore/FileSystemProviding.swift` and `DocumentCore/SidebarFileOperations.swift`: extend `FileSystemProviding` with confined create, rename, paste (`cut`/`copy`), and trash; add `SidebarItemNameValidator`, `PasteMode`, and the `ItemTrashing` seam; implement in `LocalFileSystemAdapter` and `InMemoryFileSystemFake` (`[SEC-002]`, `[SEC-003]`, `[SEC-012]`).
- `WorkspaceAndTabSession/WorkspaceTabSession.swift`: `applyRename(from:to:)` and `applyTrash(of:)` (`[BC-006]`, `[BC-008]`).
- Out of scope: any `AppKit`, menu, `NSPasteboard`, `NSWorkspace`, or SwiftUI code (`TASK-03` / `007`).

## Capabilities
- New Capabilities: `core-cr-lineending-mru-batch-search-and-sidebar-fs`
- Modified Capabilities: `document-core-and-spm-scaffold` (`REQ-002`)

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: Three `SwiftEditCore` Bounded Contexts: `DocumentCore` (`Core`: `LineEnding`, cursor metrics, file operations port), `WorkspaceAndTabSession` (`Supporting`: MRU, batch open, tab sync), and `SearchDiffAndBracketEngine` (`Supporting`: literal search) (`[BC-001]`, `[BC-002]`).
- **Owned Decisions**: Line-ending classification order, MRU membership and ordering, batch eligibility and ceilings, search match semantics, sidebar name validity, collision suffixing, and tab reconciliation after rename or trash.
- **Forbidden Responsibilities**: Core MUST NEVER import `AppKit`/`UIKit`/`SwiftUI`/`Network`, spawn subprocesses, read `NSPasteboard`, call `NSWorkspace`, permanently delete user files, or invent conflict policies beyond the specified reject-on-collision for `cut` (`[AR-002]`, `[SEC-004]`, `[BC-010]`).
- **External Decision References**: Consumes `DocumentID`, `BufferRevision`, `TabDescriptor`, `TextRange`, and `TextEdit` (`[BC-006]`).

## Impact
- **Source Modules**: modifies `DocumentPrimitives.swift`, `FileSystemProviding.swift`, `EngineEvaluationPrimitives.swift`, `WorkspaceTabSession.swift`; adds `CursorMetricsCalculator.swift`, `SidebarFileOperations.swift`, `RecentFilesStore.swift`, `ShallowFolderBatchLoader.swift`, `DocumentSearchEngine.swift`.
- **Test Suites**: adds `LineEndingThreeWayCodecTests`, `CursorMetricsCalculatorTests`, `RecentFilesStoreTests`, `ShallowFolderBatchLoaderTests`, `DocumentSearchEngineTests`, `SidebarFileOperationsTests`, `TabSessionFileSyncTests` under `Tests/SwiftEditTests/`.
- **Downstream**: unblocks `TASK-03` (`007-ui-minimal-layout-gutter-menus-cheatsheet-and-sidebar-actions`).

## Security Impact
- Blocks path traversal and symlink escape (`CWE-22`, `CWE-59`) on every sidebar mutation, batch open, and bookmark resolution; refuses to rename, copy over, or trash the scope root (`[SEC-002]`, `[SEC-003]`).
- Prevents data loss and overwrite: non-overwriting copy suffixes, reject-on-collision `cut`, Trash instead of delete, dirty tabs detached rather than closed (`CWE-73`).
- Bounds resource use (`CWE-400`): `50`-file confirmation, `256 MiB` batch and copy ceilings, `1000`-item copy cap, `1024`-unit query cap, `100000` match cap (`[BC-011]`).
- Minimizes retained data (`[SEC-011]`, `[SEC-012]`): no binary files in MRU, bookmark blobs erased on clear, unreadable persisted list fails closed.

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: SwiftEditCore Editor Lifecycle, Recent Files, Batch Open, Search and Sidebar File Operations
- Reviewer: swift-macos-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: document-core-and-spm-scaffold (REQ-002)
- Constitutional-Rules: [AR-002, AR-004, AR-007, BC-004, BC-006, BC-007, BC-008, BC-011, BC-012, DATA-002, DATA-003, DATA-004, DATA-006, DATA-007, DATA-008, SEC-002, SEC-003, SEC-011, SEC-012, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, SDD-001, SDD-002]
- Amends-Constitution: none

## Prerequisites
- Archived `005-constitution-v1-3-lineending-cr-and-workspace-handoff` (Constitution `v1.3.0`) and foundation changes `001`..`004`.
