# Spec Delta: swifteditui-purple-zed-layout-textkit2-and-appicons

## Purpose
Extends the Purple chrome and zoom contract so zoom also scales the tab strip, left navigator and gutter width, and the editor canvas keeps its inverted `#FFFFFF`/`#000000` colors with a user-selectable font instead of a mandatory monospaced face.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Concept E2 Purple Chrome Inverted B/W Canvas and 50..300 Percent Zoom
WHEN resolving theme tokens, layout state, or zoom commands across `Light`, `Black`, and `Auto` modes, the theme and zoom controller SHALL expose role-specific Concept E2 Purple tokens without `brandGround`, invert the `#FFFFFF`/`#000000` canvas at `21:1` contrast in the user-selected editor font (monospaced by default), sync `.auto` to unmasked OS appearance, and scale editor, tab strip, left navigator and gutter across `50%..300%` [UI-001][UI-002][UI-003][UI-004][UI-009].

Security-Waiver: additive only — zoom scope grows to tab strip, navigator and gutter and the editor font becomes selectable; every existing scenario (canvas `21:1`, binary-disabled tokens, `brandGround` exclusion, zoom clamps) is preserved unchanged and no security token or guard is relaxed.

#### Scenario: P7 Zoom Scales Tab Strip Navigator and Gutter With the Editor
- **Path**: P7
- **Trait**: positive
- **GIVEN** an `EditorZoomController` at `100%` and the derived `ZoomedChromeMetrics`
- **WHEN** `zoomIn()` runs ten times to reach `200%`
- **THEN** the editor font, tab font, tab height, navigator row height and gutter width are each exactly twice their `100%` values

#### Scenario: N11 Non-Monospaced Editor Font Keeps 21 to 1 Canvas Contrast
- **Path**: N11
- **Trait**: negative
- **GIVEN** the editor font set to `OpenDyslexic` in `Light` and `Black` modes
- **WHEN** canvas tokens resolve
- **THEN** canvas text and background keep `21.0` contrast and the zoom clamps remain `50%` and `300%`

## REMOVED Requirements

## RENAMED Requirements
