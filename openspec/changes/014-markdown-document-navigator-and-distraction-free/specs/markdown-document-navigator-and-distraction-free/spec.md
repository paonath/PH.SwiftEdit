# Spec Delta: Markdown Document Navigator and Distraction-Free Mode

## Purpose
Provides an Alfred-style heading navigator for the active Markdown tab and a full-screen distraction-free writing mode, both keyboard driven.

## ADDED Requirements

### Requirement: REQ-001 Heading Outline Parsing
[UI-005][BC-004] The system SHALL extract every ATX heading from `#` to `######` of the active document on the fly, excluding fenced code blocks and YAML frontmatter, and return level, title and UTF-16 offset in document order, capped at 5000 headings.

#### Scenario: P1 Headings H1 to H6 extracted
- **Path**: P1
- **Trait**: positive
- **GIVEN** a document containing `# A`, `## B` and `###### F`
- **WHEN** the outline is computed
- **THEN** it returns levels 1, 2 and 6 with titles `A`, `B`, `F` and their line-start offsets

#### Scenario: N1 Non-headings ignored
- **Path**: N1
- **Trait**: negative
- **GIVEN** `# x` inside a fenced block, `#tag`, `####### seven` and a 4-space indented `# code`
- **WHEN** the outline is computed
- **THEN** none of them appears in the outline

#### Scenario: N2 Heading flood capped
- **Path**: N2
- **Trait**: negative
- **Trait**: security
- **GIVEN** a document with 100000 heading lines
- **WHEN** the outline is computed
- **THEN** exactly 5000 headings are returned without unbounded work

### Requirement: REQ-002 Navigator Presentation and Keyboard Selection
[UI-009] While the navigator is open, the system SHALL show a centered palette listing all headings with a grey disabled `H<level>` badge instead of `#`, indentation and font size decreasing with level, and SHALL move the selection with the up and down arrow keys, wrapping at both ends.

#### Scenario: P1 Indented list with badges
- **Path**: P1
- **Trait**: positive
- **GIVEN** an outline with H1 and H2 headings
- **WHEN** the navigator is shown
- **THEN** the H2 row is indented further and smaller than the H1 row and each row shows `H1` or `H2` without `#`

#### Scenario: P2 Wrap-around selection
- **Path**: P2
- **Trait**: positive
- **GIVEN** the last row is selected
- **WHEN** the user presses the down arrow
- **THEN** the first row becomes selected

#### Scenario: N1 Empty or unmatched outline
- **Path**: N1
- **Trait**: negative
- **GIVEN** a document without headings or a query matching nothing
- **WHEN** the user presses Return
- **THEN** no jump occurs and the document is unchanged

### Requirement: REQ-003 Jump to Heading
[UI-002] When the user confirms a row with Return or click, the system SHALL place the editor caret at the start of that heading line, scroll it into view, close the navigator and return focus to the editor.

#### Scenario: P1 Click jumps and closes
- **Path**: P1
- **Trait**: positive
- **GIVEN** the navigator is open on a document with three headings
- **WHEN** the user clicks the second heading
- **THEN** the caret sits at the start of that heading line and the navigator is closed

#### Scenario: N1 Stale offset clamped
- **Path**: N1
- **Trait**: negative
- **Trait**: security
- **GIVEN** the document became shorter than a heading offset
- **WHEN** the row is confirmed
- **THEN** the caret is clamped to the document length and no error occurs

### Requirement: REQ-004 Navigator Activation Scope
[UI-009][SEC-012] When the user presses Option+Backslash on a non-binary Markdown tab, the system SHALL toggle the navigator for that tab only; ESC or a second Option+Backslash SHALL close it, and the key combination SHALL NOT insert any text.

#### Scenario: P1 Toggle open and close
- **Path**: P1
- **Trait**: positive
- **GIVEN** a Markdown tab is active
- **WHEN** the user presses Option+Backslash, then ESC
- **THEN** the navigator opens and then closes with the text unchanged

#### Scenario: N1 Non-markdown or binary tab
- **Path**: N1
- **Trait**: negative
- **GIVEN** the active tab is not Markdown or is a binary read-only tab
- **WHEN** the user presses Option+Backslash
- **THEN** the navigator does not open

### Requirement: REQ-005 Distraction-Free Mode
[UI-002][UI-012] When the user presses Option+1, the system SHALL show only the current tab editor edge to edge in native full screen with no header, sidebar, tabs, gutter, status bar or borders, and ESC or a second Option+1 SHALL restore the previous layout and window state.

#### Scenario: P1 Enter and exit
- **Path**: P1
- **Trait**: positive
- **GIVEN** a normal window with sidebar and tabs visible
- **WHEN** the user presses Option+1 and later ESC
- **THEN** all chrome is hidden in full screen and then fully restored

#### Scenario: P2 Previously full-screen window
- **Path**: P2
- **Trait**: positive
- **GIVEN** the window was already in full screen
- **WHEN** the user enters and exits distraction-free
- **THEN** the window remains in full screen after exit

#### Scenario: N1 System exit resyncs state
- **Path**: N1
- **Trait**: negative
- **GIVEN** distraction-free is active
- **WHEN** the user leaves full screen with the system control
- **THEN** the mode flag is cleared and chrome is restored

#### Scenario: N2 Safety banners preserved
- **Path**: N2
- **Trait**: negative
- **Trait**: security
- **GIVEN** a binary read-only tab in distraction-free mode
- **WHEN** the user types
- **THEN** the buffer stays read-only and unchanged
