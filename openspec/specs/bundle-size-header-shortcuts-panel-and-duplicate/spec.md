# Capability: bundle-size-header-shortcuts-panel-and-duplicate

## Purpose
Shrinks the Debug and Release app bundles, places the header command icons next to the SwiftEdit menu with the document title on the right, scales header and SwiftEdit menu with the editor zoom, turns the keyboard shortcuts reference into a searchable, clickable list available as floating sheet and right side panel, and opens the contextual palette without a selection with a new Duplicate Document action.

## Requirements

### Requirement: REQ-001 Compact Debug and Release Bundles
The Xcode Debug and Release configurations SHALL dead-strip code and move symbols into a separate dSYM outside the app bundle so the staged Debug app stays debuggable from its dSYM while its executable carries no symbol tables, and the staging script SHALL keep the dSYM next to the staged app [AR-001][TEST-007].

#### Scenario: P1 Debug Bundle Carries No Symbol Tables
- **Path**: P1
- **Trait**: positive
- **GIVEN** a Debug build staged by build-app.sh
- **WHEN** the executable segments are measured
- **THEN** the symbol segment is under 2 MB and a dSYM exists beside the app

### Requirement: REQ-002 Header Icons Beside the SwiftEdit Menu
The `SwiftEditUI` header SHALL place the command icon cluster immediately after the unchanged SwiftEdit logo menu and the folder and file breadcrumb at the right edge [UI-001].

#### Scenario: P2 Header Order Is Menu Icons Spacer Title
- **Path**: P2
- **Trait**: positive
- **GIVEN** the header source
- **WHEN** its elements are ordered
- **THEN** the logo menu precedes the icons, which precede the spacer and the breadcrumb

### Requirement: REQ-003 Zoom-Scaled Header and SwiftEdit Menu
WHEN the editor zoom changes between 50% and 300%, the header height, logo, icons, fonts and the SwiftEdit command menu SHALL scale by the same factor as the editor text while clickable targets keep the 24 pt minimum [UI-004][UI-009].

#### Scenario: P3 Header Metrics Double at 200% and Keep the Floor at 50%
- **Path**: P3
- **Trait**: positive
- **GIVEN** chrome metrics at 50%, 100% and 200%
- **WHEN** header and menu sizes are compared
- **THEN** 200% doubles them and 50% shrinks icons while targets stay at least 24 pt

### Requirement: REQ-004 Searchable Clickable Shortcuts Sheet and Side Panel
The workbench SHALL offer the shortcuts reference as the floating `Cmd+/` sheet and as a right side panel toggled by `Option+Cmd+/` or the header keyboard icon, both with a top search over function, description and shortcut that highlights matching rows, and SHALL run a clicked or Return-confirmed row on the editor caret or workbench while documentation-only rows stay inert [UI-009][UI-010].

#### Scenario: P4 Search Matches Symbols and Words and Rows Run Commands
- **Path**: P4
- **Trait**: positive
- **GIVEN** the shortcuts catalog and a workbench with text
- **WHEN** the user searches for the compare shortcut in symbol and word form and clicks Zoom In, New Document and Toggle File Compare
- **THEN** both searches find the row, zoom grows, a tab opens and the diff pane shows

#### Scenario: N4 Documentation-Only Rows and Unknown Queries Do Nothing
- **Path**: N4
- **Trait**: negative
- **GIVEN** the Accept Word Completion and Reorder Tabs rows and a query with no match
- **WHEN** they are inspected
- **THEN** the rows have no command and the result list is empty

### Requirement: REQ-005 Contextual Palette Without Selection and Duplicate Document
WHEN `Cmd+Return` is pressed in a writable tab without a selection, the palette SHALL open with selection-free groups only, and the Duplicate Document action SHALL write the current buffer to a never-overwriting `name copy.ext` sibling through the confined atomic save and open it right after the source tab, or create an in-memory untitled copy when the source has no file, refusing binary, binary-inspection and live-tail tabs [DATA-001][DATA-003][SEC-012].

#### Scenario: P5 File and Memory Documents Are Duplicated Next to Their Tab
- **Path**: P5
- **Trait**: positive
- **GIVEN** a file-backed tab with unsaved edits and an untitled tab
- **WHEN** Duplicate Document runs on each
- **THEN** a copy file with the edited text opens right after the source and the untitled copy stays in memory

#### Scenario: N5 Existing Copies Are Never Overwritten and Binary Is Refused
- **Path**: N5
- **Trait**: security
- **GIVEN** an existing name copy file and a binary inspection
- **WHEN** Duplicate Document runs
- **THEN** the existing copy keeps its content, a numbered copy is created, and the binary case is refused
