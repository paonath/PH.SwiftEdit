# Brief: Send to Terminal Contextual Action

- Branch: feature/contaxtual_actions
- Phase: implemented
- Date: 2026-11-23
- Security Review: approved

## Disambiguated Prompt

Add a contextual action **"Send to Terminal"** active whenever non-empty text is selected in an editor or log viewer tab:
- Available both in the `Cmd+Return` contextual palette (`ElementContextualActionCatalog.terminalGroup`) and in the right-click context menu (`SwiftEditNSTextView.menu(for:)`).
- Opens the embedded terminal panel (`Cmd+J`) if closed, creates an active `SwiftTerm` session if none exists, queues the payload until PTY readiness, writes the sanitized selection **without** pressing Return (all trailing `\r`/`\n` stripped), and moves keyboard focus to the embedded terminal.
- Shows an explicit multiline confirmation alert (`Send to Terminal` / `Cancel`) when the selection spans more than 1 line, and frames multiline PTY payloads with ANSI Bracketed Paste (`ESC[200~ ... ESC[201~`) after stripping C0 control / `ESC` (`0x1B`) bytes (`CWE-78`, `CWE-150`, `CWE-400`).

## `/qa` Decision Log

| # | Question | Decision |
| :--- | :--- | :--- |
| 1 | Multiline warning & safety (`Rule G3` / `CWE-78`) | Confirmation alert (`Send to Terminal` / `Cancel`) + Bracketed Paste (`ESC[200~ ... ESC[201~`) with trailing line breaks stripped |
| 2 | Post-send focus & UI entry points | Move focus to embedded terminal; expose in both `Cmd+Return` palette and right-click context menu on selection |

## 6-Category STRIDE Security Check

| Threat | Mitigation |
| :--- | :--- |
| **Spoofing** | Only local user-initiated selection actions on active SwiftEdit views can enqueue PTY payloads; no external IPC. |
| **Tampering** | `TerminalSelectionPayload.prepare` strips all C0 control characters (`< 0x20` except `\t` and `\n`), `DEL` (`0x7F`), and `ESC` (`0x1B`) to prevent ANSI escape / bracketed-paste breakout injection (`CWE-150`). |
| **Repudiation** | Multiline sends require explicit user confirmation via modal alert (`pendingMultilineTerminalSend`) and surface a status banner. |
| **Information Disclosure** | Binary read-only inspection buffers are rejected fail-closed (`isBinaryReadOnly == true -> nil`); zero network transmission. |
| **Denial of Service** | Selection payload capped at `64 KiB` (`TerminalSelectionPayload.maxUTF16Length = 65_536`, `CWE-400`); pending queue purged immediately on session termination. |
| **Elevation of Privilege** | Trailing `\r`/`\n` are stripped so no command auto-executes without explicit user `Return` in the interactive shell (`CWE-78`). |

## Implemented `P#`/`N#` Verification

- `P-STT1`: `TerminalSelectionPayload` trailing newline stripping, `ESC`/C0 sanitization, CRLF normalization, and multiline Bracketed Paste framing.
- `N-STT1 [Security]`: Rejects empty, newline-only, binary, out-of-bounds, UTF-16 surrogate-pair split, and `> 64 KiB` selections.
- `P-STT2`: Single-line `Cmd+Return` → `Send to Terminal` auto-opens closed terminal, queues and flushes to live `SwiftTerm` PTY without Return.
- `P-STT3`: Multiline selection stages warning confirmation; `Cancel` aborts without opening terminal; `Confirm` delivers bracketed multiline payload.
- `P-STT4`: Right-click `SwiftEditNSTextView.menu(for:)` preserves selection before `super.menu(for:)` and shows `Send to Terminal` only when text is selected.
- Full test suite: `404 tests in 113 suites` passed (`exit 0`), Debug build `SwiftEdit.app` succeeded.
