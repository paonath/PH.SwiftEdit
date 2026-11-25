---
title: "Settings, Themes, Keyboard Shortcuts & Security"
summary: "Reference for SwiftEdit preferences (~/.SwiftEdit/settings.json), Light/Dark/Auto appearance, semantic syntax color schemes, typography and OpenDyslexic, complete keyboard shortcuts, and privacy/security guarantees."
commit: "b6ee821"
date: "2026-11-25"
branch: "main"
review_date: "2026-12-25"
---

# Chapter 5: Settings, Shortcuts & Security

## Functional: Settings (`Cmd+,`) & JSON Persistence

Open **SwiftEdit → Settings…** (`Cmd+,`) to configure appearance, syntax color schemes, fonts, editor defaults, and external terminal handoff. All preferences are stored as human-readable JSON in **`~/.SwiftEdit/settings.json`** using atomic writes:

- **Appearance & Syntax Color Schemes**:
  - **Light**: neutral light chrome with purple accents and a pure white `#FFFFFF` / black `#000000` (`21:1`) editor canvas.
  - **Dark (Black)**: neutral dark chrome with purple accents and a pure black `#000000` / white `#FFFFFF` (`21:1`) editor canvas.
  - **Auto**: tracks macOS system appearance live without reloading open buffers.
  - **Syntax Scheme**: choose from four WCAG-AA-verified (`>= 4.5:1`) schemes (**SwiftEdit Default**, **Catppuccin**, **GitHub**, **Tokyo Night**) under **Settings → Fonts (Editor) → Syntax Scheme** — updates apply live across Markdown, YAML, JSON, HTML, and Log files.
  - You can also switch appearance from the **SwiftEdit** header menu or by clicking the theme icon in the status bar.
  - Automatically adapts to macOS **Reduce Transparency** and **Increased Contrast** accessibility settings (stepping hairline borders to `>= 3.0:1` and clamping translucent surfaces opaque).
- **Typography**:
  - Independently select **Interface Font** and **Editor Font** from installed system fonts, default monospaced, or the bundled **OpenDyslexic** font family.
  - Font changes apply live across the entire interface without mutating any document buffer.
- **Editor Behavior**:
  - **Word Wrap** (`Cmd+W`), **Trim Trailing Whitespace on Save**, **Editor Zoom** (`50%–300%`), **Launch in Full Screen** (enabled by default), and **Embedded Terminal Height**.
- **Terminal**:
  - Choose **Auto** or a specific installed external terminal for Folder Navigator **Open Terminal** handoff.

---

## Functional: Keyboard Shortcuts Reference

SwiftEdit provides two interactive ways to browse and execute shortcuts:
- **Floating CheatSheet (`Cmd+/`)**: modal searchable catalog of all shortcuts; click any executable row to run it immediately.
- **Keyboard Shortcuts Side Panel (`Option+Cmd+/`)**: dockable right panel with live search (matches titles, descriptions, and both symbol `⇧⌘D` or word `shift cmd d` shortcuts) and one-click execution.

![Keyboard Shortcuts Side Panel](images/shortcuts-panel.png)

### File

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| New Document | `Cmd+N` | Create a new untitled `UTF-8` tab |
| Open File | `Cmd+O` | Open an existing file into a tab |
| Open Folder | `Shift+Cmd+O` | Mount a workspace folder and expand the Folder Navigator |
| Open All Files in Folder | `Option+Shift+Cmd+O` | Open shallow non-binary text files in a folder (confirms `> 50` files) |
| Quick Open | `Cmd+T` | Search and open workspace files by name or relative path |
| Reopen Closed Tab | `Shift+Cmd+T` | Reopen the most recently closed file-backed tab (`<= 20`) |
| Save | `Cmd+S` | Atomically save preserving encoding and `LF`/`CRLF`/`CR` |
| Save As | `Shift+Cmd+S` | Save the active document to a new path |
| Close Document | `Shift+Cmd+W` | Close the active tab (prompts if unsaved; blocked on pinned tabs) |
| Quit SwiftEdit | `Cmd+Q` | Quit application (prompts if any tab has unsaved edits) |

### Edit, Contextual Actions & Markdown

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| Undo / Redo | `Cmd+Z` / `Shift+Cmd+Z` | Per-tab isolated undo and redo |
| Cut / Copy / Paste / Select All | `Cmd+X` / `Cmd+C` / `Cmd+V` / `Cmd+A` | Standard clipboard and selection operations |
| Duplicate Line or Selection | `Cmd+D` | Duplicate current line or selected range |
| Move Line Up / Down | `Option+Up` / `Option+Down` | Swap active or selected lines upward or downward |
| Delete Line / Join Lines | `Ctrl+Shift+K` / `Ctrl+J` | Delete active line(s) or join adjacent lines |
| Use Selection for Find / Find in Folder | `Option+Cmd+E` / `Ctrl+Shift+F` | Populate Find from selection or search across workspace files |
| Next / Previous Tab | `Shift+Cmd+]` / `Shift+Cmd+[` | Cycle through open workspace tabs (`Ctrl+Tab`, `Cmd+1..9`) |
| Next / Previous Difference | `F7` / `Shift+F7` | Jump across hunks in the File Compare diff pane |
| Accept Word Completion | `Tab` | Accept inline ghost-text suggestion (`Esc` dismisses) |
| Contextual Actions | `Cmd+Return` | Open Surround With, Send to Terminal, Reveal in Folder Navigator, Start Dictation Here, and Duplicate Document palette |
| Format Markdown or JSON Document | `Shift+Cmd+F` | Format full Markdown (AST) or JSON (2-space sorted keys) document |
| Format Markdown Section | `Option+Shift+Cmd+F` | Format only selected Markdown lines |
| Bold / Italic / Inline Code | `Shift+Cmd+B` / `Cmd+I` / `Cmd+E` | Toggle Markdown emphasis or inline code |
| Insert Link | `Cmd+K` | Wrap selection as a Markdown link |
| Toggle Task Checkbox | `Option+Cmd+L` | Toggle `- [ ]` ↔ `- [x]` |
| Markdown Heading (1–6) | `Ctrl+Cmd+1` … `Ctrl+Cmd+6` | Apply ATX heading level 1 through 6 |

