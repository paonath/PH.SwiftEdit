# Memory: Repeatable Deep Debug Audit Playbook for PH.SwiftEdit (macOS)

## Metadata

- PatternId: MEMORY-001
- PatternVersion: 1
- Status: active
- Supersedes: -
- CreatedAt: 2026-11-20
- LastValidatedAt: 2026-11-20
- ValidationEvidence: docs/qa/debug-audit-report-2026-11-20.md, docs/qa/debug-verification-report-2026-11-20.md

## Source Context

- Triggering task: Full 3x Debug build, live macOS GUI sweep, stress benchmarks, memory/CPU/leak telemetry, and post-fix verification playbook for `PH.SwiftEdit`.
- Scope/system: `/Users/paoloinnocenti/Documents/git/PH.SwiftEdit` (`macOS 26+ arm64`, Swift `6.2`, `XcodeApp`, `SwiftEditCore`, `SwiftEditUI`, `SwiftEditTests`).
- Date/time: 2026-11-20

## Memory

- Key fact or decision: Repeatable in-depth macOS debugging of `PH.SwiftEdit` requires 5 coordinated layers executed in `.tmp/` (and cleaned afterwards): (1) clean Debug `.app` build + `codesign`/`otool`/design-asset checks, (2) 3x `swift test` runs checking for `cfprefsd` stalls, (3) a compiled Swift `AXUIElement`/`CGEvent`/`NSWorkspace` CLI driver instead of `osascript`, (4) an isolated SwiftPM `QAHarness` executable linking `SwiftEditCore` + `SwiftEditUI` (with `NSWindow.isReleasedWhenClosed = false`, explicit `fflush(stdout)`, and no `removePersistentDomain` in loops) for microbenchmarks and `/usr/bin/leaks --atExit`, and (5) macOS `footprint`, `vmmap --summary`, `sample`, `leaks`, and JSON `.ips` crash parsing.
- Why it matters: Naive macOS automation fails silently or stalls for tens of seconds: `osascript` targeting `System Events` hangs on Automation TCC prompts; `log stream --level debug` amplifies `cfprefsd` custom-suite stalls up to `~86 s`; reading `AXMenuBar` before `runningApp.activate(options: [])` yields `NO_MENUBAR`; and programmatic `NSWindow` instances inside `autoreleasepool` without `isReleasedWhenClosed = false` cause false `SIGSEGV` double-releases in `objc_autoreleasePoolPop` that break `leaks --atExit`. Eliminating those pitfalls cuts a full 3x deep debug cycle to a fast, deterministic, zero-noise verification pass.

## Applicability

- When to reuse:
  - Running a pre-fix baseline audit or post-fix verification sweep (`AutomatedDebugAuditVerification` in spec `015`).
  - Reproducing UI, menu, shortcut, Undo/Redo, Finder `open-doc`, focus, or lifecycle bugs on the real Debug `.app`.
  - Measuring typing/caret/open/preview latency (`min`/`p50`/`p95`/`max`), `phys_footprint`, RSS churn, CPU hotspots (`sample`), and native/ObjC leaks (`leaks`).
- Preconditions/limitations:
  - Terminal/agent host must have Accessibility permission (`AXIsProcessTrusted()`) for `AXUIElement` and `CGEvent` synthesis.
  - All temporary build artifacts, compiled harnesses, logs, and test workspaces MUST stay exclusively inside `./.tmp/` (`DerivedData`, `logs`, `output`, `qa-workspace`, `qa-harness`, `gui-driver`) and MUST be removed on completion so `git status` stays clean.
  - Note for TokenSave MCP queries in this repo: always pass `graph_root: "/Users/paoloinnocenti/Documents/git/PH.SwiftEdit"`.

## Actionable Guidance

- Recommended future action: Execute Phases 0–6 below in order whenever auditing or verifying `PH.SwiftEdit` (minimum 3 runs per check).
- Related files/services/components:
  - [build-app.sh](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Scripts/build-app.sh)
  - [verify-design-assets.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Scripts/verify-design-assets.swift)
  - [SwiftEditApp.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/SwiftEditApp.swift)
  - [SwiftEditRootView.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift)
  - [TextKit2EditorView.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift)
  - [debug-audit-report-2026-11-20.md](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/docs/qa/debug-audit-report-2026-11-20.md)

