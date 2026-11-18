# Tasks: SwiftEditCore 3-Way LineEnding (CR), Cursor Metrics, 10-Entry MRU, Shallow Batch Open, Literal Search and Confined Sidebar File Operations

## 1. Unit: LineEndingThreeWayCodec
<!-- Governing rules: DATA-004, BC-007, BC-012, TEST-001, TEST-002, TEST-005 -->

- [ ] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` `@Suite("LineEndingThreeWayCodecTests")` tests in `Tests/SwiftEditTests/LineEndingThreeWayCodecTests.swift` for `P1` (`LF`, `CRLF`, `CR` files load and save byte-exact through `DocumentLoader` with `InMemoryFileSystemFake`, plus a `Cmd+D` regression on a `.cr` session) and `N1` (`\r\n` not classified `CR`, mixed text resolves to `CRLF`, normalization adds no blank lines); verify failure on assertions [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P1, N1]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Add `LineEnding.cr`, unicode-scalar `detect`, and `.cr` serialization in `Sources/SwiftEditCore/DocumentCore/DocumentPrimitives.swift` (and update any exhaustive `switch` over `LineEnding`) so `P1` and `N1` pass [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P1, N1]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract the scalar-scan precedence helper and keep `DocumentCodecAndLoaderTests` and `DocumentSessionAndCommandDTests` green [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P1, N1]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `LineEnding.cr` and the `\r\n`-before-`\r` precedence rule
  - paths: [P1, N1]

## 2. Unit: CursorMetricsCalculator
<!-- Governing rules: BC-004, BC-006, BC-007, TEST-002 -->

- [ ] 2.1 [RED] TASK-002-RED: Write failing `@Suite("CursorMetricsCalculatorTests")` tests in `Tests/SwiftEditTests/CursorMetricsCalculatorTests.swift` for `P2` (buffer `"ab\ncd\r\nef\rg"`, caret `8` gives line `3` column `2`, caret `10` gives line `4` column `1`, scalar count `11`) and `N2` (caret `12` and `-1` throw `DomainError.invalidTextRange`); verify failure on assertions [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P2, N2]
- [ ] 2.2 [GREEN] TASK-002-GREEN: Implement `CursorMetrics` and `CursorMetricsCalculator.metrics(in:caretLocation:)` in `Sources/SwiftEditCore/DocumentCore/CursorMetricsCalculator.swift` so `P2` and `N2` pass [Const: BC-007 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P2, N2]
- [ ] 2.3 [REFACTOR] TASK-002-REFACTOR: Share the line-break scalar classifier with `LineEnding` and keep the suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P2, N2]
- [ ] 2.4 [DOC] TASK-002-DOC: Write concise English Swift Markup (`///`) documentation on `CursorMetrics` (units: UTF-16 column, scalar count) and the thrown error
  - paths: [P2, N2]

## 3. Unit: RecentFilesStore
<!-- Governing rules: BC-007, BC-008, DATA-003, DATA-007, DATA-008, SEC-002, SEC-011, SEC-012, TEST-003, TEST-004 -->

- [ ] 3.1 [RED] TASK-003-RED: Write failing `@Suite("RecentFilesStoreTests")` tests in `Tests/SwiftEditTests/RecentFilesStoreTests.swift` using `InMemoryFileSystemFake`, an injected clock, and unique `UserDefaults(suiteName:)` for `P3` (reopen moves to index `0` with newer timestamp, eleventh file evicts the oldest) and `N3` (binary file throws `DomainError.binaryFileSaveForbidden`, deleted file omitted from `entries()`); verify failure on assertions [Const: DATA-008 (04-data-persistence/write-read-separation.md)]
  - paths: [P3, N3]
