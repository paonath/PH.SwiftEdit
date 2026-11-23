# Capability: integrations-autocomplete-contextual-menu-and-redesign-plan

## Purpose
Adds in-memory ghost-text word completion, a collapsed-by-default YAML Properties panel, a Shift+Cmd+D File Compare shortcut, the extensible Cmd+Return ElementContextualMenu, literal occurrence highlighting, an offscreen visual audit harness, and the Zed-neutral redesign with the in-code AppIcon line set while keeping the Concept E2 logo unchanged.

## Requirements

### Requirement: REQ-001 In-Memory Ghost-Text Word Completion
WHEN the user types a character that ends a word prefix of at least 2 UTF-16 units, the `SwiftEditUI` editor SHALL show the grey remainder of the most frequent document word longer than 3 units starting with that case-sensitive prefix, insert it as one undoable edit on `Tab`, dismiss it on `Esc`, any other key or caret move, keep the existing `Tab` behaviour when no suggestion is visible, and build the per-document `WordCompletionIndex` off the main actor without persisting it [UI-006][UI-012][SEC-012].

#### Scenario: P1 Frequent Document Word Is Suggested and Accepted With Tab
- **Path**: P1
- **Trait**: positive
- **GIVEN** a document containing SwiftEdit three times and swiftly once
- **WHEN** the user types Swi and presses Tab
- **THEN** ftEdit is shown as ghost text and inserted as one edit

#### Scenario: N1 Short Prefixes Excluded Words and Binary Tabs Yield No Suggestion
- **Path**: N1
- **Trait**: negative
- **GIVEN** a one-character prefix, a caret inside a word, the word being typed, and a binary read-only tab
- **WHEN** a completion is requested
- **THEN** no suggestion is shown and Tab falls through to list, table or default handling

### Requirement: REQ-002 Collapsed Properties Panel and File Compare Shortcut
The `SwiftEditUI` workbench SHALL open the YAML frontmatter Properties panel collapsed, omit File Compare from the header quick menu, and toggle File Compare with `Shift+Cmd+D` from the View menu, the shortcut dispatcher and the CheatSheet [UI-001][UI-009].

#### Scenario: P2 Compare Toggles via Shift Cmd D and Properties Start Collapsed
- **Path**: P2
- **Trait**: positive
- **GIVEN** a fresh workbench with a Markdown tab
- **WHEN** Shift+Cmd+D is pressed
- **THEN** the diff pane is shown, the header items contain no Compare entry, and the Properties panel state is collapsed

### Requirement: REQ-003 Extensible ElementContextualMenu on Cmd+Return
WHEN the user presses `Cmd+Return` with a non-empty selection in a writable tab, the `SwiftEditUI` workbench SHALL open a keyboard-navigable palette anchored under the selection listing `ElementContextualActionCatalog` groups and actions, apply the chosen action to the captured selection as exactly one `BufferRevision` keeping the inner text selected, and leave `Cmd+Return` unconsumed without a selection [BC-006][UI-010][DATA-003][SEC-012].

#### Scenario: P3 Surround With Backticks Fence and Parentheses
- **Path**: P3
- **Trait**: positive
- **GIVEN** the word it selected in make it bold
- **WHEN** Cmd+Return opens the palette and Return runs Backticks
- **THEN** the text becomes make `it` bold in one revision with it still selected, and the fence variant places fences on their own lines

#### Scenario: N3 No Selection Binary and Out-of-Bounds Selections Are Refused
- **Path**: N3
- **Trait**: security
- **GIVEN** an empty selection, a binary read-only snapshot and an out-of-bounds range
- **WHEN** the palette or a surround action is requested
- **THEN** the key is not consumed, no edit is produced and Escape restores the original selection

### Requirement: REQ-004 Literal Character-Group Occurrence Highlighting
WHEN the selection is a single-line, non-blank group of 2 to 128 UTF-16 units, the `WordOccurrenceScanner` SHALL return whole-word matches for whole words and case-sensitive literal matches for any other group, excluding ranges overlapping the selection and capping results at 1000 [UI-007][SEC-012].

#### Scenario: P4 Partial Words and Symbols Highlight Literal Matches
- **Path**: P4
- **Trait**: positive
- **GIVEN** the text a ab abc ab cd AB x->y z->w
- **WHEN** ab inside abc or the first arrow is selected
- **THEN** the other lowercase ab ranges or the second arrow are returned and uppercase AB is not

#### Scenario: N4 Whitespace Multi-Line and Single Characters Highlight Nothing
- **Path**: N4
- **Trait**: negative
- **GIVEN** a single character, a whitespace-only selection and a selection spanning a line break
- **WHEN** occurrences are scanned
- **THEN** no ranges are returned

### Requirement: REQ-005 Offscreen Visual Audit Harness and Redesign Plan
WHERE `SWIFTEDIT_VISUAL_AUDIT_DIR` is set, the test suite SHALL render the workbench offscreen in Light and Black modes for the base, occurrence, preview and properties, header menu, sidebar and contextual menu states and write PNG snapshots, which back the Zed-inspired redesign plan in `docs/design/redesign-020` [TEST-005][UI-001].

#### Scenario: P5 Twelve Snapshots Are Produced When Enabled
- **Path**: P5
- **Trait**: positive
- **GIVEN** the environment variable pointing to an output directory
- **WHEN** VisualAuditSnapshotTests runs
- **THEN** light and dark PNGs for six states are written

### Requirement: REQ-006 Zed-Neutral Chrome and AppIcon Line Set
The `SwiftEditUI` shell SHALL render header and status bar on one neutral chrome surface, reserve Purple accents for caret, focus, active tab and active toggles, draw every icon with the in-code `AppIcon` line set instead of SF Symbols, keep the Concept E2 logo unchanged, show a folder and file breadcrumb with a right icon cluster, flat tabs, a gutter with a separate diagnostics column, a plain-text lint label with one status-bar icon, and keep every paired foreground at WCAG AA [UI-001][UI-002][UI-009][UI-010].

#### Scenario: P6 Neutral Chrome Icon Set and Gutter Column Hold
- **Path**: P6
- **Trait**: positive
- **GIVEN** Light and Black palettes and the SwiftEditUI sources
- **WHEN** palettes, icons and gutter metrics are audited
- **THEN** status bar equals header surface, accents stay purple, every AppIcon has grid geometry, and the gutter reserves the diagnostics column

#### Scenario: N6 No SF Symbols and No Duplicate Lint Glyph
- **Path**: N6
- **Trait**: negative
- **GIVEN** every SwiftEditUI source file and the active lint status
- **WHEN** they are scanned
- **THEN** no Image systemName, systemImage or systemSymbolName remains and the lint label contains no warning or check glyph

#### Scenario: P7 Visual Audit Covers Every Surface in Both Modes
- **Path**: P7
- **Trait**: positive
- **GIVEN** `SWIFTEDIT_VISUAL_AUDIT_DIR` pointing to an output directory
- **WHEN** VisualAuditSnapshotTests runs
- **THEN** light and dark PNGs for thirteen states including find and compare, navigator, CheatSheet, About, diagnostics, Help and the icon sheet are written
