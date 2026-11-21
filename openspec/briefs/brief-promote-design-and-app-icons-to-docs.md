---
id: "brief-promote-design-and-app-icons-to-docs"
change_id: "000-promote-design-and-app-icons-to-docs"
capability: "design-assets-promotion"
branch: "feature/FirstStub"
modifies_specs: "none"
status: "approved-via-qa"
date: "2026-11-17"
owners:
  - "swift-macos-expert"
  - "cyber-security-expert"
---

# TDD Specification Brief: Promote Concept E2 Design Assets and AppIcon Catalogs to `docs/design/` (`TASK-01`)

## 1. Context & Source Traceability

- **Originating Roadmap Task**: `TASK-01` in `reasoning/001_project-constitution/README.ai.md` (`Phase 1 — Foundation, Versioning & Core Domain`).
- **Active Git Branch**: `feature/FirstStub` (`Nerdbank.GitVersioning` `0.0.1-alpha1`).
- **Consolidated Specs Modified (`modifies_specs`)**: `none` (`openspec/index.yml` currently has zero consolidated living capabilities; all requirements are `ADDED`).
- **Source Reasoning Deliverables** (retained intact in git-ignored `reasoning/001_project-constitution/deliverables/` so `scaffold_reasoning.py --validate` remains green):
  - `color-schemes-and-zed-layout.md` (`v1.2.0` Purple `Viola` chrome tokens, `#FFFFFF`/`#000000` inverted editor canvas, `50%..300%` Zoom Mode, Zed-minimal layout, and File Compare Diff palette)
  - `assets/app-icons-riepilogo.md` (Concept E2 logo & icon set summary)
  - `assets/logo-e2-refined.svg` (`512x512` master vector: `#0B0614` rounded ground, `#A78BFA` inverted triangle stroke, `#C4B5FD -> #7C3AED` feather nib gradient)
  - `assets/logo-e2-refined-512.png` (`512x512` master PNG with alpha)
  - `assets/app-icons/macos/AppIcon.appiconset/` (`Contents.json` + 10 PNGs `16..1024 px`, `hasAlpha == true`)
  - `assets/app-icons/ios/AppIcon.appiconset/` (`Contents.json` with 9 slots + 8 PNGs `40..1024 px`, `hasAlpha == false`, opaque `#0B0614`)
  - `assets/preview-dark-black-purple.png`, `assets/preview-light-purple.png`, `assets/preview-file-compare-diff.png`

## 2. Domain & Security Expert Notes

- **`swift-macos-expert` (`openspec/agents/swift-macos-expert.agent.md` v1.2.0)**:
  - Before `Package.swift` is introduced in `TASK-02`, verification is executed via a zero-dependency Swift 6 script (`Scripts/verify-design-assets.swift`) compiled/interpreted with the host Apple Swift 6.4 toolchain (`swift Scripts/verify-design-assets.swift`) using `Foundation` and `ImageIO` (`CGImageSourceCreateWithURL`, `CGImageSourceCopyPropertiesAtIndex`).
  - `ImageIO` deterministically inspects `kCGImagePropertyPixelWidth`, `kCGImagePropertyPixelHeight`, and `kCGImagePropertyHasAlpha` without AppKit/UIKit window server dependencies:
    - macOS `AppIcon.appiconset`: 10 distinct files (`16x16` `@1x/@2x` -> `16, 32`; `32x32` `@1x/@2x` -> `32, 64`; `128x128` `@1x/@2x` -> `128, 256`; `256x256` `@1x/@2x` -> `256, 512`; `512x512` `@1x/@2x` -> `512, 1024`), every PNG must report `hasAlpha == true`.
    - iOS `AppIcon.appiconset`: 9 `Contents.json` slots mapped to 8 PNG files (`40, 58, 60, 80, 87, 120` shared across `40x40@3x` and `60x60@2x`, `180`, `1024`), every PNG must report `hasAlpha == false` (App Store Connect ITMS-90717 compliance).
- **`cyber-security-expert` (`07-security-privacy/authn-authz-and-boundaries.md`)**:
  - Rewriting `color-schemes-and-zed-layout.md` during promotion MUST scrub all local workstation `file:///Users/...` URIs (`CWE-200` Information Exposure) and convert them to repository-confined relative links.
  - Both Markdown link resolution and `Contents.json` `filename` entries MUST resolve via `resolvingSymlinksInPath()` strictly inside the canonical `docs/design/` directory, rejecting `..` parent traversal, absolute paths, and symlink escapes (`CWE-22`, `[SEC-003]`), as well as SVG script/foreignObject/external-entity payloads (`CWE-79` / `CWE-611`).

## 3. 4-Pillar Breakdown