### Phase 0 — Clean `.tmp/` Workspace & Stray-Process Reset

```bash
pkill -9 -x PH.SwiftEdit 2>/dev/null || true
rm -rf .tmp/{DerivedData,logs,output,qa-workspace,qa-harness,gui-driver}
mkdir -p .tmp/{DerivedData,logs,output,qa-workspace,qa-harness,gui-driver}
```

### Phase 1 — Clean Debug `.app` Build, Codesign, Linking & Design Assets

```bash
time ./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData \
  > .tmp/logs/xcodebuild-debug.log 2>&1
echo "BUILD_EXIT=$?"

APP_PATH=".tmp/DerivedData/Build/Products/Debug/PH.SwiftEdit.app"
BIN_PATH="$APP_PATH/Contents/MacOS/PH.SwiftEdit"

# Verify Sandbox entitlements (no network, no files.all, no temporary-exception)
codesign -dvvv --entitlements - "$APP_PATH" > .tmp/output/codesign-entitlements.txt 2>&1

# Verify 0 external/WebKit/Network dynamic libraries
otool -L "$BIN_PATH" > .tmp/output/otool-links.txt

# Verify bundle version & design asset integrity
plutil -p "$APP_PATH/Contents/Info.plist" | grep -E "CFBundle(Identifier|ShortVersionString|Version)|MinimumSystemVersion"
swift Scripts/verify-design-assets.swift
```

Check `.tmp/logs/xcodebuild-debug.log` for compiler/build warnings (`ALWAYS_SEARCH_USER_PATHS`, `AppIntents`, script `alwaysOutOfDate` warnings).

### Phase 2 — SwiftPM Unit & Fitness Suite (`>= 3x`)

```bash
for run in 1 2 3; do
  echo "=== SWIFT_TEST_RUN_$run ==="
  /usr/bin/time -p swift test > ".tmp/logs/swift-test-run$run.log" 2>&1
  tail -n 12 ".tmp/logs/swift-test-run$run.log"
done
```

Watch wall-clock time: `removePersistentDomain(forName:)` calls serialize on `cfprefsd` and inflate runs to `41–91 s`; post-fix target is `< 10 s` deterministic across all 3 runs with 0 failures.

### Phase 3 — Compiled Swift AX/CGEvent Live GUI Sweep (`>= 3x` per feature)

#### Critical Automation Rules on macOS
1. **Never use `osascript -e 'tell application "System Events"...'`**: hangs waiting on macOS Automation TCC consent.
2. **Compile a native Swift CLI driver** in `.tmp/gui-driver/axdriver.swift` (`swiftc -O -framework ApplicationServices -framework Cocoa .tmp/gui-driver/axdriver.swift -o .tmp/gui-driver/axdriver`).
3. **Always activate before menu queries**: `runningApp.activate(options: [])` (avoid deprecated `.activateIgnoringOtherApps`) before reading `kAXMenuBarAttribute`, otherwise `AXUIElementCopyAttributeValue` returns `NO_MENUBAR`.
4. **Never attach `log stream --level debug` during timed launches**: it amplifies `cfprefsd` stalls up to `~86 s`. If unified logging is needed, capture separately with `--level default`:
   ```bash
   log stream --level default --style compact --predicate 'process == "PH.SwiftEdit"' > .tmp/logs/unified-live.log 2>&1 &
   LOG_PID=$!
   ```
5. **Kill AppKit saved state / zombie restarts between fresh launches** so every cold launch starts clean:
   ```bash
   defaults delete it.ph.SwiftEdit NSQuitAlwaysKeepsWindows 2>/dev/null || true
   rm -rf ~/Library/Saved\ Application\ State/it.ph.SwiftEdit.savedState 2>/dev/null || true
   ```

