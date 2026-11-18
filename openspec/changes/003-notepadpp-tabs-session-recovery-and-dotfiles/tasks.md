# Tasks: Implement WorkspaceAndTabSession (Notepad++ Pin, SessionRecovery GC, Dotfiles & EditorPreferences)

## 1. Unit: WorkspaceTabBarState
<!-- Governing rules: AR-002, AR-004, BC-001, BC-002, BC-006, BC-008, BC-009, BC-012, DATA-003, SEC-011, SEC-012, TEST-001, TEST-002, TEST-005, SDD-002, SDD-003 -->

- [ ] 1.0 [SETUP] TASK-000-SETUP: Create `Sources/SwiftEditCore/WorkspaceAndTabSession` directory and add `tabNotFound`, `pinnedTabCloseForbidden`, `sessionRecoveryQuotaExceeded`, and `corruptedRecoveryManifest` cases to `DomainError` in `DocumentPrimitives.swift` before behavioral TDD triads [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
  - paths: [P1, P2, P3]
- [ ] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` `@Suite("WorkspaceTabSessionTests")` tests in `Tests/SwiftEditTests/WorkspaceTabSessionTests.swift` for `P1` (opening, activating, pinning/unpinning with pinned-first ordering, and updating `caretLocation`/`BufferRevision`) and `N1` (`DomainError.pinnedTabCloseForbidden` on closing a pinned tab and `DomainError.tabNotFound` on unknown IDs); verify failure on assertions [Const: BC-008 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P1, N1]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Implement `TabDescriptor` and `WorkspaceTabSession` in `Sources/SwiftEditCore/WorkspaceAndTabSession/WorkspaceTabSession.swift` so `P1` and `N1` pass [Const: BC-006 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P1, N1]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract pinned-first partition helper and active-tab fallback resolution in `WorkspaceTabSession` while keeping `P1` and `N1` green [Const: AR-004 (01-architecture/module-topology.md)]
  - paths: [P1, N1]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `TabDescriptor` and `WorkspaceTabSession`
  - paths: [P1, N1]
- [ ] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing security test `n2SecurityBinarySnapshotRejectedFromTabsAndPinning` in `Tests/SwiftEditTests/WorkspaceTabSessionTests.swift` for `N2` verifying that binary read-only snapshots (`isBinaryReadOnly == true`) throw `DomainError.binaryFileSaveForbidden`; verify failure on assertions [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [ ] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Enforce `isBinaryReadOnly == false` guard in `WorkspaceTabSession` throwing `DomainError.binaryFileSaveForbidden` so `N2` passes [Const: SEC-011 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [ ] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Consolidate binary admissibility checks across `WorkspaceTabSession` entry points while keeping all suites green [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P1, N2] · tags: security
- [ ] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document binary tab and pinning exclusion invariants (`BC-008`, `DATA-003`, `SEC-011`) in English Swift Markup (`///`) comments
  - paths: [P1, N2]

## 2. Unit: SessionRecoveryStore
<!-- Governing rules: BC-007, BC-008, DATA-001, DATA-003, DATA-005, DATA-006, SEC-003, SEC-007, SEC-011, SEC-012, TEST-003, TEST-005 -->

- [ ] 2.1 [RED] TASK-003-RED: Write failing `Swift Testing` `@Suite("SessionRecoveryStoreTests")` tests in `Tests/SwiftEditTests/SessionRecoveryStoreTests.swift` for `P2` (atomic save/load of `SessionRecoveryManifest` and `<UUID>.recovery` text snapshots with `0700`/`0600` permissions and `isExcludedFromBackup == true`, immediate unlink on tab close, and startup orphan GC) and `N3` (`DomainError.corruptedRecoveryManifest` on invalid JSON); verify failure on assertions [Const: DATA-005 (04-data-persistence/write-read-separation.md)]
  - paths: [P2, N3]
- [ ] 2.2 [GREEN] TASK-003-GREEN: Implement `SessionRecoveryManifest`, `RecoveredDocumentSnapshot`, and `SessionRecoveryStore` in `Sources/SwiftEditCore/WorkspaceAndTabSession/SessionRecoveryStore.swift` so `P2` and `N3` pass [Const: DATA-006 (04-data-persistence/write-read-separation.md)]
  - paths: [P2, N3]
- [ ] 2.3 [REFACTOR] TASK-003-REFACTOR: Extract `0700`/`0600` permission and `isExcludedFromBackup` resource-value helpers in `SessionRecoveryStore` while keeping `P2` and `N3` green [Const: SEC-007 (07-security-privacy/secrets-and-supply-chain.md)]
  - paths: [P2, N3]
- [ ] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation on `SessionRecoveryManifest`, `RecoveredDocumentSnapshot`, and `SessionRecoveryStore`
  - paths: [P2, N3]
- [ ] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing security test `n4SecurityBinarySnapshotQuotaAndSymlinkRecoveryGuards` in `Tests/SwiftEditTests/SessionRecoveryStoreTests.swift` for `N4` verifying binary snapshot rejection (`DomainError.binaryFileSaveForbidden`), `> 64 MiB` quota rejection (`DomainError.sessionRecoveryQuotaExceeded`), and symlink rejection (`DomainError.securityScopeViolation`); verify failure on assertions [Const: SEC-007 (07-security-privacy/secrets-and-supply-chain.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [ ] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Implement binary guard, `64 MiB` (`67_108_864` bytes) aggregate directory quota check, and symlink verification in `SessionRecoveryStore` so `N4` passes [Const: SEC-011 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [ ] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Refine directory byte-usage accounting (subtracting existing snapshot size on overwrite) in `SessionRecoveryStore` while keeping all suites green [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P2, N4] · tags: security
- [ ] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document the `64 MiB` quota, `0700`/`0600` permissions, backup exclusion, and GDPR Art. 5(1)(c) close-unlink/GC invariants in English Swift Markup (`///`) comments
  - paths: [P2, N4]

## 3. Unit: DotfileNavigatorAndPreferences
<!-- Governing rules: AR-007, BC-007, DATA-007, DATA-008, SEC-002, SEC-003, SEC-012, TEST-003, TEST-004, TEST-005, TEST-008 -->

- [ ] 3.1 [RED] TASK-005-RED: Write failing `Swift Testing` `@Suite("DotfileNavigatorAndPreferencesTests")` tests in `Tests/SwiftEditTests/DotfileNavigatorAndPreferencesTests.swift` for `P3` (shallow dotfile-inclusive directory listing sorted directories-first with balanced `RecordingSecurityScopeFake` calls, plus `EditorPreferencesStore` round-trip) and `N5` (`50...300` zoom clamping and `.auto` appearance fallback); verify failure on assertions [Const: DATA-007 (04-data-persistence/write-read-separation.md)]
  - paths: [P3, N5]
- [ ] 3.2 [GREEN] TASK-005-GREEN: Implement `SecurityScopedResourceAccessing`, `FolderEntryDescriptor`, `DotfileFolderNavigator`, `AppearanceMode`, `EditorPreferences`, and `EditorPreferencesStore` in `Sources/SwiftEditCore/WorkspaceAndTabSession/` so `P3` and `N5` pass [Const: DATA-008 (04-data-persistence/write-read-separation.md)]
  - paths: [P3, N5]
- [ ] 3.3 [REFACTOR] TASK-005-REFACTOR: Extract directory-first case-insensitive comparator and `EditorPreferences` clamping logic while keeping `P3` and `N5` green [Const: BC-007 (02-domain/negative-ownership-and-refs.md)]
  - paths: [P3, N5]
- [ ] 3.4 [DOC] TASK-005-DOC: Write concise English Swift Markup (`///`) documentation on `SecurityScopedResourceAccessing`, `FolderEntryDescriptor`, `DotfileFolderNavigator`, `AppearanceMode`, `EditorPreferences`, and `EditorPreferencesStore`
  - paths: [P3, N5]
- [ ] 3.5 [RED] [SECURITY] TASK-006-RED: Write failing security test `n6SecurityFolderNavigatorSymlinkEscapeAndBalancedScopeRelease` in `Tests/SwiftEditTests/DotfileNavigatorAndPreferencesTests.swift` for `N6` verifying that a symlink escaping the workspace scope throws `DomainError.securityScopeViolation` and still calls `stopAccessing` in `defer`; verify failure on assertions [Const: SEC-002 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [ ] 3.6 [GREEN] [SECURITY] TASK-006-GREEN: Enforce `resolvingSymlinksInPath()` confinement across directory and child entries in `DotfileFolderNavigator` with guaranteed `defer { stopAccessing }` so `N6` passes [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [ ] 3.7 [REFACTOR] [SECURITY] TASK-006-REFACTOR: Verify zero compiler warnings and `>= 85%` `SwiftEditCore` line coverage across all parallel test suites [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N6] · tags: security
- [ ] 3.8 [DOC] [SECURITY] TASK-006-DOC: Document security-scoped resource bracketing (`SEC-002`) and symlink confinement (`SEC-003`) invariants on `DotfileFolderNavigator` in English Swift Markup (`///`) comments
  - paths: [P3, N6]
