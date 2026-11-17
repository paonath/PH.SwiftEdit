# Threat Model: Scaffold Cross-Platform Package.swift and Implement DocumentCore (Cmd+D & Binary Quarantine)

## 1. Asset Boundaries & Trust Zones
- **Untrusted Inbound Filesystem Zone**: Arbitrary user-selected files on disk (including oversized `> 64 MiB` logs/dumps, binary executables/images containing `0x00` bytes, malformed byte encodings, and symbolic links pointing outside the granted workspace scope).
- **Anti-Corruption Layer (`DocumentLoader` + `DocumentCodec` + `LocalFileSystemAdapter`)**: Validates symlink confinement (`resolvingSymlinksInPath()`), inspects file size attributes prior to heap allocation, scans the first `8 KiB` for `0x00` binary markers, and translates raw `Data` into immutable `Sendable` `DocumentSession` value types (`[BC-007]`, `[DATA-002]`, `[DATA-003]`, `[SEC-003]`, `[SEC-012]`).
- **Pure Domain Zone (`SwiftEditCore` / `DocumentCore`)**: Platform-independent (`Foundation` + `Markdown` only), 100% offline (`[SEC-004]`), value-type domain ring enforcing `DomainError.binaryFileSaveForbidden` on binary sessions (`[AR-002]`, `[BC-003]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | A binary executable, SQLite database, or archive renamed with a `.txt` or `.md` extension to bypass extension checks and trigger destructive text re-encoding on save (`[DATA-003]`). | Inspect content bytes rather than file extension: scan the first `8 KiB` (`8192` bytes) for `0x00` NUL bytes (after checking valid `UTF-16` BOMs) and classify matching files as `isBinaryReadOnly = true` (`[DATA-003]`, `[SEC-012]`). |
| Tampering | Saving or mutating (`applyEdit` / `Cmd+D`) a binary-inspected buffer or writing through a symbolic link escaping the authorized workspace directory (`CWE-22`, `[SEC-003]`, `[DATA-003]`). | `DocumentSession` and `DocumentLoader.save` reject binary buffers with `DomainError.binaryFileSaveForbidden`; `LocalFileSystemAdapter` resolves symlinks via `resolvingSymlinksInPath()` and rejects escapes with `DomainError.securityScopeViolation`. |
| Repudiation | Concurrent or out-of-order buffer edits overwriting document state without verifiable revision tracking across async lint/diff tasks (`[BC-004]`, `[BC-006]`). | Every accepted mutation increments `BufferRevision` (`UInt64`) monotonically and emits an immutable `DomainEvent` carrying `(DocumentID, BufferRevision)`. |
| Information Disclosure | Retaining raw binary file payloads in memory, tabs, or `SessionRecovery` snapshots after inspection (`[SEC-011]`, `[DATA-003]`). | Cap binary inspection text conversion at `1 MiB`, mark `DocumentSession.isEligibleForSessionRecovery == false` and `isPinnable == false` when `isBinaryReadOnly == true`, and forbid binary save/recovery (`[SEC-011]`). |
| Denial of Service | Opening a multi-gigabyte file exhausting process memory (`CWE-400`) or running full AST/lint passes on a `10..64 MiB` log file freezing `@MainActor` (`[DATA-002]`, `[BC-011]`). | Stat file byte size before reading: throw `DomainError.fileTooLarge` above `64 MiB` (`67_108_864` bytes) and enable `isDegradedPlainText = true` for `(10 MiB, 64 MiB]` (`[DATA-002]`). |
| Elevation of Privilege | Importing unauthorized third-party packages or UI/network frameworks (`WebKit`, `Network`) into `SwiftEditCore` (`[AR-002]`, `[AR-005]`). | `ArchitectureFitnessTests` parses `Package.swift` / `swift package dump-package` and scans `Sources/SwiftEditCore/**/*.swift` to block any non-allowlisted dependency or forbidden `import` (`[TEST-006]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Scenario `N3` (Binary File Save & Retention Quarantine — `Trait: security`)**: A file disguised as `notes.md` contains `0x00` bytes within its first `8 KiB`; `DocumentLoader` opens it with `isBinaryReadOnly == true` (truncating preview at `1 MiB`, `isPinnable == false`, `isEligibleForSessionRecovery == false`), and any `DocumentLoader.save` attempt throws `DomainError.binaryFileSaveForbidden` without writing to disk (`[DATA-003]`, `[SEC-011]`, `[SEC-012]`).
- **Abuse Scenario `N4` (Symlink Escape Outside Workspace Scope — `Trait: security`)**: A load or save request targets a path inside the workspace whose symbolic link destination resolves outside the granted workspace root; `FileSystemProviding` aborts with `DomainError.securityScopeViolation` (`CWE-22`, `[SEC-003]`).
- **Abuse Scenario `N6` (Direct Buffer Mutation / `Cmd+D` on Binary Session — `Trait: security`)**: A caller invokes `applyEdit` or `duplicateLineOrSelection()` (`Cmd+D`) on a binary read-only `DocumentSession`; the aggregate rejects the mutation with `DomainError.binaryFileSaveForbidden` and keeps `revision` unchanged (`[BC-003]`, `[BC-012]`, `[SEC-012]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-17
- Verdict: approved
- Status: approved
- Open items: none
