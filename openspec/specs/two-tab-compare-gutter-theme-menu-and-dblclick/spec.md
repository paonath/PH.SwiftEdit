# Capability: two-tab-compare-gutter-theme-menu-and-dblclick

## Purpose
Turns File Compare into a two-tab comparison with a removable destination, gives the editor gutter a grey surface with slightly smaller zoom-scaled numbers, adds Light/Dark/Auto to the SwiftEdit menu, dismisses the contextual palette on outside clicks, and adds a repeated double-click cycle from word to token to no selection.

## Requirements

### Requirement: REQ-001 Two-Tab Compare With Removable Destination
WHEN File Compare opens, the tab it is opened from SHALL be the source; the Compare header SHALL let the user pick another open non-binary tab as destination and compare source against it, and its X SHALL drop only the destination (the tab stays open) and return to comparing the source saved version against its current buffer, which is also the behaviour without a destination or after the destination tab closes [UI-007][BC-006].

#### Scenario: P1 Source Versus Destination and Back to Saved Versus Current
- **Path**: P1
- **Trait**: positive
- **GIVEN** two open file tabs a.md and b.md with a.md active
- **WHEN** Compare opens, b.md is picked as destination, then the X is pressed
- **THEN** rows compare a.md with b.md while b.md stays open, then compare a.md saved with current

#### Scenario: N1 Invalid or Closed Destinations Are Dropped
- **Path**: N1
- **Trait**: negative
- **GIVEN** an open Compare with a destination
- **WHEN** the source is offered as its own destination or the destination tab is closed
- **THEN** the destination is rejected or cleared and the source is kept

### Requirement: REQ-002 Grey Gutter With Smaller Zoom-Scaled Numbers
The editor line-number gutter SHALL use a grey surface distinct from the canvas and render numbers at 85% of the zoomed editor font size, baseline-aligned with the text, keeping at least 4.5:1 contrast in Light and Black modes [UI-002][UI-004][UI-009].

#### Scenario: P2 Gutter Surface and Number Scale
- **Path**: P2
- **Trait**: positive
- **GIVEN** Light and Black palettes
- **WHEN** the gutter tokens are audited
- **THEN** the surface differs from the canvas, numbers use the 0.85 scale and contrast is at least 4.5:1

### Requirement: REQ-003 Appearance Modes in the SwiftEdit Menu
The SwiftEdit command menu SHALL list Light, Dark and Auto with a check on the active mode and switch the appearance when one is chosen, while the status-bar toggle remains [UI-003].

#### Scenario: P3 Menu Switches Appearance
- **Path**: P3
- **Trait**: positive
- **GIVEN** the SwiftEdit menu with Dark active
- **WHEN** Auto and then Dark are chosen
- **THEN** only the active mode is checked and the appearance follows each choice

### Requirement: REQ-004 Outside Click Dismisses the Contextual Palette
WHEN the contextual palette is open and the user clicks anywhere outside it, including the document being edited, the palette SHALL close exactly like Escape, restoring the original selection without editing [UI-010].

#### Scenario: P4 Outside Click Behaves Like Escape
- **Path**: P4
- **Trait**: positive
- **GIVEN** an open contextual palette
- **WHEN** the user clicks outside it
- **THEN** the palette closes and the selection and text are unchanged

### Requirement: REQ-005 Repeated Double-Click Selection Cycle
WHEN the user double-clicks the current selection again, the editor SHALL extend a selected word to its whitespace-free token with wrapping brackets, quotes and trailing punctuation trimmed, and SHALL clear the selection when the token is already selected or equals the word [UI-010].

#### Scenario: P5 Word Then Token Then Nothing
- **Path**: P5
- **Trait**: positive
- **GIVEN** the text see (contextual-menu). now with contextual selected by double-click
- **WHEN** the user double-clicks it twice more
- **THEN** contextual-menu is selected and then the selection is cleared

#### Scenario: N5 Other Selections Keep the System Word Selection
- **Path**: N5
- **Trait**: negative
- **GIVEN** a previous selection unrelated to the clicked word or an empty word
- **WHEN** the user double-clicks
- **THEN** the standard word selection is applied
