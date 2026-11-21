---
id: "brief-swifteditcore-document-and-binary-guard"
change_id: "001-swifteditcore-document-and-binary-guard"
capability: "document-core-and-spm-scaffold"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-17"
owners:
  - "swift-macos-expert"
  - "ddd-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: Cross-Platform `Package.swift` & `DocumentCore` (`Cmd+D` & Binary Quarantine) (`TASK-02`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-02` in `reasoning/001_project-constitution/README.ai.md`.
- **Active Git Branch**: `feature/FirstStub` (`Nerdbank.GitVersioning` `0.0.1-alpha1`).
- **Consolidated Specs Modified (`modifies_specs`)**: `none` (existing living spec `design-assets-promotion` is untouched; all requirements in `document-core-and-spm-scaffold` are `ADDED`).
- **Governing Constitutional Rules**: `[AR-001]`, `[AR-002]`, `[AR-003]`, `[AR-004]`, `[AR-005]`, `[AR-006]`, `[AR-007]`, `[AR-008]`, `[AR-009]`, `[AR-012]`, `[BC-001]`, `[BC-002]`, `[BC-003]`, `[BC-004]`, `[BC-005]`, `[BC-006]`, `[BC-007]`, `[BC-009]`, `[BC-011]`, `[BC-012]`, `[DATA-001]`, `[DATA-002]`, `[DATA-003]`, `[DATA-004]`, `[TEST-001]`, `[TEST-002]`, `[TEST-003]`, `[TEST-004]`, `[TEST-005]`, `[TEST-006]`, `[TEST-008]`, `[SEC-003]`, `[SEC-009]`, `[SEC-010]`, `[SEC-011]`, `[SEC-012]`, `[SDD-001]`, `[SDD-002]`, `[SDD-003]`.

## 2. Domain, Architecture & Security Expert Notes

- **`swift-macos-expert` (`openspec/agents/swift-macos-expert.agent.md` v1.2.0)**:
  - `Package.swift` (`swift-tools-version: 6.0` / Swift 6 language mode with `-strict-concurrency=complete`) declares `.macOS(.v26)` and `.iOS(.v26)` platforms and three targets: `SwiftEditCore` (depending solely on `Markdown` from `swiftlang/swift-markdown`), `SwiftEditUI` (depending on `SwiftEditCore` and isolating platform code behind `#if os(macOS)` / `#if os(iOS)`), and `SwiftEditTests` (using native `Swift Testing`: `@Suite`, `@Test`, `#expect`, `#require`).
  - `FileSystemProviding` is a narrow `Sendable` protocol seam (`AR-007`, `TEST-004`) abstracting stat size inspection, prefix byte probing (`8 KiB`), full/capped byte reads, symlink confinement verification, and atomic sibling writes so unit tests run 100% in-memory in parallel (`swift test --parallel`).
- **`ddd-expert` (`02-domain/bounded-context-ownership.md` & `negative-ownership-and-refs.md`)**:
  - `DocumentCore` (`Core` subdomain) owns the `DocumentSession` Aggregate Root (`struct`, `Sendable`, `Equatable`) identified by `DocumentID` (`UUID`) and monotonic `BufferRevision` (`UInt64`).
  - All mutations (`applyEdit`, `duplicateLineOrSelection` for `Cmd+D`) are `mutating` methods on `DocumentSession` returning immutable `DomainEvent` values and producing `DocumentSnapshot` values (`BC-003`, `BC-004`, `BC-006`).
  - `Cmd+D` (`duplicateLineOrSelection`):
    1. When `selection.length == 0` (caret only): duplicates the entire line containing the caret using the document's `LineEnding` (`\n` or `\r\n`) and places the caret at the same column offset on the newly inserted line.
    2. When `selection.length > 0` (active selection): inserts a newline (`LineEnding`) followed by the selected text on a new line immediately after the line containing the selection end, advancing the selection to the duplicated text.
