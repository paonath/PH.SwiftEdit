---
area: "04-data-persistence"
file: "write-read-separation.md"
rules: ["DATA-005", "DATA-006", "DATA-007", "DATA-008"]
---

# 04-data-persistence/write-read-separation (DATA-005..DATA-008)

## Context
- write_model: `Explicit Cmd+S Atomic Safe-Save (autosavesInPlace = false)`
- external_sync: `NSFilePresenter Clean Auto-Reload vs Dirty Conflict Banner`

## Rules
- **DATA-005**: The document persistence adapter SHALL disable in-place background autosave (`autosavesInPlace = false`) by default, committing target-file bytes exclusively on explicit Save commands via `NSFileCoordinator` `.atomic` replacement while confining optional crash-recovery drafts inside the private App Sandbox container.
- **DATA-006**: WHEN `NSFilePresenter` detects an external on-disk modification, `SwiftEditUI` SHALL reload clean buffers (`isDirty == false`) automatically while presenting a non-destructive conflict banner on dirty buffers (`isDirty == true`).
- **DATA-007**: WHILE accessing a security-scoped URL outside automatic `NSDocument` lifecycles, the bookmark adapter SHALL bracket access with `startAccessingSecurityScopedResource()` and `defer { stopAccessingSecurityScopedResource() }`.
- **DATA-008**: The `EditorPreferences` adapter SHALL serialize non-sensitive user settings via schema-clamped `Codable` value types inside an isolated `UserDefaults` suite without invoking `NSKeyedUnarchiver` or `UserDefaults.standard` in `SwiftEditCore`.