- [ ] 3.2 [GREEN] TASK-003-GREEN: Implement `RecentFileEntry`, `SecurityScopedBookmarkCoding` (with system implementation), and `RecentFilesStore.record(url:withinScope:)` / `entries()` in `Sources/SwiftEditCore/WorkspaceAndTabSession/RecentFilesStore.swift` so `P3` and `N3` pass [Const: BC-008 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P3, N3]
- [ ] 3.3 [REFACTOR] TASK-003-REFACTOR: Extract the dedupe-and-cap list reducer and the file probe helper while keeping the suite green [Const: AR-007 (01-architecture/dependency-and-layering.md)]
  - paths: [P3, N3]
- [ ] 3.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on `RecentFileEntry`, `RecentFilesStore.record`, and the injected seams
  - paths: [P3, N3]
- [ ] 3.5 [RED] [SECURITY] TASK-004-RED: Write failing security tests in `Tests/SwiftEditTests/RecentFilesStoreTests.swift` for `P4` (resolve releases scope once, `start == stop == 1`), `N4` (unresolvable or path-mismatched bookmark throws, entry pruned, counts equal), `P5` (`clear()` removes the list key), and `N5` (malformed or `> 1 MiB` persisted list returns `[]` and removes the key); verify failure on assertions [Const: SEC-011 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P4, N4, P5, N5] · tags: security · priority: critical
- [ ] 3.6 [GREEN] [SECURITY] TASK-004-GREEN: Implement `resolve(entry:)` with `startAccessing`/`defer stopAccessing` and path-match check, `clear()`, and fail-closed bounded decode (no archive deserialization) in `RecentFilesStore.swift` so `P4`, `N4`, `P5`, and `N5` pass [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P4, N4, P5, N5] · tags: security · priority: critical
- [ ] 3.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Consolidate the persisted-blob guard and scope-bracketing helper without weakening any security assertion [Const: DATA-007 (04-data-persistence/write-read-separation.md)]
  - paths: [P4, N4, P5, N5] · tags: security
- [ ] 3.8 [DOC] [SECURITY] TASK-004-DOC: Document bookmark privacy, balanced scope release, and fail-closed decode invariants (`SEC-011`, `SEC-012`) in English Swift Markup (`///`) comments
  - paths: [P4, N4, P5, N5]

## 4. Unit: ShallowFolderBatchLoader
<!-- Governing rules: BC-007, BC-011, BC-012, DATA-002, DATA-003, SEC-002, SEC-003, SEC-012 -->

- [ ] 4.1 [RED] TASK-005-RED: Write failing `@Suite("ShallowFolderBatchLoaderTests")` tests in `Tests/SwiftEditTests/ShallowFolderBatchLoaderTests.swift` using real temporary directories for `P6` (`52` text files listed, `3` binaries and `2` folders skipped, `requiresConfirmation == true`) and `N6` (only binaries and folders gives an empty plan without error); verify failure on assertions [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P6, N6]
- [ ] 4.2 [GREEN] TASK-005-GREEN: Implement `BatchOpenPlan` and `ShallowFolderBatchLoader.plan(folder:withinScope:)` over `DotfileFolderNavigator` in `Sources/SwiftEditCore/WorkspaceAndTabSession/ShallowFolderBatchLoader.swift` so `P6` and `N6` pass [Const: BC-007 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P6, N6]
- [ ] 4.3 [REFACTOR] TASK-005-REFACTOR: Extract the regular-file and binary-probe filter and keep the suite green [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P6, N6]
- [ ] 4.4 [DOC] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on `BatchOpenPlan` and the `50`-file confirmation rule
  - paths: [P6, N6]
