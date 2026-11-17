# Tasks: Scaffold Cross-Platform Package.swift and Implement DocumentCore (Cmd+D & Binary Quarantine)

## 1. Unit: SwiftPackageTopologyAndArchitectureFitness
<!-- Governing rules: AR-001, AR-002, AR-003, AR-005, AR-006, TEST-001, TEST-006, SDD-002, SDD-003 -->

- [ ] 1.0 [SETUP] TASK-000-SETUP: Scaffold `Package.swift` (`.macOS(.v26), .iOS(.v26)`, Swift 6 strict concurrency, `swiftlang/swift-markdown`) and initial `Sources/SwiftEditCore`, `Sources/SwiftEditUI`, and `Tests/SwiftEditTests` target directories [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
  - paths: [P1]
- [ ] 1.1 [RED] TASK-001-RED: Write failing `Swift Testing` `@Suite("ArchitectureFitnessTests")` tests in `Tests/SwiftEditTests/ArchitectureFitnessTests.swift` for `P1` (`Package.swift` target/platform dump and clean `SwiftEditCore` import scan) and `N1` (detection of forbidden `AppKit`/`UIKit`/`SwiftUI`/`WebKit`/`Combine`/`Network`/`SwiftEditUI` imports and unapproved dependencies); verify tests fail on assertions [Const: TEST-006 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P1, N1]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Implement `ArchitectureImportScanner` in `Sources/SwiftEditCore/ArchitectureFitness/ArchitectureImportScanner.swift` and minimal `#if os(macOS)` / `#if os(iOS)` bridge stub in `Sources/SwiftEditUI/SwiftEditUIBridge.swift` so `P1` and `N1` pass under `swift test --parallel` [Const: AR-002 (01-architecture/module-topology.md)]
  - paths: [P1, N1]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Refine `ArchitectureImportScanner` comment/string-literal stripping and dependency allowlist validation while keeping `P1` and `N1` green [Const: AR-005 (01-architecture/module-topology.md)]
  - paths: [P1, N1]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `ArchitectureImportScanner` and `SwiftEditUIBridge` public contracts
  - paths: [P1, N1]

## 2. Unit: DocumentCodecAndSizeBinaryQuarantine
<!-- Governing rules: AR-007, BC-007, BC-011, BC-012, DATA-001, DATA-002, DATA-003, DATA-004, SEC-003, SEC-011, SEC-012, TEST-004, TEST-005 -->

- [ ] 2.1 [RED] TASK-002-RED: Write failing parameterized `Swift Testing` tests in `Tests/SwiftEditTests/DocumentCodecAndLoaderTests.swift` for `P2` (`UTF-8`, `UTF-8 BOM`, `UTF-16LE BOM`, `UTF-16BE BOM`, `LF`/`CRLF` round-trip and `10..64 MiB` degraded plain-text mode) and `N2` (`> 64 MiB` `DomainError.fileTooLarge` and invalid byte stream `DomainError.unsupportedEncoding`); verify failure on assertions [Const: TEST-005 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N2]
- [ ] 2.2 [GREEN] TASK-002-GREEN: Implement `TextEncoding`, `LineEnding`, `DomainError`, `FileSystemProviding`, `InMemoryFileSystemFake`, `DocumentCodec`, and `DocumentLoader` size/encoding logic in `Sources/SwiftEditCore/DocumentCore/` so `P2` and `N2` pass [Const: DATA-002 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P2, N2]
- [ ] 2.3 [REFACTOR] TASK-002-REFACTOR: Consolidate BOM header table and `LF`/`CRLF` normalization helpers in `DocumentCodec` while keeping `P2` and `N2` green [Const: DATA-004 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P2, N2]
- [ ] 2.4 [DOC] TASK-002-DOC: Write concise English Swift Markup (`///`) documentation on `DocumentCodec`, `FileSystemProviding`, `TextEncoding`, and `LineEnding`
  - paths: [P2, N2]
- [ ] 2.5 [RED] [SECURITY] TASK-003-RED: Write failing security tests in `Tests/SwiftEditTests/DocumentSecurityQuarantineTests.swift` for `N3` (`8 KiB` `0x00` binary classification, `1 MiB` inspection cap, `isPinnable == false`, `isEligibleForSessionRecovery == false`, and `DomainError.binaryFileSaveForbidden` on save) and `N4` (`LocalFileSystemAdapter` symlink escape throwing `DomainError.securityScopeViolation`); verify failure on assertions [Const: DATA-003 (04-data-persistence/storage-and-migrations.md)]
  - paths: [P2, N3, N4] · tags: security · priority: critical
- [ ] 2.6 [GREEN] [SECURITY] TASK-003-GREEN: Implement `8 KiB` `0x00` NUL binary probe, `1 MiB` read-only preview cap, `DomainError.binaryFileSaveForbidden` save guard in `DocumentLoader`, and `resolvingSymlinksInPath()` scope check in `LocalFileSystemAdapter` so `N3` and `N4` pass [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P2, N3, N4] · tags: security · priority: critical
- [ ] 2.7 [REFACTOR] [SECURITY] TASK-003-REFACTOR: Audit binary quarantine and symlink canonicalization edge cases and verify all `SwiftEditTests` suites remain green [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N3, N4] · tags: security
- [ ] 2.8 [DOC] [SECURITY] TASK-003-DOC: Document binary quarantine (`DATA-003`, `SEC-011`) and symlink confinement (`SEC-003`) invariants in English Swift Markup (`///`) comments
  - paths: [P2, N3, N4]

## 3. Unit: DocumentSessionAndCommandDDuplication
<!-- Governing rules: AR-004, AR-008, AR-012, BC-003, BC-004, BC-006, BC-012, SEC-012 -->

- [ ] 3.1 [RED] TASK-004-RED: Write failing `Swift Testing` tests in `Tests/SwiftEditTests/DocumentSessionAndCommandDTests.swift` for `P3` (`applyEdit` and `duplicateLineOrSelection` `Cmd+D` for unselected line duplication and selected text insertion on a new line after cursor with `BufferRevision` increment and `DomainEvent`) and `N5` (out-of-bounds `TextRange` throwing `DomainError.invalidTextRange`); verify failure on assertions [Const: BC-003 (02-domain/bounded-context-ownership.md)]
  - paths: [P3, N5]
- [ ] 3.2 [GREEN] TASK-004-GREEN: Implement `DocumentSession.applyEdit` and `DocumentSession.duplicateLineOrSelection` (`Cmd+D`), `BufferRevision`, `DocumentSnapshot`, and `DomainEvent` in `Sources/SwiftEditCore/DocumentCore/DocumentSession.swift` so `P3` and `N5` pass [Const: AR-012 (01-architecture/host-and-sagas.md)]
  - paths: [P3, N5]
- [ ] 3.3 [REFACTOR] TASK-004-REFACTOR: Extract UTF-16 line-boundary calculation helpers in `DocumentSession` while keeping `P3` and `N5` green [Const: BC-004 (02-domain/bounded-context-ownership.md)]
  - paths: [P3, N5]
- [ ] 3.4 [DOC] TASK-004-DOC: Write concise English Swift Markup (`///`) documentation on `DocumentSession`, `DocumentSnapshot`, `BufferRevision`, `TextRange`, and `DomainEvent`
  - paths: [P3, N5]
- [ ] 3.5 [RED] [SECURITY] TASK-005-RED: Write failing security tests in `Tests/SwiftEditTests/DocumentSessionAndCommandDTests.swift` for `N6` verifying that `applyEdit` and `duplicateLineOrSelection` (`Cmd+D`) on a binary read-only session throw `DomainError.binaryFileSaveForbidden` without mutating state or `BufferRevision` [Const: BC-012 (02-domain/ubiquitous-language-and-policy.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [ ] 3.6 [GREEN] [SECURITY] TASK-005-GREEN: Enforce `isBinaryReadOnly` pre-mutation guard in `DocumentSession.applyEdit` and `DocumentSession.duplicateLineOrSelection` throwing `DomainError.binaryFileSaveForbidden` so `N6` passes [Const: SEC-012 (07-security-privacy/stride-and-gdpr-privacy.md)]
  - paths: [P3, N6] · tags: security · priority: critical
- [ ] 3.7 [REFACTOR] [SECURITY] TASK-005-REFACTOR: Centralize mutability precondition guard in `DocumentSession` and verify full parallel test suite passes with zero compiler warnings [Const: TEST-008 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P3, N6] · tags: security
- [ ] 3.8 [DOC] [SECURITY] TASK-005-DOC: Document read-only binary mutation prohibition invariants on `DocumentSession` mutating APIs in English Swift Markup (`///`) comments
  - paths: [P3, N6]
