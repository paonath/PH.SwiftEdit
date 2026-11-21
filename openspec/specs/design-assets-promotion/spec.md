# Capability: design-assets-promotion

## Purpose
Promotes the ratified PH.SwiftEdit Concept E2 brand logo, macOS and iOS `AppIcon.appiconset` catalogs, Zed-minimal Purple (`Viola`) color scheme specification, and UI preview mockups into `docs/design/` with deterministic Swift 6 `Foundation` and `ImageIO` integrity and security verification.

## Requirements

### Requirement: REQ-001 Canonical Design Documentation and Preview Promotion
The design asset promotion workflow SHALL copy `color-schemes-and-zed-layout.md`, `app-icons-riepilogo.md`, `logo-e2-refined.svg`, `logo-e2-refined-512.png`, and the three UI preview PNGs into `docs/design/` with repository-relative Markdown links while preserving `reasoning/001_project-constitution/deliverables/` intact [UI-001][UI-002][UI-004][SDD-001].

#### Scenario: P1 Canonical Promotion and Relative Link Resolution
- **Path**: P1
- **Trait**: positive
- **GIVEN** the ratified design deliverables exist in `reasoning/001_project-constitution/deliverables/`
- **WHEN** the canonical promotion copies the Markdown specifications, Concept E2 SVG/PNG master logos, and three UI preview PNGs into `docs/design/`, updates root `README.md` links, and runs `swift Scripts/verify-design-assets.swift --root .`
- **THEN** every required file in `docs/design/` and `reasoning/001_project-constitution/deliverables/` exists, every relative link in `docs/design/*.md` and `README.md` resolves to an existing target, and the verifier exits with status `0`

#### Scenario: N1 Missing Promoted Asset or Broken Markdown Link Rejection
- **Path**: N1
- **Trait**: negative
- **GIVEN** a workspace fixture where a required preview PNG is absent or `docs/design/color-schemes-and-zed-layout.md` references a non-existent relative asset
- **WHEN** `swift Scripts/verify-design-assets.swift` inspects the fixture root
- **THEN** the verifier exits with non-zero status `1` and prints the missing file or broken Markdown link path to standard error

### Requirement: REQ-002 Repository Path Confinement and Host Path Redaction
IF a Markdown link or asset entry under `docs/design/` traverses parent directories, points to a symbolic link escaping `docs/design/`, contains a `file://` or `/Users/` host path, or embeds executable SVG markup, THEN the design asset verifier SHALL terminate with exit status `2` and report the offending path [SEC-003][SEC-005].

#### Scenario: P1 Confined Relative Documentation Links Pass Security Scan
- **Path**: P1
- **Trait**: positive
- **GIVEN** `docs/design/color-schemes-and-zed-layout.md`, `docs/design/assets/app-icons-riepilogo.md`, `README.md`, and `docs/design/assets/logo-e2-refined.svg` contain exclusively confined relative links and static vector elements
- **WHEN** `swift Scripts/verify-design-assets.swift` executes the path-confinement and SVG hygiene scan
- **THEN** zero path-traversal, host-path leakage, or SVG active-content violations are reported and the scan succeeds with exit status `0`

#### Scenario: N2 Path Traversal Symlink Escape or Host Path Leak Rejection
- **Path**: N2
- **Trait**: security
- **GIVEN** a workspace fixture containing a `../` link, a symbolic link resolving outside `docs/design/`, a `file:///Users/developer/` URI, or an `<script>` element inside `logo-e2-refined.svg`
- **WHEN** `swift Scripts/verify-design-assets.swift` evaluates the fixture root
- **THEN** the verifier rejects the fixture with exit status `2` and emits a `SECURITY_VIOLATION` diagnostic identifying the offending file

### Requirement: REQ-003 Concept E2 AppIcon Catalog Integrity and Alpha Channel Governance
The design asset verifier SHALL validate via `ImageIO` that `docs/design/assets/app-icons/macos/AppIcon.appiconset` provides 10 PNG files (`16 px` to `1024 px`) with an alpha channel and `docs/design/assets/app-icons/ios/AppIcon.appiconset` provides 8 PNG files across 9 `Contents.json` slots (`40 px` to `1024 px`) with zero alpha channel [AR-001][UI-001][TEST-007].

#### Scenario: P2 Valid macOS and iOS Concept E2 AppIcon Catalogs Pass ImageIO Inspection
- **Path**: P2
- **Trait**: positive
- **GIVEN** `docs/design/assets/app-icons/macos/AppIcon.appiconset` and `docs/design/assets/app-icons/ios/AppIcon.appiconset` contain promoted Concept E2 PNGs and `Contents.json` manifests
- **WHEN** `swift Scripts/verify-design-assets.swift` decodes both `Contents.json` manifests and inspects each PNG via `CGImageSourceCopyPropertiesAtIndex`
- **THEN** all 10 macOS slots match exact `size * scale` pixel dimensions with `hasAlpha == true`, all 9 iOS slots resolve to the 8 PNG files matching `size * scale` pixel dimensions with `hasAlpha == false`, and the verifier exits with status `0`

#### Scenario: N3 Missing Slot Corrupted Contents Manifest or Pixel Dimension Mismatch Rejection
- **Path**: N3
- **Trait**: negative
- **GIVEN** a workspace fixture where an `.appiconset` `Contents.json` omits a required idiom/size/scale slot or a PNG file has pixel dimensions inconsistent with its declared `size * scale`
- **WHEN** `swift Scripts/verify-design-assets.swift` validates the `.appiconset` catalog
- **THEN** the verifier exits with non-zero status `1` and identifies the mismatched or missing icon slot

#### Scenario: N4 Invalid Alpha Channel Symlink or Oversized Icon Payload Rejection
- **Path**: N4
- **Trait**: security
- **GIVEN** a workspace fixture where an iOS `AppIcon` PNG contains an alpha channel (`hasAlpha == true`), a macOS `AppIcon` PNG lacks outer alpha (`hasAlpha == false`), a `Contents.json` `filename` is a symbolic link or contains `/`, or an asset exceeds `16 MiB`
- **WHEN** `swift Scripts/verify-design-assets.swift` validates the `.appiconset` catalog
- **THEN** the verifier exits with status `2` and emits an alpha-contract or security-confinement failure diagnostic
