# Tasks: Promote Concept E2 Brand Icons, AppIcon Sets, Color Schemes, and UI Previews to docs/design/

## 1. Unit: DesignDocsPromotionAndLinkIntegrity
<!-- Governing rules: UI-001, UI-002, UI-004, SEC-003, SEC-005, SDD-002, SDD-003 -->

- [ ] 1.0 [SETUP] TASK-000-SETUP: Create canonical `docs/design/assets/app-icons/{macos,ios}` and `Scripts/` directory structure before behavioral TDD triads [Const: SDD-003 (08-sdd-governance/artifact-traceability.md)]
  - paths: [P1]
- [ ] 1.1 [RED] TASK-001-RED: Write failing Swift 6 `--self-test` assertions in `Scripts/verify-design-assets.swift` for `P1` (promoted Markdown, Concept E2 SVG/PNG, 3 preview PNGs, intact `reasoning/` source, and relative `README.md` links) and `N1` (missing deliverable or broken Markdown link); verify failure before promotion [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [ ] 1.2 [GREEN] TASK-001-GREEN: Copy `color-schemes-and-zed-layout.md`, `app-icons-riepilogo.md`, `logo-e2-refined.svg`, `logo-e2-refined-512.png`, and the 3 UI preview PNGs into `docs/design/`, rewrite links to relative paths, update `README.md`, and implement `verifyDocumentationAndAssets` so `P1` and `N1` pass [Const: UI-002 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [ ] 1.3 [REFACTOR] TASK-001-REFACTOR: Extract Markdown link parser and brand hex token assertions in `Scripts/verify-design-assets.swift` while keeping `P1` and `N1` green [Const: UI-004 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P1, N1]
- [ ] 1.4 [DOC] TASK-001-DOC: Write concise English Swift Markup (`///`) documentation on `DesignAssetsVerifier` documentation/link check types and contracts
  - paths: [P1, N1]
- [ ] 1.5 [RED] [SECURITY] TASK-002-RED: Write failing `--self-test --filter security` fixture tests for `N2` covering `../` traversal, symlink escaping `docs/design/`, residual `file://` or `/Users/` host URIs, and `<script>`/`<!ENTITY` SVG injection [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [ ] 1.6 [GREEN] [SECURITY] TASK-002-GREEN: Implement `resolvingSymlinksInPath()` confinement inside `docs/design/`, host-path leak detection, and SVG active-content rejection returning exit code `2` so `N2` passes [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P1, N2] · tags: security · priority: critical
- [ ] 1.7 [REFACTOR] [SECURITY] TASK-002-REFACTOR: Consolidate path-confinement and `16 MiB` file-size guards without weakening `N2` security checks and verify suite stays green [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P1, N2] · tags: security
- [ ] 1.8 [DOC] [SECURITY] TASK-002-DOC: Document `CWE-22`, `CWE-200`, and `CWE-79`/`CWE-611` confinement invariants in English Swift Markup (`///`) comments
  - paths: [P1, N2]

## 2. Unit: AppIconCatalogVerification
<!-- Governing rules: AR-001, UI-001, TEST-007, SEC-003 -->

- [ ] 2.1 [RED] TASK-003-RED: Write failing `--self-test` tests in `Scripts/verify-design-assets.swift` for `P2` (macOS 10 PNGs `16..1024 px` and iOS 9 slots / 8 PNGs `40..1024 px`) and `N3` (missing slot, invalid `Contents.json`, or `size * scale` pixel mismatch); verify failure before copying `.appiconset` bundles [Const: AR-001 (01-architecture/module-topology.md)]
  - paths: [P2, N3]
- [ ] 2.2 [GREEN] TASK-003-GREEN: Copy `macos/AppIcon.appiconset` and `ios/AppIcon.appiconset` into `docs/design/assets/app-icons/` and implement `Codable` `Contents.json` + `ImageIO` dimension verification so `P2` and `N3` pass [Const: TEST-007 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N3]
- [ ] 2.3 [REFACTOR] TASK-003-REFACTOR: Deduplicate macOS and iOS `IconSlotSpec` table definitions in `Scripts/verify-design-assets.swift` while keeping `P2` and `N3` green [Const: TEST-007 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N3]
- [ ] 2.4 [DOC] TASK-003-DOC: Write concise English Swift Markup (`///`) documentation for `AppIcon` `Contents.json` models and `ImageIO` pixel inspection helpers
  - paths: [P2, N3]
- [ ] 2.5 [RED] [SECURITY] TASK-004-RED: Write failing `--self-test --filter security` fixture tests for `N4` covering iOS `hasAlpha == true` (`ITMS-90717`), macOS `hasAlpha == false`, `.appiconset` symlink or `/` filename traversal, and `> 16 MiB` icon payloads [Const: UI-001 (03-ui-ux/design-system-and-tokens.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [ ] 2.6 [GREEN] [SECURITY] TASK-004-GREEN: Enforce `kCGImagePropertyHasAlpha` platform invariants (`macos == true`, `ios == false`), `.appiconset` symlink/filename confinement, and size limits returning exit code `2` so `N4` passes [Const: SEC-003 (07-security-privacy/authn-authz-and-boundaries.md)]
  - paths: [P2, N4] · tags: security · priority: critical
- [ ] 2.7 [REFACTOR] [SECURITY] TASK-004-REFACTOR: Run full `--self-test` and live `--root .` verification, remove any `./.tmp/` artifacts, and confirm zero Swift 6 compiler warnings [Const: TEST-007 (06-testing-fitness/architecture-fitness-and-quality.md)]
  - paths: [P2, N4] · tags: security
- [ ] 2.8 [DOC] [SECURITY] TASK-004-DOC: Document macOS/iOS alpha-channel and App Store Connect `ITMS-90717` invariants in English Swift Markup (`///`) comments
  - paths: [P2, N4]
