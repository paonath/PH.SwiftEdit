# Design: SwiftEditCore 3-Way LineEnding (CR), Cursor Metrics, 10-Entry MRU, Shallow Batch Open, Literal Search and Confined Sidebar File Operations

## Context
Constitution `v1.3.0` (archived change `005`) mandates `LF`/`CRLF`/`CR` preservation (`DATA-004`), balanced security-scoped access (`DATA-007`, `SEC-002`), symlink confinement (`SEC-003`), and fail-closed bookmark handling (`SEC-012`). `SwiftEditCore` today knows only `LF`/`CRLF`, has no recents, batch open, literal search, cursor metrics, or file mutation port, and `WorkspaceTabSession` cannot react to rename or trash. `TASK-03` (`SwiftEditUI`) needs all of these as tested pure types before it can bind menus and the sidebar.

## Goals / Non-Goals
- Goals:
  - Implement the eleven requirements in `specs/core-cr-lineending-mru-batch-search-and-sidebar-fs/spec.md` and the modified `REQ-002` in `specs/document-core-and-spm-scaffold/spec.md` inside `SwiftEditCore` with `Foundation` only (`[AR-002]`, `[AR-004]`, `[AR-007]`).
  - Keep every new value type `Sendable` and `Equatable`, and put every disk, clock, bookmark, and Trash effect behind an injectable seam (`[TEST-003]`, `[TEST-004]`).
