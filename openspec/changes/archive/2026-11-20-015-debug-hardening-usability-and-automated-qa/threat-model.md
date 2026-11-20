# Threat Model: Debug Hardening, Click-Only Accessible Usability & Automated 3x QA Verification

## 1. Asset Boundaries & Trust Zones
- **macOS App Sandbox Shell (`XcodeApp` / `PH.SwiftEdit.app`)**: Unprivileged sandboxed binary (`app-sandbox`, `files.bookmarks.app-scope`, `files.user-selected.read-write`; zero network/files.all entitlements). Receives external Finder AppleEvents (`application(_:open:)` / `.onOpenURL`) and termination signals (`applicationShouldTerminate(_:)`).
- **UI Presentation Ring (`SwiftEditUI`, `@MainActor`)**: Owns TextKit 2 coordinators, per-tab `NSUndoManager` instances, click-only header submenu overlay, gutter, FindBar focus, and transient binary inspection views. Never bypasses domain confinement.
- **Trusted Core Ring (`SwiftEditCore`, Pure Swift 6)**: Enforces symlink confinement (`SEC-003`), binary NUL quarantine (`DATA-003`), bounded `64`-image caps (`CWE-400`), fast URI/image security rules (`SEC-004`), and immutable `BufferRevision` concurrency guards (`CWE-362`).
- **Untrusted Inputs**: Finder-supplied external file URLs, directories containing escaping child symlinks, oversized (`5kL–20kL` / `> 10 MiB`) Markdown files with obfuscated `javascript:`/`file://` URIs or `> 64` images, binary payloads with `0x00` bytes, and corrupted `UserDefaults` preference blobs.

## 2. STRIDE Threat Analysis

| Threat Category | Potential Vector | Security Requirement & Mitigation |
| :--- | :--- | :--- |
| Spoofing | Malicious external `open-doc` URI or unallowlisted Terminal bundle ID attempts to trick shell launch (`BUG-002`, `BUG-017`). | Validate incoming Finder URLs strictly through `DocumentLoader` sandbox/size/NUL gates (`[SEC-002]`, `[SEC-003]`); restrict Terminal launch exclusively to allowlisted `com.apple.Terminal` and `com.googlecode.iterm2` with symlink-verified directory URLs (`[SEC-004]`). |
| Tampering | Shared `NSWindow.undoManager` causes dangling ObjC pointer execution (`CWE-416`, `BUG-001`); dirty quit discards unsaved user documents (`BUG-003`); stale async lint overwrites newer edits (`PERF-006`). | Bind one `NSUndoManager` per `DocumentID` cleared in `dismantleNSView` (`BUG-021`), enforce exhaustive dirty-tab quit prompts, and guard async lint/projection commits against active `(DocumentID, BufferRevision)` (`[BC-004]`). |
| Repudiation | Escaping child symlinks silently ignored without operator awareness (`BUG-017`) or post-fix regressions unverified. | Track `skippedExternalSymlinkCount` in `.skipAndReport` and surface a non-destructive UI warning banner (`[UI-010]`); gate release on automated 3x Debug verification (`[TEST-001]`). |
| Information Disclosure | Opened binary payloads remain retained in `sessionsByID`/`savedBaselineByID` after close/switch (`BUG-007`, `MEM-002`) or leak host preference state (`PERF-003`). | Store binary previews strictly in transient state released on tab change/close (`[DATA-003]`), exclude from `SessionRecovery`/MRU/pinning, and inject `InMemoryKeyValueStore` in tests. |
| Denial of Service | Large `>= 5kL` Markdown files freeze `@MainActor` (`964 ms`) and discard all lint results silently disabling XSS protection (`PERF-006`); multi-paragraph docs admit `70 > 64` images (`BUG-014`); synchronous decoding/layout stalls UI (`PERF-001`, `PERF-002`, `PERF-005`, `PERF-007`). | Run AST lint off `@MainActor` with bounded security fast-path retaining `.unsafeLinkScheme`/`.unsafeImagePath` errors (`[SEC-012]`), enforce document-wide `64`-image counter (`CWE-400`), cache bracket topology, and decode large files/thumbnails off `@MainActor`. |
| Elevation of Privilege | Child symlink inside workspace points to sensitive external target probed for `8 KiB` NUL bytes (`BUG-017`, `CWE-59`) or binary file saved via residual session (`BUG-007`). | Check `resolvingSymlinksInPath()` strictly BEFORE opening file descriptors or probing `8 KiB` bytes under both `.failClosed` and `.skipAndReport` (`[SEC-003]`), and keep binary mutating commands disabled across UI & Core. |

## 3. Abuse Cases & Negative Scenarios
- **Abuse Case 1 — Cross-Tab Undo Use-After-Free (`BUG-001`, `CWE-416`)**: Rapidly editing, invoking FindBar + Format, closing dirty tab B, and pressing `Cmd+Z` in tab A never accesses deallocated undo stack entries or crashes.
- **Abuse Case 2 — Stealth XSS on Large Document (`PERF-006`)**: A `5,000`-line or `20,000`-line Markdown document containing `[xss](javascript:alert(1))` or `![p](../../etc/passwd)` still reports `.unsafeLinkScheme`/`.unsafeImagePath` errors instead of silently timing out to `lint=0`.
- **Abuse Case 3 — Preview Image Cap Bypass (`BUG-014`, `CWE-400`)**: A Markdown document placing `70` valid local images across separate paragraphs admits at most `64` images total, never `70`.
- **Abuse Case 4 — Escaping Child Symlink Probe (`BUG-017`, `CWE-59`)**: Placing a symlink pointing to `/etc/passwd` alongside valid Markdown files in a workspace triggers `.securityScopeViolation` in `.failClosed` mode or skips without probing any bytes while incrementing `skippedExternalSymlinkCount` under `.skipAndReport`.
- **Abuse Case 5 — Quarantined Binary Memory Retention (`BUG-007`, `MEM-002`)**: Opening a `2 MiB` NUL-bearing binary file enables read-only inspection without mutating persistence, disables Save/Format/Pin/Preview/Recovery, and releases `0` residual entries upon switching or closing.
- **Abuse Case 6 — Multi-Tab Dirty Termination Bypass (`BUG-003`)**: Invoking `Cmd+Q` with `>= 2` dirty tabs prompts for every dirty tab sequentially and cancels termination cleanly without data loss if any prompt is canceled.

## 4. Security Review Verdict
- Reviewer: cyber-security-expert
- Date: 2026-11-20
- Verdict: approved
- Open items: none