- [ ] 4.5 [RED] [SECURITY] TASK-006-RED: Write failing security tests in `Tests/SwiftEditTests/ShallowFolderBatchLoaderTests.swift` for `P7` (batch exactly at an injected `1 KiB` ceiling accepted with balanced scope counts) and `N7` (symlink escaping scope throws `DomainError.securityScopeViolation`, over-ceiling batch throws `DomainError.batchLimitExceeded`); verify failure on assertions [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P7, N7] · tags: security · priority: critical
- [ ] 4.6 [GREEN] [SECURITY] TASK-006-GREEN: Add `DomainError.batchLimitExceeded`, the injectable `maxBatchBytes` ceiling, the `64 MiB` per-file skip, and abort-before-open semantics in `ShallowFolderBatchLoader.swift` so `P7` and `N7` pass [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P7, N7] · tags: security · priority: critical
- [ ] 4.7 [REFACTOR] [SECURITY] TASK-006-REFACTOR: Consolidate cumulative-size accounting and confinement error paths while keeping all suites green [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P7, N7] · tags: security
- [ ] 4.8 [DOC] [SECURITY] TASK-006-DOC: Document the `256 MiB` ceiling, symlink abort, and `CWE-22`/`CWE-400` invariants in English Swift Markup (`///`) comments
  - paths: [P7, N7]

## 5. Unit: DocumentSearchEngine
<!-- Governing rules: AR-004, BC-004, BC-006, BC-011, SEC-012, TEST-002 -->

- [ ] 5.1 [RED] TASK-007-RED: Write failing `@Suite("DocumentSearchEngineTests")` tests in `Tests/SwiftEditTests/DocumentSearchEngineTests.swift` for `P8` (find `"alpha"` insensitive `(0,5)` and `(11,5)` and sensitive `(11,5)`, replace-all batch applied by `DocumentSession.applyTextEdits` in one revision, line `3` resolves to `TextRange(location: 23, length: 5)`) and `N8` (empty query and lines `0`/`4` are inert); verify failure on assertions [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P8, N8]
- [ ] 5.2 [GREEN] TASK-007-GREEN: Implement `SearchOptions` and `DocumentSearchEngine.find`, `replaceAll`, and `goToLine` in `Sources/SwiftEditCore/SearchDiffAndBracketEngine/DocumentSearchEngine.swift` so `P8` and `N8` pass [Const: AR-004 (01-architecture/module-topology.md)]
  - paths: [P8, N8]
- [ ] 5.3 [REFACTOR] TASK-007-REFACTOR: Share the UTF-16 line-start index builder between `goToLine` and cursor metrics while keeping the suite green [Const: TEST-002 (06-testing-fitness/tdd-and-unit-testing.md)]
  - paths: [P8, N8]
- [ ] 5.4 [DOC] TASK-007-DOC: Write concise English Swift Markup (`///`) documentation on `SearchOptions` and the three engine entry points
  - paths: [P8, N8]
- [ ] 5.5 [RED] [SECURITY] TASK-008-RED: Write failing security test in `Tests/SwiftEditTests/DocumentSearchEngineTests.swift` for `N9` (`1025`-unit query returns `inputTooLarge`, `> 100000` matches returns `matchLimitExceeded`, binary snapshot returns `binarySnapshot`) plus the passing `P8` baseline; verify failure on assertions [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P8, N9] · tags: security · priority: critical
- [ ] 5.6 [GREEN] [SECURITY] TASK-008-GREEN: Add `DegradedEvaluationReason.matchLimitExceeded(maxMatches:)` and the query, match, binary, and degraded guards in `DocumentSearchEngine.swift` so `N9` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P8, N9] · tags: security · priority: critical
- [ ] 5.7 [REFACTOR] [SECURITY] TASK-008-REFACTOR: Consolidate guard ordering and audit `switch` statements over `DegradedEvaluationReason` while keeping all suites green [Const: BC-011 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P8, N9] · tags: security
- [ ] 5.8 [DOC] [SECURITY] TASK-008-DOC: Document the literal-only (no regex) decision and `CWE-400`/`CWE-1333` caps in English Swift Markup (`///`) comments
  - paths: [P8, N9]

## 6. Unit: SidebarCreateAndRenameOperations
<!-- Governing rules: BC-007, BC-012, SEC-002, SEC-003, SEC-012, TEST-003, TEST-004 -->

