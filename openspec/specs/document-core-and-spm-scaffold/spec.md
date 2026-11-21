# Capability: document-core-and-spm-scaffold

## Purpose
Fixes `DocumentSession.activeSeparator` on single-line Classic Mac `CR` documents so `Cmd+D` never leaks raw `\r` bytes into the normalized in-memory LF buffer while preserving exact `LineEnding.cr` serialization on save (`BUG-016`), and removes per-keystroke full-buffer `Array(text.utf16)` copies (`PERF-007`).

## Requirements

### Requirement: REQ-001 Cross-Platform Swift 6 Package Topology and Import Isolation
The Swift package manifest SHALL declare `.macOS(.v26)` and `.iOS(.v26)` platforms under Swift 6 strict concurrency with targets `SwiftEditCore`, `SwiftEditUI`, and `SwiftEditTests` while restricting `SwiftEditCore` imports to the standard library, `Foundation`, and `Markdown` (`swiftlang/swift-markdown`) [AR-001][AR-002][AR-003][AR-005][TEST-006].

#### Scenario: P1 Valid SwiftPM Manifest and Clean SwiftEditCore Imports Pass Fitness Check
- **Path**: P1
- **Trait**: positive
- **GIVEN** the repository `Package.swift` and source files under `Sources/SwiftEditCore/` and `Sources/SwiftEditUI/`
- **WHEN** `swift test --parallel` executes `ArchitectureFitnessTests`
- **THEN** `swift package dump-package` confirms `.macOS(.v26)` and `.iOS(.v26)` platforms, only `swift-markdown` as external dependency, and zero `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, `Combine`, `Network`, or `SwiftEditUI` imports in `Sources/SwiftEditCore/`

#### Scenario: N1 Forbidden UI or Network Import in SwiftEditCore Is Rejected
- **Path**: N1
- **Trait**: negative
- **GIVEN** a source snippet in `SwiftEditCore` containing `import AppKit`, `import WebKit`, or `import Network`, or a manifest listing an unapproved external package
- **WHEN** `ArchitectureImportScanner` evaluates the source text and dependency list
- **THEN** the scanner returns a non-empty list of architecture fitness violations identifying the forbidden import or package

### Requirement: REQ-002 Lossless Encoding BOM and Line-Ending Round-Trip with Size Gates
WHEN loading or saving a text document through `FileSystemProviding`, the document codec and loader SHALL preserve `UTF-8`, `UTF-8 BOM`, `UTF-16LE BOM`, and `UTF-16BE BOM` encodings alongside `LF`, `CRLF`, and Classic Mac `CR` line endings, evaluating `\r\n` before bare `\r`, while activating degraded plain-text mode above `10 MiB` and throwing `DomainError.fileTooLarge` above `64 MiB` [BC-007][BC-011][BC-012][DATA-002][DATA-004][TEST-005].

#### Scenario: P2 Lossless Encoding and Line-Ending Round-Trip Plus Degraded Mode Activation
- **Path**: P2
- **Trait**: positive
- **GIVEN** input byte buffers encoded as `UTF-8` (with and without BOM), `UTF-16LE` with BOM, and `UTF-16BE` with BOM using `LF` or `CRLF` line endings, plus a `12 MiB` UTF-8 text file in `InMemoryFileSystemFake`
- **WHEN** `DocumentLoader` loads each file, applies a text edit, saves atomically, and loads the `12 MiB` file
- **THEN** the saved bytes preserve the original `TextEncoding` (including BOM) and `LineEnding` sequence (`LF` vs `CRLF`), and the `12 MiB` session sets `isDegradedPlainText == true`

#### Scenario: N2 Oversized File Above 64 MiB or Invalid Byte Sequence Rejection
- **Path**: N2
- **Trait**: negative
- **GIVEN** an inbound file whose size is `64 MiB + 1` byte (`67_108_865` bytes) or a byte buffer `[0xFF, 0xFE, 0xC3, 0x28]` with invalid UTF-8 bytes and no valid UTF-16 code unit sequence
- **WHEN** `DocumentLoader` or `DocumentCodec` attempts to load or decode the input
- **THEN** the `> 64 MiB` file fails pre-allocation with `DomainError.fileTooLarge` and the malformed byte buffer fails closed with `DomainError.unsupportedEncoding`

#### Scenario: P1 Three-Way LF CRLF and CR Detection with Byte-Exact Round-Trip
- **Path**: P1
- **Trait**: positive
- **GIVEN** three UTF-8 files in `InMemoryFileSystemFake` whose lines are separated by `\n`, `\r\n`, and `\r` respectively
- **WHEN** `DocumentLoader` loads each file, applies one text edit, and saves it atomically
- **THEN** the sessions report `LineEnding.lf`, `LineEnding.crlf`, and `LineEnding.cr`, and each saved byte buffer uses only its own separator without introducing either of the other two

#### Scenario: N1 CRLF Is Never Misclassified as CR and Mixed Endings Resolve Deterministically
- **Path**: N1
- **Trait**: negative
- **GIVEN** the texts `"x\r\ny\r\nz"` and `"a\nb\r\nc\rd"`
- **WHEN** `LineEnding.detect(in:)` and `LineEnding.normalizeToLF(_:)` evaluate them using unicode-scalar scanning
- **THEN** both texts are classified `LineEnding.crlf` rather than `LineEnding.cr`, and normalization yields `"x\ny\nz"` and `"a\nb\nc\nd"` without duplicated blank lines

### Requirement: REQ-003 Eight-Kilobyte NUL Binary Quarantine and Symlink Confinement
IF an inbound file contains a `0x00` byte within its first `8 KiB` outside a valid `UTF-16` BOM stream or resolves via symbolic link outside the granted workspace scope, THEN the document loader SHALL quarantine binary files as read-only (`DomainError.binaryFileSaveForbidden` on save) and reject symlink escapes with `DomainError.securityScopeViolation` [BC-008][BC-012][DATA-003][SEC-003][SEC-011][SEC-012].

#### Scenario: P2 Clean UTF-8 Text File Without NUL Bytes Opens as Editable Session
- **Path**: P2
- **Trait**: positive
- **GIVEN** a confined UTF-8 Markdown file with zero `0x00` bytes in its first `8 KiB`
- **WHEN** `DocumentLoader.load` inspects and decodes the file
- **THEN** the resulting `DocumentSession` has `isBinaryReadOnly == false`, `isPinnable == true`, and `isEligibleForSessionRecovery == true`

#### Scenario: N3 Binary File With NUL Byte Opens Read-Only and Blocks Save With binaryFileSaveForbidden
- **Path**: N3
- **Trait**: security
- **GIVEN** an inbound file containing a `0x00` byte within its first `8 KiB` (including a `2 MiB` binary payload)
- **WHEN** `DocumentLoader.load` opens the file for inspection and the caller subsequently invokes `DocumentLoader.save`
- **THEN** the loaded `DocumentSession` sets `isBinaryReadOnly == true`, `isPinnable == false`, `isEligibleForSessionRecovery == false`, caps the inspection text at `1 MiB`, and throws `DomainError.binaryFileSaveForbidden` on save without writing to `FileSystemProviding`

#### Scenario: N4 Symlink Escaping Granted Workspace Scope Fails With securityScopeViolation
- **Path**: N4
- **Trait**: security
- **GIVEN** a file URL inside the workspace directory that is a symbolic link resolving outside the granted workspace root
- **WHEN** `LocalFileSystemAdapter` or `DocumentLoader` attempts to load or save through that URL
- **THEN** the operation aborts immediately and throws `DomainError.securityScopeViolation`

### Requirement: REQ-004 Deterministic Command-D Line and Selection Duplication on DocumentSession
WHEN `duplicateLineOrSelection` or `applyEdit` executes on a mutable `DocumentSession`, the document core engine SHALL normalize in-memory insertions to `"\n"` regardless of raw `\r` separators on single-line `CR`-only documents, preserve `LineEnding.cr` serialization on save, increment `BufferRevision`, and emit an immutable `DomainEvent` [AR-004][AR-008][AR-012][BC-003][BC-004][BC-006].

#### Scenario: P3 Command-D Duplicates Unselected Line or Inserts Selected Text on New Line After Cursor
- **Path**: P3
- **Trait**: positive
- **GIVEN** a `DocumentSession` containing `"alpha\r\nbeta"` (`LineEnding.crlf`)
- **WHEN** `duplicateLineOrSelection` is invoked first with a collapsed caret on `"alpha"` (`TextRange(location: 2, length: 0)`) and on a second session with `"alp"` selected (`TextRange(location: 0, length: 3)`)
- **THEN** the unselected call produces `"alpha\r\nalpha\r\nbeta"` with incremented `BufferRevision`, and the selected call inserts `"alp"` on a new `\r\n`-separated line immediately after the `"alpha"` line while returning a `DomainEvent.commandDDuplicated` event

#### Scenario: N5 Out-of-Bounds TextRange Throws invalidTextRange Without State Mutation
- **Path**: N5
- **Trait**: negative
- **GIVEN** a `DocumentSession` whose text has `10` UTF-16 code units at `BufferRevision(1)`
- **WHEN** `applyEdit` or `duplicateLineOrSelection` is called with `TextRange(location: 8, length: 5)`
- **THEN** the method throws `DomainError.invalidTextRange` and leaves both text and `BufferRevision(1)` unchanged

#### Scenario: N6 Editing or Command-D Duplication on Binary Read-Only Session Throws binaryFileSaveForbidden
- **Path**: N6
- **Trait**: security
- **GIVEN** a `DocumentSession` opened with `isBinaryReadOnly == true` at `BufferRevision(1)`
- **WHEN** `applyEdit` or `duplicateLineOrSelection` (`Cmd+D`) is invoked on the session
- **THEN** the call throws `DomainError.binaryFileSaveForbidden` and leaves the buffer text and `BufferRevision(1)` unchanged

#### Scenario: P4 Single-Line CR-Only Document Cmd+D Preserves Clean Normalized Newlines and CR Save
- **Path**: P4
- **Trait**: positive
- **GIVEN** a single-line Classic Mac `CR` file decoded into `DocumentSession` with `LineEnding.cr` and normalized text `"alpha"` (zero `\r` inside buffer)
- **WHEN** `duplicateLineOrSelection` (`Cmd+D`) duplicates line `1` and `DocumentCodec.encode` serializes the session back to disk
- **THEN** the in-memory `snapshot.text` becomes `"alpha\nalpha"` with zero raw `\r` characters (`hasRawCR == false`), `BufferRevision` increments, and encoded save bytes equal `"alpha\ralpha"`

#### Scenario: N7 Mixed Raw Carriage Return Injection Is Normalized Safely Without Corrupting Line Counts
- **Path**: N7
- **Trait**: negative
- **GIVEN** a single-line `LineEnding.cr` session receiving a programmatic edit containing `\r\n` or `\r`
- **WHEN** `DocumentSession.applyEdit` validates and applies the edit and `CursorMetricsCalculator` computes metrics
- **THEN** in-memory storage normalizes separators deterministically without dangling raw `\r` artifacts and cursor line metrics count every line accurately
