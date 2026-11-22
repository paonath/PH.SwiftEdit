<p align="center">
  <img src="docs/design/assets/logo-e2-refined-512.png" alt="SwiftEdit logo" width="128" height="128" />
</p>

<h1 align="center">SwiftEdit</h1>

<p align="center">
  A minimal, fast, and private text editor for macOS, written in Swift 6.<br />
  Markdown, YAML, and log files with a native TextKit&nbsp;2 editor and an embedded GPU-accelerated terminal.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2026%2B-7C3AED" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-A78BFA" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-C4B5FD" />
</p>

---

## Overview

SwiftEdit is a lightweight native document editor built with Apple frameworks (SwiftUI, AppKit, and TextKit 2). It launches into full screen by default, persists user preferences as human-readable JSON in `~/.SwiftEdit/settings.json`, works completely offline while editing, and keeps your files on your Mac with zero telemetry and no accounts.

## Features

### Editing

- **TextKit 2 engine** with line-number gutter, current-line highlight, nested bracket matching, `Cmd+W` Word Wrap toggle, and `50%`–`300%` zoom that scales tabs, the folder navigator, and the gutter together.
- **Multi-level highlighting** with WCAG-verified contrast in Light and Black modes:
  - Antique parchment-yellow highlighting for inline and fenced backtick code spans.
  - High-contrast purple selection with soft secondary highlighting and non-color-only underlines for all other whole-word occurrences of the selected word.
- **Tabs and sessions** with pinning, reordering, dynamic untitled tab names, unsaved-change prompts, and automatic crash recovery.
- **Explicit save** preserving text encoding (`UTF-8`, `UTF-16`) and line endings (`LF`, `CRLF`, `CR`).
- **Literal Find & Replace**, Go to Line (`Cmd+G`), and duplicate line or selection (`Cmd+D`).
- **Typography and themes**: choose interface and editor fonts in Settings (`Cmd+,`) from system fonts, bundled OpenDyslexic, or default monospaced; Light, Black, and Auto appearance modes with WCAG 2.2 AA contrast.
- **JSON preferences**: settings are stored in `~/.SwiftEdit/settings.json`.

### Markdown