- [ ] 6.1 [RED] TASK-009-RED: Write failing `@Suite("SidebarFileOperationsTests")` tests in `Tests/SwiftEditTests/SidebarFileOperationsTests.swift` using real temporary directories for `P9` (create folder `"docs"`, create file `"notes.md"`, rename to `"final.md"`) and `N10` (parameterized invalid names throw `DomainError.invalidItemName`, existing target throws `DomainError.destinationAlreadyExists`); verify failure on assertions [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P9, N10]
- [ ] 6.2 [GREEN] TASK-009-GREEN: Add `SidebarItemNameValidator`, `DomainError.invalidItemName` and `destinationAlreadyExists`, and `createDirectory`, `createFile`, `renameItem` on `FileSystemProviding`, `LocalFileSystemAdapter`, and `InMemoryFileSystemFake` in `Sources/SwiftEditCore/DocumentCore/FileSystemProviding.swift` and `SidebarFileOperations.swift` so `P9` and `N10` pass [Const: BC-007 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P9, N10]
- [ ] 6.3 [REFACTOR] TASK-009-REFACTOR: Extract the shared name-and-parent resolution used by create and rename and keep existing `DocumentCodecAndLoaderTests` green [Const: AR-007 (01-architecture/dependency-and-layering.md)]
  - paths: [P9, N10]
- [ ] 6.4 [DOC] TASK-009-DOC: Write concise English Swift Markup (`///`) documentation on `SidebarItemNameValidator` and the new port methods
  - paths: [P9, N10]
- [ ] 6.5 [RED] [SECURITY] TASK-010-RED: Write failing security test in `Tests/SwiftEditTests/SidebarFileOperationsTests.swift` for `N11` (create inside a symlinked parent that escapes scope and rename of the scope root both throw `DomainError.securityScopeViolation` with no disk change); verify failure on assertions [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P9, N11] · tags: security · priority: critical
- [ ] 6.6 [GREEN] [SECURITY] TASK-010-GREEN: Enforce `resolvingSymlinksInPath()` parent confinement and scope-root protection in `LocalFileSystemAdapter` create and rename so `N11` passes [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P9, N11] · tags: security · priority: critical
- [ ] 6.7 [REFACTOR] [SECURITY] TASK-010-REFACTOR: Reuse `verifyScopeConfinement` for all mutating methods and keep all suites green [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P9, N11] · tags: security
- [ ] 6.8 [DOC] [SECURITY] TASK-010-DOC: Document `CWE-22`/`CWE-59` confinement and scope-root protection invariants in English Swift Markup (`///`) comments
  - paths: [P9, N11]

## 7. Unit: SidebarPasteAndTrashOperations
<!-- Governing rules: BC-012, DATA-004, SEC-003, SEC-012, TEST-003, TEST-004 -->

- [ ] 7.1 [RED] TASK-011-RED: Write failing tests in `Tests/SwiftEditTests/SidebarFileOperationsTests.swift` for `P10` (copy twice gives `"final copy.md"` and `"final copy 2.md"`, cut moves into `"docs"`) and `N12` (`"src"` into `"src/nested"` throws `DomainError.invalidPasteTarget`, cut onto existing name throws `DomainError.destinationAlreadyExists`); verify failure on assertions [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P10, N12]
- [ ] 7.2 [GREEN] TASK-011-GREEN: Add `PasteMode`, `DomainError.invalidPasteTarget`, and `pasteItem(from:toDirectory:mode:withinScope:)` with first-free suffixing to `FileSystemProviding`, `LocalFileSystemAdapter`, and `InMemoryFileSystemFake` so `P10` and `N12` pass [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P10, N12]
- [ ] 7.3 [REFACTOR] TASK-011-REFACTOR: Extract the collision-suffix generator and keep the suite green [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P10, N12]
- [ ] 7.4 [DOC] TASK-011-DOC: Write concise English Swift Markup (`///`) documentation on `PasteMode` and the suffix rules
  - paths: [P10, N12]
