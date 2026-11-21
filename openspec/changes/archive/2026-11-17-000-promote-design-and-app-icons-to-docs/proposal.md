# Proposal: Promote Concept E2 Brand Icons, AppIcon Sets, Color Schemes, and UI Previews to docs/design/

## Why
Pre-development reasoning in `reasoning/001_project-constitution/` finalized the PH.SwiftEdit brand identity (`Concept E2` Feather-in-Inverted-Triangle logo, macOS `16..1024 px` and iOS `40..1024 px` `AppIcon.appiconset` catalogs), the Zed-minimal Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome token specification, the inverted `#FFFFFF`/`#000000` TextKit 2 editor canvas contract, `50%..300%` Zoom Mode, and three high-resolution UI preview mockups. Because `reasoning/` is excluded from Git tracking as an ephemeral workspace reasoning log, these canonical design deliverables must be promoted (`TASK-01` in `README.ai.md`) into version-controlled `docs/design/` with portable repository-relative links and automated Swift 6 integrity verification before `TASK-02` scaffolds `Package.swift` and `TASK-10` wires `Assets.xcassets`.

## What Changes
- Copy `color-schemes-and-zed-layout.md` (`v1.2.0`) to `docs/design/color-schemes-and-zed-layout.md` and rewrite workstation-local `file:///Users/...` links to portable paths confined inside `docs/design/` (`[UI-001]`, `[UI-002]`, `[UI-004]`, `[SEC-003]`, `[SEC-005]`).
- Copy `assets/app-icons-riepilogo.md`, `assets/logo-e2-refined.svg`, `assets/logo-e2-refined-512.png`, `assets/preview-dark-black-purple.png`, `assets/preview-light-purple.png`, and `assets/preview-file-compare-diff.png` into `docs/design/assets/` while keeping `reasoning/001_project-constitution/deliverables/` intact.
- Copy `assets/app-icons/macos/AppIcon.appiconset/` (`Contents.json` + 10 PNGs `16..1024 px` with outer alpha) and `assets/app-icons/ios/AppIcon.appiconset/` (`Contents.json` with 9 slots + 8 opaque `#0B0614` PNGs `40..1024 px`) into `docs/design/assets/app-icons/` (`[AR-001]`, `[UI-001]`).
- Update root `README.md` with relative documentation links pointing to `docs/design/color-schemes-and-zed-layout.md` and `docs/design/assets/app-icons-riepilogo.md`.
- Add a zero-dependency Swift 6 CLI verification and self-test script (`Scripts/verify-design-assets.swift`) using `Foundation`, `ImageIO`, and `CoreGraphics` to enforce asset completeness, relative-link confinement, SVG hygiene, and `AppIcon.appiconset` pixel/alpha contracts (`[TEST-007]`, `[SDD-001]`, `[SDD-002]`, `[SDD-003]`).

## Capabilities
- New Capabilities: `design-assets-promotion`
- Modified Capabilities: None

<!-- Optional (Uncomment for multi-context DDD or cross-module boundary changes):
## Domain Carrier & Decision Ownership (BC-###)
- **BC-001**: [Bounded Context / Capability Name and authoritative lifecycle scope]
- **Owned Decisions**: [Decisions and state transitions exclusively governed by this capability]
- **Forbidden Responsibilities**: [Actions/policies this capability MUST NEVER execute or silently invent (BC-011)]
- **External Decision References**: [Opaque strongly-typed IDs such as PaymentAuthorizationId, StockReservationId, CustomerId stored as evidence instead of embedded foreign models/PII, or 'none']
-->

## Impact
- **Documentation & Brand Assets**: Populates `docs/design/` and updates root `README.md` without altering `reasoning/001_project-constitution/`.
- **Verification Tooling**: Introduces `Scripts/verify-design-assets.swift` executable via `swift Scripts/verify-design-assets.swift --root .` and `swift Scripts/verify-design-assets.swift --self-test` prior to `Package.swift` creation in `TASK-02`.
- **Downstream Tasks**: Unblocks `TASK-02` (`Package.swift` bootstrap) and `TASK-10` (`SwiftEditUI` workspace shell & `Assets.xcassets` consumption).

## Security Impact
- Eliminates workstation username/path disclosure (`CWE-200`, `[SEC-005]`) by banning `file://` and `/Users/` URIs from tracked Markdown documentation.
- Enforces strict directory confinement (`CWE-22`, `[SEC-003]`) via `resolvingSymlinksInPath()` on all Markdown links and `Contents.json` icon `filename` references under `docs/design/`.
- Scans `logo-e2-refined.svg` against embedded `<script>`, `<foreignObject>`, `javascript:` URIs, and `<!ENTITY` declarations (`CWE-79` / `CWE-611`), and enforces a `16 MiB` per-asset size ceiling (`CWE-400`).

## Metadata
- Owner: PH.SwiftEdit Team
- Domain: Design System, Brand Identity & Swift 6 Asset Fitness
- Reviewer: swift-macos-expert, cyber-security-expert
- Branch: feature/FirstStub
- Manual-Steps: none
- Modifies-Specs: none
- Constitutional-Rules: [AR-001, UI-001, UI-002, UI-004, TEST-007, SEC-003, SEC-005, SDD-001, SDD-002, SDD-003]
- Amends-Constitution: none

## Prerequisites
- Ratified `openspec/Constitution.md` (`v1.2.0`) and `reasoning/001_project-constitution/` deliverables (`brief-promote-design-and-app-icons-to-docs.md`).
