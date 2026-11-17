# Design: Promote Concept E2 Brand Icons, AppIcon Sets, Color Schemes, and UI Previews to docs/design/

## Context
`PH.SwiftEdit` currently stands at pre-SwiftPM bootstrap (`TASK-01` on branch `feature/FirstStub`, version `0.0.1-alpha1`). During `reasoning/001_project-constitution/` (`v1.2.0`), the project ratified its visual architecture (`color-schemes-and-zed-layout.md`), Concept E2 Feather-in-Inverted-Triangle brand identity (`logo-e2-refined.svg`, `logo-e2-refined-512.png`, `app-icons-riepilogo.md`), three UI preview PNGs, and complete Xcode `AppIcon.appiconset` catalogs for macOS (`10` PNGs `16..1024 px` with outer alpha) and iOS (`8` opaque `#0B0614` PNGs across `9` slots `40..1024 px`). Because `reasoning/` is globally git-ignored, `TASK-01` promotes these deliverables into tracked `docs/design/` while verifying them deterministically with the Apple Swift 6.4 host toolchain before `Package.swift` is created in `TASK-02`.

## Goals / Non-Goals
- Goals:
  - Establish `docs/design/` as the single Git-tracked source of truth for color tokens (`[UI-001]`, `[UI-002]`, `[UI-004]`), UI mockups, and Concept E2 `AppIcon.appiconset` catalogs (`[AR-001]`).
  - Preserve `reasoning/001_project-constitution/deliverables/` untouched via canonical `cp` so reasoning validation (`scaffold_reasoning.py --validate`) stays green.
  - Rewrite all Markdown links in `docs/design/*.md` and root `README.md` to portable repository-relative paths free of workstation `file:///Users/...` URIs (`[SEC-003]`, `[SEC-005]`).
  - Provide a KISS-compliant, zero-dependency Swift 6 verifier (`Scripts/verify-design-assets.swift`) supporting `--root <dir>` and `--self-test` (`[TEST-007]`, `[SDD-002]`).
- Non-Goals:
  - Scaffolding `Package.swift`, `SwiftEditCore`, `SwiftEditUI`, or the Xcode `.xcodeproj` / `Assets.xcassets` app target (deferred to `TASK-02` and `TASK-10`).
  - Runtime SwiftUI theme rendering or TextKit 2 editor implementation.

## Constitutional Alignment & Module Boundaries (AR-### / UI-### / DATA-### / API-###)
- **AR-001**: Canonical brand icon catalogs (`docs/design/assets/app-icons/{macos,ios}/AppIcon.appiconset`) and design specifications reside in `docs/design/` outside `SwiftEditCore`, ready for direct consumption by the thin Xcode `.app` shell (`Assets.xcassets`) in `TASK-10` without polluting `SwiftEditCore` (`Foundation` + `Markdown` only).
- **Single-Reference Lock**: Loaded `openspec/Constitution.md` alongside `01-architecture/module-topology.md` (`AR-001..AR-005`), `03-ui-ux/design-system-and-tokens.md` (`UI-001..UI-004`), `06-testing-fitness/architecture-fitness-and-quality.md` (`TEST-005..TEST-008`), `07-security-privacy/authn-authz-and-boundaries.md` (`SEC-001..SEC-004`), and `08-sdd-governance/artifact-traceability.md` (`SDD-001..SDD-004`).

## Decisions
- **Decision 1 — Canonical Copy (`cp`) Over Destructive Move (`mv`)**:
  - *Rationale*: `reasoning/001_project-constitution/README.md` and `README.ai.md` reference `./deliverables/...` and are checked by `scaffold_reasoning.py --validate`. Copying into `docs/design/` keeps the git-ignored reasoning record reproducible while committing clean, relative-linked deliverables into Git (`[SDD-001]`).
  - *Alternatives Considered*: Moving files (`mv`) — rejected because it breaks `reasoning/001_project-constitution/` link integrity.
- **Decision 2 — Pure Swift 6 `Foundation` + `ImageIO` Verifier (`Scripts/verify-design-assets.swift`)**:
  - *Rationale*: Follows **KISS-First** (`Rule of Three`: single standalone CLI file with value-type `Sendable` structs `VerificationIssue`, `IconSlotSpec`, and `DesignAssetsVerifier`, zero class inheritance hierarchies, zero external packages `[AR-005]`). `ImageIO` (`CGImageSourceCopyPropertiesAtIndex`) reads PNG headers (`PixelWidth`, `PixelHeight`, `HasAlpha`) natively on macOS in milliseconds without launching `sips` subprocesses or importing `AppKit`.
  - *Alternatives Considered*: Shell + `sips` script — rejected because `Swift 6` `Codable` + `ImageIO` provides typed `Contents.json` parsing, cross-platform Apple SDK alignment, and built-in `--self-test` fixtures (`P1, P2, N1..N4`).
- **Decision 3 — Promoted Directory Layout**:
  ```text
  docs/design/
  ├── color-schemes-and-zed-layout.md
  └── assets/
      ├── app-icons-riepilogo.md
      ├── logo-e2-refined.svg
      ├── logo-e2-refined-512.png
      ├── preview-dark-black-purple.png
      ├── preview-light-purple.png
      ├── preview-file-compare-diff.png
      └── app-icons/
          ├── macos/AppIcon.appiconset/ (Contents.json + 10 PNGs, hasAlpha == true)
          └── ios/AppIcon.appiconset/   (Contents.json + 8 PNGs across 9 slots, hasAlpha == false)
  ```

## Risks / Trade-offs
- **Dual Copies Between Ignored `reasoning/` and Tracked `docs/design/`** -> Mitigated by declaring `docs/design/` as the sole normative reference for `TASK-02..TASK-11` and guarding its contents via `Scripts/verify-design-assets.swift`.
- **App Store Connect Rejection for Transparent iOS Icons (`ITMS-90717`)** -> Mitigated by `N4` `ImageIO` assertion enforcing `hasAlpha == false` across all 8 iOS PNGs (`[UI-001]`, `[TEST-007]`).

## Migration Plan
1. Scaffold `docs/design/assets/app-icons/{macos,ios}/` and `Scripts/` during `/myspec-apply`.
2. Execute `[RED] -> [GREEN] -> [REFACTOR] -> [DOC]` cycles for `DesignDocsPromotionAndLinkIntegrity` (`P1, N1, N2`) and `AppIconCatalogVerification` (`P2, N3, N4`).
3. Run `swift Scripts/verify-design-assets.swift --self-test` and `swift Scripts/verify-design-assets.swift --root .` to confirm exit code `0`, and verify `./.tmp/` is clean.

## Security Review
- Reviewer: cyber-security-expert
- Date: 2026-11-17
- Verdict: approved
- Status: approved
- Open items: none