- [ ] 7.5 [RED] [SECURITY] TASK-012-RED: Write failing security tests in `Tests/SwiftEditTests/SidebarFileOperationsTests.swift` for `P11` (trash passes the standardized URL to a recording `ItemTrashing` fake once), `N13` (symlink in source tree, item cap overflow, and out-of-scope destination refused with no partial copy), and `N14` (scope root and escaping symlink trash throw `DomainError.securityScopeViolation` without calling the seam); verify failure on assertions [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P10, P11, N13, N14] · tags: security · priority: critical
- [ ] 7.6 [GREEN] [SECURITY] TASK-012-GREEN: Add `ItemTrashing` (system `FileManager.trashItem` implementation), `trashItem(at:withinScope:)`, injectable `maxCopyItems`/`maxCopyBytes`, symlink pre-scan, and `DomainError.batchLimitExceeded` reuse in `LocalFileSystemAdapter` so `P11`, `N13`, and `N14` pass [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P10, P11, N13, N14] · tags: security · priority: critical
- [ ] 7.7 [REFACTOR] [SECURITY] TASK-012-REFACTOR: Consolidate tree pre-scan and confinement checks, remove any `./.tmp/` test artifacts, and keep all suites green [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P10, P11, N13, N14] · tags: security
- [ ] 7.8 [DOC] [SECURITY] TASK-012-DOC: Document non-overwrite, no-symlink-copy, Trash-only deletion, and `CWE-73`/`CWE-400` invariants in English Swift Markup (`///`) comments
  - paths: [P10, P11, N13, N14]

## 8. Unit: TabSessionFileSync
<!-- Governing rules: BC-006, BC-008, DATA-006, TEST-002 -->

- [ ] 8.1 [RED] TASK-013-RED: Write failing `@Suite("TabSessionFileSyncTests")` tests in `Tests/SwiftEditTests/TabSessionFileSyncTests.swift` for `P12` (rename updates title and `fileURL` in place for a file and a folder prefix keeping `DocumentID`, trash closes clean tabs) and `N15` (dirty trashed tab keeps `isDirty == true` with `fileURL == nil`, and `"/w/draft.md.bak"` is untouched); verify failure on assertions [Const: BC-008 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P12, N15]
- [ ] 8.2 [GREEN] TASK-013-GREEN: Implement `WorkspaceTabSession.applyRename(from:to:)` and `applyTrash(of:)` with `/`-boundary prefix matching in `Sources/SwiftEditCore/WorkspaceAndTabSession/WorkspaceTabSession.swift` so `P12` and `N15` pass [Const: BC-006 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P12, N15]
- [ ] 8.3 [REFACTOR] TASK-013-REFACTOR: Extract the path-prefix matcher, then run `swift test --parallel -Xswiftc -warnings-as-errors --enable-code-coverage` and confirm `>= 85%` `SwiftEditCore` coverage and green `ArchitectureFitnessTests` and `ConstitutionFitnessTests` [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P12, N15]
- [ ] 8.4 [DOC] TASK-013-DOC: Write concise English Swift Markup (`///`) documentation on `applyRename` and `applyTrash` including the dirty-tab detach rationale
  - paths: [P12, N15]

## 9. Unit: LivingSpecificationReconciliation
<!-- Required because the change includes a MODIFIED requirement -->

- [ ] 9.1 [SYNC] TASK-014-SYNC: Execute `/myspec-sync 006-core-cr-lineending-mru-batch-search-and-sidebar-fs` to reconcile delta changes into `openspec/specs/document-core-and-spm-scaffold/spec.md` and `openspec/specs/core-cr-lineending-mru-batch-search-and-sidebar-fs/spec.md` (automatically marked `[x]` by `myspec_sync.py`)
