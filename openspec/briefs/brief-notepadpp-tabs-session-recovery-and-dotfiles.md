---
id: "brief-notepadpp-tabs-session-recovery-and-dotfiles"
change_id: "003-notepadpp-tabs-session-recovery-and-dotfiles"
capability: "notepadpp-tabs-session-recovery-and-dotfiles"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-18"
owners:
  - "swift-macos-expert"
  - "ddd-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `WorkspaceAndTabSession` (Notepad++ Pin, `SessionRecovery` GC & Dotfile Folder Navigator) (`TASK-04`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-04` in `reasoning/001_project-constitution/README.ai.md`.
- **Active Git Branch**: `feature/FirstStub` (`Nerdbank.GitVersioning` `0.0.1-alpha1`).
- **Consolidated Specs Modified (`modifies_specs`)**: `none` (existing living specs `design-assets-promotion`, `document-core-and-spm-scaffold`, and `markdown-lint-format-bracket-and-diff` are untouched; all requirements in `notepadpp-tabs-session-recovery-and-dotfiles` are `ADDED`).
- **Governing Constitutional Rules**: `[AR-002]`, `[AR-004]`, `[AR-007]`, `[AR-008]`, `[BC-001]`, `[BC-002]`, `[BC-006]`, `[BC-007]`, `[BC-008]`, `[BC-009]`, `[BC-012]`, `[DATA-001]`, `[DATA-003]`, `[DATA-005]`, `[DATA-006]`, `[DATA-007]`, `[DATA-008]`, `[TEST-001]`, `[TEST-002]`, `[TEST-003]`, `[TEST-004]`, `[TEST-005]`, `[TEST-008]`, `[SEC-002]`, `[SEC-003]`, `[SEC-006]`, `[SEC-007]`, `[SEC-009]`, `[SEC-010]`, `[SEC-011]`, `[SEC-012]`, `[SDD-001]`, `[SDD-002]`, `[SDD-003]`.

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert` (`openspec/agents/swift-macos-expert.agent.md` v1.2.0)**:
  - `WorkspaceAndTabSession` (`Supporting` subdomain) resides inside `Sources/SwiftEditCore/WorkspaceAndTabSession/` and imports exclusively `Foundation` (`AR-002`, `AR-004`).
  - `WorkspaceTabSession` manages ordered `TabDescriptor` value objects (`id: DocumentID`, `title: String`, `fileURL: URL?`, `isPinned: Bool`, `isDirty: Bool`, `caretLocation: Int`, `revision: BufferRevision`), keeping pinned tabs ordered before unpinned tabs and preventing unforced closure of pinned tabs (`BC-006`, `BC-008`).
  - `SessionRecoveryStore` persists `session-manifest.json` (`SessionRecoveryManifest`) and `<UUID>.recovery` text draft blobs in an isolated `SessionRecovery/` directory (`0700` directory permissions, `0600` file permissions, `FileProtectionType.complete` on iOS, `URLResourceValues.isExcludedFromBackup = true`, `<= 64 MiB` total quota), unlinking draft snapshots synchronously on tab close and purging unreferenced orphan `<UUID>.recovery` files at startup (`DATA-005`, `DATA-006`, `SEC-007`, `SEC-011`).
  - `DotfileFolderNavigator` performs shallow single-directory enumeration (`contentsOfDirectory`) returning `FolderEntryDescriptor` items including hidden dotfiles (`.gitignore`, `.env`, `.editorconfig`, excluding `.` and `..`), sorted directories-first then case-insensitively by name, bracketing access with `startAccessingSecurityScopedResource()` / `defer { stopAccessingSecurityScopedResource() }` (`DATA-007`, `SEC-002`).
  - `EditorPreferencesStore` serializes `EditorPreferences` (`appearanceMode`: `.light` / `.black` / `.auto`, `zoomPercent`: clamped to `50...300`) as schema-clamped `Codable` values inside an isolated `UserDefaults` suite (`DATA-008`, `TEST-003`).
- **`ddd-expert` (`02-domain/bounded-context-ownership.md` & `negative-ownership-and-refs.md`)**:
  - `WorkspaceAndTabSession` references documents exclusively by `DocumentID` and `BufferRevision` (`BC-006`) and translates raw `Foundation` filesystem/UserDefaults payloads via Anti-Corruption Layer (`ACL`) value objects (`BC-007`).
  - Binary read-only sessions (`isBinaryReadOnly == true`) are strictly barred from persistent tabs, pinning, and `SessionRecovery` snapshots (`BC-008`, `DATA-003`, `SEC-011`).
- **`cyber-security-expert` (`07-security-privacy/authn-authz-and-boundaries.md`, `secrets-and-supply-chain.md`, `stride-and-gdpr-privacy.md`)**:
  - `SessionRecoveryStore` enforces a `64 MiB` (`67_108_864` bytes) aggregate directory quota (`DomainError.sessionRecoveryQuotaExceeded`), rejects path-traversal or non-UUID snapshot filenames, enforces `0700`/`0600` POSIX permissions and `isExcludedFromBackup = true`, and refuses binary snapshots (`DomainError.binaryFileSaveForbidden`) (`SEC-007`, `SEC-011`, `SEC-012`).
  - `DotfileFolderNavigator` resolves symlinks via `resolvingSymlinksInPath()` and aborts with `DomainError.securityScopeViolation` if the target directory or any child symlink escapes the granted workspace root (`SEC-002`, `SEC-003`, `CWE-22`).

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `WorkspaceTabBarState` | `P1` | `positive` | Opens, activates, reorders, pins, and unpins text `TabDescriptor` items in `WorkspaceTabSession` (keeping pinned tabs ahead of unpinned tabs and preserving `caretLocation` and `BufferRevision`) (`[AR-004]`, `[BC-006]`, `[BC-008]`). |
| `WorkspaceTabBarState` | `N1` | `negative` | Attempting to close a pinned tab without unpinning or querying an unknown `DocumentID` fails closed with `DomainError.pinnedTabCloseForbidden` or `DomainError.tabNotFound` without mutating tab order (`[BC-008]`, `[BC-012]`). |
| `WorkspaceTabBarState` | `N2` | `security` | Attempting to pin or register a binary read-only `DocumentSnapshot` (`isBinaryReadOnly == true`) into persistent `WorkspaceTabSession` state is rejected with `DomainError.binaryFileSaveForbidden` (`[BC-008]`, `[DATA-003]`, `[SEC-011]`, `[SEC-012]`). |
| `SessionRecoveryStore` | `P2` | `positive` | Atomically saves and restores `SessionRecoveryManifest` (`session-manifest.json`) and dirty/unbacked `<UUID>.recovery` text snapshots with `0700`/`0600` permissions and `isExcludedFromBackup = true`, unlinks snapshots synchronously on tab close, and purges unreferenced orphan `.recovery` files on startup GC (`[DATA-005]`, `[DATA-006]`, `[SEC-007]`, `[SEC-011]`). |
| `SessionRecoveryStore` | `N3` | `negative` | Corrupted `session-manifest.json` payloads fail closed with `DomainError.corruptedRecoveryManifest` without partial state corruption (`[BC-007]`, `[SEC-012]`). |
| `SessionRecoveryStore` | `N4` | `security` | Attempting to persist a binary snapshot (`isBinaryReadOnly == true`), exceeding the `64 MiB` (`67_108_864` bytes) `SessionRecovery` quota, or traversing a symlinked recovery directory aborts fail-closed with `DomainError.binaryFileSaveForbidden`, `DomainError.sessionRecoveryQuotaExceeded`, or `DomainError.securityScopeViolation` (`[DATA-003]`, `[SEC-003]`, `[SEC-007]`, `[SEC-011]`, `[SEC-012]`). |
| `DotfileNavigatorAndPreferences` | `P3` | `positive` | Lists shallow directory entries including hidden dotfiles (`.env`, `.gitignore`) sorted directories-first with balanced `start/stopAccessingSecurityScopedResource()` calls, and persists schema-clamped `EditorPreferences` (`Light`/`Black`/`Auto`, zoom `50%..300%`) in an isolated `UserDefaults` suite (`[BC-007]`, `[DATA-007]`, `[DATA-008]`, `[SEC-002]`, `[TEST-003]`). |
| `DotfileNavigatorAndPreferences` | `N5` | `negative` | Out-of-range zoom values (`< 50` or `> 300`) and unknown appearance strings in `UserDefaults` are deterministically clamped to `50...300` and defaulted to `.auto` by `EditorPreferencesStore` (`[BC-007]`, `[DATA-008]`). |
| `DotfileNavigatorAndPreferences` | `N6` | `security` | Expanding a directory or child symlink escaping the granted workspace scope via `resolvingSymlinksInPath()` throws `DomainError.securityScopeViolation` while still executing `stopAccessingSecurityScopedResource()` in `defer` (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`, `[SEC-012]`). |