- **`cyber-security-expert` (`04-data-persistence/storage-and-migrations.md` & `07-security-privacy/stride-and-gdpr-privacy.md`)**:
  - Pre-allocation size guard (`DATA-002`): `> 64 MiB` (`67_108_864` bytes) fails immediately with `DomainError.fileTooLarge` before allocating buffer memory (`CWE-400`); `(10 MiB, 64 MiB]` activates `isDegradedPlainText = true` (`BC-011`).
  - Binary quarantine (`DATA-003`, `SEC-011`, `SEC-012`): scanning the first `8 KiB` (`8192` bytes) of non-UTF-16-BOM files for `0x00` NUL bytes classifies the file as binary (`isBinaryReadOnly = true`, preview truncated at `1 MiB` decoded ISO-8859-1/ASCII printable representation). Any save or buffer edit/duplication on a binary session fails closed with `DomainError.binaryFileSaveForbidden`.
  - Symlink/scope guard (`SEC-003`): `FileSystemProviding` verifies `resolvingSymlinksInPath()` confinement inside the granted workspace root and throws `DomainError.securityScopeViolation` on escape.

## 3. 4-Pillar Breakdown & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `SwiftPackageTopologyAndArchitectureFitness` | `P1` | `positive` | `Package.swift` builds `SwiftEditCore`, `SwiftEditUI`, and `SwiftEditTests` under Swift 6 strict concurrency (`.macOS(.v26), .iOS(.v26)`), and `ArchitectureFitnessTests` confirms zero forbidden imports in `SwiftEditCore` (`[AR-001]`, `[AR-002]`, `[TEST-006]`). |
| `SwiftPackageTopologyAndArchitectureFitness` | `N1` | `negative` | `ArchitectureImportScanner` flags any `import AppKit`, `UIKit`, `SwiftUI`, `WebKit`, `Combine`, `Network`, or `SwiftEditUI` inside `SwiftEditCore` sources or unauthorized dependencies in `Package.swift` (`[AR-002]`, `[AR-005]`). |
| `DocumentCodecAndSizeBinaryQuarantine` | `P2` | `positive` | `DocumentCodec` and `DocumentLoader` round-trip `UTF-8` (with/without BOM), `UTF-16LE` BOM, and `UTF-16BE` BOM preserving `LF`/`CRLF` line endings on atomic Save and flagging `(10 MiB, 64 MiB]` files as `isDegradedPlainText == true` (`[DATA-002]`, `[DATA-004]`, `[TEST-005]`). |
| `DocumentCodecAndSizeBinaryQuarantine` | `N2` | `negative` | Files `> 64 MiB` throw `DomainError.fileTooLarge` pre-allocation, and invalid non-UTF-8 byte sequences without a valid UTF-16 BOM throw `DomainError.unsupportedEncoding` (`[BC-012]`, `[DATA-002]`). |
| `DocumentCodecAndSizeBinaryQuarantine` | `N3` | `security` | Files containing a `0x00` byte in the first `8 KiB` open as `isBinaryReadOnly == true` (capped at `1 MiB` preview) and reject any Save call with `DomainError.binaryFileSaveForbidden` (`[DATA-003]`, `[SEC-011]`, `[SEC-012]`). |
| `DocumentCodecAndSizeBinaryQuarantine` | `N4` | `security` | Loading or saving a file whose symlink target escapes the granted workspace directory throws `DomainError.securityScopeViolation` (`CWE-22`, `[SEC-003]`). |
| `DocumentSessionAndCommandDDuplication` | `P3` | `positive` | `DocumentSession` executes edits and `Cmd+D` (`duplicateLineOrSelection`) for both unselected current-line duplication and selected-text-to-new-line-after-cursor insertion, advancing `BufferRevision` and emitting `DomainEvent` (`[AR-012]`, `[BC-003]`, `[BC-004]`). |
| `DocumentSessionAndCommandDDuplication` | `N5` | `negative` | Out-of-bounds `TextRange` edit or `Cmd+D` selection throws `DomainError.invalidTextRange` without mutating `DocumentSession` or `BufferRevision` (`[BC-003]`, `[BC-012]`). |
| `DocumentSessionAndCommandDDuplication` | `N6` | `security` | Calling `applyEdit` or `duplicateLineOrSelection` (`Cmd+D`) on a binary read-only `DocumentSession` throws `DomainError.binaryFileSaveForbidden` without mutating state (`[BC-012]`, `[DATA-003]`, `[SEC-012]`). |
