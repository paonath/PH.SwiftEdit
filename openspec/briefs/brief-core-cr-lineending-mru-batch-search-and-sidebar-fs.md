---
id: "brief-core-cr-lineending-mru-batch-search-and-sidebar-fs"
change_id: "006-core-cr-lineending-mru-batch-search-and-sidebar-fs"
capability: "core-cr-lineending-mru-batch-search-and-sidebar-fs"
branch: "feature/FirstStub"
modifies_specs: "document-core-and-spm-scaffold (REQ-002)"
status: "approved-via-qa"
date: "2026-11-18"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: `SwiftEditCore` 3-Way `LineEnding` (`CR`), Cursor Metrics, 10-Entry MRU, Shallow Batch Open, Literal Search and Confined Sidebar File Operations (`TASK-02`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-02` in `reasoning/002_minimal-ui-menus-and-editor-features/README.ai.md` (prerequisite `TASK-01` / `005` archived at commit `128f10c`).
- **Active Git Branch**: `feature/FirstStub` (baseline `fff329b`).
- **Consolidated Specs Modified (`modifies_specs`)**: `document-core-and-spm-scaffold` `REQ-002` (adds Classic Mac `CR`; existing scenarios `P2`/`N2` are preserved additively). All other requirements are `ADDED` in the new capability `core-cr-lineending-mru-batch-search-and-sidebar-fs`.
- **Governing Constitutional Rules (`v1.3.0`)**: `[AR-004]`, `[AR-007]`, `[BC-004]`, `[BC-006]`, `[BC-007]`, `[BC-008]`, `[BC-011]`, `[BC-012]`, `[DATA-002]`, `[DATA-003]`, `[DATA-004]`, `[DATA-006]`, `[DATA-007]`, `[DATA-008]`, `[SEC-002]`, `[SEC-003]`, `[SEC-011]`, `[SEC-012]`, `[TEST-001]`..`[TEST-005]`, `[SDD-001]`, `[SDD-002]`.
- **Human Confirmation**: Phase 2 single-question confirmation answered `(Recommended)` (scope as listed below, `SwiftEditCore` only, zero `AppKit`).

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert`**:
  - `LineEnding` gains `case cr = "\r"`; detection evaluates `\r\n` first, then bare `\r`, then defaults to `.lf`. Scanning MUST use `unicodeScalars`/`utf16` because Swift treats `"\r\n"` as a single `Character` and `String.contains("\r")` can disagree with a scalar scan. `DocumentSession.lineContentBounds` already treats `0x0D` as a terminator, so `Cmd+D` stays correct.
  - `CursorMetricsCalculator` is a pure single-pass function over UTF-16 units up to the caret; `characterCount` is the Unicode scalar count.
  - `RecentFilesStore` persists `[RecentFileEntry]` as `Codable` JSON in an isolated `UserDefaults` suite, injects a `now` closure, a `SecurityScopedBookmarkCoding` seam, and reuses `SecurityScopedResourceAccessing` and `FileSystemProviding`.
  - `ShallowFolderBatchLoader` reuses `DotfileFolderNavigator.listEntries`, filters regular non-binary files, and returns an immutable `BatchOpenPlan`.
  - `DocumentSearchEngine` is literal-only (no regex, so no `CWE-1333`); `replaceAll` returns a `TextEdit` batch consumed by `DocumentSession.applyTextEdits`.
  - `FileSystemProviding` is extended (ratified in reasoning) with `createDirectory(named:in:)`, `createFile(named:contents:in:)`, `renameItem(at:toName:)`, `pasteItem(from:toDirectory:mode:)`, and `trashItem(at:)`; both `LocalFileSystemAdapter` and `InMemoryFileSystemFake` implement them. Trash goes through an injectable `ItemTrashing` seam.
  - `WorkspaceTabSession.applyRename(from:to:)` and `applyTrash(of:)` keep open tabs consistent with sidebar changes.
- **`cyber-security-expert`**:
  - Names are validated as a single path segment (reject empty, `.`, `..`, `/`, `:`, NUL and ASCII control bytes, BiDi overrides, more than `255` UTF-8 bytes) before any path is built (`CWE-22`).
  - Every mutating operation verifies `resolvingSymlinksInPath()` confinement and refuses the scope root itself (`CWE-59`).
  - Copy never dereferences symlinks, never overwrites, rejects self-descendant targets, and caps at `1000` items / `256 MiB` (`CWE-400`).
  - MRU keeps no binary files, balances `startAccessing`/`stopAccessing`, erases bookmark blobs on Clear, and fails closed on unreadable persisted JSON (`SEC-011`, `SEC-012`).
  - Batch open enforces `50`-file confirmation, `256 MiB` cumulative and `64 MiB` per-file ceilings, and aborts on any escaping symlink.
  - Trashing never permanently deletes; a dirty open tab is detached (not lost) when its file is trashed.

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `LineEndingThreeWayCodec` | `P1` | `positive` | `LF`, `CRLF`, and `CR` files round-trip byte-exact through `DocumentCodec` (`[DATA-004]`). |
| `LineEndingThreeWayCodec` | `N1` | `negative` | `\r\n` is never misread as `CR`; mixed endings resolve deterministically to `CRLF` (`[DATA-004]`). |
| `CursorMetricsCalculator` | `P2` | `positive` | 1-based line, column, and scalar count across mixed breaks. |
| `CursorMetricsCalculator` | `N2` | `negative` | Out-of-range caret throws `DomainError.invalidTextRange`. |
| `RecentFilesStore` | `P3`, `N3` | `positive`, `negative` | Dedupe, reorder, cap `10`, eviction; binary and deleted files excluded. |
| `RecentFilesStore` | `P4`, `N4` | `positive`, `security` | Balanced `start`/`stop`; stale bookmark fails closed with balanced release. |
| `RecentFilesStore` | `P5`, `N5` | `positive`, `security` | Clear erases bookmark blobs; unreadable persisted list fails closed. |
| `ShallowFolderBatchLoader` | `P6`, `N6` | `positive`, `negative` | Shallow regular non-binary selection with `>50` confirmation; empty result is not an error. |
| `ShallowFolderBatchLoader` | `P7`, `N7` | `positive`, `security` | Exact-ceiling batch accepted; escaping symlink or `>256 MiB` aborts. |
| `DocumentSearchEngine` | `P8`, `N8`, `N9` | `positive`, `negative`, `security` | Find, `replaceAll`, `goToLine`; empty query and bad line are inert; oversize query, match flood, binary or degraded snapshot degrade. |
| `SidebarCreateAndRenameOperations` | `P9`, `N10`, `N11` | `positive`, `negative`, `security` | Create and rename; invalid names and existing targets rejected; escape and root mutation blocked. |
| `SidebarPasteAndTrashOperations` | `P10`, `N12`, `N13` | `positive`, `negative`, `security` | Copy suffixes and cut move; self-descendant and collision rejected; symlink, caps, and out-of-scope blocked. |
| `SidebarPasteAndTrashOperations` | `P11`, `N14` | `positive`, `security` | Trash through seam; root and escaping targets blocked without calling the seam. |
| `TabSessionFileSync` | `P12`, `N15` | `positive`, `negative` | Rename updates tabs in place; dirty trashed tabs detach; prefix-sibling paths untouched. |

## 4. Declarative GIVEN-WHEN-THEN Behavior Contracts

```gherkin
Feature: SwiftEditCore Line Endings, Recent Files, Batch Open, Search and Confined Sidebar File Operations

  @REQ-CORE-CR-LINEENDING-MRU-BATCH-SEARCH-AND-SIDEBAR-FS-001
  Scenario: Classic Mac CR files round-trip losslessly and recent files stay deduplicated
    Given a UTF-8 file "notes.md" using CR line breaks and a recent list already holding 10 files including "notes.md"
    When the file is reopened, edited, and saved
    Then the saved bytes keep CR line breaks and the recent list still holds 10 entries with "notes.md" first

  @REQ-CORE-CR-LINEENDING-MRU-BATCH-SEARCH-AND-SIDEBAR-FS-002 @security
  Scenario: Batch open skips unsafe entries and enforces limits
    Given a granted folder with 52 text files, 3 binary files, 2 subfolders, and a symlink that escapes the granted scope
    When the user opens all files in the folder
    Then the operation aborts with a scope violation before any file is opened and no tab is created

  @REQ-CORE-CR-LINEENDING-MRU-BATCH-SEARCH-AND-SIDEBAR-FS-003
  Scenario: Find and replace operate on literal text without mutating the snapshot
    Given a text snapshot containing the word "alpha" twice with different letter case
    When the user finds and replaces all occurrences
    Then both ranges are reported and one edit batch is produced while the snapshot stays unchanged

  @REQ-CORE-CR-LINEENDING-MRU-BATCH-SEARCH-AND-SIDEBAR-FS-004 @security
  Scenario: Sidebar operations reject traversal names and never overwrite
    Given an authorized workspace folder containing "draft.md"
    When the user renames "draft.md" to "../outside.md" or copies it twice into the same folder
    Then the rename is rejected without changes and the copies are named "draft copy.md" and "draft copy 2.md"

  @REQ-CORE-CR-LINEENDING-MRU-BATCH-SEARCH-AND-SIDEBAR-FS-005 @security
  Scenario: Delete uses the system Trash and detaches dirty tabs
    Given an open dirty tab backed by "draft.md" inside the workspace
    When the user deletes "draft.md" from the sidebar
    Then the file is handed to the Trash seam and the tab stays open without a backing file
```
