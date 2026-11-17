# Design: Scaffold Cross-Platform Package.swift and Implement DocumentCore (Cmd+D & Binary Quarantine)

## Context
`PH.SwiftEdit` requires its Swift Package Manager foundation (`Package.swift`) and first Core Bounded Context (`DocumentCore`) per `TASK-02` in `reasoning/001_project-constitution/README.ai.md`. In accordance with `openspec/Constitution.md` (`v1.2.0`), `SwiftEditCore` must compile cleanly in Swift 6 mode (`-strict-concurrency=complete`) for both `.macOS(.v26)` and `.iOS(.v26)` without importing `AppKit`, `UIKit`, `SwiftUI`, `WebKit`, `Combine`, or `Network`, while `SwiftEditUI` isolates platform UI bridges behind `#if os(macOS)` and `#if os(iOS)`.

## Goals / Non-Goals
- Goals:
  - Scaffold `Package.swift` with `SwiftEditCore`, `SwiftEditUI`, and `SwiftEditTests` plus the single allowlisted `swiftlang/swift-markdown` package (`[AR-001]`, `[AR-005]`).
  - Provide an automated static architecture fitness gate (`ArchitectureImportScanner` + `ArchitectureFitnessTests`) verifying manifest topology and `SwiftEditCore` import hygiene (`[AR-002]`, `[TEST-006]`).
  - Implement `DocumentCore` (`Core` subdomain per `[BC-002]`) using immutable `Sendable` value types (`DocumentSession`, `BufferRevision`, `DocumentSnapshot`, `DomainEvent`, `DomainError`) and the `FileSystemProviding` I/O seam (`[AR-004]`, `[AR-007]`, `[BC-003]`).
  - Enforce lossless `UTF-8`/`UTF-16` BOM and `LF`/`CRLF` round-trip encoding, `10 MiB` degraded mode / `64 MiB` ceiling (`DomainError.fileTooLarge`), `8 KiB` `0x00` binary quarantine (`DomainError.binaryFileSaveForbidden`), and `Cmd+D` (`duplicateLineOrSelection`) (`[AR-012]`, `[DATA-002]`, `[DATA-003]`, `[DATA-004]`).
- Non-Goals:
  - AST Markdown linting/formatting, `(){}[]` bracket matching, and Myers diff (`TASK-03`).
  - `WorkspaceAndTabSession`, Notepad++ tab pinning, and `SessionRecovery` GC (`TASK-04`).
  - Full `SwiftEditUI` TextKit 2 workspace rendering (`TASK-05`).

