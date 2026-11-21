# Threat Model: Root-ZStack Translucent Header Brand Submenu, Descriptive Action Badges, Single-Source SwiftEditCommands & Binary Quarantine Guards

## 1. Asset Boundaries & Trust Zones
- **Trusted Core Domain (`SwiftEditCore`)**: Pure `Foundation` and `Markdown` AST value types (`DocumentSession`, `DocumentSnapshot`, `MarkdownLintAndFormatEngine.formatSection`, `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory`) holding canonical buffer revisions, binary quarantine flags (`isBinaryReadOnly`), and static UI token fitness checks (`[AR-002]`, `[AR-006]`, `[BC-004]`, `[DATA-003]`).
- **Presentation & Command Dispatch (`SwiftEditUI`, `@MainActor`)**: Resolves `HeaderSubmenuStateMachine` (`120 ms` dwell / `180 ms` grace / `Escape` latch), `HeaderCommandCatalog` descriptive descriptors, root-`ZStack` `HeaderBrandSubmenuView` (`submenuTranslucentSurface` `0.90` / `1.0` alpha), and centralized `SwiftEditCommands` (`⌘P` Preview, `⌥⇧⌘F` Format Section, `⌘D` Duplicate) (`[AR-003]`, `[UI-005]`, `[UI-008]`, `[UI-009]`).
- **Untrusted / Hostile Inputs**: Quarantined binary read-only files (`0x00` within `8 KiB`), degraded `> 10 MiB` plain-text buffers, rapid pointer sweeps across macOS traffic lights or `EditorTabStrip`, active tab/sidebar drag gestures, and system keyboard shortcuts (`⌘S`, `⇧⌘S`, `⌘D`, `⇧⌘F`, `⌥⇧⌘F`, `⌘P`) (`[DATA-003]`, `[SEC-004]`, `[SEC-012]`).

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Cryptic shorthand labels (`Cmd+D`, `Format`, `Preview`) or low-contrast translucent overlay (`CWE-451`) mislead the user into triggering destructive edits over editor content. | Replace shorthand buttons with full verb-noun `HeaderCommandCatalog` titles + badges (`>= 4.5:1` contrast via `submenuTranslucentSurface` + `1.0` alpha clamping under `reduceTransparency`/`increasedContrast`) verified by `scanSwiftEditUIViewsDirectory` (`[SEC-009]`, `[TEST-006]`, `[UI-009]`). |
| Tampering | Invoking `Duplicate Line or Selection` (`⌘D`), `Save`, `Save As…` (`⇧⌘S`), `Format Document` (`⇧⌘F`), or `Format Section` (`⌥⇧⌘F`) via menu shortcut on a binary read-only buffer corrupts NUL-bearing wire bytes (`DATA-003`). | Synchronize `.disabled(!safetyBanner.canSave)` and `.disabled(!safetyBanner.canFormat)` across `HeaderCommandCatalog` and `SwiftEditCommands` AND enforce fail-closed `!session.isBinaryReadOnly` guards in `SwiftEditWorkbenchModel` (`[DATA-003]`, `[SEC-012]`, `[UI-008]`). |
| Repudiation | Duplicate `.keyboardShortcut` bindings on both `toolbarBar` and `SwiftEditCommands` trigger ambiguous double-execution or bypass status feedback. | Centralize all global keyboard shortcuts exclusively inside `SwiftEditCommands` with zero `.keyboardShortcut` modifiers inside `toolbarBar` or `HeaderBrandSubmenuView` (`[UI-009]`, `[UI-010]`). |
| Information Disclosure | Default-enabled `Cmd+P` macOS `.printItem` spawns print-spooler XPC/IPC dialogs exposing sandboxed document contents or metadata (`SEC-004`). | Override `CommandGroup(replacing: .printItem)` in `SwiftEditCommands` to toggle in-memory Zero-WebKit Markdown Preview (`showMarkdownPreview` defaulting to `false`) (`[SEC-004]`, `[UI-006]`). |
| Denial of Service | `0 ms` hover trigger flashes `HeaderBrandSubmenuView` during pointer travel or drag, or `formatActiveSection()` runs unbounded AST work on degraded `> 10 MiB` buffers (`CWE-400`). | Gate hover-open behind `120 ms` dwell, active-drag lockout, and `Escape` suppression latch (WCAG 2.2 SC 1.4.13), and enforce `MarkdownLintAndFormatEngine.formatSection` `128`-depth / `250 ms` / degraded guards (`[BC-011]`, `[SEC-012]`, `[UI-012]`). |
| Elevation of Privilege | `saveActiveDocumentAsViaPanel()` (`⇧⌘S`) opens `NSSavePanel` on a quarantined binary buffer, allowing binary re-serialization to a user-chosen path (`DATA-003`). | Reject `saveActiveDocumentAsViaPanel()` fail-closed before constructing `NSSavePanel` whenever `session.isBinaryReadOnly == true` (`[DATA-003]`, `[SEC-012]`, `[UI-008]`). |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Binary Quarantine Bypass via Menu Shortcut (`⌘D` / `⇧⌘S` / `⌥⇧⌘F`) (`DATA-003`)**: Triggering `performCommandD()`, `saveActiveDocument()`, `saveActiveDocumentAsViaPanel()`, `formatActiveDocument()`, or `formatActiveSection()` while a binary read-only tab is active is blocked both in UI enablement (`HeaderCommandCatalog` + `SwiftEditCommands`) and inside `SwiftEditWorkbenchModel`, leaving `BufferRevision` unchanged and opening zero `NSSavePanel` dialogs (`[DATA-003]`, `[SEC-012]`, `[UI-008]`).
- **Abuse Case 2 — Hover-Flash & Escape-Dismissal Bypass (WCAG 2.2 SC 1.4.13)**: Sweeping the pointer across the header for `< 120 ms`, dragging a tab/sidebar divider, or keeping the pointer stationary on the header after pressing `Escape` never opens or re-opens `HeaderBrandSubmenuView` until pointer exit and re-entry or an explicit click (`[UI-010]`, `[UI-012]`).
- **Abuse Case 3 — Non-Semantic Color Injection in New Submenu Views (`CWE-451`)**: Any `brandGround`, `#RRGGBB`, `Color(.sRGB`, or `NSColor(srgbRed:` introduced in `HeaderBrandSubmenuView.swift` or `SwiftEditCommands.swift` fails `ArchitectureImportScanner.scanSwiftEditUIViewsDirectory` (`[AR-006]`, `[TEST-006]`).

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