### Pillar 1: Public Behaviors & Nominal Scenarios
- **`P1` (`DesignDocsPromotionAndLinkIntegrity`)**: Canonical promotion copies the Markdown specifications, Concept E2 SVG/PNG master logos, and 3 UI preview PNGs into `docs/design/` and `docs/design/assets/`, updates root `README.md` with relative navigation links to `docs/design/color-schemes-and-zed-layout.md` and `docs/design/assets/app-icons-riepilogo.md`, preserves `reasoning/001_project-constitution/deliverables/` untouched, and passes `swift Scripts/verify-design-assets.swift --root .` with exit code `0`.
- **`P2` (`AppIconCatalogVerification`)**: Both `docs/design/assets/app-icons/macos/AppIcon.appiconset` (10 PNGs `16..1024 px`, `hasAlpha == true`) and `docs/design/assets/app-icons/ios/AppIcon.appiconset` (9 slots / 8 PNGs `40..1024 px`, `hasAlpha == false`) pass `Contents.json` schema decoding and `ImageIO` pixel/alpha verification with exit code `0`.

### Pillar 2: Edge Cases, Boundaries & Negative Paths
- **`N1` (`DesignDocsPromotionAndLinkIntegrity` — Missing File / Broken Link)**: Removing any required deliverable or introducing a broken relative link in `docs/design/*.md` or `README.md` causes the verifier to exit non-zero with a deterministic diagnostic naming the missing target.
- **`N3` (`AppIconCatalogVerification` — Slot / Dimension Mismatch)**: Corrupting `Contents.json`, omitting a required slot/PNG, or supplying a PNG whose pixel width/height disagrees with `size * scale` causes the verifier to exit non-zero.

### Pillar 3: Testability, Dependency Seams & KISS/SOLID Balance
- **KISS-First CLI Seam**: `Scripts/verify-design-assets.swift` accepts `--root <directory>` for workspace validation and `--self-test` to execute an isolated, branch-free Arrange-Act-Assert suite over temporary fixture trees created under `./.tmp/test-results/verify-design-assets/` and deterministically removed on exit.
- **Zero External Dependencies**: Uses exclusively Swift 6 standard library, `Foundation`, `ImageIO`, and `CoreGraphics` (`CGContext` / `ImageIO` PNG fixture generation in `--self-test`), honoring `[AR-005]` before `Package.swift` is created in `TASK-02`.

### Pillar 4: Abuse Cases & Security Traits (`STRIDE`)
- **`N2` (`security` — `CWE-22` / `CWE-200` / `CWE-79`)**: Any Markdown link or asset reference containing `..`, a symlink resolving outside `docs/design/`, a residual `file://` or `/Users/` host path, or an `<script>`/`javascript:`/`<!ENTITY` construct inside `logo-e2-refined.svg` is rejected with exit code `2` and a security violation diagnostic.
- **`N4` (`security` — AppIcon Alpha / Symlink / Oversized Payload Gate)**: Any iOS icon containing an alpha channel (`hasAlpha == true`), macOS icon missing outer alpha (`hasAlpha == false`), symbolic link inside `.appiconset`, `filename` path separator (`/` or `..`), or asset exceeding `16 MiB` is rejected with exit code `2`.

## 4. Behavior Contracts & Path Coverage Matrix

| Unit | Path ID | Trait | Summary |
| :--- | :--- | :--- | :--- |
| `DesignDocsPromotionAndLinkIntegrity` | `P1` | `positive` | All promoted Markdown docs, SVG/PNG logos, UI previews, and root `README.md` relative links resolve inside `docs/design/`. |
| `DesignDocsPromotionAndLinkIntegrity` | `N1` | `negative` | Missing promoted file or broken relative Markdown link triggers non-zero verification failure. |
| `DesignDocsPromotionAndLinkIntegrity` | `N2` | `security` | `..` traversal, symlink escaping `docs/design/`, residual `file://` or `/Users/` URI, or active SVG script/entity is blocked (`[SEC-003]`, `[SEC-005]`). |
| `AppIconCatalogVerification` | `P2` | `positive` | macOS (10 PNGs `16..1024 px` with alpha) and iOS (9 slots / 8 PNGs `40..1024 px` without alpha) `AppIcon.appiconset` catalogs pass `ImageIO` verification (`[AR-001]`, `[UI-001]`, `[TEST-007]`). |
| `AppIconCatalogVerification` | `N3` | `negative` | Malformed `Contents.json`, missing PNG file, or `size * scale` pixel mismatch triggers non-zero failure. |
| `AppIconCatalogVerification` | `N4` | `security` | iOS alpha channel (`hasAlpha == true`), macOS missing alpha, `.appiconset` symlink/traversal `filename`, or `> 16 MiB` payload is rejected. |
