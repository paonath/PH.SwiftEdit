# Capability: log-tail-terminal-panel-lint-hover-and-help

## Purpose
Adds level-aware log highlighting with a non-blocking live tail (direct and inverse) and synchronous secondary occurrence highlighting across all log modes, a bottom embedded GPU-accelerated Terminal panel (`SwiftTerm` PTY) with sidebar external terminal handoff, English lint explanations on gutter hover, reliable navigator jumps, and an offline multi-chapter in-app Help viewer built from `docs/guide/` and `README.md`.

## Requirements

### Requirement: REQ-001 Always-On Level-Aware Log Highlighting
WHEN a `.log` tab is laid out, the `LogSyntaxHighlighter` SHALL return viewport-only spans for severity words (trace to critical), timestamps, GUIDs, quoted strings, exception names and stack frames using zero regex, skip lines over 4096 UTF-16 units, and render each class with palette tokens of at least 4.5:1 contrast [BC-004][UI-009][UI-012][SEC-012].

#### Scenario: P1 Common Logger Layouts Expose Level and Timestamp
- **Path**: P1
- **Trait**: positive
- **GIVEN** NLog, Serilog, log4net, JSON and syslog lines with ERROR, INF, WARN, debug and crit levels
- **WHEN** each line is tokenized
- **THEN** the level token and the timestamp token are reported for every layout

#### Scenario: N1 Prose Plurals and Overlong Lines Yield No Level
- **Path**: N1
- **Trait**: negative
- **GIVEN** prose with lowercase level words, the words ERRORS and INFORMATIONAL, and a 5000-unit ERROR line
- **WHEN** they are classified
- **THEN** no level token is produced and the overlong line yields no spans

### Requirement: REQ-002 Non-Blocking Live Log Tail With Direct and Inverse Order and Secondary Occurrence Highlighting
WHEN the user presses `Cmd+L` or `Shift+Cmd+L` on a file-backed tab, the workbench SHALL show a read-only selectable live tail of the last N lines (default 80, 1 to 10000) in direct or newest-first order, read appended bytes on a background queue without locking the file (`O_RDONLY | O_NONBLOCK | O_CLOEXEC` + `O_EVTONLY`), restart on truncation or rotation, highlight all secondary occurrences of any selected word or token across Plain, Direct, Inverse, and tail-only modes while preserving active user selection across live polls and order switches, and keep every other tab usable [UI-012][DATA-003][SEC-012].

#### Scenario: P2 Tail Follows Appends and Switches Order and Line Count
- **Path**: P2
- **Trait**: positive
- **GIVEN** an open `app.log` with 100 lines and another Markdown tab
- **WHEN** the direct tail starts, a writer appends an ERROR line, the order switches to inverse, the line count becomes 3 and the Markdown tab is edited
- **THEN** the tail shows 80 lines ending with the new line, inverse shows it first, three lines are shown and the other tab edit succeeds

#### Scenario: N2 Untitled Tabs Oversized Logs and Stopped Tails Are Guarded
- **Path**: N2
- **Trait**: security
- **GIVEN** an untitled tab, a 200 MB log above the open gate, and a stopped tail
- **WHEN** the tail is requested, the oversized log is opened and saved, and the file grows after stop
- **THEN** the untitled tab is refused, the oversized log opens tail-only with saving blocked, and no line written after stop appears

### Requirement: REQ-003 Bottom Embedded Terminal Panel (`SwiftTerm` PTY)
WHEN the user presses `Cmd+J`, the workbench SHALL toggle a resizable bottom panel hosting an embedded VT100/xterm-256color `SwiftTerm` PTY terminal in the current folder or user home (per Constitution `v1.6.0` `SEC-004`), support multiple terminal tabs with OSC 7 directory tracking, record launch or abnormal exit failures without crashing, and cleanly terminate child shell process groups on tab close or application exit [SEC-001][SEC-004].

#### Scenario: P3 Sessions Open in Home or Folder and Close With the Panel
- **Path**: P3
- **Trait**: positive
- **GIVEN** a workbench without a folder
- **WHEN** `Cmd+J` opens the panel, a folder is opened, a second session is added, the terminal app quits and `Cmd+J` is pressed again
- **THEN** sessions start in home then in the folder, both report the quit, and closing clears all sessions

#### Scenario: N3 Terminal Launch Failure Is Reported Without Crashing
- **Path**: N3
- **Trait**: security
- **GIVEN** a terminal that cannot be launched
- **WHEN** the panel opens and the user keeps editing
- **THEN** the session shows the failure message and editing continues

### Requirement: REQ-004 English Lint Explanation on Gutter Hover
WHEN the pointer hovers a gutter lint dot, the `SwiftEditUI` SHALL show the rule code, the diagnostic message and a one-sentence English explanation for every diagnostic of that line in a popover, tooltip and VoiceOver label [UI-009][UI-010].

#### Scenario: P4 Hover Text Lists Code Message and Explanation
- **Path**: P4
- **Trait**: positive
- **GIVEN** a Markdown tab with an unsafe `javascript:` link on line 3
- **WHEN** the gutter hover details are built
- **THEN** line 3 lists `unsafeLinkScheme`, its message and its explanation

#### Scenario: N4 Every Rule Is Explained and Clean Lines Have No Hover
- **Path**: N4
- **Trait**: negative
- **GIVEN** all lint rule identifiers and an empty diagnostic list
- **WHEN** explanations and hover details are built
- **THEN** every rule has an English explanation and the empty list produces no hover text

### Requirement: REQ-005 Reliable Navigator Jump With Scroll Into View
WHEN the user clicks anywhere on a navigator row, the workbench SHALL move the caret to that heading or key and scroll the editor up or down until the target line is visible, laying out only the target fragment when TextKit 2 estimation misses it and clamping stale offsets [UI-010][UI-012].

#### Scenario: P5 Far Targets Are Revealed Downward and Upward
- **Path**: P5
- **Trait**: positive
- **GIVEN** a 4000-line document scrolled to the top
- **WHEN** line 3500 and then line 50 are revealed
- **THEN** each target line intersects the visible rect and the caret sits on the last target

#### Scenario: N5 Out-of-Range Targets Are Clamped
- **Path**: N5
- **Trait**: negative
- **GIVEN** a 10-line document
- **WHEN** an offset beyond the end is revealed
- **THEN** the caret is clamped to the end without error

### Requirement: REQ-006 Offline In-App Help From Bundled User Guide and Repository README
WHEN the user chooses Help, SwiftEdit Help (`Shift+Cmd+?`), `SwiftEditUI` SHALL render the bundled multi-chapter English User Guide (`docs/guide/*.md`) and repository `README.md` offline with chapter navigation and the native Markdown preview, keeping bundled copies byte-identical to the repository documents [UI-001][SEC-004].

#### Scenario: P6 Bundled Help Matches the Repository README
- **Path**: P6
- **Trait**: positive
- **GIVEN** the bundled help README and the repository README
- **WHEN** the help document is projected
- **THEN** both files are identical, the quarantine command targets `SwiftEdit.app` and preview blocks are produced

#### Scenario: N6 Legacy App Name Never Appears
- **Path**: N6
- **Trait**: negative
- **GIVEN** the README lines that mention PH.SwiftEdit
- **WHEN** they are classified
- **THEN** only the repository path, the release archive name and the clone folder remain and `PH.SwiftEdit.app` is absent