### Navigation & View

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| Find / Find & Replace / Go to Line | `Cmd+F` / `Option+Cmd+F` / `Cmd+G` | Literal search, replace, and 1-based line jump |
| Line Start / Line End | `Home` / `End` | Move caret to start or end of current line |
| Toggle Folder Navigator | `Cmd+B` | Show or collapse the left sidebar |
| Zoom In / Out / Reset (100%) | `Cmd++` / `Cmd+-` / `Cmd+0` | Scale editor and chrome from `50%` to `300%` |
| Toggle Word Wrap | `Cmd+W` | Switch between soft wrap and horizontal scroll |
| Toggle Markdown Preview | `Cmd+P` | Show or hide native offline Markdown preview |
| Toggle File Compare | `Shift+Cmd+D` | Show or hide side-by-side Myers diff pane |
| Toggle Markdown Diagnostics | `Shift+Cmd+M` | Open diagnostics popover with Quick Fix and Fix All |
| Document Navigator | `Option+\` | Jump to Markdown headings or YAML top-level keys |
| Distraction-Free Mode | `Option+1` | Full-screen editor canvas only (`Esc` or `Option+1` restores) |
| Log Tail (Direct / Inverse) | `Cmd+L` / `Shift+Cmd+L` | Start or switch live log tail order |
| Embedded Terminal Panel | `Cmd+J` | Show or hide the bottom terminal panel |
| Settings | `Cmd+,` | Open application preferences |
| SwiftEdit Help | `Shift+Cmd+?` | Open this onboard documentation offline |
| Keyboard Shortcuts CheatSheet / Side Panel | `Cmd+/` / `Option+Cmd+/` | Open floating shortcuts sheet or right side panel |

---

## Functional: Privacy & Security Guarantees

- **Offline by Design**: editing, syntax highlighting, linting, formatting, native Markdown preview, diagram rendering, File Compare, and in-app Help operate **100% offline** with zero telemetry and no accounts.
- **Explicit Network Boundary**: the only network access occurs when you explicitly invoke **Check for Updates…**, which connects only to allowlisted GitHub HTTPS endpoints (`api.github.com` / `github.com`) and verifies SHA-256 checksums before staging any update.
- **BiDi (Trojan Source) Detection**: files containing Unicode bidirectional control characters display an immediate warning banner.
- **Binary Quarantine & Empty Session Filtering**: files with NUL bytes open in transient read-only mode with Save, Format, Duplicate, Pin, and Session Recovery disabled; empty or whitespace-only untitled tabs are excluded from recovery persistence and purged on startup.
- **Path, Extension & Symlink Confinement**: Folder Navigator operations, **Reveal in Folder Navigator**, preview local images, `.git/HEAD` inspection, and session recovery manifests reject escaping symlinks and path traversal; language classification inspects only the final extension to block double-extension smuggling.
- **Dictation Isolation**: **Start Dictation Here** operates strictly on writable non-binary, non-tail-only editor buffers using standard macOS `startDictation:` dispatch with zero additional entitlements.
- **Verified Bundled Fonts**: bundled OpenDyslexic font files are SHA-256 verified before process-scoped registration (`OpenDyslexicBundle`).

---

## Technical: Preferences, Shortcuts & Security Modules

| Component | Source File | Responsibility |
| :--- | :--- | :--- |
| `JSONPreferencesStore` & `EditorPreferencesStore` | `Sources/SwiftEditCore/WorkspaceAndTabSession/` | Serialized atomic JSON persistence in `~/.SwiftEdit/settings.json` |
| `PurpleThemePalette`, `SyntaxColorSchemePalette` & `ZoomedChromeMetrics` | `Sources/SwiftEditUI/Theme/` | WCAG 2.2 AA verified semantic tokens, 4 syntax schemes, and proportional `50%..300%` chrome scaling |
| `OpenDyslexicBundle` | `Sources/SwiftEditUI/Fonts/OpenDyslexicBundle.swift` | SHA-256 verification and CoreText process-scoped font registration |
| `SwiftEditShortcutDispatcher` & `KeyboardShortcutsCheatSheetCatalog` | `Sources/SwiftEditUI/Views/` | Single-source shortcut routing and searchable/clickable command catalog |
| `GitHubReleaseUpdateChecker` & `AppUpdateInstaller` | `Sources/SwiftEditUI/Updates/` | Allowlisted GitHub HTTPS checks, SHA-256 verification, and atomic app replacement |
