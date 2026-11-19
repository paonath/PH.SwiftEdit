# Threat Model: SwiftEditCore 3-Way LineEnding (CR), Cursor Metrics, 10-Entry MRU, Shallow Batch Open, Literal Search and Confined Sidebar File Operations

## 1. Asset Boundaries & Trust Zones
- **User Documents and Workspace Folder (Untrusted Content, Granted Scope)**: Files and folders chosen by the user. Names, symlinks, file sizes, and bytes are untrusted; only paths that stay inside the granted scope after `resolvingSymlinksInPath()` are trusted (`[SEC-002]`, `[SEC-003]`).
- **Recent Files Persistence (`UserDefaults` suite)**: Holds security-scoped bookmark blobs. These grant renewed file access, so they are sensitive and must not outlive Clear or include binary files (`[SEC-011]`, `[DATA-008]`).
- **Persisted Bytes and Line Endings (`DocumentCodec` wire format)**: A misclassified line ending silently rewrites a user's file on save (`[DATA-004]`).
- **System Trash Seam (`ItemTrashing`)**: The only deletion path; permanent removal is forbidden.

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A stale or swapped bookmark blob resolves to a different file than the recorded path (`CWE-345`). | `RecentFilesStore` compares the resolved standardized path with the stored path and rejects mismatches; unresolvable bookmarks fail closed with a balanced `stopAccessing` (`[SEC-002]`, `[SEC-012]`). |
| Tampering | Rename or paste with `../`, `/`, `:`, control or BiDi characters, or through a symlink to write outside the scope (`CWE-22`, `CWE-59`); overwriting an existing file on paste; `\r\n` misread as `\r` rewriting file content. | `SidebarItemNameValidator` accepts one safe segment; every mutation verifies `resolvingSymlinksInPath()` confinement and refuses the scope root; copy never overwrites or follows symlinks; `cut` onto an existing name is rejected; `LineEnding.detect` tests `\r\n` before `\r` (`[SEC-003]`, `[DATA-004]`, `[BC-012]`). |
| Repudiation | Permanent deletion leaves no recovery path; silent loss of an unsaved edit when its file is trashed (`CWE-73`). | `trashItem` always uses the Trash seam; a dirty tab of a trashed file is detached and kept open so edits can be saved elsewhere (`[BC-008]`, `[DATA-006]`). |
| Information Disclosure | Batch open of a symlink to a secret outside the workspace (for example a home-directory credentials file); bookmark blobs left in `UserDefaults` after Clear; binary files retained in recents (`CWE-200`). | Escaping symlink aborts the whole batch before any read; Clear removes the list key entirely; binary files are rejected by the `8 KiB` NUL probe before recording (`[SEC-003]`, `[SEC-011]`, `[DATA-003]`). |
| Denial of Service | Folder with thousands of large files; copying a huge tree or a folder into itself; megabyte search queries or a match flood; metrics over a very large buffer (`CWE-400`, `CWE-674`). | `50`-file confirmation, `256 MiB` cumulative and `64 MiB` per-file ceilings, `1000`-item and `256 MiB` copy caps, self-descendant paste rejection, `1024`-unit query cap, `100000` match cap, binary and degraded snapshots skipped, `64 MiB` document ceiling bounds the metrics pass (`[BC-011]`, `[DATA-002]`). |
| Elevation of Privilege | Renaming, pasting over, or trashing the granted scope root or its ancestor to escape confinement; reusing a stale scoped bookmark outside its grant. | Scope root and outside-scope targets throw `DomainError.securityScopeViolation` before any mutation; every bookmark access is bracketed by `startAccessing`/`defer stopAccessing` (`[SEC-002]`, `[SEC-003]`, `[DATA-007]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N4` (Stale or Unresolvable Bookmark — `Trait: security`)**: A recent entry whose bookmark cannot be resolved is pruned or rejected and the security-scoped access count stays balanced (`start == stop`).
- **Abuse Scenario `N5` (Unreadable Persisted Recents — `Trait: security`)**: Corrupted or oversized `UserDefaults` data yields an empty list and removes the stored blob; no `NSKeyedUnarchiver` is used.
- **Abuse Scenario `N7` (Escaping Symlink or Oversized Batch — `Trait: security`)**: A folder containing a symlink to a path outside the scope, or eligible files above the cumulative ceiling, aborts with `securityScopeViolation` or `batchLimitExceeded` before any file is opened.
- **Abuse Scenario `N9` (Search Flood — `Trait: security`)**: A query above `1024` UTF-16 units, more than `100000` matches, or a binary or degraded snapshot returns a degraded outcome instead of a result.
- **Abuse Scenario `N11` (Traversal and Root Mutation — `Trait: security`)**: A parent directory that resolves outside the scope, or a rename of the scope root, throws `securityScopeViolation` and changes nothing.
- **Abuse Scenario `N13` (Hostile Copy Source — `Trait: security`)**: A copy source containing a symlink, exceeding the item or byte cap, or targeting a destination outside the scope is refused without any partial copy.
- **Abuse Scenario `N14` (Trash Misuse — `Trait: security`)**: Trashing the scope root or an escaping path throws `securityScopeViolation` and the Trash seam is never invoked.

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
