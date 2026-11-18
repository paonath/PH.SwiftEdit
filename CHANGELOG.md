# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased] - 2026-11-18 UTC
Branch: feature/FirstStub | Commit: 56e5507

### Added
- Implemented `WorkspaceTabSession` (`TabDescriptor`) in `SwiftEditCore` with Notepad++ pinned-first tab ordering, active tab fallback, and pinned-tab close protection (`DomainError.pinnedTabCloseForbidden`, `DomainError.tabNotFound`) (`openspec/specs/notepadpp-tabs-session-recovery-and-dotfiles/spec.md`, archived at `openspec/changes/archive/2026-11-18-003-notepadpp-tabs-session-recovery-and-dotfiles/`).
- Implemented `SessionRecoveryStore` (`SessionRecoveryManifest`, `RecoveredDocumentSnapshot`) for atomic `session-manifest.json` and `<UUID>.recovery` persistence with immediate unlink on tab closure and deterministic startup orphan garbage collection (`[DATA-005]`, `[DATA-006]`).
- Implemented `DotfileFolderNavigator` (`SecurityScopedResourceAccessing`, `FolderEntryDescriptor`) for shallow directory enumeration including hidden dotfiles (`.env`, `.gitignore`) sorted directories-first, alongside `EditorPreferencesStore` (`AppearanceMode`, `50%..300%` clamped zoom) on isolated `UserDefaults` suites (`[DATA-007]`, `[DATA-008]`).
- Implemented `MarkdownLintAndFormatEngine` (`lint`, `formatDocument`, `formatSection`) using `swiftlang/swift-markdown` 100% offline in `SwiftEditCore` to detect `missingHeadingSpace`, `emptyLinkTarget`, `unsafeLinkScheme`, and `unbalancedFencedCodeBlock` and emit `TextEdit` batches preserving fenced code blocks (`openspec/specs/markdown-lint-format-bracket-and-diff/spec.md`, archived at `openspec/changes/archive/2026-11-18-002-markdown-lint-format-bracket-and-diff/`).
- Added atomic `DocumentSession.applyTextEdits(_:expectedRevision:)` advancing `BufferRevision` once per batch (`DomainEvent.formatBatchApplied`) and rejecting stale revisions (`DomainError.staleBufferRevision`) or overlapping/out-of-bounds ranges (`DomainError.invalidTextRange`) without buffer mutation (`[BC-003]`, `[BC-004]`).
- Implemented `SearchDiffAndBracketEngine.evaluateBrackets(in:caretLocation:)` for nested `()`, `{}`, and `[]` matching, active caret pair resolution, and unbalanced delimiter reporting, alongside `computeMyersDiff(lhs:rhs:clock:)` for stateless line-level Myers shortest-edit-script diffs (`DiffHunk`, `FileCompareDiffResult`) (`[AR-012]`, `[BC-006]`).

### Security
- Enforced `0700`/`0600` POSIX permissions, iOS `FileProtectionType.complete`, `isExcludedFromBackup = true`, `64 MiB` (`67_108_864` bytes) aggregate quota (`DomainError.sessionRecoveryQuotaExceeded`), binary buffer non-retention (`DomainError.binaryFileSaveForbidden`), and symlink rejection across `WorkspaceTabSession` and `SessionRecoveryStore` (`[BC-008]`, `[DATA-003]`, `[SEC-007]`, `[SEC-011]`).
- Enforced balanced `startAccessing`/`defer { stopAccessing }` security-scoped resource bracketing and `resolvingSymlinksInPath()` confinement (`DomainError.securityScopeViolation`, `CWE-22`) in `DotfileFolderNavigator` (`[SEC-002]`, `[SEC-003]`, `[SEC-012]`).
- Enforced Markdown link URI scheme allowlisting (`https`, `http`, `mailto`, relative/fragment paths) flagging `javascript:`, `file:`, and `data:` links as `.unsafeLinkScheme`, iterative `128`-level AST depth caps, and `250 ms` `ElapsedTimeProviding` cooperative deadlines returning `.degradedOrTimedOut` (`[AR-013]`, `[BC-011]`, `[SEC-004]`, `[SEC-012]`).
- Enforced `4096` UTF-16 code-unit per-line caps in `evaluateBrackets`, `10 MiB` (`10_485_760` UTF-8 bytes) and `500 ms` cooperative deadlines in `computeMyersDiff`, and fail-closed binary/degraded snapshot rejection across both engines (`[BC-011]`, `[SEC-012]`).

