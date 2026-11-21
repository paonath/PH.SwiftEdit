# Threat Model: Implement WorkspaceAndTabSession (Notepad++ Pin, SessionRecovery GC, Dotfiles & EditorPreferences)

## 1. Asset Boundaries & Trust Zones
- **Untrusted Workspace & Recovery Filesystem Zone**: User-selected workspace directories (containing hidden dotfiles such as `.env`, `.ssh/config`, `.gitignore`, and potentially malicious symlinks) and on-disk `SessionRecovery/` files (`session-manifest.json` and `<UUID>.recovery` blobs) which may be corrupted, oversized (`> 64 MiB`), or replaced by symlinks.
- **Anti-Corruption & Session Management Zone (`WorkspaceTabSession`, `SessionRecoveryStore`, `DotfileFolderNavigator`, `EditorPreferencesStore`)**: Pure `SwiftEditCore` domain and ACL components (`[BC-007]`, `[BC-008]`) enforcing binary non-retention, `0700`/`0600` permissions, backup exclusion, `64 MiB` recovery quota, balanced security-scoped resource access, and `resolvingSymlinksInPath()` confinement.
- **Isolated Preferences Boundary (`UserDefaults`)**: Stores only schema-clamped UI settings (`AppearanceMode`, `zoomPercent` `50...300`) with zero document content or binary data (`[DATA-008]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Malicious symlink inside a workspace folder or `SessionRecovery/` pointing to sensitive files outside the granted sandbox scope (`CWE-22`, `[SEC-003]`). | `DotfileFolderNavigator` and `SessionRecoveryStore` canonicalize paths via `resolvingSymlinksInPath()` and abort with `DomainError.securityScopeViolation` whenever a target or child symlink resolves outside the granted root (`[SEC-003]`, `[SEC-012]`). |
| Tampering | Corrupted or tampered `session-manifest.json` or `UserDefaults` values injecting invalid zoom scales or non-UUID recovery paths (`[BC-007]`, `[DATA-008]`, `[SEC-012]`). | Decode `SessionRecoveryManifest` strictly via `JSONDecoder` (throwing `DomainError.corruptedRecoveryManifest` on failure), derive recovery filenames strictly from `DocumentID.rawValue.uuidString`, and clamp `zoomPercent` to `50...300` (`[BC-007]`, `[DATA-008]`, `[SEC-012]`). |
| Repudiation | Orphaned `<UUID>.recovery` draft blobs lingering after tab closure or crash, violating GDPR Art. 5(1)(c) storage limitation (`[DATA-006]`, `[SEC-011]`). | `SessionRecoveryStore.removeRecoverySnapshot(for:)` deletes the draft file synchronously upon tab closure, and `purgeOrphanedSnapshots(keeping:)` deletes any `<UUID>.recovery` file not referenced by the active manifest at startup (`[DATA-006]`, `[SEC-011]`). |
| Information Disclosure | Sensitive unbacked drafts or hidden dotfiles leaked via world-readable recovery files, cloud backups, or binary buffer persistence (`CWE-312`, `[DATA-003]`, `[SEC-007]`, `[SEC-011]`). | Create `SessionRecovery/` with POSIX `0700`, write recovery files with `0600` and `isExcludedFromBackup = true` (plus `FileProtectionType.complete` on iOS), and reject `isBinaryReadOnly` snapshots from tabs, pinning, and `SessionRecovery` (`[BC-008]`, `[SEC-007]`, `[SEC-011]`). |
| Denial of Service | Unbounded `SessionRecovery/` growth or leaked security-scoped kernel handles exhausting disk or sandbox descriptors (`CWE-400`, `[DATA-007]`, `[SEC-002]`, `[SEC-007]`). | Enforce a hard `64 MiB` (`67_108_864` bytes) aggregate quota across `SessionRecovery/` (`DomainError.sessionRecoveryQuotaExceeded`) and pair every `startAccessing(url:)` with a deterministic `defer { stopAccessing(url:) }` release (`[DATA-007]`, `[SEC-002]`, `[SEC-007]`). |
| Elevation of Privilege | Subprocess execution or ORM/SQLite dynamic loading inside workspace/session management (`CWE-78`, `[DATA-001]`, `[SEC-007]`). | `WorkspaceAndTabSession` uses pure `Foundation` file/plist APIs with zero subprocess execution and zero database/ORM dependencies (`[DATA-001]`, `[SEC-007]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N2` (Binary Buffer Tab Persistence & Pinning Rejection — `Trait: security`)**: Calling `WorkspaceTabSession.openOrActivate(snapshot:title:fileURL:)` or `setPinned(_:for:)` with a binary read-only snapshot (`isBinaryReadOnly == true`) fails closed with `DomainError.binaryFileSaveForbidden` and never records the binary buffer in persistent or pinnable tabs (`[BC-008]`, `[DATA-003]`, `[SEC-011]`, `[SEC-012]`).
- **Abuse Scenario `N4` (`SessionRecovery` Binary Rejection, `> 64 MiB` Quota Exhaustion & Symlink Escape — `Trait: security`)**: Attempting to save a binary snapshot to `SessionRecoveryStore`, exceeding the `64 MiB` (`67_108_864` bytes) recovery directory quota, or writing through a symlinked `SessionRecovery` path fails closed with `DomainError.binaryFileSaveForbidden`, `DomainError.sessionRecoveryQuotaExceeded`, or `DomainError.securityScopeViolation` (`[DATA-003]`, `[SEC-003]`, `[SEC-007]`, `[SEC-011]`, `[SEC-012]`).
- **Abuse Scenario `N6` (Folder Navigator Symlink Escape & Guaranteed Security-Scope Release — `Trait: security`)**: Expanding a workspace directory containing a symlink that resolves outside the granted workspace scope throws `DomainError.securityScopeViolation` while guaranteeing that `stopAccessing(url:)` is still invoked via `defer` (`[DATA-007]`, `[SEC-002]`, `[SEC-003]`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
