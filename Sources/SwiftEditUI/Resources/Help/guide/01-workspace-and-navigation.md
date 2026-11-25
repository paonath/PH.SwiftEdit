---
title: "Workspace Layout, Tabs, Folder Navigator & Session Recovery"
summary: "Complete guide to the SwiftEdit window chrome, multi-tab management, Quick Open, Find in Folder, Folder Navigator, external disk monitoring, Session Recovery, Document Navigator, and Distraction-Free mode."
commit: "b6ee821"
date: "2026-11-25"
branch: "main"
review_date: "2026-12-25"
---

# Chapter 1: Workspace Layout, Tabs & Navigation

## Functional: Window Anatomy

SwiftEdit presents a minimal, distraction-free workspace composed of four chrome regions surrounding the high-contrast editor canvas:

1. **Header Bar**:
   - **SwiftEdit Brand Menu** (top-left): clicking the logo opens a sticky translucent command menu with File, Edit, Markdown, View, Appearance (`Light`, `Dark`, `Auto`), and CheatSheet actions. Press `Esc` or click outside to dismiss.
   - **Quick Action Icon Cluster**: toggle buttons for Folder Navigator (`Cmd+B`), Find (`Cmd+F`), Markdown Preview (`Cmd+P`), File Compare (`Shift+Cmd+D`), Embedded Terminal (`Cmd+J`), and Keyboard Shortcuts Side Panel (`Option+Cmd+/`).
   - **Breadcrumb** (top-right): displays `folder / filename` for the active file-backed tab.
2. **Tab Bar**: flat tabs with a 2 pt purple accent bar on the active tab, a dot indicator for unsaved changes, a pin icon for pinned tabs, and a close button shown on the active or hovered tab.
3. **Editor Canvas & Line-Number Gutter**: pure `#FFFFFF`/`#000000` (Light) or `#000000`/`#FFFFFF` (Dark) canvas with a neutral grey gutter showing line numbers at 85% of the editor font size and a dedicated column for lint severity badges.
4. **Status Bar** (24 pt): sidebar toggle, confined `.git/HEAD` branch badge, Markdown/YAML/JSON lint status button (`Shift+Cmd+M`), unbalanced bracket counter (shown only when unbalanced brackets exist), cursor position (`Ln`, `Col`), selection character/line counts, character & Markdown word count, clickable encoding menu (`UTF-8` / `UTF-16`), clickable line-ending menu (`LF`, `CRLF`, `CR`), detected language, clickable zoom menu (`50%–300%`), and theme cycle button (`Light → Dark → Auto`).

---

## Functional: Multi-Tab Management

- **New Tab (`Cmd+N`)**: creates an untitled `UTF-8` buffer. Untitled tabs dynamically derive their title from the first non-empty line of content.
- **Pin & Unpin Tabs**: right-click any tab and select **Pin Tab** / **Unpin Tab**. Pinned tabs stay grouped at the left of the tab strip and cannot be closed (`Shift+Cmd+W`) until unpinned.
- **Reordering Tabs**: drag and drop tabs horizontally within their pinned or unpinned partition, or right-click a tab and choose **Move Tab Left** / **Move Tab Right**.
- **Closing, Bulk Close & Reopen Closed Tab**: untouched `Untitled` tabs and tabs reverted to their saved baseline close immediately without confirmation. Right-click any tab for **Close Tabs to the Right**, **Close Other Tabs**, **Close All Unpinned Tabs** (preserving pinned tabs), or **Close All Tabs**, middle-click any unpinned tab to close it, cycle tabs with `Shift+Cmd+]` / `Shift+Cmd+[`, `Ctrl+Tab`, or `Cmd+1..9`, and reopen recently closed files with **`Shift+Cmd+T`** (up to `20` entries). Closing a dirty tab or quitting SwiftEdit (`Cmd+Q`) prompts with **Save**, **Don't Save**, or **Cancel**.
- **External Disk Change Detection & Revert to Saved**: clean file-backed tabs automatically reload when modified externally on disk; dirty tabs preserve unsaved local edits and display a **Reload from Disk / Keep Mine / Compare** banner. Choose **File → Revert to Saved** to discard local edits and reload from disk.
- **Quick Open (`Cmd+T`) & Find in Folder (`Ctrl+Shift+F`)**: press **`Cmd+T`** to search and open workspace files by filename or relative path (up to `10,000` non-binary files), or press **`Ctrl+Shift+F`** for confined literal multi-file search across the active workspace folder (`<= 5,000` matches) with one-click jump to file and line.
- **Duplicate Document**: press `Cmd+Return` and choose **Duplicate Document**. File-backed tabs are copied (including unsaved edits) to `name copy.ext`, `name copy 2.ext`, and so on in the same folder without overwriting existing files, and opened right next to the source tab. Untitled tabs are duplicated in memory.

---

## Functional: Folder Navigator & File Operations

Toggle the left Folder Navigator with **`Cmd+B`** or the sidebar header icon. The sidebar is collapsed by default on empty launch or single-file open (`Cmd+O`) and expands automatically when opening a folder (`Shift+Cmd+O`). You can also reveal any open disk-backed file directly in the Folder Navigator using **Reveal in Folder Navigator** from the `Cmd+Return` palette or editor right-click menu.

![Folder Navigator Sidebar](images/folder-navigator.png)

### Browsing & Resizing

- **Proportional Width**: drag the 1 pt hairline divider to resize the sidebar between `12%` and `65%` of the window width.
- **Hidden Dotfiles**: dotfiles such as `.env` and `.gitignore` are displayed with a dedicated hidden-file icon so configuration files are always accessible.
- **Parent Directory (`...`)**: click the up-folder icon or the `...` row to ascend one folder level when permissions allow.
- **Click Behavior**: single-clicking a folder selects it without entering; double-clicking opens the folder. Single-clicking or double-clicking a text file opens it in a tab.
- **Binary Files**: files detected as binary are dimmed and italicized in the sidebar and opened only in transient read-only inspection mode when opened directly.

