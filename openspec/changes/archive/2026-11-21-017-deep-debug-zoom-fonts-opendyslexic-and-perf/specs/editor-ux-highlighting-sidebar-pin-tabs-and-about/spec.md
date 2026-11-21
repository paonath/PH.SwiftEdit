# Spec Delta: editor-ux-highlighting-sidebar-pin-tabs-and-about

## Purpose
Extends proportional zoom scaling from left-sidebar typography to the full tab strip, navigator row metrics and gutter so the whole editing surface grows and shrinks together while appearance switching behavior stays unchanged.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-005 Live Light Dark Auto Selector Current-Line Highlighting and Sidebar Zoom Scaling
WHEN switching appearance modes, syncing unmasked system appearance, or adjusting zoom across `50%..300%`, the workbench and theme controller SHALL update `Light`, `Dark`, and `Auto` semantic palettes, synchronize `NSApp.appearance` and `TextKit2EditorView` styling without reloading buffers or poisoning `systemPrefersDark`, and scale editor typography, left sidebar rows, tab strip and gutter proportionally with `>= 24 pt` targets [UI-001][UI-002][UI-003][UI-004][UI-005].

Security-Waiver: additive only — proportional zoom extends to tabs, sidebar rows and gutter; appearance-sync scenarios including the tainted-colorScheme negative case (`N11`) are preserved unchanged.

#### Scenario: P12 Sidebar Rows Tabs and Gutter Follow Zoom Proportionally
- **Path**: P12
- **Trait**: positive
- **GIVEN** a workbench with an open folder, three tabs and zoom at `100%`
- **WHEN** zoom is set to `150%`
- **THEN** `ZoomedChromeMetrics` reports sidebar row height, icon size, indent, tab font, tab height and gutter width at `1.5x` their `100%` values, and the sidebar font equals `19.5 pt`

#### Scenario: N14 Fifty Percent Zoom Never Shrinks Targets Below 24 pt
- **Path**: N14
- **Trait**: negative
- **GIVEN** zoom at `50%`
- **WHEN** tab, tab close button and sidebar row metrics are computed
- **THEN** each clickable height is `>= 24 pt` while text sizes still scale to `0.5x`

## REMOVED Requirements

## RENAMED Requirements
