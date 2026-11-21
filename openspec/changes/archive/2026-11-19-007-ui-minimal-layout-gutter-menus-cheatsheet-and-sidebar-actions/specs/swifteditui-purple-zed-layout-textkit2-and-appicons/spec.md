# Spec Delta: SwiftEditUI Minimalist Layout Default-Collapsed Sidebar Right-Column Tabs and Left Line Gutter

## Purpose
Extends `REQ-001` of `swifteditui-purple-zed-layout-textkit2-and-appicons` to align with Constitution `v1.3.0` (`UI-001`): the left Folder Navigator sidebar starts collapsed by default until a folder is opened, `EditorTabStrip` sits strictly above the right-hand editor column, `LineNumberGutterView` renders 1-based line numbers to the left of the `#FFFFFF`/`#000000` canvas, and the status bar exposes live `Line`, `Column`, `Character count`, `UTF-8`, and `LF`/`CRLF`/`CR`.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-001 Concept E2 Purple Chrome Inverted B/W Canvas and 50..300 Percent Zoom
WHEN resolving theme tokens, layout state, or zoom commands across `Light`, `Black`, and `Auto` modes, the theme and zoom controller SHALL expose the Concept E2 Purple palette (`#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`), default the left sidebar to collapsed, place `EditorTabStrip` above the right editor column with a left 1-based `LineNumberGutterView`, invert the `#FFFFFF`/`#000000` canvas at `21:1` contrast, and scale zoom across `50%..300%` [UI-001][UI-002][UI-003][UI-004][UI-009].

Security-Waiver: additive modification only; existing scenarios P1 and N1 and all UI-001..004 and UI-009 citations are preserved intact while adding the Constitution v1.3.0 default-collapsed sidebar, right-column tab strip, and left 1-based line gutter verification.

#### Scenario: P1 Purple Chrome Tokens Default-Collapsed Sidebar Right-Column Tabs Line Gutter and Zoom Scaling
- **Path**: P1
- **Trait**: positive
- **GIVEN** `PurpleThemePalette` in `.light` and `.black` modes, an `EditorZoomController` at `100%` (`14 pt` base font), and a `LineNumberGutterProjection` on a 3-line document
- **WHEN** the palette resolves chrome and canvas tokens, `zoomIn` (`Cmd++`), `zoomOut` (`Cmd+-`), `resetZoom` (`Cmd+0`), and `togglePaneFocus` execute, and the gutter projection evaluates line numbers
- **THEN** `.light` resolves `#FFFFFF` canvas background and `#000000` text, `.black` resolves `#000000` canvas background and `#FFFFFF` text with `21.0` contrast ratio alongside Concept E2 `#0B0614`/`#7C3AED`/`#A78BFA`/`#C4B5FD` chrome tokens, the gutter projection lists `[1, 2, 3]`, and zoom scales font size cleanly without altering buffer text

#### Scenario: N1 Zoom Commands and Empty Gutter Projection Clamp Safely at Boundaries
- **Path**: N1
- **Trait**: negative
- **GIVEN** an `EditorZoomController` initialized at `50%` or `300%` and an empty buffer `""`
- **WHEN** `zoomOut()` is called at `50%`, `zoomIn()` is called at `300%`, and `LineNumberGutterProjection.evaluate(text:caretLocation:)` evaluates `""`
- **THEN** `zoomPercent` remains clamped at `50` and `300` respectively and the gutter projection returns `[1]`

## REMOVED Requirements

## RENAMED Requirements