## Architecture Memory & Module Boundaries (AR-###)
- **AR-001**: `Package.swift` declares `.macOS(.v26)` and `.iOS(.v26)` deployment targets and restricts library/test targets to `SwiftEditCore`, `SwiftEditUI`, and `SwiftEditTests` with `swiftlang/swift-markdown` as the sole external dependency (`[AR-005]`).
- **AR-007**: `SwiftEditCore` isolates disk stat, `8 KiB` prefix probing, symlink confinement checks, and atomic sibling writes behind the `Sendable` `FileSystemProviding` protocol (`LocalFileSystemAdapter` in production, `InMemoryFileSystemFake` in `SwiftEditTests`).
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` alongside `01-architecture/module-topology.md`, `01-architecture/dependency-and-layering.md`, `01-architecture/host-and-sagas.md`, `02-domain/bounded-context-ownership.md`, `02-domain/negative-ownership-and-refs.md`, `02-domain/ubiquitous-language-and-policy.md`, `04-data-persistence/storage-and-migrations.md`, `06-testing-fitness/tdd-and-unit-testing.md`, `06-testing-fitness/architecture-fitness-and-quality.md`, `07-security-privacy/authn-authz-and-boundaries.md`, `07-security-privacy/stride-and-gdpr-privacy.md`, and `08-sdd-governance/artifact-traceability.md`.

## Bounded Context Classification & Ubiquitous Language Glossary (`BC-002`, `BC-009`)

| Bounded Context / Type | Classification / Kind | Normative Definition (`BC-009`) |
| :--- | :--- | :--- |
| `DocumentCore` | `Core` Subdomain | Authoritative context owning text buffer state, encoding/line-ending fidelity, `Cmd+D` duplication, size gates, and binary quarantine. |
| `DocumentSession` | Aggregate Root (`struct`, `Sendable`) | Value-type session holding `id: DocumentID`, `revision: BufferRevision`, `text: String`, `encoding: TextEncoding`, `lineEnding: LineEnding`, `isDirty: Bool`, `isDegradedPlainText: Bool`, and `isBinaryReadOnly: Bool`. |
| `DocumentID` | Value Object (`struct`, `Sendable`) | Strongly-typed `UUID` wrapper identifying an open document across bounded contexts (`[BC-006]`). |
| `BufferRevision` | Value Object (`struct`, `Sendable`) | Monotonically increasing `UInt64` revision counter incremented on every accepted buffer mutation (`[AR-008]`, `[BC-006]`). |
| `TextEncoding` | Value Object (`enum`, `Sendable`) | Supported encodings: `.utf8`, `.utf8WithBOM`, `.utf16LEWithBOM`, `.utf16BEWithBOM`. |
| `LineEnding` | Value Object (`enum`, `Sendable`) | Canonical line break sequence: `.lf` (`"\n"`) or `.crlf` (`"\r\n"`). |
| `TextRange` | Value Object (`struct`, `Sendable`) | Non-negative UTF-16 `(location: Int, length: Int)` span within `DocumentSession.text`. |
| `DocumentSnapshot` | Value Object (`struct`, `Sendable`) | Immutable point-in-time projection `(id, revision, text, encoding, lineEnding, isDegradedPlainText, isBinaryReadOnly)` published to downstream contexts (`[BC-004]`). |
| `DomainEvent` | Domain Event (`enum`, `Sendable`) | Immutable event emitted by `DocumentSession`: `.textEdited(DocumentID, BufferRevision, TextRange)` or `.commandDDuplicated(DocumentID, BufferRevision, TextRange)`. |
| `DomainError` | Domain Error (`enum`, `Error`, `Sendable`, `Equatable`) | Typed failure contract: `.fileTooLarge(byteCount: UInt64)`, `.binaryFileSaveForbidden`, `.unsupportedEncoding`, `.invalidTextRange(TextRange)`, `.securityScopeViolation(path: String)`, `.ioFailure(String)` (`[BC-012]`). |
| `FileSystemProviding` | I/O Seam Protocol (`Sendable`) | Narrow port providing `fileAttributes(at:)`, `readPrefix(at:maxBytes:)`, `readData(at:maxBytes:)`, and `writeAtomic(data:to:withinScope:)`. |

## Decisions
- **Decision 1 — Value-Type `DocumentSession` Aggregate Root (`KISS-First`)**:
  - *Rationale*: Modeling `DocumentSession` as a `Sendable` Swift `struct` eliminates reference-sharing race conditions under Swift 6 `-strict-concurrency=complete` (`[AR-004]`, `[BC-003]`, `[BC-004]`).
- **Decision 2 — Two-Stage Binary & Encoding Detection in `DocumentCodec`**:
  - *Rationale*: First inspect BOM prefixes (`EF BB BF` -> `.utf8WithBOM`, `FF FE` -> `.utf16LEWithBOM`, `FE FF` -> `.utf16BEWithBOM`). For non-UTF-16 streams, scan the first `min(data.count, 8192)` bytes for `0x00`; if present, classify as binary read-only (`isBinaryReadOnly = true`, decoding up to `1 MiB` via ISO-8859-1 lossy visual representation for read-only inspection) and forbid all edits/saves (`DomainError.binaryFileSaveForbidden`). Otherwise validate strict UTF-8 and detect dominant/first line ending (`\r\n` -> `.crlf`, default `.lf`).
- **Decision 3 — Deterministic `Cmd+D` (`duplicateLineOrSelection`) Semantics**:
  - *Rationale*: Matches Notepad++ / Zed smart duplication (`[AR-012]`, `[BC-003]`):
    - *Unselected (`selection.length == 0`)*: Locate the full line containing `selection.location` (excluding its trailing `\r\n` or `\n`), insert `lineEnding.rawValue + lineContent` immediately after that line, and place the caret at the same relative column in the duplicated line.
    - *Selected (`selection.length > 0`)*: Extract the selected substring, locate the end of the line containing `selection.upperBound`, and insert `lineEnding.rawValue + selectedSubstring` on a new line immediately after that line, returning the new selection range covering the inserted duplicate.

## Risks / Trade-offs
- **UTF-16 Text Files Contain Legitimate `0x00` Bytes** -> Mitigated by checking `UTF-16LE` (`FF FE`) and `UTF-16BE` (`FE FF`) BOM headers *before* running the `8 KiB` `0x00` binary probe, and verifying even byte length + valid UTF-16 decoding.
- **Line-Ending Normalization During Edits** -> Mitigated by preserving internal text or normalizing upon `DocumentCodec.encode(_:encoding:lineEnding:)` so saved files always emit the session's authoritative `LineEnding` (`LF` or `CRLF`) and BOM.

## Migration Plan
1. Create `Package.swift` and minimal target stubs in task `1.0 [SETUP]`.
2. Execute TDD quads (`[RED] -> [GREEN] -> [REFACTOR] -> [DOC]`) for Unit 1 (`SwiftPackageTopologyAndArchitectureFitness`), Unit 2 (`DocumentCodecAndSizeBinaryQuarantine`), and Unit 3 (`DocumentSessionAndCommandDDuplication`).
3. Verify `swift test --parallel` passes with zero warnings and `>= 85%` line coverage across `SwiftEditCore`.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-17
- Verdict: approved
- Status: approved
- Open items: none