- Non-Goals:
  - Regex search, case folding beyond Foundation's `caseInsensitive`, or search-in-files (`[BC-005]`).
  - Any `AppKit`, `NSPasteboard`, `NSWorkspace`, menu, gutter, or SwiftUI code (`TASK-03`).
  - Conflict-resolution UI for `cut` onto an existing name; it is rejected (`[BC-010]`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: All code lives in `Sources/SwiftEditCore/` (`DocumentCore`, `WorkspaceAndTabSession`, `SearchDiffAndBracketEngine`) targeting `.macOS(.v26)` and `.iOS(.v26)`; tests live in `Tests/SwiftEditTests/` (`[AR-001]`).
- **AR-002**: Imports are limited to `Foundation` (and existing `Markdown` where already used); `ArchitectureFitnessTests` keeps enforcing this (`[AR-002]`, `[TEST-006]`).
- **AR-007**: Disk, clock, bookmark, Trash, and security-scope effects use narrow `Sendable` protocols (`FileSystemProviding`, `SecurityScopedBookmarkCoding`, `SecurityScopedResourceAccessing`, `ItemTrashing`) (`[AR-007]`).
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` (`v1.3.0`) with `01-architecture/dependency-and-layering.md`, `02-domain/negative-ownership-and-refs.md`, `02-domain/ubiquitous-language-and-policy.md`, `04-data-persistence/storage-and-migrations.md`, `04-data-persistence/write-read-separation.md`, `06-testing-fitness/tdd-and-unit-testing.md`, `07-security-privacy/authn-authz-and-boundaries.md`, and `07-security-privacy/stride-and-gdpr-privacy.md` (`[SDD-009]`).

## Bounded Context Classification & Ubiquitous Language Glossary (`BC-002`, `BC-009`)

| Component / Type | Context (Tier) | Normative Definition |
| :--- | :--- | :--- |
| `LineEnding.cr` | `DocumentCore` (`Core`) | Classic Mac `\r` line break; `detect` tests `\r\n` first, then `\r`, else `.lf`; scanning uses `unicodeScalars` (`[DATA-004]`). |
| `CursorMetrics` / `CursorMetricsCalculator` | `DocumentCore` (`Core`) | Value `(line: Int, column: Int, characterCount: Int)`; single pass over UTF-16 units up to the caret (`[BC-004]`). |
| `FileSystemProviding` (extended) | `DocumentCore` (`Core`) | Port adding `createDirectory(named:in:withinScope:)`, `createFile(named:contents:in:withinScope:)`, `renameItem(at:toName:withinScope:)`, `pasteItem(from:toDirectory:mode:withinScope:)`, `trashItem(at:withinScope:)` (`[SEC-003]`). |
| `SidebarItemNameValidator` | `DocumentCore` (`Core`) | Pure `enum` accepting one safe path segment of at most `255` UTF-8 bytes (`[SEC-012]`). |
| `PasteMode` | `DocumentCore` (`Core`) | `enum { cut, copy }` selecting move or suffix-copy semantics. |
| `ItemTrashing` | `DocumentCore` (`Core`) | Seam over `FileManager.trashItem`; fake records URLs (`[AR-007]`). |
| `RecentFileEntry` | `WorkspaceAndTabSession` (`Supporting`) | `Codable` value `(standardizedPath, displayName, bookmarkData, lastOpenedAt)` (`[BC-007]`). |
| `SecurityScopedBookmarkCoding` | `WorkspaceAndTabSession` (`Supporting`) | Seam `makeBookmark(for:)` / `resolveBookmark(_:)`; system version uses security-scoped bookmark options (`[SEC-002]`). |
| `RecentFilesStore` | `WorkspaceAndTabSession` (`Supporting`) | Isolated `UserDefaults` list capped at `10`, deduplicated by standardized path (`[DATA-008]`, `[SEC-011]`). |
| `BatchOpenPlan` / `ShallowFolderBatchLoader` | `WorkspaceAndTabSession` (`Supporting`) | Immutable plan `(files, skippedBinaryCount, skippedFolderCount, totalBytes, requiresConfirmation)` built from first-level entries (`[BC-011]`). |
| `WorkspaceTabSession.applyRename` / `applyTrash` | `WorkspaceAndTabSession` (`Supporting`) | Mutating reconcilers keyed by path prefix with a `/` boundary (`[BC-006]`, `[BC-008]`). |
| `SearchOptions` / `DocumentSearchEngine` | `SearchDiffAndBracketEngine` (`Supporting`) | Literal search over `DocumentSnapshot` returning `EngineEvaluationOutcome` values (`[BC-011]`). |

## Decisions
- **Decision 1 — Three-way `LineEnding` by scalar scan (`KISS-First`)**: `detect` walks `unicodeScalars` once; seeing `\r` followed by `\n` returns `.crlf` immediately, a lone `\r` is remembered as `.cr`, and a `\n` is remembered as `.lf`, with precedence `crlf > cr > lf` for mixed text to keep detection deterministic. `apply(toCanonicalLF:)` maps `\n` to `rawValue`. `DocumentSession.activeSeparator` and `lineContentBounds` already handle `0x0D`, so `Cmd+D` needs no change beyond a regression test.
- **Decision 2 — Extend `FileSystemProviding` (ratified in reasoning) with parent-plus-name operations**: The ratified design extends the existing port; the signatures take a parent URL and a name rather than a full target URL so a path separator can never be smuggled in. `InMemoryFileSystemFake` gains a directory set and a virtual trash list; `LocalFileSystemAdapter` uses `FileManager` and gains `init(trasher: any ItemTrashing = FileManagerTrasher(), maxCopyItems: Int = 1000, maxCopyBytes: UInt64 = 256 MiB)` so caps are testable.
- **Decision 3 — Confinement reuses `verifyScopeConfinement`**: Every mutation resolves the parent (and the source for rename, paste, and trash) with `resolvingSymlinksInPath()` and refuses a target equal to the scope root, throwing `DomainError.securityScopeViolation` before touching disk.
- **Decision 4 — Paste semantics**: `copy` picks the first free `name copy.ext`, `name copy 2.ext`, `name copy 3.ext`; `cut` throws `destinationAlreadyExists` on collision; a destination equal to or inside the source throws `invalidPasteTarget`; directory copies pre-scan the tree, reject any symlink with `securityScopeViolation`, and enforce the item and byte caps with `batchLimitExceeded` before copying so nothing is left half-copied.
- **Decision 5 — `RecentFilesStore` injects seams, not globals**: `init(suiteName:fileSystem:bookmarkCoder:securityScope:now:)`. `record(url:withinScope:)` probes the file through `FileSystemProviding` (size, `8 KiB` NUL probe via `DocumentCodec.isBinaryPrefix`) so binary and missing files never enter the list. `resolve(entry:)` brackets `startAccessing`/`defer stopAccessing`, compares the resolved standardized path with the stored one, and prunes the entry on any failure. `entries()` drops entries whose file no longer exists. `clear()` removes the defaults key. Decoding rejects data above `1 MiB` and malformed JSON by removing the key and returning `[]`.
- **Decision 6 — `ShallowFolderBatchLoader` reuses `DotfileFolderNavigator`**: Listing, confinement, and balanced scope access come from the navigator (an escaping symlink aborts the whole plan, which is the fail-closed reading of the ratified scenario). The loader keeps only regular files (`isRegularFileKey`), skips files above `64 MiB`, probes `8 KiB` for NUL, sums sizes against an injectable ceiling (`init(maxBatchBytes: UInt64 = 256 MiB)`), and sets `requiresConfirmation` when eligible files exceed `50`.
- **Decision 7 — Literal-only `DocumentSearchEngine`**: No regex avoids `CWE-1333`. `find` returns `EngineEvaluationOutcome<[TextRange]>`; `replaceAll` returns `EngineEvaluationOutcome<[TextEdit]>` for `DocumentSession.applyTextEdits`; `goToLine` returns `TextRange?` (line content without its terminator). Caps: query `1024` UTF-16 units, matches `100000`; binary and degraded snapshots return their existing reasons; one new reason `matchLimitExceeded(maxMatches:)` is added to `DegradedEvaluationReason`.
- **Decision 8 — Tab reconciliation by path prefix with a boundary**: A tab matches when `fileURL.path == old` or starts with `old + "/"`, so `draft.md.bak` is never matched by `draft.md`. Rename rewrites `fileURL` and, for exact matches, the title. Trash closes clean matching tabs (`forcePinned: true`) and detaches dirty ones (`fileURL = nil`) so unsaved text is never lost.

## Risks / Trade-offs
- **`"\r\n"` is one Swift `Character`** -> All line-ending scans use `unicodeScalars` or `utf16`, never `Character` equality or `String.contains`; `N1` pins this.
- **Real-disk tests for symlinks and caps** -> They run in unique directories under `.tmp/test-results/` with `defer` cleanup and an injected `ItemTrashing` fake so the user's Trash is never touched (`[TEST-003]`, `[TEST-004]`).
- **Adding enum cases (`DomainError`, `DegradedEvaluationReason`)** -> Both are internal-module enums; a repository-wide `switch` audit in the `[GREEN]` task confirms no exhaustive switch breaks (`SwiftEditUI` compiles in the same package).
- **`cut` collision is rejected rather than replaced** -> Avoids silent data loss and an invented policy (`[BC-010]`); a future UI prompt can add replace under a new change.
- **Sandbox bookmarks in unit tests** -> The `SecurityScopedBookmarkCoding` fake keeps tests deterministic; the system coder is exercised by one integration-style test that skips creation errors only when running without file access.

## Migration Plan
1. Execute the nine units in `tasks.md` in order, each as `[RED] -> [GREEN] -> [REFACTOR] -> [DOC]` (plus a security triad where the unit has `Trait: security` paths).
2. Run `swift test --parallel -Xswiftc -warnings-as-errors --enable-code-coverage`, confirm `>= 85%` `SwiftEditCore` coverage and green `ArchitectureFitnessTests` and `ConstitutionFitnessTests` (`[TEST-006]`, `[TEST-008]`).
3. Run `/myspec-verify`, then `/myspec-archive` (the `[SYNC]` task merges the modified `REQ-002` into the living `document-core-and-spm-scaffold` spec).

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-18
- Verdict: approved
- Status: approved
- Open items: none
