# Spec Delta: swifteditui-purple-zed-layout-textkit2-and-appicons

## Purpose
Updates `REQ-001` and `REQ-002` of `swifteditui-purple-zed-layout-textkit2-and-appicons` so `PurpleThemePalette` replaces `public let brandGround` with contrast-verified role-specific semantic Light and Black tokens across all chrome, gutter, tab, sheet, and security-warning surfaces while preserving `21:1` `#FFFFFF`/`#000000` editor contrast and all binary quarantine and Trojan Source BiDi controls.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Concept E2 Purple Chrome Inverted B/W Canvas and 50..300 Percent Zoom
WHEN resolving theme tokens, layout state, or zoom commands across `Light`, `Black`, and `Auto` modes, the theme and zoom controller SHALL expose role-specific Concept E2 Purple surface, foreground, accent, gutter, tab, sheet, highlight, and disabled-binary tokens without `brandGround`, invert the `#FFFFFF`/`#000000` canvas at `21:1` contrast, sync `.auto` to unmasked OS appearance, and scale editor and sidebar zoom across `50%..300%` [UI-001][UI-002][UI-003][UI-004][UI-009].

Security-Waiver: replaces public brandGround on PurpleThemePalette with exhaustive role-specific Light/Black semantic tokens to remediate CWE-451 1.10:1 Light-mode dark-ground camouflage while preserving Concept E2 #0B0614/#7C3AED/#A78BFA/#C4B5FD brand anchors in SwiftEditBrandLogoGeometry and .black chrome, 21:1 #FFFFFF/#000000 canvas, and all existing P1, N1, P4, and N7 scenarios.

#### Scenario: P6 Role-Specific Semantic Chrome Tokens Eliminate Light-Mode Dark-Ground Leakage
- **Path**: P6
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** `topBarSurface`, `sheetSurface`, `sidebarSurface`, `tabBarSurface`, `gutterSurface`, `statusBarSurface`, `secondaryForeground`, and `nestedBracketPalette` are inspected
- **THEN** `.light` resolves `#F3E8FF`, `#F3E8FF`, `#EDE0FF`, `#E9D5FF`, `#F5F3FF`, `#7C3AED`, and `#5B21B6` with every `.light` nested bracket color achieving at least `4.5:1` contrast on `#FFFFFF`, while `.black` resolves `#0B0614`, `#0B0614`, `#140A24`, `#180C2C`, `#0B0614`, `#2E1065`, and `#C4B5FD`

#### Scenario: N9 Unbalanced Bracket Pill Satisfies WCAG 2.2 AA Contrast in Both Modes
- **Path**: N9
- **Trait**: negative
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** `unbalancedBracketHighlight` is compared against `unbalancedBracketBackground`
- **THEN** `contrastRatio` is at least `4.5` in both `.light` (`#991B1B` on `#FEE2E2`) and `.black` (`#FCA5A5` on `#450A0A`)

### Requirement: REQ-002 Binary Read-Only Lockout BiDi Trojan Source Badges and URI Gate
IF a document snapshot is binary read-only, contains Unicode BiDi control characters, or triggers an external URI handoff, THEN `InspectionSafetyBannerState` and `PurpleThemePalette` SHALL disable mutating commands on binary buffers, emit BiDi, Binary Quarantine, and Inert HTML `RGBAColorToken` triples at `>= 4.5:1` text and `>= 3.0:1` border contrast across `.light` and `.black`, and require confirmation on allowlisted `https`/`http`/`mailto` URIs [DATA-003][SEC-004][SEC-012][UI-008][UI-009].

Security-Waiver: strictly strengthens REQ-002 additively by enforcing deterministic >= 4.5:1 text and >= 3.0:1 border RGBAColorToken triples on BiDi Trojan Source, Binary Quarantine, and Inert HTML warnings across Light and Black modes while keeping existing scenarios P1 and N2 intact.

#### Scenario: N10 Security Banner Foreground and Border Tokens Pass Contrast Thresholds in Light and Black Modes
- **Path**: N10
- **Trait**: security
- **GIVEN** `PurpleThemePalette` resolved in `.light` and `.black` modes
- **WHEN** BiDi warning, Binary Quarantine warning, and Inert Raw HTML foreground, background, and border tokens are evaluated
- **THEN** each foreground-to-background ratio is at least `4.5` and each border-to-`chromeSurface` ratio is at least `3.0`

## REMOVED Requirements

## RENAMED Requirements
