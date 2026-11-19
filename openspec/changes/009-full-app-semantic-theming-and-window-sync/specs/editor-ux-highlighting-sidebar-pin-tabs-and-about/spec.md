# Spec Delta: editor-ux-highlighting-sidebar-pin-tabs-and-about

## Purpose
Extends `REQ-005` of `editor-ux-highlighting-sidebar-pin-tabs-and-about` additively to synchronize `NSApp.appearance` and `TextKit2EditorView` selection, caret, and scroller appearance across `Light`, `Dark`, and `Auto` switches using an unmasked macOS interface style detector that prevents `.auto` feedback loops and cold-start flashes.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-005 Live Light Dark Auto Selector Current-Line Highlighting and Sidebar Zoom Scaling
WHEN switching appearance modes, syncing unmasked system appearance, or adjusting zoom across `50%..300%`, the workbench and theme controller SHALL update `Light`, `Dark`, and `Auto` semantic palettes, synchronize `NSApp.appearance` and `TextKit2EditorView` selection, caret, and scroller styling without reloading buffers or poisoning `systemPrefersDark`, and scale editor and left sidebar typography proportionally [UI-001][UI-002][UI-003][UI-004][UI-005].

Security-Waiver: additive modification only; existing scenarios P5 and N7 remain intact while adding MacOSAppearanceSynchronizer, unmasked systemDarkDetector, and live TextKit2EditorView scroller/selection synchronization.

#### Scenario: P8 Unmasked System Appearance Detector Restores Light Mode After Forced Black Override
- **Path**: P8
- **Trait**: positive
- **GIVEN** a `SwiftEditWorkbenchModel` initialized with `systemDarkDetector: { false }` in `.auto` mode
- **WHEN** `appearanceMode` switches `.auto -> .black`, a forced dark container `colorScheme` signal arrives, and `appearanceMode` switches back to `.auto`
- **THEN** initial Frame 0 mode is `.light`, `.black` resolves `.black`, and returning to `.auto` restores `.light` immediately

#### Scenario: N11 Forced Light or Black Mode Ignores Tainted Container ColorScheme Signals
- **Path**: N11
- **Trait**: negative
- **GIVEN** `SwiftEditWorkbenchModel` initialized with `systemDarkDetector: { true }` and switched explicitly to `.light`
- **WHEN** SwiftUI emits a light container `colorScheme` change (`prefersDark: false`) while `appearanceMode == .light` and the user then switches to `.auto`
- **THEN** `systemPrefersDark` remains `true` and `.auto` resolves `.black`

## REMOVED Requirements

## RENAMED Requirements
