<p align="center">
  <img src="docs/design/assets/logo-e2-refined-512.png" alt="SwiftEdit logo" width="128" height="128" />
</p>

<h1 align="center">SwiftEdit</h1>

<p align="center">
  A minimal, fast and private text editor for macOS, written in Swift 6.<br />
  Markdown, YAML and log files, with a native TextKit&nbsp;2 editing engine.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2026%2B-7C3AED" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-A78BFA" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-C4B5FD" />
</p>

---

## Overview

SwiftEdit is a lightweight document editor built entirely with Apple frameworks (SwiftUI, AppKit and TextKit 2). It opens instantly, works fully offline and keeps your files on your Mac: there is no account, no telemetry and no background network traffic.

## Features

### Editing

- TextKit 2 editor with line-number gutter, current-line highlight, bracket matching and `50%`–`300%` zoom that also scales tabs, the folder navigator and the gutter.
- Tabs with pinning, reordering, unsaved-change prompts and automatic session recovery.
- Explicit save that preserves encoding (UTF-8, UTF-16) and line endings (`LF`, `CRLF`, `CR`).
- Literal Find and Replace, Go to Line, and duplicate line or selection (`Cmd+D`).
- Interface and editor fonts selectable in Settings (`Cmd+,`): any installed system font, the bundled OpenDyslexic, or the default monospaced font.
- Light, Black and Auto appearance with WCAG 2.2 AA contrast.

### Markdown

- Live GitHub Flavored Markdown highlighting and authoring commands (bold, italic, links, tables, task lists, headings).
- Adaptive list indentation with `Tab` / `Shift+Tab` and smart `Enter` continuation.
- 26-rule linter with quick fixes, Fix All and a diagnostics popover (`Shift+Cmd+M`); hover a gutter dot to read the explanation.
- Native preview (`Cmd+P`) rendered without a web view.
- Document navigator (`Option+\`) for headings, and distraction-free mode (`Option+1`).
- YAML frontmatter with key/value highlighting and a Properties panel.

### YAML

- Native `.yml` / `.yaml` highlighting, structural lint, top-level key outline and two-space smart indentation.

### Logs

- Level-aware highlighting for `.log` files (trace, debug, info, warning, error, critical), timestamps, GUIDs, strings and stack traces; common NLog, Serilog, log4net, syslog and JSON layouts are recognized.
- Live tail (`Cmd+L`, newest at the bottom; `Shift+Cmd+L`, newest at the top) with an in-editor panel to stop, switch order and set the number of lines (80 by default).
- Tailing runs in the background, never locks the file and handles truncation and rotation; logs too large to edit open directly as a live tail.

### Workspace

- Folder navigator with file actions, Finder reveal and a Terminal panel (`Cmd+J`) that opens your preferred terminal (Terminal, iTerm2, Warp, Ghostty and others) in the current folder.
- Side-by-side diff against the last saved version.
- Manual update check against GitHub Releases.

## Requirements

- macOS 26 or later on Apple silicon.
- Xcode 26 / Swift 6.2 or later to build from source.

## Installation

Releases are published on [GitHub Releases](https://github.com/paonath/PH.SwiftEdit/releases) as `PH.SwiftEdit-<version>-macOS-arm64.zip`, each with a matching `.sha256` checksum. The archive contains `SwiftEdit.app`.

### Install or update with the script

```bash
./Scripts/install-from-github.sh --remove-quarantine
# Or pin a specific release:
./Scripts/install-from-github.sh --version v0.1.3 --remove-quarantine
```

The installer verifies the SHA-256 checksum before replacing `/Applications/SwiftEdit.app`, quits a running instance first, and removes the `com.apple.quarantine` attribute only when `--remove-quarantine` is passed.

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
| New / Open / Save | `Cmd+N` / `Cmd+O` / `Cmd+S` |
| Open folder | `Shift+Cmd+O` |
| Find / Find and Replace / Go to Line | `Cmd+F` / `Option+Cmd+F` / `Cmd+G` |
| Duplicate line or selection | `Cmd+D` |
| Markdown preview | `Cmd+P` |
| Markdown diagnostics | `Shift+Cmd+M` |
| Document navigator | `Option+\` |
| Distraction-free mode | `Option+1` |
| Log tail (direct / inverse) | `Cmd+L` / `Shift+Cmd+L` |
| Toggle task checkbox | `Option+Cmd+L` |
| Terminal panel | `Cmd+J` |
| Zoom in / out / reset | `Cmd++` / `Cmd+-` / `Cmd+0` |
| Settings | `Cmd+,` |
| All shortcuts | `Cmd+/` |

## Privacy and Security

- Runs in the macOS App Sandbox with access limited to files and folders you open.
- Works offline. The only network request is the update check you start from the menu, sent to `api.github.com`.
- Never starts shell processes: the Terminal panel hands the folder to your terminal application.
- Bundled fonts are verified by SHA-256 before use and are registered only for SwiftEdit.

## Building from Source

```bash
git clone https://github.com/paonath/PH.SwiftEdit.git
cd PH.SwiftEdit
swift test --parallel
./Scripts/build-app.sh --configuration Release --clean --derived-data .tmp/DerivedData
open .tmp/DerivedData/Build/Products/Release/SwiftEdit.app
```

Pushing a version tag builds `PH.SwiftEdit-<tag>-macOS-arm64.zip` and publishes it with its checksum through `.github/workflows/release.yml`.

## Documentation

| Document | Scope |
| :--- | :--- |
| [Color schemes and layout](docs/design/color-schemes-and-zed-layout.md) | Color tokens, editor canvas and layout |
| [App icons](docs/design/assets/app-icons-riepilogo.md) | Logo master and icon sets for macOS and iOS |
| [Constitution](openspec/Constitution.md) | Architecture, security and testing rules of the project |

## License

SwiftEdit is released under the [MIT License](LICENSE). The bundled OpenDyslexic font is distributed under the SIL Open Font License 1.1 (see `Sources/SwiftEditUI/Resources/Fonts/OFL.txt`).
