# Test Plan: Contextual Reveal in Folder Navigator, Start Dictation Here & Empty Untitled Session Filter

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `ElementContextualActionCatalog` (`SwiftEditCore`) | P1: `groups(hasSelection:canRevealInFolderNavigator:canStartDictation:)` includes `Reveal in Folder Navigator` and `Start Dictation Here` in `Document` group with and without selection | N1: Omitting flags excludes both actions; `evaluate()` returns `nil` for `.revealInFolderNavigator` and `.startDictationHere` (`negative`) |
| `SwiftEditWorkbenchModel` Reveal in Folder Navigator (`SwiftEditUI`) | P2: Collapsed sidebar, `nil` folder, or different folder expands sidebar, sets `selectedFolderURL` to canonical parent (preserving ancestor `grantedScopeRootURL`), refreshes entries, and highlights `selectedSidebarEntryURL` | N2: Untitled tab or already-open matching canonical folder (incl. symlink equivalence) returns `canRevealActiveDocumentInFolderNavigator == false`; missing/unreadable parent fails closed with `statusBannerMessage` (`security`) |
| `SwiftEditWorkbenchModel` & `SwiftEditNSTextView` Start Dictation Here (`SwiftEditUI`) | P3: Writable tab exposes `Start Dictation Here` in `Cmd+Return` palette and right-click `NSMenu`; invoking closes palette, focuses editor, and calls `dictationTrigger` returning `true`; `AppIcon.microphone` passes 24x24 vector geometry check | N3: Binary read-only, live log-tail, or missing editable text view omits menu action and returns `false` without calling `dictationTrigger` (`security`) |
| `SessionRecoveryEligibility` & Workbench Recovery (`SwiftEditCore` + `SwiftEditUI`) | P4: Non-empty untitled tabs and disk-backed/pinned tabs (including empty disk-backed files) persist and restore cleanly across relaunch | N4: Empty (`""`) and whitespace-only (`" \n\t"`) untitled tabs are excluded on save and restore; clearing a non-empty untitled tab unlinks its `.recovery` file; legacy empty snapshots are purged on startup (`security`) |

## 2. Test Automation Strategy & Commands
- Constitutional Alignment: `[TEST-001][TEST-005][UI-010][DATA-005][DATA-006][SEC-002][SEC-011][SEC-012]`
- Unit test runner command: `swift test --filter ContextualRevealDictationAndSessionFilterTests`
- Full regression suite command: `swift test`
- Trait / security test filter command: `swift test --filter "ContextualRevealDictationAndSessionFilterTests/(n1|n2|n3|n4)"`

## 3. Testability Seams & Test Doubles
- Real collaborators: `WorkspaceTabSession`, `DocumentSession`, `ElementContextualActionCatalog`, `ElementContextualMenuState`, `SessionRecoveryStore` (backed by ephemeral temp directory), `DotfileFolderNavigator`, `LocalFileSystemAdapter` on temporary directories.
- Isolation seams:
  - Injectable `dictationTrigger: @MainActor (SwiftEditNSTextView) -> Bool` in `SwiftEditWorkbenchModel.init` / `WorkbenchDependencies` (avoids live macOS Dictation UI in headless tests).
  - Injectable `parentPermissionChecker: (URL) -> Bool` and ephemeral `recoveryDirectoryURL` + isolated `PreferencesProviding` for deterministic parallel `Swift Testing`.
  - Direct `SwiftEditNSTextView.menu(for:)` inspection with synthetic `NSEvent` (matching existing `SendToTerminalContextualActionTests`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | EARS requirements and Given/When/Then scenarios defined across both capability deltas |
| Path coverage completeness | Verified | All 4 units have P1..P4 and N1..N4 paths |
| Security traits tagged | Verified | Security abuse cases N1, N2, N10 tagged `- **Trait**: security` with Rule G3 waiver |
