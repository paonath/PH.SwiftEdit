---
area: "04-data-persistence"
file: "write-read-separation.md"
rules: ["DATA-005", "DATA-006", "DATA-007", "DATA-008"]
---

# 04-data-persistence/write-read-separation (DATA-005..DATA-008)

## Context
- session_recovery: `Application Support/PH.SwiftEdit/SessionRecovery/ (session-manifest.json + UUID Text Snapshots, Immediate Close Unlink + Startup GC)`
- external_sync: `NSFilePresenter Clean Auto-Reload vs Dirty Conflict Banner`

## Rules
- **DATA-005**: The `SwiftEditCore` session manager SHALL atomically autosave `session-manifest.json` (recording open text tabs, pinned tab flags, and caret offsets) and dirty or unbacked `Untitled` tab text snapshots inside `Application Support/PH.SwiftEdit/SessionRecovery/`.
- **DATA-006**: The `SwiftEditCore` session manager SHALL unlink a tab's `SessionRecovery` snapshot file immediately upon tab closure and execute a deterministic startup garbage-collection pass deleting any unreferenced snapshot files in `SessionRecovery/`.
- **DATA-007**: WHILE accessing security-scoped file or dotfile-inclusive folder URLs and monitoring external disk edits via `NSFilePresenter`, the `SwiftEditCore` I/O coordinator SHALL pair `startAccessingSecurityScopedResource()` with a deterministic `defer { stopAccessingSecurityScopedResource() }` call.
- **DATA-008**: The `EditorPreferences` adapter SHALL serialize appearance mode (`Light`, `Black`, `Auto`), zoom percentage (`50%..300%`), and non-sensitive UI settings via schema-clamped `Codable` value types inside an isolated `UserDefaults` suite without storing file contents or binary payloads.
