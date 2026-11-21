# Test Plan: SwiftEditCore 3-Way LineEnding (CR), Cursor Metrics, 10-Entry MRU, Shallow Batch Open, Literal Search and Confined Sidebar File Operations

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `LineEndingThreeWayCodec` (`LineEnding`, `DocumentCodec`, `DocumentLoader`) | `P1`: `LF`, `CRLF`, and `CR` files load and save byte-exact (`[DATA-004]`, `[TEST-005]`). | `N1`: `\r\n` never classified as `CR`; mixed endings resolve to `CRLF`; normalization adds no blank lines (`[DATA-004]`). |
| `CursorMetricsCalculator` | `P2`: line, column, and scalar count across `\n`, `\r\n`, `\r` (`[BC-004]`). | `N2`: caret `12` and `-1` throw `DomainError.invalidTextRange`. |
| `RecentFilesStore` (list) | `P3`: reopen moves to index `0`, no duplicate, eleventh file evicts the oldest (`[DATA-008]`, `[SEC-011]`). | `N3`: binary file rejected, deleted file omitted (`[BC-008]`, `[DATA-003]`). |
| `RecentFilesStore` (bookmarks) | `P4`: `resolve` releases scope once; `P5`: `clear` removes the list key (`[DATA-007]`, `[SEC-011]`). | `N4` (`security`): stale bookmark fails closed with balanced release; `N5` (`security`): corrupted or oversized persisted list yields `[]` and removes the key (`[SEC-002]`, `[SEC-012]`). |
| `ShallowFolderBatchLoader` | `P6`: `52` text files listed, binaries and folders skipped, confirmation required; `P7`: batch exactly at the ceiling accepted (`[BC-011]`, `[SEC-003]`). | `N6`: no eligible files gives an empty plan; `N7` (`security`): escaping symlink and over-ceiling batch abort (`[SEC-003]`, `[SEC-012]`). |
| `DocumentSearchEngine` | `P8`: case-aware find, replace-all batch, go-to-line (`[BC-004]`, `[BC-006]`). | `N8`: empty query and bad line are inert; `N9` (`security`): oversized query, match flood, binary or degraded snapshot degrade (`[BC-011]`, `[SEC-012]`). |
| `SidebarCreateAndRenameOperations` (`FileSystemProviding` create/rename, `SidebarItemNameValidator`) | `P9`: create folder, create file, rename inside scope (`[SEC-002]`). | `N10`: invalid names and existing targets rejected; `N11` (`security`): escaping parent and scope-root rename blocked (`[SEC-003]`, `[SEC-012]`). |
| `SidebarPasteAndTrashOperations` (`pasteItem`, `trashItem`, `ItemTrashing`) | `P10`: copy suffixes and cut move; `P11`: trash through the seam (`[BC-012]`). | `N12`: self-descendant paste and cut collision rejected; `N13` (`security`): symlink source, cap overflow, out-of-scope destination refused; `N14` (`security`): scope root and escaping trash blocked (`[SEC-003]`, `[SEC-012]`). |
| `TabSessionFileSync` (`WorkspaceTabSession.applyRename`, `applyTrash`) | `P12`: rename updates tabs in place and trash closes clean tabs (`[BC-006]`, `[BC-008]`). | `N15`: dirty trashed tab detaches; prefix-sibling path untouched (`[DATA-006]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Targeted suites: `swift test --parallel --filter LineEndingThreeWayCodecTests`, `--filter RecentFilesStoreTests`, `--filter ShallowFolderBatchLoaderTests`, `--filter DocumentSearchEngineTests`, `--filter SidebarFileOperationsTests`, `--filter TabSessionFileSyncTests`, `--filter CursorMetricsCalculatorTests`
- Security trait filter command: `swift test --parallel --filter Security`
- Coverage and warnings gate: `swift test --parallel -Xswiftc -warnings-as-errors --enable-code-coverage`

## 3. Testability Seams & Test Doubles
- Real collaborators: `DocumentSession`, `DocumentCodec`, `DocumentLoader`, `WorkspaceTabSession`, `DotfileFolderNavigator`, `EngineEvaluationOutcome`, and real temporary directories under `.tmp/test-results/<UUID>/` for symlink, cap, and rename tests (cleaned with `defer`).
- Isolation seams: `InMemoryFileSystemFake` (extended with directories and a virtual trash), `SecurityScopedBookmarkCoding` fake, counting `SecurityScopedResourceAccessing` fake, recording `ItemTrashing` fake, injected `now` closure, and unique `UserDefaults(suiteName:)` suites (`[TEST-003]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in both delta specs (`REQ-001..REQ-011` plus modified `REQ-002`) |
| Path coverage completeness | Verified | All units have positive (`P1..P12`) and negative (`N1..N15`) paths |
| Security traits tagged | Verified | Abuse cases `N4`, `N5`, `N7`, `N9`, `N11`, `N13`, and `N14` tagged `- **Trait**: security` (`[SEC-002]`, `[SEC-003]`, `[SEC-011]`, `[SEC-012]`, `[BC-011]`) |