## [Unreleased] - 2026-11-17 UTC
Branch: feature/FirstStub | Commit: bca0e90

### Added
- Scaffolded cross-platform Swift 6 `Package.swift` (`.macOS(.v26)`, `.iOS(.v26)`, `-strict-concurrency=complete`) declaring `SwiftEditCore` (`swiftlang/swift-markdown` `0.9.0`), `SwiftEditUI` (`#if os(macOS)` / `#if os(iOS)`), and `SwiftEditTests` (`Swift Testing`), alongside `ArchitectureImportScanner` and `PackageManifestDumpValidator` (`openspec/specs/document-core-and-spm-scaffold/spec.md`, archived at `openspec/changes/archive/2026-11-17-001-swifteditcore-document-and-binary-guard/`).
- Implemented `DocumentCore` (`DocumentSession`, `DocumentLoader`, `DocumentCodec`, `FileSystemProviding`, `LocalFileSystemAdapter`, `InMemoryFileSystemFake`) with lossless `UTF-8`/`UTF-8 BOM`/`UTF-16LE BOM`/`UTF-16BE BOM` and `LF`/`CRLF` round-trip encoding, `10 MiB` plain-text degraded mode, and deterministic `Cmd+D` (`duplicateLineOrSelection`) line and selection duplication (`[AR-012]`, `[BC-003]`, `[DATA-004]`).
- Promoted Concept E2 brand icons (`logo-e2-refined.svg`, `logo-e2-refined-512.png`), macOS (`10` PNGs `16..1024 px`) and iOS (`8` PNGs across `9` slots `40..1024 px`) `AppIcon.appiconset` catalogs, Zed-minimal Purple (`Viola`) chrome and inverted `#FFFFFF`/`#000000` editor canvas specification (`color-schemes-and-zed-layout.md`), and three UI preview mockups to `docs/design/` (`openspec/specs/design-assets-promotion/spec.md`, archived at `openspec/changes/archive/2026-11-17-000-promote-design-and-app-icons-to-docs/`).
- Updated root `README.md` with relative links to `docs/design/color-schemes-and-zed-layout.md`, `docs/design/assets/app-icons-riepilogo.md`, and `openspec/Constitution.md`.
- Added pure Swift 6 CLI asset verifier and 14-test `--self-test` harness (`Scripts/verify-design-assets.swift`) using `Foundation`, `ImageIO`, and `CoreGraphics` to validate file completeness, brand tokens, `Contents.json` slots, and PNG pixel dimensions (`[AR-001]`, `[UI-001]`, `[TEST-007]`).
- Configured Nerdbank.GitVersioning (`version.json` at `0.0.0`, `feature/FirstStub` `0.0.1-alpha1`) and ratified the Bare-Bones `openspec/Constitution.md` (`v1.2.0`) alongside the `swift-macos-expert` agent profile (`e2af960`, `9008090`, `0a74b1f`).

### Security
- Enforced pre-allocation `64 MiB` ceiling (`DomainError.fileTooLarge`), `8 KiB` `0x00` NUL binary-file quarantine (`isBinaryReadOnly`, `1 MiB` inspection preview cap, `DomainError.binaryFileSaveForbidden` on edits/`Cmd+D`/saves), strict UTF-8/UTF-16 decoding (`DomainError.unsupportedEncoding`), and `resolvingSymlinksInPath()` workspace scope confinement (`DomainError.securityScopeViolation`, `CWE-22`) in `DocumentCore` (`[DATA-002]`, `[DATA-003]`, `[SEC-003]`, `[SEC-011]`, `[SEC-012]`).
- Scrubbed workstation-local `file://` and `/Users/` URIs (`CWE-200`) from promoted documentation and enforced symlink/parent-traversal confinement inside `docs/design/` (`CWE-22`, `[SEC-003]`, `[SEC-005]`).
- Enforced SVG active-content rejection (`<script>`, `<foreignObject>`, `javascript:`, `<!ENTITY`, `CWE-79`/`CWE-611`), `16 MiB` per-asset size caps (`CWE-400`), and platform alpha-channel invariants (`hasAlpha == false` on iOS App Store icons for `ITMS-90717`, `hasAlpha == true` on macOS icons).
