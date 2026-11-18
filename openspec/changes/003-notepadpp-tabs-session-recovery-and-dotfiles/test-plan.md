# Test Plan: Implement WorkspaceAndTabSession (Notepad++ Pin, SessionRecovery GC, Dotfiles & EditorPreferences)

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `WorkspaceTabBarState` (`WorkspaceTabSession` & `TabDescriptor`) | `P1`: Opens, activates, updates (`caretLocation`, `BufferRevision`, `isDirty`), pins, and unpins text tabs, keeping pinned tabs ordered ahead of unpinned tabs (`[AR-004]`, `[BC-006]`, `[BC-008]`). | `N1`: Rejects closing a pinned tab (`DomainError.pinnedTabCloseForbidden`) and operations on unknown tab IDs (`DomainError.tabNotFound`) without mutating state; `N2` (`security`): Rejects opening or pinning a binary read-only snapshot (`isBinaryReadOnly == true`) with `DomainError.binaryFileSaveForbidden` (`[BC-008]`, `[DATA-003]`, `[SEC-011]`, `[SEC-012]`). |
| `SessionRecoveryStore` (`SessionRecoveryStore`, `SessionRecoveryManifest`, `RecoveredDocumentSnapshot`) | `P2`: Atomically persists and restores `session-manifest.json` and dirty/unbacked `<UUID>.recovery` snapshots with `0700`/`0600` permissions and `isExcludedFromBackup == true`, unlinks snapshots synchronously on tab close, and purges unreferenced orphan `.recovery` files on startup GC (`[DATA-005]`, `[DATA-006]`, `[SEC-007]`, `[SEC-011]`). | `N3`: Rejects malformed `session-manifest.json` payloads with `DomainError.corruptedRecoveryManifest`; `N4` (`security`): Rejects binary read-only snapshots (`DomainError.binaryFileSaveForbidden`), recovery writes exceeding the `64 MiB` (`67_108_864` bytes) quota (`DomainError.sessionRecoveryQuotaExceeded`), and symlinked recovery paths (`DomainError.securityScopeViolation`) (`[DATA-003]`, `[SEC-003]`, `[SEC-007]`, `[SEC-011]`, `[SEC-012]`). |
| `DotfileNavigatorAndPreferences` (`DotfileFolderNavigator` & `EditorPreferencesStore`) | `P3`: Lists shallow directory entries including hidden dotfiles (`.env`, `.gitignore`) sorted directories-first with balanced `startAccessing`/`stopAccessing` calls, and round-trips `EditorPreferences` (`Light`/`Black`/`Auto`, zoom `50%..300%`) in isolated `UserDefaults` (`[BC-007]`, `[DATA-007]`, `[DATA-008]`, `[SEC-002]`, `[TEST-003]`). | `N5`: Clamps out-of-range zoom values (`< 50` -> `50`, `> 300` -> `300`) and defaults invalid appearance values to `.auto`; `N6` (`security`): Rejects directories or child symlinks escaping the granted workspace scope via `resolvingSymlinksInPath()` with `DomainError.securityScopeViolation` while still calling `stopAccessing` in `defer` (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`, `[SEC-012]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Security trait / suite filter command: `swift test --parallel --filter Security`
- Coverage verification command: `swift test --parallel --enable-code-coverage`

## 3. Testability Seams & Test Doubles
- Real collaborators: Real `WorkspaceTabSession`, `SessionRecoveryStore`, `DotfileFolderNavigator`, and `EditorPreferencesStore` operating on isolated `.tmp/test-results/` directories and unique `UserDefaults(suiteName:)` suites (`TEST-003`).
- Isolation seams: `RecordingSecurityScopeFake` conforming to `SecurityScopedResourceAccessing` (`AR-007`, `DATA-007`, `SEC-002`, `TEST-004`) recording `startCount` and `stopCount` deterministically across normal and throwing paths.

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in `specs/notepadpp-tabs-session-recovery-and-dotfiles/spec.md` (`REQ-001..REQ-004`) |
| Path coverage completeness | Verified | All 3 units cover positive (`P1..P3`) and negative (`N1..N6`) paths |
| Security traits tagged | Verified | Abuse cases `N2`, `N4`, and `N6` tagged `- **Trait**: security` (`[BC-008]`, `[DATA-003]`, `[SEC-002]`, `[SEC-003]`, `[SEC-007]`, `[SEC-011]`, `[SEC-012]`) |
