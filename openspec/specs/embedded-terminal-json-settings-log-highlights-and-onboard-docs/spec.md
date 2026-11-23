# Capability: embedded-terminal-json-settings-log-highlights-and-onboard-docs

## Purpose
Converges OpenSpec living specifications with the current SwiftEdit capabilities delivered after spec 022: embedded GPU-accelerated `SwiftTerm` PTY terminal, JSON user settings in `~/.SwiftEdit/settings.json`, Drag & Drop, `Cmd+W` Word Wrap / `Shift+Cmd+W` Close Tab, verified in-app auto-updates, synchronous secondary occurrence highlighting across both the TextKit 2 editor and the lock-free Log Viewer (Plain, Live Direct, Live Inverse, tail-only), and the bundled multi-chapter English User Guide (`docs/guide/` + `Help → SwiftEdit Help`).

## Requirements

### Requirement: REQ-023-01 Synchronous Secondary Occurrence Highlighting in Editor and Log Viewer
WHEN the user selects any word or token of length `2...128` UTF-16 units via mouse double-click, drag, or `Shift + Arrow` keys in either a writable editor tab or the integrated Log Viewer (Plain, Live Direct, Live Inverse, Stopped, or >64 MiB tail-only), `SwiftEditNSTextView` SHALL synchronously compute all other occurrences in memory, paint soft secondary pills and non-color-only underlines in `drawBackground(in:)`, invalidate nested TextKit 2 CoreAnimation sublayers, preserve active user selection across live log polls and `Direct ↔ Inverse` order switches, and NEVER lock the `.log` file on disk (`O_RDONLY | O_NONBLOCK | O_CLOEXEC` + `O_EVTONLY`) [UI-002][UI-009][UI-012][AR-007].

#### Scenario: P1 Secondary Occurrences Render Immediately in Editor and Log Viewer Without File Locking
- **Path**: P1
- **Trait**: positive
- **GIVEN** an open Markdown tab and an open `.log` tab running live tail in Direct and Inverse modes
- **WHEN** the user selects a repeated token via double-click or `Shift + Right Arrow` while an external writer acquires `flock(LOCK_EX | LOCK_NB)` and appends new lines
- **THEN** all other occurrences render with `wordOccurrenceBackground` and underline, `flock` succeeds without contention, and the active selection persists across live polls and mode switches

### Requirement: REQ-023-02 Embedded Terminal, JSON Preferences, Word Wrap, Drag & Drop, and Verified Auto-Updates
THE workbench SHALL persist preferences atomically in `~/.SwiftEdit/settings.json` (`JSONPreferencesStore`), support `Cmd+W` Word Wrap toggle and `Shift+Cmd+W` Close Tab, open dropped files in tabs and dropped folders in the Folder Navigator, host an embedded resizable `SwiftTerm` PTY terminal on `Cmd+J` with clean `SIGHUP`/`SIGKILL` teardown, and execute user-initiated GitHub Releases updates with SHA-256 verification and atomic app replacement (`AppUpdateInstaller`) [DATA-005][SEC-001][SEC-004].

### Requirement: REQ-023-03 Onboard Multi-Chapter English User Guide in `docs/guide/` and `Help → SwiftEdit Help`
THE repository SHALL maintain a complete, chapter-organized English User Guide in `docs/guide/` (`00-index.md` through `05-settings-shortcuts-and-security.md`) linked from `README.md`, free of third-party editor references, and bundled byte-identically in `Sources/SwiftEditUI/Resources/Help/guide/` so **Help → SwiftEdit Help** (`Shift+Cmd+?`) presents navigable offline chapters rendered natively by `MarkdownNativePreviewView` [UI-001][SEC-004].

#### Scenario: P2 Bundled Help Chapters Stay Synchronized With `docs/guide/`
- **Path**: P2
- **Trait**: positive
- **GIVEN** `docs/guide/00-index.md` through `05-settings-shortcuts-and-security.md` and `Sources/SwiftEditUI/Resources/Help/guide/`
- **WHEN** `HelpDocumentationTests` verifies the bundled Help chapters
- **THEN** every chapter matches its repository source byte-for-byte, projects non-empty `GFMPreviewDocument` blocks offline, and contains zero third-party editor references
