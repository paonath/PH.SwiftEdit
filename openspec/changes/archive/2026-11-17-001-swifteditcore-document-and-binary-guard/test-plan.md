# Test Plan: Scaffold Cross-Platform Package.swift and Implement DocumentCore (Cmd+D & Binary Quarantine)

## 1. Path Coverage Matrix

Every unit under test MUST list at least 1 positive path (P#) and at least 1 negative path (N#).

| Unit (method/class) | Positive paths (good path) | Negative paths (fail path) |
| :--- | :--- | :--- |
| `SwiftPackageTopologyAndArchitectureFitness` (`ArchitectureImportScanner`) | `P1`: Verifies `Package.swift` (`swift package dump-package`) declares `.macOS(.v26)` and `.iOS(.v26)` platforms, `SwiftEditCore`, `SwiftEditUI`, `SwiftEditTests`, only `swift-markdown` as external package, and zero forbidden imports across `Sources/SwiftEditCore/**/*.swift` (`[AR-001]`, `[AR-002]`, `[TEST-006]`). | `N1`: Rejects source snippets containing `import AppKit`, `import UIKit`, `import SwiftUI`, `import WebKit`, `import Combine`, `import Network`, or `import SwiftEditUI`, and rejects unapproved package dependencies (`[AR-002]`, `[AR-005]`). |
| `DocumentCodecAndSizeBinaryQuarantine` (`DocumentCodec` & `DocumentLoader`) | `P2`: Parameterized `@Test(arguments:)` round-trips `UTF-8`, `UTF-8 BOM`, `UTF-16LE BOM`, and `UTF-16BE BOM` with `LF` and `CRLF` line endings via atomic `FileSystemProviding` save, and activates `isDegradedPlainText == true` for `(10 MiB, 64 MiB]` files (`[DATA-002]`, `[DATA-004]`, `[TEST-005]`). | `N2`: Rejects files `> 64 MiB` pre-allocation with `DomainError.fileTooLarge` and invalid byte sequences with `DomainError.unsupportedEncoding`; `N3` (`security`): Classifies files with `0x00` in first `8 KiB` as `isBinaryReadOnly == true` (capped at `1 MiB` preview, `isPinnable == false`, `isEligibleForSessionRecovery == false`) and blocks `save` with `DomainError.binaryFileSaveForbidden` (`[DATA-003]`, `[SEC-012]`); `N4` (`security`): Rejects symlink escapes outside workspace root with `DomainError.securityScopeViolation` (`[SEC-003]`). |
| `DocumentSessionAndCommandDDuplication` (`DocumentSession`) | `P3`: Applies text edits and `duplicateLineOrSelection()` (`Cmd+D`) for both collapsed caret (current line duplicated with document `LineEnding`) and non-empty selection (selected text inserted on a new line immediately after the cursor line), incrementing `BufferRevision` and returning `DomainEvent` (`[AR-012]`, `[BC-003]`, `[BC-004]`). | `N5`: Rejects out-of-bounds `TextRange` with `DomainError.invalidTextRange` leaving `DocumentSession` and `BufferRevision` unchanged; `N6` (`security`): Rejects `applyEdit` and `duplicateLineOrSelection()` on binary read-only sessions with `DomainError.binaryFileSaveForbidden` (`[BC-012]`, `[DATA-003]`, `[SEC-012]`). |

## 2. Test Automation Strategy & Commands
- Unit test runner command: `swift test --parallel`
- Security trait / suite filter command: `swift test --parallel --filter Security`
- Coverage verification command: `swift test --parallel --enable-code-coverage`

## 3. Testability Seams & Test Doubles
- Real collaborators: Real `Sendable` domain value types (`DocumentSession`, `DocumentSnapshot`, `BufferRevision`, `TextEncoding`, `LineEnding`, `TextRange`, `DomainEvent`, `DomainError`) and `DocumentCodec`.
- Isolation seams: `InMemoryFileSystemFake` conforming to `FileSystemProviding` (simulating arbitrary file byte sizes up to `65 MiB` via metadata without allocating `65 MiB` buffers on disk, plus real temporary directory symlink escape tests for `LocalFileSystemAdapter` cleaned via `defer`) (`[AR-007]`, `[TEST-003]`, `[TEST-004]`).

## 4. AI-Readiness Verification

| Check | Status | Verification Detail |
| :--- | :--- | :--- |
| Unambiguous behavior contracts | Verified | Given/When/Then scenarios defined in `specs/document-core-and-spm-scaffold/spec.md` (`REQ-001..REQ-004`) |
| Path coverage completeness | Verified | All 3 units cover positive (`P1..P3`) and negative (`N1..N6`) paths |
| Security traits tagged | Verified | Abuse cases `N3`, `N4`, and `N6` tagged `- **Trait**: security` (`[SEC-003]`, `[SEC-011]`, `[SEC-012]`) |
