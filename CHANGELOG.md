# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