#### Recommended Subcommands for `.tmp/gui-driver/axdriver.swift`
Build the single-file driver supporting:
- `launch <app-path>` — `NSWorkspace.shared.openApplication`, waits for window (`WINDOW_READY_MS`), prints PID and readiness latency.
- `open-doc <app-path> <file-path>` — `NSWorkspace.shared.open([fileURL], withApplicationAt: appURL)` to test Finder/`application(_:open:)` handoff cleanly without closing existing docs first.
- `dump-menus <pid>` — `activate(options: [])`, recursively dumps every `AXMenuBarItem` / `AXMenuItem` with shortcut glyph and `AXEnabled` state (`Cmd+H` vs `Opt+Cmd+F`, single vs duplicate `Redo`).
- `press-menu <pid> <menu> <item>` — invokes `kAXPressAction` on the exact menu item.
- `dump-tree <pid>` — dumps `AXWindow` role/title/frame hierarchy (`AXButton`, `AXTextField`, `AXTextArea`, `AXStaticText`, `AXCheckBox`, `AXRadioButton`).
- `find-press <pid> <title-or-desc-substring>` — locates matching clickable AX control (`Logo`, `Replace`, `Fix All`, `Don't Save`, `Save`, `Cancel`, etc.) and fires `kAXPressAction`.
- `hover <pid> <x> <y> <duration-ms>` — synthesizes real `CGEvent(.mouseMoved, ...)` over the top-left `PH.SwiftEdit` logo center (`minX + 70, minY + 18`) and waits `duration-ms` (verify **no auto-open** on hover!).
- `focus-editor <pid>` / `get-editor <pid>` — queries first `AXTextArea` (`kAXFocusedAttribute`, `kAXNumberOfCharactersAttribute`, `kAXSelectedTextRangeAttribute`, `kAXValueAttribute`).
- `set-textfield <pid> <placeholder-or-index> <value>` — writes AX value + Return/focus check.
- `key <pid> <keyname> [cmd,shift,opt,ctrl]` — synthesizes `CGEvent(keyboardEventSource:...)` (`Cmd+N/O/S/W/Q/Z/Y/A/C/V/D/F/P/G/B`, `Opt+Cmd+F`, `Shift+Cmd+Z`, `Shift+Cmd+M`, `Opt+\`, `Opt+1`, `Escape`, `Down/Up/Return`).
- `is-hidden <pid>` / `unhide <pid>` — checks `NSRunningApplication(processIdentifier:)?.isHidden` (detects `Cmd+H` collision immediately).
- `quit <pid>` / `force-quit <pid>` — calls `NSRunningApplication.terminate()`, polls up to `2.0 s` (`IS_TERMINATED=true/false`), then `forceTerminate()`.

#### Live GUI Checklist (`3x` Pass)
1. **Menu Bar Inspection**: `Cmd+H` bound strictly to `Hide PH.SwiftEdit`; `Find and Replace…` bound to `Opt+Cmd+F`; single enabled/disabled `Redo` (`Shift+Cmd+Z`); zero duplicate `Redo (Cmd+Y)`.
2. **External Finder Open (`open-doc`)** x3 on fresh processes: active `AXTextArea` reflects opened file text (not default `Welcome.md`).
3. **Header Brand Logo Submenu UX & Accessibility** x3:
   - Hover logo for `>= 700 ms` -> submenu stays **CLOSED** (0 hover auto-open, 0 layout shift).
   - Click logo button -> submenu opens in `0 ms` and stays **STICKY OPEN** at `40 ms`, `280 ms`, and `1000 ms`; navigate items with `Down`/`Up` + `Return`, verify `AXExpanded` / `AXFocused` state, verify `Escape` & outside click close cleanly.
4. **Editor Undo Safety & Tab Stress (`BUG-001` / `BUG-005` Repro)** x3:
   - Edit text -> `Cmd+D` -> `Cmd+Z` (text restores to exact pre-`Cmd+D` content & selection).
   - Open tab A & tab B -> type, `Cmd+D`, `Bold`, `Format Markdown Section`, open FindBar & type -> close tab B (`Cmd+W` -> `Don't Save`) -> `Cmd+Z` in tab A & re-switch tabs -> `0` crashes!
5. **Find / Replace / Go-to-Line (`BUG-008` / `BUG-009`)** x3:
   - `Cmd+F` auto-focuses Find field; `Opt+Cmd+F` auto-focuses without hiding app (`is-hidden == false`); single `Replace` replaces 1 match (leaving remaining count decremented by 1); `Next`/`Prev` and `Cmd+G` bump selection and scroll editor into view; `Escape` closes bar and returns focus to editor.
6. **Preview / Diff / Sidebar / Gutter / Modals (`>= 3x`)**:
   - `Cmd+P` renders ordered lists (`1., 2.`) + HTML adjacent to GFM table + respects 64-image cap; Diff shows red LHS + green RHS on modified lines; Sidebar mounts folder with external child symlink safely (banner shown, valid siblings accessible); Distraction-Free (`Opt+1`) + `Escape` returns focus cleanly; CheatSheet (`Cmd+/`) & About show `0.0.1-alpha5` + Diff/Markdown/Opt+Cmd+F entries.
7. **Dirty Quit (`Cmd+Q`) & Graceful `terminate()`** x3 on fresh processes:
   - Dirty multiple tabs -> `Cmd+Q` blocks exit and displays `Unsaved Changes` prompt iterating ALL dirty tabs until saved or canceled (`Cancel` keeps all tabs alive).
   - Clean window -> `NSRunningApplication.terminate()` exits with `IS_TERMINATED=true` within `2.0 s`.

### Phase 4 — In-Process SwiftPM `QAHarness` (Core Stress, Benchmarks, Real-Window `--leak-check`)

Scaffold a temporary SwiftPM executable target inside `.tmp/qa-harness/` pointing cleanly at repo path `../..` (so `Package.swift` stays untouched):

#### Critical `QAHarness` Coding Rules
1. **Window double-release prevention**: Whenever instantiating a headless `NSWindow` wrapping `NSHostingView(rootView: SwiftEditRootView())` inside `autoreleasepool`, set:
   ```swift
   window.isReleasedWhenClosed = false
   ```
   Without this, `window.close()` + `objc_autoreleasePoolPop` triggers a false `SIGSEGV` crash and aborts `/usr/bin/leaks --atExit`.
2. **Unbuffered log flushing**: Call `fflush(stdout)` after every benchmark/check line when redirecting `>`.
3. **Avoid `UserDefaults.removePersistentDomain`**: Use `InMemoryKeyValueStore` (or fixed suite + `removeObject(forKey:)`) in tight harness/benchmark loops.

Run both modes 3 times each:
- `QAHarness --functional`: verifies all A–G areas (multi-tab dirty `.save`, CR-only `Cmd+D` + `previewSourceLine`, binary inspection lifecycle & release, symlink policy `.failClosed` vs `.skipAndReport`, TextKit 2 gutter scroll sync & wrapped current-line rect, `DiffHunkKind.modified`, `HTML+Table`, 70-image -> 64-cap, bracket cache hit/miss).
- `QAHarness --bench` (runs `50/50/20/5` edits for `50/500/5000/20000L` Markdown docs containing `[xss](javascript:alert(1))`): verifies:
  - Typing `p99 <= 16 ms` at `50L`, `500L`, `5,000L`, and `20,000L`
  - **Security parity**: `.unsafeLinkScheme` diagnostics count `> 0` even at `5,000L` and `20,000L` (never `lint=0`!)
  - Caret move `10,000L` `p99 <= 16 ms`
  - File open `5 MiB` & `12 MiB` non-blocking Main Thread (`<= 50 ms`)
  - 20-model open/edit/close churn: `survivingModels == 0/20`, `tabsLeft == 0`, `sessionsLeft == 0`, `baselinesLeft == 0`, non-monotonically exploding RSS.

### Phase 5 — Memory, Leak, CPU Hotspot & Crash Telemetry Commands

Run against live Debug `PH.SwiftEdit` (`$PID`) and `QAHarness`:

```bash
# 1. Process RSS / VSZ / CPU
ps -o pid,rss,vsz,%cpu,etime -p "$PID"

# 2. Detailed dirty / reclaimable / CoreAnimation / IOSurface / Malloc footprint
footprint "$PID" > .tmp/output/footprint-live.txt

# 3. VM zone fragmentation & Allocation breakdown
vmmap --summary "$PID" > .tmp/output/vmmap-summary.txt

# 4. 3-second CPU stack sample (diagnoses main-thread AST/layout bottlenecks)
sample "$PID" 3 -file .tmp/output/sample-3s.txt

# 5. Live process leak scan
leaks "$PID" > .tmp/output/leaks-live.txt

# 6. Process-exit deterministic leak check (requires isReleasedWhenClosed = false)
/usr/bin/leaks --atExit -- .tmp/qa-harness/.build/debug/QAHarness --leak-check \
  > .tmp/output/leaks-at-exit.txt 2>&1
```

#### Inspecting macOS `.ips` Crash Reports (if any crash occurs)

```bash
ls -lt ~/Library/Logs/DiagnosticReports/*SwiftEdit* | head -n 5
python3 - <<'PY'
import glob, json
files = sorted(glob.glob('/Users/paoloinnocenti/Library/Logs/DiagnosticReports/*SwiftEdit*.ips'))
if not files:
    print("NO_CRASH_REPORTS")
else:
    latest = files[-1]
    lines = open(latest).read().splitlines()
    header = json.loads(lines[0])
    body = json.loads("\n".join(lines[1:]))
    print("FILE:", latest)
    print("HEADER:", header.get("bug_type"), header.get("timestamp"))
    print("EXCEPTION:", body.get("exception"), body.get("termination"))
    ft = body.get("faultingThread", 0)
    frames = body.get("threads", [])[ft].get("frames", [])
    imgs = body.get("usedImages", [])
    for i, f in enumerate(frames[:20]):
        img = imgs[f["imageIndex"]]["name"] if "imageIndex" in f else "?"
        print(f"#{i:02d} {img} :: {f.get('symbol','<nosym>')} (+{f.get('symbolLocation',0)})")
PY
```

### Phase 6 — Acceptance Thresholds & Mandatory Cleanliness Verification

| Gate Metric | Target Threshold |
| :--- | :--- |
| Crashes (`.ips`, live `SIGSEGV`, double-release) | `0` |
| App Swift/ObjC Leaks (`leaks --atExit` & live non-Apple roots) | `0 leaks` |
| Idle Dirty Footprint (`1 MiB` doc / empty window) | `<= 50 MB` |
| Post-Sweep 3x Live Footprint | `< 80 MB` |
| P99 Keystroke Latency (`50L`..`20,000L`) | `<= 16 ms` |
| P99 Caret Move Latency (`10,000L`) | `<= 16 ms` |
| Security Lint on Large Docs (`>= 5kL` / `20kL`) | `.unsafeLinkScheme` `> 0` (never silently `0`) |
| `swift test` 3x Wall Clock | `< 10 s` per run (`100% PASS`) |
| Header Brand Submenu | Click/key open `0 ms`; stays open on hover/gap `>= 1000 ms`; `0` hover auto-open |

### Verified Post-Fix Baseline & Security Gate Evidence (2026-11-20)

- **Reference Report**: `docs/qa/debug-verification-report-2026-11-20.md` (Change `015-debug-hardening-usability-and-automated-qa`).
- **Test Speed & Pass Rate**: 3x `swift test --parallel` passed `186 tests in 53 suites` in `3.163 s / 2.014 s / 2.045 s` wall clock (`0.849–0.940 s` runner).
- **Performance (Worst of 3x `QAHarness --bench`)**: `t50_p99=1.803 ms`, `t500_p99=0.062 ms`, `t5k_p99=0.022 ms`, `t20k_p99=0.025 ms`, `caret10k_p99=0.005 ms`, `open12m_main_ms=0.01 ms`, `sec5k=2`, `sec20k=2`, `surviving=0`.
- **Memory & Leaks**: `leaks --atExit` on `QAHarness --leak-check`: `42.0M` (`42.1M` peak), `0 leaks`; live `PH.SwiftEdit.app` (`README.md`): `62.4M`, `0 leaks`; idle `57 MB` raw (`37.8 MB` non-graphics); post-3x-sweep `86 MB` raw (`72.0 MB` non-reclaimable excl. `14 MB` IOSurface, `67.6 MB` non-graphics).
- **Security Gate Evidence**:
  - `codesign -dvvv --entitlements -`: `com.apple.security.app-sandbox=true`, `bookmarks.app-scope=true`, `user-selected.read-write=true`, `get-task-allow=true`, `0` forbidden entitlements.
  - `otool -L`: `0` `WebKit`, `Network`, or `CFNetwork` linkages.
  - `QAHarness --functional` 3x: `symlink_escape_reads=0`, `skipped_symlinks=1`, `image_slots=70`.
  - Automated gate deterministically exited `1` on injected failures (`--self-test-fail`) and `0` on verified metrics.

Always execute final cleanup before reporting results:

```bash
pkill -9 -x PH.SwiftEdit 2>/dev/null || true
rm -rf .tmp/{DerivedData,logs,output,qa-workspace,qa-harness,gui-driver}
defaults delete qa.harness.prefs 2>/dev/null || true
defaults delete qa.harness.recents 2>/dev/null || true
git status -sb
```
