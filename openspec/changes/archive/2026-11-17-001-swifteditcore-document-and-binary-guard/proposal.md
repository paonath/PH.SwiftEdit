# Proposal: Scaffold Cross-Platform Package.swift and Implement DocumentCore (Cmd+D & Binary Quarantine)

## Why
With `TASK-01` (`000-promote-design-and-app-icons-to-docs`) archived, `PH.SwiftEdit` requires its foundational Swift 6 Package Manager topology (`Package.swift` targeting `.macOS(.v26)` and `.iOS(.v26)` with `-strict-concurrency=complete`) and the `DocumentCore` (`Core` subdomain) Bounded Context (`TASK-02` in `README.ai.md`). `DocumentCore` provides the immutable `Sendable` value-type buffer engine (`DocumentSession`, `BufferRevision`, `DocumentSnapshot`, `DomainEvent`), lossless `UTF-8`/`UTF-16` BOM and `LF`/`CRLF` round-trip encoding, deterministic `Cmd+D` smart duplication (line or selection to new line after cursor), the `10 MiB`/`64 MiB` pre-allocation size gate, and the `8 KiB` `0x00` binary-file quarantine (`DomainError.binaryFileSaveForbidden`) required by all downstream Markdown (`TASK-03`), SessionRecovery (`TASK-04`), and TextKit 2 UI (`TASK-05`) tasks.

## What Changes
- Create `Package.swift` (`swift-tools-version: 6.0`, Swift 6 language mode, `.macOS(.v26)` and `.iOS(.v26)`) declaring `SwiftEditCore` (importing only `Foundation` and `Markdown` from `swiftlang/swift-markdown`), `SwiftEditUI` (isolating platform bridges behind `#if os(macOS)` and `#if os(iOS)`), and `SwiftEditTests` (`Swift Testing`) (`[AR-001]`, `[AR-002]`, `[AR-003]`, `[AR-005]`).
- Implement static architecture fitness verification (`ArchitectureImportScanner` + `ArchitectureFitnessTests`) validating target topology and zero forbidden UI/network imports inside `Sources/SwiftEditCore/` (`[AR-002]`, `[AR-006]`, `[TEST-006]`).
- Implement `DocumentCore` value types and I/O seam under `Sources/SwiftEditCore/DocumentCore/`:
  - `DocumentID`, `BufferRevision`, `TextEncoding` (`utf8`, `utf8WithBOM`, `utf16LEWithBOM`, `utf16BEWithBOM`), `LineEnding` (`lf`, `crlf`), `TextRange`, `DomainError`, `DomainEvent`, and `DocumentSnapshot` (`[AR-004]`, `[AR-008]`, `[BC-006]`, `[BC-009]`).
  - `FileSystemProviding` (`Sendable` protocol seam) + `LocalFileSystemAdapter` (symlink confinement check + atomic sibling write) and `InMemoryFileSystemFake` for parallel unit tests (`[AR-007]`, `[DATA-001]`, `[DATA-004]`, `[SEC-003]`, `[TEST-003]`, `[TEST-004]`).
  - `DocumentCodec` and `DocumentLoader` enforcing pre-allocation size gates (`> 64 MiB` -> `DomainError.fileTooLarge`; `> 10 MiB..64 MiB` -> `isDegradedPlainText = true`), `8 KiB` `0x00` NUL-byte binary detection (`isBinaryReadOnly = true`, `<= 1 MiB` inspection preview, blocking saves with `DomainError.binaryFileSaveForbidden`), and fail-closed `DomainError.unsupportedEncoding` on invalid byte sequences (`[BC-007]`, `[BC-010]`, `[BC-011]`, `[BC-012]`, `[DATA-002]`, `[DATA-003]`, `[SEC-011]`, `[SEC-012]`).
  - `DocumentSession` Aggregate Root enforcing text edits and `Cmd+D` (`duplicateLineOrSelection`: current line when unselected, or selected text onto a new line immediately after the cursor when selected) while rejecting mutations on binary read-only buffers (`[AR-012]`, `[BC-003]`, `[BC-004]`).