- Live GitHub Flavored Markdown highlighting and authoring commands (bold, italic, strikethrough, inline code, code fences, links, images, blockquotes, tables, task lists, headings `H1`–`H6`).
- Adaptive list indentation (`Tab` / `Shift+Tab`) and smart `Enter` continuation.
- 26-rule linter with quick fixes, Fix All, diagnostics popover (`Shift+Cmd+M`), and gutter hover explanations.
- Native offline preview (`Cmd+P`) rendered with SwiftUI (no web view).
- Document Navigator (`Option+\`) for headings and YAML keys — press `Enter` or click any row to jump directly to the target line — plus Distraction-Free mode (`Option+1`).
- YAML frontmatter highlighting and an inline **Properties** panel for editing top-level keys and lists.

### YAML

- Native `.yml` / `.yaml` highlighting, structural lint (`YML001`–`YML005`), top-level key outline in the Document Navigator, and two-space smart indentation.

### Logs

- Level-aware highlighting for `.log` files (trace, debug, info, warning, error, critical), timestamps, GUIDs, strings, exceptions, and stack frames across NLog, Serilog, log4net, syslog, and JSON layouts.
- Live log tail (`Cmd+L` direct, newest at the bottom; `Shift+Cmd+L` inverse, newest first) with an in-editor panel for Stop/Resume, ordering, and line limit (80 by default).
- Background tailing never locks the file, survives truncation and rotation, and opens logs above 64 MiB as read-only tail-only tabs.

### Workspace, Embedded Terminal, and Updates

- **Drag & Drop**: drop files onto SwiftEdit to open them in tabs; drop folders to open them in the left Folder Navigator.
- **Folder Navigator** (`Cmd+B`) with file operations, Finder reveal, path copy, and external terminal handoff (Terminal, iTerm2, Warp, Ghostty, and others configured in **Settings → Terminal**).
- **Embedded Terminal (`Cmd+J`)**: resizable VT100/xterm-256color terminal emulator built directly inside SwiftEdit (`SwiftTerm`) with GPU Metal rendering, multi-session tabs, and automatic clean process teardown on close.
- **Side-by-side diff** against the last saved version.
- **In-app Updates (`Check for Updates…`)**: checks GitHub Releases (`paonath/PH.SwiftEdit`), verifies SHA-256 checksums, quits the running instance, swaps `SwiftEdit.app` atomically, preserves quarantine-free status if previously unquarantined, and relaunches automatically.

## Requirements

- macOS 26 or later on Apple silicon.
- Xcode 26 / Swift 6.2 or later to build from source.

## Installation

Releases are published on [GitHub Releases](https://github.com/paonath/PH.SwiftEdit/releases) as `PH.SwiftEdit-<version>-macOS-arm64.zip` alongside a matching `.sha256` checksum. Each archive contains `SwiftEdit.app`.

### Install or update with the script

```bash
./Scripts/install-from-github.sh --remove-quarantine
# Pin a specific release:
./Scripts/install-from-github.sh --version v0.1.3 --remove-quarantine
# Preview resolved URLs and actions without downloading:
./Scripts/install-from-github.sh --dry-run
```

The installer verifies the SHA-256 checksum before replacing `/Applications/SwiftEdit.app`, closes any running instance first, preserves quarantine-free status automatically on updates (or always strips `com.apple.quarantine` when `--remove-quarantine` is passed), and relaunches `SwiftEdit.app` unless `--no-relaunch` is specified.

### Manual install

1. Download the `.zip` and its `.sha256` file from the release page and verify the checksum:

   ```bash
   shasum -a 256 -c PH.SwiftEdit-<version>-macOS-arm64.zip.sha256
   ```

2. Unzip the archive and move `SwiftEdit.app` to `/Applications`.
3. If the build is not notarized, macOS blocks the first launch. Open the app once, click **OK**, then go to **System Settings → Privacy & Security** and click **Open Anyway**. Alternatively, after verifying the checksum, remove the quarantine attribute:

   ```bash
   xattr -dr com.apple.quarantine /Applications/SwiftEdit.app
   open /Applications/SwiftEdit.app
   ```

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| New / Open / Save / Save As | `Cmd+N` / `Cmd+O` / `Cmd+S` / `Shift+Cmd+S` |
| Open Folder / Open All Files in Folder | `Shift+Cmd+O` / `Option+Shift+Cmd+O` |
| Close Document | `Shift+Cmd+W` |
| Toggle Word Wrap | `Cmd+W` |
| Toggle Folder Navigator | `Cmd+B` |
| Find / Find and Replace / Go to Line | `Cmd+F` / `Option+Cmd+F` / `Cmd+G` |
| Duplicate Line or Selection | `Cmd+D` |
| Format Markdown Document / Section | `Shift+Cmd+F` / `Option+Shift+Cmd+F` |
| Markdown Preview | `Cmd+P` |
| Markdown Diagnostics | `Shift+Cmd+M` |
| Document Navigator (Headings & YAML Keys) | `Option+\` |
| Distraction-Free Mode | `Option+1` |
| Log Tail (Direct / Inverse) | `Cmd+L` / `Shift+Cmd+L` |
| Toggle Task Checkbox | `Option+Cmd+L` |
| Embedded Terminal Panel | `Cmd+J` |
| Zoom In / Out / Actual Size (100%) | `Cmd++` / `Cmd+-` / `Cmd+0` |
| Settings | `Cmd+,` |
| SwiftEdit Help / Keyboard Shortcuts CheatSheet | `Shift+Cmd+?` / `Cmd+/` |

## Privacy and Security

- Built with macOS **Hardened Runtime**; editing, Markdown preview, linting, and diffing work strictly offline with zero telemetry.
- The only network requests are user-initiated update checks and downloads from allowlisted GitHub HTTPS URLs (`api.github.com` / `github.com`), verified with SHA-256 before installation.
- The embedded terminal (`Cmd+J`) runs your local login shell inside an in-app PTY and terminates its process group cleanly when closed.
- Bundled OpenDyslexic fonts are SHA-256 verified before process-scoped registration.

## Building from Source

```bash
git clone https://github.com/paonath/PH.SwiftEdit.git
cd PH.SwiftEdit
swift test --parallel
./Scripts/build-app.sh --configuration Release --clean --derived-data .tmp/DerivedData
open build/$(plutil -extract version raw -o - version.json)/SwiftEdit.app
```

Release builds apply `-Osize`, whole-module compilation, ThinLTO, dead-code stripping, and symbol stripping to keep `SwiftEdit.app` compact (~6.3 MB). Pushing a version tag builds `PH.SwiftEdit-<tag>-macOS-arm64.zip` and publishes it with its checksum through `.github/workflows/release.yml`.

## Documentation

| Document | Scope |
| :--- | :--- |
| [Color schemes and layout](docs/design/color-schemes-and-zed-layout.md) | Color tokens, editor canvas, and layout |
| [App icons](docs/design/assets/app-icons-riepilogo.md) | Logo master and icon sets for macOS and iOS |
| [Constitution](openspec/Constitution.md) | Architecture, security, and testing rules of the project |

## License

SwiftEdit is released under the [MIT License](LICENSE). The bundled OpenDyslexic font is distributed under the SIL Open Font License 1.1 (see `Sources/SwiftEditUI/Resources/Fonts/OFL.txt`).
