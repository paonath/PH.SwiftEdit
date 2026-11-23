# Capability: send-to-terminal-contextual-action

## Purpose
Adds a selection-scoped "Send to Terminal" contextual action in both the `Cmd+Return` contextual palette and the editor/log-viewer right-click menu that opens the embedded terminal panel if closed, writes the sanitized selection into the active PTY without pressing Return, moves focus to the terminal, and prompts for confirmation with Bracketed Paste framing when the selection spans multiple lines.

## Requirements

### Requirement: REQ-024-01 Selection-Scoped Send to Terminal Without Auto-Execution
WHEN the user selects non-empty text and invokes "Send to Terminal" from the `Cmd+Return` contextual palette or the editor/log-viewer right-click menu, `SwiftEditCore` and `SwiftEditUI` SHALL sanitize the selection via `TerminalSelectionPayload.prepare` (stripping trailing `\r`/`\n`, normalizing line endings to `\n`, stripping `ESC`/`0x1B` and unsafe C0/DEL control bytes, and capping at `64 KiB`), open the embedded terminal panel (`Cmd+J`) and create a session if needed, queue the payload until PTY readiness, deliver it without appending Return, and move window first-responder focus to the embedded terminal [BC-006][UI-010][UI-012][SEC-004][SEC-012].

#### Scenario: P1 Single-Line Selection Opens Closed Terminal and Delivers Without Return
- **Path**: P1
- **Trait**: positive
- **GIVEN** a document tab with `"git status\n"` selected and the embedded terminal panel closed
- **WHEN** the user triggers "Send to Terminal" via `Cmd+Return` or right-click
- **THEN** the terminal panel opens, a session starts, and `"git status"` (with no trailing line break) is written to the PTY with keyboard focus on the terminal

#### Scenario: N1 Binary, Empty, Surrogate-Split, Escape-Injected, and >64 KiB Selections Are Guarded
- **Path**: N1
- **Trait**: security
- **GIVEN** empty, newline-only, binary read-only, UTF-16 surrogate-split, `ESC`-injected, or `> 64 KiB` selections
- **WHEN** `TerminalSelectionPayload.prepare` evaluates them
- **THEN** invalid selections return `nil` and valid selections have all `ESC` (`0x1B`) and unsafe C0 bytes stripped

### Requirement: REQ-024-02 Multiline Confirmation Warning and Bracketed Paste Framing
WHEN the sanitized selection spans more than one line (`lineCount > 1`), the workbench SHALL NOT open or write to the terminal immediately; instead it SHALL present a confirmation alert warning that multiline text may execute intermediate lines in a shell, abort cleanly on Cancel, and deliver the payload wrapped in ANSI Bracketed Paste (`ESC[200~ ... ESC[201~`) without a trailing Return on Confirm [SEC-004][SEC-012][UI-010].

#### Scenario: P2 Multiline Selection Prompts Before Delivery
- **Path**: P2
- **Trait**: security
- **GIVEN** a 3-line selection in an editor tab and the terminal panel closed
- **WHEN** the user invokes "Send to Terminal", cancels once, then invokes again and confirms
- **THEN** Cancel leaves the terminal closed with zero bytes delivered, and Confirm opens the terminal and writes the sanitized 3-line payload in Bracketed Paste framing with no trailing newline