## Capabilities
- New Capabilities: `document-core-and-spm-scaffold`
- Modified Capabilities: None

## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: `DocumentCore` (`Core` subdomain in `SwiftEditCore`) is the sole authoritative Bounded Context governing document buffer state (`DocumentSession`), `BufferRevision` progression, `TextEncoding`/`LineEnding` detection and preservation, `Cmd+D` duplication, `10 MiB`/`64 MiB` size classification, and `8 KiB` `0x00` binary quarantine (`[BC-003]`, `[BC-004]`, `[BC-012]`).
- **Owned Decisions**: Pre-allocation file size admissibility (`<= 10 MiB` normal, `> 10..64 MiB` degraded plain-text, `> 64 MiB` `DomainError.fileTooLarge`), `8 KiB` `0x00` binary classification (`isBinaryReadOnly`, `DomainError.binaryFileSaveForbidden`), BOM/line-ending round-trip fidelity, and synchronous `DocumentSession` mutation (`applyEdit`, `duplicateLineOrSelection`).
- **Forbidden Responsibilities**: `DocumentCore` MUST NEVER import `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, `SQLite`, `CoreData`, or `SwiftData` (`[AR-002]`, `[DATA-001]`), MUST NEVER persist binary files to disk, tabs, or `SessionRecovery` (`[BC-008]`, `[DATA-003]`, `[SEC-011]`), and MUST NEVER introduce LSP clients, terminals, or network I/O (`[BC-005]`).
- **External Decision References**: Downstream contexts (`MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, `WorkspaceAndTabSession`) reference documents exclusively via immutable `(DocumentID, BufferRevision)` and `DocumentSnapshot` value objects (`[BC-006]`).

## Impact
- **Build & Package Manifest**: Introduces root `Package.swift` and `Package.resolved` (with `swiftlang/swift-markdown`).
- **Source Modules**: Populates `Sources/SwiftEditCore/DocumentCore/`, `Sources/SwiftEditUI/`, and `Tests/SwiftEditTests/`.
- **Downstream Unblocking**: Unblocks `TASK-03` (`MarkdownLintAndFormat` & `SearchDiffAndBracketEngine`) and `TASK-04` (`WorkspaceAndTabSession` & `SessionRecovery`).

## Security Impact
- Prevents OOM / Denial of Service (`CWE-400`) via pre-allocation `64 MiB` stat gate (`DomainError.fileTooLarge`) and `10 MiB` degraded plain-text mode (`[DATA-002]`).
- Prevents binary file corruption and sensitive binary retention (`[DATA-003]`, `[SEC-011]`, `[SEC-012]`) via the `8 KiB` `0x00` NUL probe, `1 MiB` read-only inspection cap, and fail-closed `DomainError.binaryFileSaveForbidden` guard on both edits and saves.
- Enforces symlink boundary confinement (`CWE-22`, `[SEC-003]`) in `LocalFileSystemAdapter` (`DomainError.securityScopeViolation`).

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: Swift 6 Core Architecture & DocumentCore Bounded Context
- Reviewer: swift-macos-expert, ddd-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: [AR-001, AR-002, AR-003, AR-004, AR-005, AR-006, AR-007, AR-008, AR-012, BC-001, BC-002, BC-003, BC-004, BC-005, BC-006, BC-007, BC-009, BC-011, BC-012, DATA-001, DATA-002, DATA-003, DATA-004, TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-008, SEC-003, SEC-009, SEC-010, SEC-011, SEC-012, SDD-001, SDD-002, SDD-003]
- Amends-Constitution: none

## Prerequisites
- Completed `000-promote-design-and-app-icons-to-docs` (`TASK-01`) and ratified `openspec/Constitution.md` (`v1.2.0`).
