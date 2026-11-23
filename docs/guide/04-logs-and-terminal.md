---
title: "Log Viewer, Live Log Tail & Embedded Terminal"
summary: "Guide to .log syntax highlighting, lock-free Live Log Tail in Direct and Inverse modes, secondary occurrence highlighting in logs, >64 MiB tail-only handling, and the embedded GPU-accelerated terminal."
commit: "ea62d54"
date: "2026-11-23"
branch: "feature/contaxtual_actions"
review_date: "2026-12-23"
---

# Chapter 4: Log Viewer & Embedded Terminal

## Functional: Log Syntax Highlighting

Opening any `.log` file enables level-aware log highlighting across **NLog**, **Serilog**, **log4net**, **syslog**, and **JSON** log formats:

- **Severity Levels**: distinct high-contrast colors for `TRACE`, `DEBUG`, `INFO`, `WARN` (bold), `ERROR` (bold), and `CRITICAL` / `FATAL` (bold with alert background).
- **Structured Tokens**: timestamps, GUIDs/UUIDs, quoted strings, exception types, and stack trace frames are highlighted automatically without mutating the underlying file.

---

## Functional: Live Log Tail (`Cmd+L` / `Shift+Cmd+L`)

SwiftEdit includes an integrated live tail viewer (`tail -F` semantics) for any file-backed tab:

- **Direct Mode (`Cmd+L`)**: displays log lines in chronological file order with the newest entries at the bottom.
- **Inverse Mode (`Shift+Cmd+L`)**: displays the newest log entries at the top so recent activity is immediately visible without scrolling.

### Log Panel Controls

When Live Log Tail is active, a compact control bar appears above the viewer:

| Control | Function |
| :--- | :--- |
| **Status Indicator** | Shows `Log · live` while tailing or `Log · stopped` when paused |
| **Order (`Direct` / `Inverse`)** | Switches line order immediately without restarting the background tail |
| **Lines (`80` default)** | Sets how many trailing lines are displayed (configurable from `1` to `10,000` via text field or stepper) |
| **Stop / Resume** | Pauses or resumes live polling while keeping the last snapshot visible |
| **Close (`×`)** | Closes the live tail panel and returns to normal editing (unavailable on >64 MiB tail-only tabs) |

### Lock-Free Architecture & Large Log Files (>64 MiB)

- **Zero File Locking**: SwiftEdit **never** locks `.log` files. Background reads open the file with `O_RDONLY | O_NONBLOCK | O_CLOEXEC`, read only appended bytes via positional `pread`, and close the file descriptor immediately after each read. Kernel vnode monitoring uses `O_EVTONLY | O_CLOEXEC`, so external services can write, append, truncate, rotate, or delete the log file at any time without contention.
- **Rotation & Truncation Recovery**: if a log file is truncated or rotated (inode/device change), the tail automatically resets and follows the new file.
- **Large Logs (>64 MiB)**: opening a `.log` file larger than the `64 MiB` editor gate automatically opens it as a read-only **tail-only** tab reading a bounded window from the end of the file, keeping memory usage strictly bounded.

---

## Functional: Secondary Occurrence Highlighting in the Log Viewer

Secondary occurrence highlighting works seamlessly across **all** log viewer modes — **Plain `.log` tabs**, **Live Direct**, **Live Inverse**, **Stopped**, and **>64 MiB tail-only** tabs:

- Select any log level (`INFO`, `WARN`, `ERROR`), timestamp, GUID, logger name, or token via mouse double-click, drag, or `Shift + Arrow` keys.
- All other occurrences in the log view are highlighted immediately with soft purple pills and bottom underlines.
- **Selection Preservation**: incoming live log lines and `Direct ↔ Inverse` order switches preserve your active token selection instead of resetting the caret, automatically highlighting matching tokens in newly appended lines as they arrive.

![Integrated Log Viewer in Live Inverse Mode with Secondary Occurrence Highlighting](images/log-viewer-live-inverse.png)

---

## Functional: Embedded Terminal (`Cmd+J`) & External Terminal Handoff

### Embedded Terminal Panel (`Cmd+J`)

Press **`Cmd+J`** (or click the terminal icon in the header bar) to toggle the bottom **Embedded Terminal** panel:

- Powered by a native **VT100 / xterm-256color** terminal emulator (`SwiftTerm`) with GPU Metal rendering.
- Launches your default macOS login shell automatically in the current workspace folder (or your home directory when no folder is open).
- Supports **multiple terminal tabs** (`+` to open additional sessions, `×` to close a session, **Restart** if a shell exits abnormally).
- Drag the top resize handle to adjust the panel height (persisted in `~/.SwiftEdit/settings.json`).
- Closing a terminal tab or quitting SwiftEdit cleanly terminates the child shell process group.
- While the embedded terminal has keyboard focus, all terminal shortcuts (`Ctrl+C`, `Ctrl+D`, `Ctrl+L`, `Cmd+C`/`V`/`K`, Option-as-Meta) go directly to the shell; only `Cmd+J` toggles the panel.
- **Send to Terminal** *(from `Cmd+Return` or right-click on any selection in the editor or Log Viewer)*: automatically opens the embedded terminal panel if closed, starts a session if none exists, sanitizes the selected text (stripping trailing line breaks and unsafe `ESC`/C0 control bytes), writes it into the active PTY **without pressing Return**, and focuses the terminal so you can review or edit before executing. Selections spanning multiple lines prompt with a confirmation warning and are delivered via ANSI Bracketed Paste (`ESC[200~ … ESC[201~`).

### External Terminal Handoff

Right-clicking any item in the Folder Navigator and choosing **Open Terminal** opens your preferred external terminal at that folder (configured in **Settings → Terminal**).

---

## Technical: Log Tail & Terminal Internals

| Component | Source File | Design Details |
| :--- | :--- | :--- |
| `LogTailBuffer` & `LogTailSession` | `Sources/SwiftEditCore/LogSupport/LogTail.swift` | Bounded `10_000`-line ring buffer, `8 MiB` max incremental read window, `memchr` newline scanning, `O_RDONLY \| O_NONBLOCK \| O_CLOEXEC` + `pread` |
| `LogTailWorker` & `LogTailController` | `Sources/SwiftEditUI/Workspace/LogTailController.swift` | Serial `.utility` background queue, `O_EVTONLY` kqueue `DispatchSourceFileSystemObject` + 1 s rotation fallback timer, monotonic sequence delivery to `@MainActor` |
| `LogSyntaxHighlighter` | `Sources/SwiftEditCore/LogSupport/LogSyntaxHighlighter.swift` | Linear single-pass line tokenizer for NLog, Serilog, log4net, syslog, and JSON |
| `EmbeddedTerminalRegistry` | `Sources/SwiftEditUI/Views/EmbeddedTerminalEmulatorView.swift` | Manages `SwiftTerm` PTY sessions, OSC 7 working-directory tracking, and `SIGHUP`/`SIGKILL` teardown |