### Context Menu Actions

Right-click any file, folder, or empty space in the Folder Navigator to access:

| Action | Scope | Behavior |
| :--- | :--- | :--- |
| **Reveal in Finder** | File / Folder | Selects the item in macOS Finder |
| **Open Folder in Finder** | Folder / Current Folder | Opens the folder in Finder |
| **Open Terminal** | File / Folder / Background | Launches the configured external terminal at the target folder (or parent folder for files) |
| **Copy Path to Clipboard** | File / Folder / Background | Copies the standardized absolute filesystem path |
| **New File…** | Folder / Background | Prompts for a single-segment filename and opens the new `UTF-8` file |
| **New Folder…** | Folder / Background | Prompts for a single-segment directory name |
| **Cut / Copy / Paste** | Non-binary items | Moves or copies files/folders strictly within workspace scope |
| **Rename File… / Rename Folder…** | Non-binary items | Renames the item and reconciles open tabs automatically |
| **Delete (Move to Trash)** | Any item | Requests confirmation before moving the item to macOS Trash and updating open tabs |

---

## Functional: Opening Files, Batch Open, Drag & Drop & Recent Files

- **Open File (`Cmd+O`)**: opens a single file into a tab (or activates the existing tab if already open).
- **Open Folder (`Shift+Cmd+O`)**: mounts a workspace folder and expands the Folder Navigator.
- **Open All Files in Folder (`Option+Shift+Cmd+O`)**: opens all non-binary text files in the selected folder (shallow scan). Folders with more than `50` eligible files display a confirmation dialog first.
- **Drag & Drop**: drop files onto the SwiftEdit window to open them in tabs; drop folders to mount them in the Folder Navigator.
- **Recent Files**: **File → Open Recent** tracks up to `10` recently opened files using macOS security-scoped bookmarks, deduplicating re-opened paths and updating their recency order.

---

## Functional: Binary Quarantine, Clean Startup & Session Recovery

- **Clean Startup & Empty Session Filter**: on first launch (when no pinned documents or non-empty recovery snapshots exist), SwiftEdit opens directly onto a minimal empty workspace canvas (`New Document ⌘N`, `Open File… ⌘O`, `Open Folder… ⇧⌘O`) without creating a placeholder document. Empty or whitespace-only untitled tabs (`fileURL == nil`) are excluded from recovery persistence and startup restoration so stale blank tabs never accumulate across restarts. On subsequent launches, pinned documents are automatically reopened from disk alongside any non-empty unsaved recovery snapshots.
- **Binary Quarantine**: files containing NUL (`0x00`) bytes are never loaded into persistent tabs. Instead, SwiftEdit opens them in a transient read-only inspection banner where Save, Save As, Format, Duplicate, Pin, and Session Recovery are disabled. Closing or dismissing releases the buffer immediately.
- **Automatic Session Recovery**: unsaved edits and non-empty untitled tabs are persisted atomically to `~/Library/Application Support/PH.SwiftEdit/SessionRecovery/` (debounced during typing, flushed immediately on tab switch or close). Orphaned and legacy empty snapshots are garbage-collected on startup.

---

## Functional: Document Navigator & Distraction-Free Mode

- **Document Navigator (`Option+\`)**: opens a centered searchable jump palette listing all headings in a Markdown tab or top-level keys in a YAML tab. Use `Up`/`Down` arrows and press `Return` (or click any row) to jump and scroll directly to that line. Press `Esc` or `Option+\` to close.

![Document Navigator Overlay](images/document-navigator.png)

- **Distraction-Free Mode (`Option+1`)**: enters full-screen mode and hides the header bar, tab bar, sidebar, gutter, panels, and status bar so only the editor canvas remains visible. Press `Esc` or `Option+1` to restore the layout.

---

## Technical: Workspace & Session Components

| Component | Source File | Responsibility |
| :--- | :--- | :--- |
| `SwiftEditWorkbenchModel` & Sub-Controllers | `Sources/SwiftEditUI/Workbench/` | `@MainActor @Observable` coordinator decomposed across focused extensions and sub-controllers for tabs, search, sidebar, terminal, and updates |
| `WorkspaceTabSession` & `WorkbenchBulkCloseAndHistoryController` | `Sources/SwiftEditCore/WorkspaceAndTabSession/` & `Sources/SwiftEditUI/Workbench/` | Pinned-first tab ordering, bulk close, closed-tab history (`<= 20`), rename/trash reconciliation |
| `DotfileFolderNavigator` | `Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift` | Confined directory listing with dotfile visibility and symlink escape protection |
| `SessionRecoveryStore` & `SessionRecoveryEligibility` | `Sources/SwiftEditCore/WorkspaceAndTabSession/SessionRecoveryStore.swift` | Atomic manifest and recovery snapshot storage with empty-untitled filtering and symlink validation |
| `ExternalFileChangeMonitor` | `Sources/SwiftEditUI/Workspace/ExternalFileChangeMonitor.swift` | Confined `O_EVTONLY` disk watcher with clean auto-reload and dirty conflict detection |
| `RecentFilesStore` | `Sources/SwiftEditCore/WorkspaceAndTabSession/RecentFilesStore.swift` | 10-entry MRU store with balanced security-scoped bookmark resolution |
| `DocumentLoader` | `Sources/SwiftEditCore/DocumentCore/DocumentLoader.swift` | 64 MiB open size gate, binary NUL detection, encoding & line-ending round-trip |
