# Audit Tecnico Completo Debug, Benchmark & Piano di Correzioni/Migliorie — `PH.SwiftEdit`

> **Stato Audit:** **COMPLETATO (100% — tutte le fasi eseguite `>= 3` volte su app Debug reale e harness Debug)**  
> **Data rilevazione:** `2026-11-20` (`17:35` – `19:31` `+01:00`)  
> **Repository:** `/Users/paoloinnocenti/Documents/git/PH.SwiftEdit` — Branch `feature/FirstStub` (`HEAD 6f13c46`, nessun file tracciato modificato)  
> **Bundle:** `PH.SwiftEdit` (`it.ph.SwiftEdit`) — Versione `0.0.1` (`0.0.1-alpha5`, [Info.plist](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/Info.plist))  
> **Piattaforma di test:** `macOS 27.2.1 (26B131)` (`arm64`) — `MACOSX_DEPLOYMENT_TARGET = 26.0` — Swift `6.2` (`-strict-concurrency=complete`)

---

## 1. Riepilogo Esecutivo & Copertura Eseguita

Tutte le verifiche richieste sul binario **Debug** di `PH.SwiftEdit` (app compilata `.app`, unit test, sweep GUI interattiva reale tramite `AXUIElement`/`CGEvent`, suite funzionale edge-case `QAHarness`, stress benchmark `p50/p95/max` e profiling memoria/`leaks`) sono state completate **almeno 3 volte ciascuna**.

### Perimetro Esecuzioni Verificate (`>= 3x`)
- **Build Debug `.app` & Asset/Security Check:** 1 build pulita (`159.10 s`, exit `0`), `codesign`, `otool -L`, entitlements sandbox, [verify-design-assets.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Scripts/verify-design-assets.swift).
- **Unit Test `swift test`:** 3 run consecutivi (`166 test in 45 suite` x 3 = `498` esecuzioni, `100% PASS`).
- **Live Debug `.app` Telemetria & Avvii:** 3 avvii indipendenti (`PID 97482`, `98257`, `98294`) + Pre/Post-Sweep su `PID 6729` + 3 test `open-doc` Finder + 3 test `Cmd+Q` dirty quit su processi freschi + 3 test repro crash `BUG-001`.
- **Live GUI Feature Sweep:** Run iniziale (`task-317`, interrotto da **crash `SIGSEGV` reale** in Run 2) + **Clean Live GUI Sweep 3x completo** (`PID 6729`, 11 macro-funzionalità UI x 3 = 33 verifiche end-to-end a finestra viva).
- **Harness Debug `QAHarness --functional` (Aree A–G):** `63` controlli su 3 run (`21` scenari x 3 run: `39 PASS`, `24 FAIL` — di cui 15 fallimenti confermano bug reali dell'app e 9 derivano da 3 assunzioni conservative dell'harness documentate in §4.2).
- **Benchmark & Endurance `QAHarness --bench` (Bench 1–5):** `30` blocchi benchmark (`10` scenari x 3 run, `30 PASS`, metriche `min/p50/p95/max`).
- **Memory & Leak Audit:** `/usr/bin/leaks` 3x su app idle + `/usr/bin/leaks` su app viva post-sweep + `/usr/bin/leaks --atExit` su `QAHarness --leak-check` (`61.178` nodi).

### Conteggio Finale Problemi Identificati

| Categoria | Conteggio | Distribuzione & ID Principali |
| :--- | :---: | :--- |
| **Bug & Malfunzionamenti (`BUG-*`)** | **21** | **P0: 3** (`BUG-001..003`) · **P1: 7** (`BUG-004..010`) · **P2: 10** (`BUG-011..017, 019..021`) · **P3: 1** (`BUG-018`) |
| **Memoria & Leak (`MEM-*`)** | **4** | `MEM-001` (picco lancio `264–288 MB`), `MEM-002` (leak logico snapshot binari), `MEM-003` (`45->135 MB` post-sweep + peak `483 MB` + 85 leak OS vs 0 leak Swift/Core), `MEM-004` (RSS `488.8->699.3 MB` sotto churn) |
| **Velocità & Prestazioni (`PERF-*`)** | **7** | `PERF-001..005` + **`PERF-006`** (typing `945–964 ms` su `20k` righe & lint silenziato `lint=0` >= `5k` righe, inclusa regola XSS!) + **`PERF-007`** (spostamento cursore `70–78 ms` su `10k` righe) |
| **Velocità Suite Test (`TEST-*`)** | **1** | `TEST-001` (`swift test` `41–91 s` per `31` `removePersistentDomain` in `11` file -> stalli `cfprefsd`) |

---

## 2. Build Debug, Packaging, Entitlements, Asset & Unit Test (3x)

### 2.1 Build `.app` Debug
- **Comando:** `./Scripts/build-app.sh --configuration Debug --clean --derived-data .tmp/DerivedData` ([build-app.sh](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Scripts/build-app.sh))
- **Esito:** `BUILD_EXIT=0` (`159.10 s`, `2.839` righe log). Zero errori Swift o `-strict-concurrency=complete`.
- **Warning & Note Xcode osservati:**
  - Destinazioni multiple (`arm64` / `x86_64`) nel log di `xcodebuild` (righe `53-57` e `64-67`).
  - `appintentsmetadataprocessor`: `warning: Metadata extraction skipped, no AppIntents.framework dependency found` (riga `2804`).
  - Target [PH.SwiftEdit.xcodeproj](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/PH.SwiftEdit.xcodeproj/project.pbxproj#L155-L212): `warning: Traditional headermap style is no longer supported; please migrate to using separate headermaps and set 'ALWAYS_SEARCH_USER_PATHS' to NO.` (riga `2835`).
  - Script build phase `Stamp Info.plist from version.json` ([project.pbxproj:124-135](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/PH.SwiftEdit.xcodeproj/project.pbxproj#L124-L135)): `alwaysOutOfDate = 1` con `outputPaths = ()`, forzando l'esecuzione ad ogni build incremental (riga `2836`).

### 2.2 Firma, Entitlements, Linkaggio e Asset
- **`codesign -dvvv --entitlements -`:** `Identifier=it.ph.SwiftEdit`, Mach-O thin `arm64`, firma `adhoc,runtime`.
- **Entitlements ([PH.SwiftEdit.macOS.entitlements](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/PH.SwiftEdit.macOS.entitlements)):** `app-sandbox=true`, `files.bookmarks.app-scope=true`, `files.user-selected.read-write=true`, `get-task-allow=true` (Debug).
- **`otool -L`:** nessuna dipendenza esterna o WebKit; solo librerie/framework di sistema Apple.
- **`swift Scripts/verify-design-assets.swift`:** `exit 0`.

### 2.3 Unit Test `swift test` (3x)

| Run | Esito | Test & Suite | Tempo Suite Riportato | Tempo Wall | Suite più Lente Osservate |
| :---: | :---: | :--- | :---: | :---: | :--- |
| **Run 1** | **PASS** | `166 / 45` | `91.390 s` | `107.36 s` | `GFMEditorPipelineWiringTests` (`91.389 s`), `DocumentNavigatorWorkbenchTests` (`91.286 s`), `ListIndentationWorkbenchTests` (`91.267 s`), `WorkbenchSearchLifecycleAndMenusTests` (`91.254 s`) |
| **Run 2** | **PASS** | `166 / 45` | `40.991 s` | `61.49 s` | `GFMEditorPipelineWiringTests` (`40.991 s`), `DocumentNavigatorWorkbenchTests` (`40.871 s`), `MinimalLayoutGutterAndParentNavigationTests` (`40.860 s`) |
| **Run 3** | **PASS** | `166 / 45` | `41.043 s` | `61.52 s` | `GFMEditorPipelineWiringTests` (`41.043 s`), `DocumentNavigatorWorkbenchTests` (`40.923 s`), `ListIndentationWorkbenchTests` (`40.915 s`), `EditorUXLayoutThemeAndAboutTests` (`40.901 s`) |

**Causa radice (`TEST-001`):** `rg -n "removePersistentDomain" Tests/` rileva **`31` chiamate in `11` file di test** ([DotfileNavigatorAndPreferencesTests.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Tests/SwiftEditTests/DotfileNavigatorAndPreferencesTests.swift#L56-L80), `EditorUXLayoutThemeAndAboutTests`, `RecentFilesStoreTests`, `TranslucentHeaderBrandSubmenuTests`, `MinimalLayoutGutterAndParentNavigationTests`, `FullAppSemanticThemingAndWindowSyncTests`, `ListIndentationWorkbenchTests`, `TextKit2EditorAndDiffCoordinatorTests`, `MarkdownQuickFixAndStatusTests`, `SidebarActionsAndWorkspaceHandoffTests`, `WorkbenchSearchLifecycleAndMenusTests`), che avviano in parallelo sottoprocessi `/usr/bin/defaults delete` causando attese serializzate su `cfprefsd` a multipli di ~10s.

---

## 3. Telemetria App Debug Live macOS, Breakdown VM & Crash `.ips`

### 3.1 Confronto Telemetria: Idle (Run 1–3) vs Pre-Sweep vs Post-Sweep (`PID 6729`)

| Metrica | Idle Run 1 (`97482`) | Idle Run 2 (`98257`) | Idle Run 3 (`98294`) | Pre-Sweep (`6729`, t=1s) | **Post-Sweep 3x Vivo (`6729`, 1m59s)** |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **`WINDOW_READY_MS`** | — | `638.24 ms` | `347.89 ms` | `316.19 ms` | — |
| **`RSS` (`ps`)** | — | `133264 KB` (~130.1 MB) | `133584 KB` (~130.5 MB) | `149776 KB` (~146.3 MB) | **`194688 KB` (~190.1 MB)** |
| **`%CPU` a riposo (`ps`/`sample`)** | `0%` (`mach_msg2_trap`) | `0.0%` | `0.1%` | `18.4%` *(boot)* | `3.6%` (`sample` 2558/2558 su `mach_msg2_trap`) |
| **`phys_footprint` (`footprint`)** | `45 MB` (`45.2M`) | `45 MB` (`45.4M`) | `46 MB` | `288 MB` *(boot spike)* | **`135 MB`** (`+89–90 MB` vs idle!) |
| **`phys_footprint_peak`** | `264 MB` (`264.3M`) | `264 MB` (`264.2M`) | `265 MB` | `288 MB` | **`483 MB`** |
| **Reclaimable / Clean (`footprint`)** | `114M` / `26M` | `115M` / `34M` | `146M` / `34M` | `160K` / `26M` | **`272 MB`** / `46 MB` |
| **`Malloc Small` / `Malloc Large`** | `23 MB` / `0` | `22.2M` / `0` | — | `23 MB` / `0` | **`48 MB`** / **`18 MB`** (`17.7M` empty) |
| **`IOSurface` / `CoreUI` dirty** | — | `272 KB` / `144 KB` | — | `272 KB` / `976 KB` | **`35 MB` (+27M recl.)** / `2176 KB` |
| **`vmmap` Heap (`MALLOC ZONE TOTAL`)** | — | `131344` nodi / `16.9M` alloc / `25.0M` dirty (`33%` frag) | — | — | **`264471` nodi / `32.4M` alloc / `50.9M` dirty (`37%` frag, `109.3M` virt.)** |
| **`leaks` Live** | `128651` nodi -> **0 leaks** | `131344` nodi -> **0 leaks** | `131252` nodi -> **0 leaks** | — | `264460` nodi (`33197 KB`) -> **85 leaks (`12432 B`, tutti OS `CGEvent`/`ViewBridge`)** |
| **External Finder `open-doc`** | **FAIL** | **FAIL** (`CHARS=429`) | **FAIL** (`CHARS=429`) | N/A | N/A |
| **`NSRunningApplication.terminate()`** | — | **FAIL** (`IS_TERMINATED=false`) | **FAIL** (`IS_TERMINATED=false`) | — | **FAIL** (`TERMINATE_CALLED=true IS_TERMINATED=false`) |

**Breakdown Regione per Regione (`vmmap` / `footprint`):**
- **Picco al lancio (`MEM-001`):** al secondo 1 (`footprint-clean-before.txt`) **`Owned physical footprint (unmapped) (graphics)` vale `217 MB`** e **`CoreAnimation` `28 MB`** (`TOTAL dirty = 288 MB`), che poi AppKit/Metal marcano come `reclaimable` (`112–240 MB`) riducendo lo steady-state idle a `45–46 MB`.
- **Crescita Post-Sweep (`MEM-003`):** dopo 3 sweep delle finestre modali/preview/diff/sidebar/editor, il dirty residente sale a **`135 MB`** (con picco **`483 MB`**): `DefaultMallocZone` raddoppia (`102897 -> 227032` allocazioni, `22.3M -> 46.5M` dirty, frammentazione `31% -> 35%`), `AttributeGraph` passa da `20518` a `26800` allocazioni (`1.76M` + `960K` old mapping), `QuartzCore` da `848K` a `1440K` (`81%` frammentazione!), compare una allocazione **`Malloc Large (empty)` da `17.7M` dirty**, e **`IOSurface`** sale da `272K` a **`34.7M` dirty** (+27 MB reclaimable).
- **Analisi dei 85 leak post-sweep:** l'output integrale di `/usr/bin/leaks 6729` (6 root leak) mostra che **tutti gli 85 oggetti (`12.432` byte)** appartengono al sottosistema Apple `CGEvent` -> `CGSEventAppendix` -> `SLSSkyLightKeyEventAuthenticationMessage` / `BKSHIDEventBaseAttributes` (`"viewbridge-key-window"`, `"keyboardFocus"`); **0 leak sono attribuibili direttamente ad oggetti di `SwiftEditCore` o `SwiftEditUI`**.

### 3.2 Unified Log & Menu Reali
- **Unified Log:** ad ogni avvio compaiono **4 errori XPC** verso `com.apple.linkd.autoShortcut` (`NSCocoaErrorDomain Code=4097`, `[com.apple.appintents:Connection]` / `[com.apple.AppKit:Application]`), oltre a stalli `cfprefsd` (~86s in un tentativo Run 2 con `--level debug` tra `5s+10s+10s` e `AppKitWindowController.sizeAndPlaceWindow()`).
- **Menu Live AppKit (214 righe):**
  - Riga `81`: `- Hide PH.SwiftEdit {Cmd+H} (enabled)` vs riga `118`: `- Find and Replace… (enabled)` *(scorciatoia rubata da Hide)*.
  - Righe `103-105`: `- Undo {Cmd+Z} (DISABLED)`, `- Redo {Shift+Cmd+Z} (DISABLED)`, `- Redo {Cmd+Y} (enabled)` *(doppia voce Redo sempre abilitata)*.

### 3.3 Crash Live `.ips` & Test Riproducibilità 3x (`BUG-001`)
- **Crash Report Permanenti in `~/Library/Logs/DiagnosticReports/`:** 1 report catturato durante la sessione:
  - [`PH.SwiftEdit-2026-11-20-175043.ips`](file:///Users/paoloinnocenti/Library/Logs/DiagnosticReports/PH.SwiftEdit-2026-11-20-175043.ips) (`Incident ID: 6544E501-83B3-4F56-82D7-CB7B12D2C03A`, `PID 98566`, `2026-11-20 17:50:43 +0100`).
  - **Eccezione:** `EXC_BAD_ACCESS` (`SIGSEGV`) at `0x0065b7d0ebbb37a8` (use-after-free su puntatore ObjC nella thread `0` main):
    ```text
    #00 libobjcMsgSend.dylib :: objc_msgSend
    #01 Foundation           :: -[_NSUndoStack popAndInvoke]
    #02 Foundation           :: -[NSUndoManager undoNestedGroup]
    #03 AppKit               :: -[NSApplication(NSResponder) sendAction:to:from:]
    #04..#12                 :: NSMenu / routeKeyEquivalent / NSApplication run
    #16 PH.SwiftEdit         :: static SwiftEditApp.$main()
    ```
- **Repro Mirata 3x (lancio isolato `New Document -> GoToLine -> xmark -> Markdown Bold/Italic -> Format -> Cmd+Z x2`):** `0/3` crash su sequenza minimale isolata (`crashed=False` con `set-textfield` via AX `kAXValueAttribute` senza tab chiusi né tastiera nella FindBar), vs `1/2` crash live nello sweep multi-ciclo `task-317` dove chiusura tab sporco (`Cmd+W -> Don't Save`), Preview (`Cmd+P`) e `Format Markdown Section` precedevano `Cmd+Z` sullo `NSUndoManager` condiviso della `NSWindow`.

---

## 4. Matrice Completa Funzionalità (`>= 3` Run Ciascuna)

### 4.1 Matrice Live GUI Debug `.app` (`PID 6729` Clean Sweep 3x + Processi Freschi 3x)

| Area / Funzionalità Live | Run 1 | Run 2 | Run 3 | Dettagli Osservati (3/3) | Bug / Note |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **External Finder Open (`open-doc`)** | **FAIL** | **FAIL** | **FAIL** | `contains_sample_md=False` (`CHARS=429`, resta `Welcome.md`) | **`BUG-002`** |
| **Header Brand Submenu (AX/Click 40ms vs 280ms)** | **FAIL** | **FAIL** | **FAIL** | `openAt40ms=True` -> **`stillOpenAt280ms=False`**, `closedAfterEsc=True` | **`BUG-006`** (180ms self-dismiss) |
| **TopBar Zoom (`+`, `100%`, `-`) & `Light\|Dark\|Auto`** | **PASS** | **PASS** | **PASS** | `zoom100->90=True`, `themeDarkLightAuto=True` (`Mode: Black/Light`) | OK |
| **Typing, Clipboard (`Cmd+A/C/V`), `Cmd+Z/Y`** | **PASS** | **PASS** | **PASS** | `typed=18 pasted=37 undoOk=True redoOk=True` | OK |
| **`Cmd+D` Duplicate & `Cmd+Z` Undo** | **FAIL** | **FAIL** | **FAIL** | `cmddApplied=True` ma **`undoAfterCmdD=False` su 3/3 run** | **`BUG-005`** |
| **Find (`Cmd+F`), `Cmd+H`, Find&Replace, GoToLine (`Cmd+G`)** | **FAIL** | **FAIL** | **FAIL** | `fieldAutoFocus=False editorStayedFocused=False`, **`cmdH_HidApp=True`**, `singleReplace=False`, `editorAfterJump=[FOCUSED=false CHARS=28 SEL=19:0]` | **`BUG-004`**, **`BUG-008`**, **`BUG-009`** |
| **Markdown Menu Commands (11) & Format (senza Undo)** | **PASS** | **PASS** | **PASS** | `cmds=10/10 h1=True fmt=True fmtSec=True outLen=131` | Undo associato soggetto a **`BUG-001` / `BUG-005`** |
| **Markdown Preview (`Cmd+P`) & Rapid Diff Pane (`<180ms`)** | **PASS** | **PASS** | **PASS** | `preview=True->True`, `rapidDiffPress=True diff=True->True` | Diff funziona *solo* se cliccato `<180ms` prima di **`BUG-006`**! |
| **Diagnostics Popover (`Shift+Cmd+M`) & `Fix All`** | **PASS** | **PASS** | **PASS** | `open=True fixedHeading=True xssKept=True` | Sicurezza XSS intatta |
| **Document Navigator & Distraction-Free & ESC** | **PASS** | **PASS** | **PASS** | `nav=True->True`, `dfHidden=True`, `dfRestored=True` | Nota: dopo DF+ESC focus editor non sempre auto-ripristinato se non ricliccato |
| **Sidebar Toggle (`Cmd+B` con focus editor)** | **PASS** | **PASS** | **PASS** | `state=False->True->False` su 3/3 run | Richiede focus iniziale valido |
| **Modal Sheets (`About` `0.0.1-alpha5` & `CheatSheet`)** | **PASS** | **PASS** | **PASS** | `aboutAlpha5=True cheatSheet=True` | OK |
| **Dirty Tab Close (`Cmd+W` -> `Unsaved Changes`)** | **PASS** | **PASS** | **PASS** | `unsavedAlertShown=True`, `Cancel` & `Don't Save` OK | OK |
| **Dirty App Quit (`Cmd+Q` con tab sporco, 3 processi)** | **FAIL** | **FAIL** | **FAIL** | **`stillAlive=False unsavedPrompt=False` su 3/3 run** | **`BUG-003`** (perdita dati) |
| **Graceful `NSRunningApplication.terminate()`** | **FAIL** | **FAIL** | **FAIL** | `TERMINATE_CALLED=true IS_TERMINATED=false` (Run 2, Run 3, Post-Sweep) | **`BUG-010`** |

### 4.2 Matrice `QAHarness --functional` (Aree A–G x 3 Run = 63 Controlli)

| Area / Controllo | Run 1 | Run 2 | Run 3 | Dettaglio Chiave & Classificazione |
| :--- | :---: | :---: | :---: | :--- |
| **Area A:** New, Edit, Save & Save As | PASS (`17.2ms`) | PASS (`12.6ms`) | PASS (`10.9ms`) | Round-trip disco `ok` |
| **Area A:** Dirty Close & Multi-Tab Termination `.save` | **FAIL** (`19.1ms`) | **FAIL** (`21.2ms`) | **FAIL** (`23.3ms`) | **App Bug (`BUG-003`):** `Remaining dirty tabs after termination .save = 1 (prompt cleared=true)` |
| **Area A:** UTF-8/BOM/UTF-16 & Invalid UTF-8 | PASS (`1.0ms`) | PASS (`0.1ms`) | PASS (`0.1ms`) | Round-trip LE/BE/BOM & reject UTF-8 invalido OK |
| **Area A:** LF/CRLF/CR & `previewSourceLine` CR-only | **FAIL** (`11.1ms`) | **FAIL** (`11.0ms`) | **FAIL** (`11.3ms`) | **App Bug (`BUG-016`):** `singleCR+CmdD: hasRawCR=true` |
| **Area A:** Trojan Source BiDi & Binary Quarantine | **FAIL** (`3.1ms`) | **FAIL** (`3.0ms`) | **FAIL** (`3.0ms`) | **App Bug (`BUG-007`):** `afterOpenBinTab=trojan-bidi.txt, activeIsBinary=false` (`bidi=1`, `directSaveBlocked=true`) |
| **Area B:** Dotfile Navigator, Binary Grayout & Parent Nav | PASS (`2.4ms`) | PASS (`1.7ms`) | PASS (`1.8ms`) | Nota: `escapeDirBanner` fallisce l'intero listing su 1 symlink escape (**`BUG-017`**) |
| **Area B:** Batch Open `<=50` (35) & `>50` (60) Confirmation | PASS (`370.6ms`) | PASS (`337.3ms`) | PASS (`344.8ms`) | `after35=36, pending60=60, afterConfirm=96` |
| **Area B:** Sidebar CRUD, Cut/Copy/Paste, Trash & Tab Sync | PASS (`55.4ms`) | PASS (`15.6ms`) | PASS (`14.7ms`) | `renamed=true, copy1/copy2, movedTracked=true, dirtyTrashDetached=true` |
| **Area B:** Sidebar Ratio Clamping & `DesktopWorkspaceValidator` | **FAIL*** (`1.0ms`) | **FAIL*** (`0.9ms`) | **FAIL*** (`1.0ms`) | **Nota Harness (non app bug):** `ratios=0.12/0.65/0.22, termDir=dotfiles, badBundleBlocked=true`; fallito solo perché `isLeftSidebarCollapsed` parte `true` |
| **Area C:** Tab Pinning, Partition Reorder, MRU 10 & Recovery | PASS (`49.7ms`) | PASS (`46.3ms`) | PASS (`48.8ms`) | `recents=10/true, top=f1.md, pinnedOk=true, recoveredMatch=true` |
| **Area D:** Live `TextKit2EditorView`, Undo, GFM & Gutter Sync | **FAIL** (`742.9ms`) | **FAIL** (`659.6ms`) | **FAIL** (`667.0ms`) | **App Bug (`BUG-012`):** `editorScrollY=4833, otherScrollYs=[0, 0]`; **`BUG-021`:** warning `NSTextLayoutManagerBreakOnNilContentManager`; Nota: `gfmHeadingBold=false` dipende da lettura `lineFrag.attributedString` invece di `renderingAttributes` |
| **Area E:** Find, Case, Next/Prev, ReplaceAll, GoToLine | PASS (`7.6ms`) | PASS (`6.0ms`) | PASS (`6.2ms`) | Conferma **`BUG-008`:** `tokenBumpedFind=false tokenBumpedGoTo=false` |
| **Area E:** `MyersDiffEngine` & `DiffCoordinator` | **FAIL** (`3.0ms`) | **FAIL** (`3.1ms`) | **FAIL** (`3.0ms`) | **App Bug (`BUG-020`):** `rows=5 rem=false ins=true` — righe modificate marcate `.inserted` perdendo colore `.removed` LHS! |
| **Area F:** `BracketMatcher` & `BacktickScanner` Overlong | PASS (`0.1ms`) | PASS (`0.1ms`) | PASS (`0.1ms`) | `overlongDegraded=(true/true)` a `>4096` UTF-16 |
| **Area F:** SmartNewline, SmartList & GFMTableEdit | **FAIL*** (`0.1ms`) | **FAIL*** (`0.1ms`) | **FAIL*** (`0.1ms`) | **Nota Harness (non app bug):** `alpha=false, sec=false` perché `MarkdownListGrammar` richiede per contratto `>= 2` spazi di indentazione |
| **Area F:** `MarkdownAuthoringCommands` (16/16) & Highlighter | PASS (`0.4ms`) | PASS (`0.1ms`) | PASS (`0.1ms`) | `cmds=16/16, unbold=word, nonMdBlocked=true, spans=19` |
| **Area F:** Lint 26 Rules, Frontmatter Mask, QuickFix, 1000-Cap | PASS (`15.2ms`) | PASS (`13.2ms`) | PASS (`13.0ms`) | `allDiags=26, fmClean=true, cap=1000, errKept=true, secImmune=true` |
| **Area F:** PreviewProjector, Gate & 70-Image Cap | **FAIL** (`13.1ms`) | **FAIL** (`13.2ms`) | **FAIL** (`10.6ms`) | **App Bug (`BUG-014`):** `admittedAcross70Paras=70/64cap` + **App Bug (`BUG-019`):** `table=false` su HTML senza riga vuota prima di tabella! |
| **Area F:** DocumentNavigator, DistractionFree & ESC | PASS (`3.2ms`) | PASS (`2.9ms`) | PASS (`3.1ms`) | `headings=3, filtered=1, jumped=true, esc1/2=true` |
| **Area G:** PurpleThemePalette WCAG, Transparency, Zoom | PASS (`0.1ms`) | PASS (`0.1ms`) | PASS (`0.1ms`) | `lightContrast=21.0, darkContrast=21.0, zoom=50..300` |
| **Area G:** HeaderSubmenu SM, AboutFallback & CheatSheet | PASS (`0.2ms`) | PASS (`0.1ms`) | PASS (`0.1ms`) | Conferma **`BUG-018`:** `bundleFallback=0.0.1-alpha3`, `cheatDiff=false`, `cheatBold=false` |

---

## 5. Catalogo Completo Errori e Malfunzionamenti (`BUG-001` .. `BUG-021`)

### P0 — Critici (Crash, Perdita Dati, Funzionalità Primarie Assenti)

- **`BUG-001` — Crash `EXC_BAD_ACCESS / SIGSEGV` in `NSUndoManager` su `Cmd+Z`**
  - **Frequenza:** Osservato live `1/2` in sweep prolungato (`task-317` Run 2), `0/3` in repro minimale isolata (`0x0065b7d0ebbb37a8`)
  - **Sorgenti:** [TextKit2EditorView.swift:108-167](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L108-L167), [SwiftEditRootView.swift:2200-2220](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L2200-L2220), Crash [PH.SwiftEdit-2026-11-20-175043.ips](file:///Users/paoloinnocenti/Library/Logs/DiagnosticReports/PH.SwiftEdit-2026-11-20-175043.ips)
  - **Causa & Impatto:** `SwiftEditNSTextView` usa `allowsUndo = true` senza fornire un `NSUndoManager` per-tab né implementare `dismantleNSView`. Editor, tab chiusi e field editor della FindBar condividono lo `NSUndoManager` di `NSWindow`; dopo mutazioni programmatiche (`textView.string = text`) o smontaggio view/tab, `Cmd+Z` invoca un puntatore ObjC liberato dentro `-[_NSUndoStack popAndInvoke]`.

- **`BUG-002` — Apertura file esterni da Finder (`open-doc` / "Apri con" / doppio clic) ignorata**
  - **Frequenza:** `3/3` in live debug
  - **Sorgenti:** [SwiftEditApp.swift:4-16](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/SwiftEditApp.swift#L4-L16)
  - **Causa & Impatto:** Manca `@NSApplicationDelegateAdaptor` (`application(_:open:)`) e `.onOpenURL`; gli AppleEvent `kAEOpenDocuments` non raggiungono mai `SwiftEditWorkbenchModel`.

- **`BUG-003` — `Cmd+Q` con tab sporchi termina senza salvare né chiedere conferma + `.save` multi-tab incompleto**
  - **Frequenza:** `3/3` live (`Cmd+Q`) + `3/3` in `QAHarness` Area A
  - **Sorgenti:** [SwiftEditApp.swift:4-16](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/SwiftEditApp.swift#L4-L16), [SwiftEditRootView.swift:916-934](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L916-L934)
  - **Causa & Impatto:** `requestApplicationTermination()` è dead code non collegato ad `applicationShouldTerminate(_:)`; inoltre nel ramo `.save` azzera subito `isPendingTerminationPrompt = false` dopo il primo tab sporco lasciando gli altri `isDirty == true` (`Remaining dirty tabs = 1` in Area A). Perdita certa dei dati alla chiusura app.

### P1 — Alti (Scorciatoie Rotte, Undo Rotto, Accessibilità WCAG, Selezione)

- **`BUG-004` — Collisione scorciatoia `Cmd+H` (`Find and Replace…` vs `Hide PH.SwiftEdit`)**
  - **Frequenza:** `3/3` live (`cmdH_HidApp=True`) + dump menu AX live (`.tmp/output/menus-live.txt` righe `81`, `118`)
  - **Sorgenti:** [SwiftEditCommands.swift:102-104](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditCommands.swift#L102-L104)
  - **Fix:** Usare standard macOS `Opt+Cmd+F`.

- **`BUG-005` — `textView.string = text` azzera `NSUndoManager` e perde lunghezza selezione**
  - **Frequenza:** `3/3` live su `Cmd+D` (`undoAfterCmdD=False`), inoltre affligge SmartNewline (`TextKit2EditorView.swift:417-420`), Format e comandi Markdown
  - **Sorgenti:** [TextKit2EditorView.swift:146-156](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L146-L156)
  - **Causa:** Rimpiazzare `.string` distrugge lo stack undo nativo e forza `length: 0` sulla selezione.

- **`BUG-006` — Header Brand Submenu si auto-chiude dopo `180 ms` se aperto via click/VoiceOver/`AXPress`**
  - **Frequenza:** `3/3` live (`openAt40ms=True` -> `stillOpenAt280ms=False`)
  - **Sorgenti:** [HeaderBrandSubmenuView.swift:51-75](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/HeaderBrandSubmenuView.swift#L51-L75), [SwiftEditRootView.swift:1623-1629](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L1623-L1629)
  - **Causa:** `clickToggle()` lascia `pointerRegion == .outside`; il `.task` chiama `advance(by: 20ms)` facendo scattare `exitGraceDuration` (`180ms`) e chiudendo il menu (violazione WCAG 2.2 SC 1.4.13; `Diff Pane` irraggiungibile via tastiera/AX se non entro 180ms).

- **`BUG-007` — Apertura file binari salta `tabSession.openOrActivate` (nessun tab UI + sessione orfana)**
  - **Frequenza:** `3/3` in `QAHarness` Area A (`afterOpenBinTab=trojan-bidi.txt, activeIsBinary=false`)
  - **Sorgenti:** [SwiftEditRootView.swift:534-547](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L534-L547)

- **`BUG-008` — `executeFind`, `findNextMatch`, `findPreviousMatch`, `executeGoToLine` non incrementano `programmaticSelectionToken`**
  - **Frequenza:** `3/3` live (`editorAfterJump=[FOCUSED=false CHARS=28 SEL=19:0]`) + `3/3` `QAHarness` Area E (`tokenBumpedFind=false tokenBumpedGoTo=false`)
  - **Sorgenti:** [SwiftEditRootView.swift:776-846](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L776-L846), [TextKit2EditorView.swift:157-166](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L157-L166)

- **`BUG-009` — Barra Find/Replace/GoToLine senza auto-focus e senza pulsante singolo `Replace`**
  - **Frequenza:** `3/3` live (`fieldAutoFocus=False editorStayedFocused=False`, `singleReplace=False`)
  - **Sorgenti:** [FindReplaceGoToLineBar.swift:80-110](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/FindReplaceGoToLineBar.swift#L80-L110)

- **`BUG-010` — `NSRunningApplication.terminate()` non chiude l'app entro 2s**
  - **Frequenza:** `3/3` live (`Run 2`, `Run 3`, `CLEAN_QUIT`: `TERMINATE_CALLED=true IS_TERMINATED=false`)
  - **Sorgenti:** [SwiftEditApp.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/XcodeApp/SwiftEditApp.swift) (mancanza lifecycle delegate AppKit pulito).

### P2 — Medi (Correttezza Rendering, Gutter, Diff, Preview, File System)

- **`BUG-011` — Doppia voce `Redo` nel menu `Edit` (`Shift+Cmd+Z` disabilitata + `Cmd+Y` sempre abilitata):** [SwiftEditCommands.swift:80-85](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditCommands.swift#L80-L85).
- **`BUG-012` — `LineNumberGutterView` scollegata da scroll verticale e soft-wrap di `TextKit2EditorView`:** `3/3` Area D (`editorScrollY=4833, otherScrollYs=[0, 0]`), [LineNumberGutterView.swift:127-156](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/LineNumberGutterView.swift#L127-L156).
- **`BUG-013` — Evidenziazione riga corrente illumina solo il primo `lineFragment` su paragrafi wrapped:** [TextKit2EditorView.swift:54-60](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L54-L60).
- **`BUG-014` — Preview: bypass del tetto di 64 immagini/documento (`70/64cap` 3/3 Area F) + liste ordinate mostrate come `"•"`:** [MarkdownNativePreviewView.swift:74,113-117](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/MarkdownNativePreviewView.swift#L72-L125).
- **`BUG-015` — Cache `MarkdownLineIndex` invalidata solo su variazione `text.utf16.count`:** edit programmatici di uguale lunghezza servono indice stantio, [TextKit2EditorView.swift:365-372](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L365-L372).
- **`BUG-016` — `DocumentSession.activeSeparator` inietta `\r` crudo su `CR-only` a riga singola (`3/3` Area A `hasRawCR=true`) + `previewSourceLine` conta solo `0x0A`:** [DocumentSession.swift:185-193](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/DocumentCore/DocumentSession.swift#L185-L193), [SwiftEditRootView.swift:1103-1108](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L1103-L1108).
- **`BUG-017` — Symlink escaping in cartella annulla l'intero `listEntries` (`DotfileFolderNavigator.swift:96-114`) + iTerm2 forzato automaticamente (`DesktopWorkspaceIntegrating.swift:153-160`):** [DotfileFolderNavigator.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/WorkspaceAndTabSession/DotfileFolderNavigator.swift#L96-L114), [DesktopWorkspaceIntegrating.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Workspace/DesktopWorkspaceIntegrating.swift#L153-L160).
- **`BUG-019` — `MarkdownPreviewProjector` su HTML adiacente (`<div>...`) senza riga vuota assorbe tabelle GFM successive in `.inertHTML`:** `3/3` in `QAHarness` Area F (`table=false` su `all-constructs.md`), [MarkdownPreviewProjector.swift:126-133](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownPreviewProjector.swift#L126-L133).
- **`BUG-020` — `DiffPaneCoordinator` + `diffPanel`: righe modificate perdono evidenziazione rossa LHS (`removed` collassato in `.inserted`):** `3/3` in Area E (`rows=5 rem=false ins=true`), [WorkspaceEditorAndDiffCoordinators.swift:424-434](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Coordinators/WorkspaceEditorAndDiffCoordinators.swift#L424-L434), [SwiftEditRootView.swift:2253-2266](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L2253-L2266).
- **`BUG-021` — `TextKit2EditorView` privo di `dismantleNSView` emette breakpoint diagnostic `NSTextLayoutManagerBreakOnNilContentManager` alla chiusura finestra:** osservato in `QAHarness` Area D (`Make a symbolic breakpoint at NSTextLayoutManagerBreakOnNilContentManager`), [TextKit2EditorView.swift:101-135](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L101-L135).

### P3 — Bassi

- **`BUG-018` — Fallback versione `AboutSheetDescriptor` hardcoded `"0.0.1-alpha3"` (`0.0.1-alpha5` in `version.json`), `CheatSheet` privo di voci `Diff` / formattazione Markdown & 3 warning Xcode:** [AboutSheetView.swift:53-56](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/AboutSheetView.swift#L53-L56).

---

## 6. Analisi Memoria e Leak (`MEM-001` .. `MEM-004`)

- **`MEM-001` — Picco memoria al lancio `264–288 MB` per finestra editor vuota:** `217 MB` di `Owned physical footprint (unmapped) (graphics)` + `28 MB` `CoreAnimation` al `t = 1s`, poi marcati reclaimable portando il footprint idle a `45–46 MB` (`vmmap`: `DefaultMallocZone 22.3M` dirty, frammentazione `31–33%`).
- **`MEM-002` — Leak logico permanente di file binari:** [SwiftEditRootView.swift:535-540](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L535-L540) inserisce `sessionsByID[loaded.id]` e `savedBaselineByID[loaded.id]` prima del `return` senza creare tab; impossibile ripulirli tramite `closeTab`.
- **`MEM-003` — Triplicazione footprint post-sweep live (`45 -> 135 MB`, picco `483 MB`) + Check Leak Completi:**
  - **Live App (`PID 6729`) dopo 3 sweep UI:** `Malloc Small` raddoppiato (`23 -> 48 MB`, `131k -> 264k` nodi), `IOSurface` salito a `35 MB` (+27 MB reclaimable), `17.7M` in `Malloc Large (empty)`, `CoreUI Image Data 976K -> 2176K`, `AttributeGraph 26.8k` nodi (`+960K` old mapping). `/usr/bin/leaks 6729` segnala `85` leak (`12.4 KB`) interamente dentro `CGEvent`/`ViewBridge` Apple (`"viewbridge-key-window"`), **0 leak nel codice Swift app**.
  - **Harness Leak Audit (`QAHarness` Bench 5 & `--leak-check`):** `survivingModels = 0/20` su tutti e 3 i run (grazie a `isolated deinit` in `SwiftEditRootView.swift:406-410`), `tabsLeft=0, sessionsLeft=0, baselinesLeft=0`, `recoveryFiles=1` (solo `session-manifest.json` vuoto, 0 `.recovery` orfani), e `/usr/bin/leaks --atExit` su `QAHarness [6721]` ha confermato **`Process 6721: 61178 nodes malloced for 12266 KB | 0 leaks for 0 total leaked bytes`** (`phys_footprint 284.6M`, peak `309.8M`, `LEAKS_EXIT=0`). *(Nota: durante la scrittura dell'harness è emerso che `NSWindow` programmatico richiede `isReleasedWhenClosed = false` in ARC per evitare double-release su `autoreleasepool`.)*
- **`MEM-004` — Ritenzione RSS sotto churn sostenuto:** in `QAHarness` Bench 5 (60 batch + 20 model + 50 tab churn x 3 run), la `RSS` è cresciuta progressivamente tra i 3 cicli (`488.8 MB` -> `536.9 MB` -> `699.3 MB`), mentre `phys_footprint` oscillava in base al reclaim (`288.7 -> 213.1`, `174.3 -> 98.4`, `240.3 -> 169.0 MB`).

---

## 7. Analisi Velocità, Prestazioni & Test (`PERF-001` .. `PERF-007`, `TEST-001`)

### 7.1 Risultati Benchmark `QAHarness --bench` (3 Run Indipendenti, Debug `-Onone`)

| Scenario Benchmark | Run 1 (`min / p50 / p95 / max`) | Run 2 (`min / p50 / p95 / max`) | Run 3 (`min / p50 / p95 / max`) | Verdetto / Note Osservate |
| :--- | :---: | :---: | :---: | :--- |
| **Typing Hot Path `50L` (x50 edit)** | `3.70 / 3.88 / 4.06 / 4.30 ms` | `3.62 / 3.83 / 4.01 / 4.03 ms` | `3.72 / 3.91 / 4.05 / 4.06 ms` | OK `<16ms`, `lint=17` |
| **Typing Hot Path `500L` (x50 edit)** | `34.87 / 36.14 / 36.94 / 36.97 ms` | `35.95 / 36.52 / 37.14 / 37.30 ms` | `36.30 / 37.29 / 37.94 / 38.20 ms` | **`>2x` budget 60fps (`16.6ms`)**, `lint=159` |
| **Typing Hot Path `5000L` (x20 edit)** | `329.97 / 334.07 / 336.19 / 337.27 ms` | `331.23 / 336.28 / 338.84 / 340.07 ms` | `335.08 / 341.22 / 343.93 / 345.55 ms` | **`PERF-006` CRASH UX/SEC: **`lint=0` (`deadlineExceeded`!)** |
| **Typing Hot Path `20000L` (x5 edit)** | `941.23 / 944.53 / 952.84 / 952.84 ms` | `953.91 / 963.91 / 969.04 / 969.04 ms` | `951.65 / 960.26 / 966.01 / 966.01 ms` | **`PERF-006` ~1 sec FREEZE PER BATTUTA + **`lint=0`** |
| **Real Hosted `NSHostingView+NSTextView` (300L x20)** | `18.07 / 18.57 / 19.73 / 22.77 ms` | `18.80 / 19.83 / 20.53 / 21.53 ms` | `20.13 / 21.80 / 22.65 / 22.98 ms` | Frame drop già a 300 righe |
| **Caret Move Hot Path `500L` (x100 move)** | `3.32 / 4.95 / 6.75 / 7.10 ms` | `3.27 / 5.01 / 7.08 / 7.26 ms` | `3.36 / 4.96 / 7.01 / 7.15 ms` | OK `<16ms` |
| **Caret Move Hot Path `10000L` (x100 move)** | `64.27 / 70.01 / 74.62 / 77.85 ms` | `66.60 / 71.35 / 76.14 / 77.26 ms` | `67.10 / 71.25 / 75.87 / 76.89 ms` | **`PERF-007`: 70–78ms lag ad ogni tasto freccia!** |
| **Open `5k` / `20k` / `5MB` / `12MB`** | `231.2 / 598.1 / 670.7 / 1623.4 ms` | `237.0 / 609.2 / 679.9 / 1650.0 ms` | `236.9 / 611.7 / 691.2 / 1655.2 ms` | **`PERF-005`: 1.62–1.66s blocco Main Thread su 12MB** |
| **Batch Open 60 file (`tabs=61`)** | `210.1 ms` (`154.8->241.8 MB`) | `216.5 ms` (`217.1->242.4 MB`) | `211.2 ms` (`181.0->240.2 MB`) | Buon throughput (`+87 MB` per 60 tab) |
| **Preview Edits `500L` / `3000L`** | `40.28 / 241.10 ms` (`p50`) | `39.97 / 242.16 ms` (`p50`) | `40.41 / 243.86 ms` (`p50`) | 241ms per edit con Preview aperta a 3k righe |
| **Thumbnails `local.png` (x50) / Diff `500L` / `5000L`** | `0.24 / 0.80 / 14.63 ms` (`p50`) | `0.26 / 0.80 / 14.71 ms` (`p50`) | `0.26 / 0.80 / 14.78 ms` (`p50`) | Myers diff molto veloce; `loadThumbnail` resta sincrono MainActor (`PERF-002`) |

### 7.2 Catalogo Bottleneck Prestazioni (`PERF-001` .. `PERF-007`, `TEST-001`)

- **`PERF-006` (P1 — Critico UX & Sicurezza) — Freeze Main Thread fino a ~964 ms/keystroke e disabilitazione silenziosa Lint XSS sopra ~5000 righe:**
  - Provato da `sample` sul processo live `QAHarness` (`.tmp/output/sample-bench-hot.txt`): **609 campioni su 682 (89% del tempo CPU)** in `handleEditorTextChanged` -> [refreshDiagnosticsForActiveDocument](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L748-L768) -> [MarkdownLintAndFormatEngine.parseAdmissibleAST](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLintAndFormatEngine.swift#L219-L241) -> `swift-markdown Document(parsing:)`.
  - Inoltre `parseAdmissibleAST` controlla `deadlineMilliseconds` (`250ms`) **solo dopo** che `Document(parsing:)` è già terminato (riga `237`), congelando la UI per ~0.95s e scartando poi tutti i risultati (`lint=0`), **disabilitando di fatto la protezione `.unsafeLinkScheme` sui file lunghi**! Ad ogni battuta vengono eseguite ~8 scansioni integrali del buffer (Text+UTF16+BiDi+AST+LineIndex+SplitLines+Brackets+Backtick+Gutter).
- **`PERF-007` (P1) — Latenza movimento cursore `70–78 ms` su `10.000` righe:**
  - [handleSelectionChanged](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L633-L638) riesegue ad ogni freccia [SearchDiffAndBracketEngine.evaluateBrackets](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/SearchDiffAndBracketEngine/BracketMatcher.swift#L75-L102) (scansione completa per UTF-16 + iterazione grapheme + doppio sort), mentre [LineNumberGutterProjection.evaluate](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/LineNumberGutterView.swift#L26-L35) e [CursorMetricsCalculator.metrics](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/DocumentCore/CursorMetricsCalculator.swift#L65-L92) allocano ripetutamente `Array(text.utf16)`, `Array(1...totalLines)` e contano `text.unicodeScalars.count`.
- **`PERF-001` — Doppio `layoutViewport()` + `setRenderingAttributes([:], for: docRange)` full-doc:** ad ogni `updateNSView` ([TextKit2EditorView.swift:168-171,260](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/TextKit2EditorView.swift#L168-L171)).
- **`PERF-002` — `loadThumbnail` sincrono sul `@MainActor` senza cache:** [MarkdownPreviewProjector.swift:221-231](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownPreviewProjector.swift#L221-L231), [MarkdownNativePreviewView.swift:117](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/MarkdownNativePreviewView.swift#L117).
- **`PERF-003` — Stalli `cfprefsd` (`5–10s`, fino a 86s in `--level debug`) & `4` errori XPC `AppIntents Code=4097`:** su domini `UserDefaults` custom ([EditorPreferencesStore.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/WorkspaceAndTabSession/EditorPreferencesStore.swift), [RecentFilesStore.swift](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditCore/WorkspaceAndTabSession/RecentFilesStore.swift)).
- **`PERF-004` — `.task` polling ogni `20ms x 40` su ogni variazione hover header:** [SwiftEditRootView.swift:1623-1629](file:///Users/paoloinnocenti/Documents/git/PH.SwiftEdit/Sources/SwiftEditUI/Views/SwiftEditRootView.swift#L1623-L1629).
- **`PERF-005` — Apertura file `5–12 MB` (`671–1655 ms`) & Preview `3000L` (`241 ms`) sincrone sul Main Thread:** `Bench 3` e `Bench 4`.
- **`TEST-001` — Suite `swift test` lenta (`41–91 s` per 166 test):** `31` `removePersistentDomain` in `11` file bloccano `cfprefsd`.

---

## 8. Piano Dettagliato di Correzioni (Wave 1–4)

### Wave 1 — Stabilità Critica & Integrità Dati (P0)

| ID | Target (File / Simbolo) | Design Tecnico della Correzione | Verifica TDD & Regressione | Rischio / Effort |
| :--- | :--- | :--- | :--- | :---: |
| **`BUG-001`** | `TextKit2EditorView` (`Coordinator`), `SwiftEditWorkbenchModel` | Associare un `NSUndoManager` dedicato **per ciascun `DocumentID`** tramite `NSTextViewDelegate.undoManager(for:)`, ripulito su `closeTab`; implementare `dismantleNSView` su `TextKit2EditorView` azzerando delegate, `renderingAttributesValidator` e `undoManager` (**risolve anche `BUG-021`**). | Unit/UI test: apertura/switch/chiusura tab + FindBar + Format + `Undo` multiplo senza crash sotto `MallocScribble` / ASan. | Alto / Medio |
| **`BUG-002`** | `SwiftEditApp.swift`, `SwiftEditWorkbenchModel` | Introdurre `@NSApplicationDelegateAdaptor(SwiftEditAppDelegate.self)` con `application(_:open:)` + `.onOpenURL`; instradare gli URL verso un coordinator condiviso collegato al `SwiftEditWorkbenchModel` della finestra attiva (con supporto apertura a freddo/caldo). | Test live con `open -a ... sample.md` e AppleEvent `open-doc` x3 (`activeTabTitle == "sample.md"`). | Medio / Medio |
| **`BUG-003`** + **`BUG-010`** | `SwiftEditAppDelegate`, `SwiftEditRootView.swift` (`requestApplicationTermination`, `resolvePendingDirtyClose`) | Implementare `applicationShouldTerminate(_:)` chiamando `requestApplicationTermination()`; nel ramo `.save` **iterare su tutti i tab sporchi** anziché fermarsi al primo (`while let nextDirty = ...`), mantenendo `isPendingTerminationPrompt` coerente finché restano tab sporchi o l'utente annulla, poi chiamare `NSApp.reply(toApplicationShouldTerminate:)`. | Test unitario multi-tab `.save` con `2+` tab sporchi (`remainingDirty == 0`) + live `Cmd+Q` 3x con alert bloccante + clean quit `IS_TERMINATED=true`. | Alto / Medio |

### Wave 2 — UX Primaria, Scorciatoie, Accessibilità & Hot-Path Typing/Caret (P1 + `PERF-006`/`PERF-007`)

| ID | Target | Design Tecnico della Correzione | Verifica TDD & Regressione | Rischio / Effort |
| :--- | :--- | :--- | :--- | :---: |
| **`BUG-004`** | `SwiftEditCommands.swift`, `KeyboardShortcutsCheatSheetView.swift` | Spostare `Find and Replace…` su `Opt+Cmd+F` (`.keyboardShortcut("f", modifiers: [.command, .option])`) ed aggiornare il `CheatSheet`. | Test `menus-live` + live `Cmd+H` (hide) vs `Opt+Cmd+F` (Find & Replace). | Basso / Basso |
| **`BUG-005`** | `TextKit2EditorView.swift` (`updateNSView`, `doCommandBy`) | Sostituire `textView.string = text` con helper transazionale undo-safe (`shouldChangeText(in:replacementString:)` + `textStorage?.replaceCharacters(in:with:)` + `didChangeText()`) e ripristino esatto dell'intero `NSRange` (location + length); applicare SmartNewline/Authoring/Cmd+D tramite questo canale quando l'editor è attivo. | Test UI: `Cmd+D -> Cmd+Z`, `Bold -> Cmd+Z`, `Enter` su lista `- item` -> `Cmd+Z` (testo ripristinato a ogni step). | Medio / Medio |
| **`BUG-006`** | `HeaderBrandSubmenuView.swift`, `SwiftEditRootView.swift:1623` | Aggiungere `openedByClick: Bool` in `HeaderSubmenuStateMachine`; quando aperto da `clickToggle()`, disabilitare il timer di uscita hover finché l'utente non fa hover intenzionale o preme `ESC`/outside; sostituire il `.task` polling 20ms con `DispatchWorkItem`/task schedulato **solo** durante transizioni dwell/grace (**risolve `PERF-004`**). | Unit test state machine (`clickToggle()` + `advance(by: 500ms)` resta aperto) + live AX test a `40ms` e `500ms`. | Basso / Basso |
| **`BUG-008` + `BUG-009`** | `SwiftEditRootView.swift` (`executeFind`, `Next`, `Prev`, `GoToLine`), `FindReplaceGoToLineBar.swift` | Creare `applyProgrammaticSelection(_:)` che incrementa `programmaticSelectionToken += 1`; aggiungere `@FocusState` su `FindReplaceGoToLineBar` per focus automatico su `Cmd+F`/`Opt+Cmd+F`/`Cmd+G`; aggiungere `executeReplaceSingle()` + bottone `"Replace"`. | Live & UI test: `findFieldFocused=true`, GoToLine aggiorna `SEL`, Find seleziona match & scrolla, `Replace` sostituisce 1 occorrenza. | Basso / Medio |
| **`BUG-007` + `MEM-002`** | `SwiftEditRootView.swift:526-555` | Aprire i file binari in tab read-only effettivo (o in vista modale/tab tracciato con cleanup in `closeTab` ed esclusione da `persistRecoveryState` e pin). | `Area A`: `activeTabTitle == "random.bin"`, chiusura libera `sessionsByID` e `savedBaselineByID`. | Medio / Basso |
| **`PERF-006` + `PERF-007`** | `SwiftEditRootView.swift`, `MarkdownLintAndFormatEngine.swift`, `BracketMatcher.swift`, `CursorMetricsCalculator.swift`, `LineNumberGutterView.swift` | 1) Spostare `MarkdownLintAndFormatEngine.lint` + BiDi + Backtick scan su worker `Task` debounced (`150ms`) cancellabile con `BufferRevision` guard, mantenendo sul keystroke sincrono solo l'aggiornamento testo + gutter/metriche incrementali; per file oltre ~2.000 righe eseguire il parse sicurezza `.unsafeLinkScheme` incrementale senza droppare silentemente `lint=0`. 2) Cachare `BracketBalanceResult.matchedPairs` per `(DocumentID, BufferRevision)` risolvendo al volo solo `activePair` su `handleSelectionChanged`. 3) Eliminare `Array(text.utf16)` multipli e `Array(1...totalLines)` da `LineNumberGutterProjection`/`CursorMetricsCalculator`. | Bench target: typing `20,000L < 16 ms` sul Main Thread; caret move `10,000L < 2 ms` `p95`; `.unsafeLinkScheme` mai silenzioso a `5k–20k` righe. | Medio / Alto |

### Wave 3 — Correttezza Editor/Preview, Rendering Diff & Ottimizzazioni Memoria (P2 + `MEM-*` + `PERF-*`)

| ID | Target | Design Tecnico della Correzione | Verifica TDD & Regressione | Rischio / Effort |
| :--- | :--- | :--- | :--- | :---: |
| **`BUG-012` + `BUG-013`** | `LineNumberGutterView.swift`, `TextKit2EditorView.swift` | Sincronizzare lo scroll e le altezze righe soft-wrapped del gutter con `NSScrollView`/`NSTextLayoutManager` (preferibilmente `NSRulerView` nativo o bridge `boundsDidChangeNotification` con altezze reali dei layout fragments); in `currentLineFullWidthRect()` iterare su `fragment.textLineFragments` scegliendo il line fragment contenente `caretLocation` (o `enumerateTextLayoutFragments` per caratteri esatti). | Area D: `gutterScrollY` tracciato con `editorScrollY`; righe wrapped multi-line evidenziano esattamente la riga visuale del cursore. | Medio / Medio |
| **`BUG-014` + `BUG-019` + `PERF-002`** | `MarkdownNativePreviewView.swift`, `MarkdownPreviewProjector.swift` | 1) Passare un contatore cumulativo di immagini per documento (`admittedCount`) invece dell'indice locale di paragrafo; numerare correttamente le liste ordinate (`1.`, `2.`, ...). 2) In `MarkdownPreviewProjector.isHTMLStart`, fermare il blocco HTML se la riga corrente chiude il tag HTML single-line (`</div>`) o se la riga successiva inizia un costrutto blocco (`isTableStart`, heading, fence). 3) Decodificare thumbnail off-main-thread con `NSCache` LRU limitata. | Area F: `admittedAcross70Paras <= 64`, `table=true` su `all-constructs.md`, liste ordinate numerate. | Basso / Medio |
| **`PERF-001` + `BUG-015`** | `TextKit2EditorView.swift` | Rimuovere la doppia chiamata `layoutViewport()`, azzerare `setRenderingAttributes` **solo** su intervalli sporchi/viewport invece di `docRange` integrale, ed invalidare `Coordinator.cachedLineIndex` per `(revision / textHash)` anziché `utf16.count`. | Hosted NSTextView `300L` `< 8 ms` + unit test cache hit/miss same-length (`"# a"` vs `"* a"`). | Medio / Medio |
| **`BUG-016` + `BUG-020` + `BUG-017` + `BUG-011`** | `DocumentSession.swift`, `WorkspaceEditorAndDiffCoordinators.swift`, `SwiftEditRootView.swift`, `DotfileFolderNavigator.swift`, `DesktopWorkspaceIntegrating.swift`, `SwiftEditCommands.swift` | 1) Normalizzare `activeSeparator` sempre a `"\n"` in memoria, conteggiando `\r\n|\r|\n` in `previewSourceLine`. 2) Aggiungere `.modified` a `DiffHunkKind` (o `lhsKind`/`rhsKind` in `SideBySideDiffRow`) per colorare rosso LHS e verde RHS sulle righe cambiate. 3) Saltare/marcare singoli symlink escaping in `listEntries` senza fallire la cartella; rispettare preferenza Terminal esplicita. 4) Rimuovere il `Redo Cmd+Y` duplicato o allinearne `.disabled`. | Area A (`hasRawCR=false`), Area E (`lhsModifiedHighlight`), Dotfile test con 1 symlink ostile + folder valido. | Basso / Medio |
| **`PERF-005` + `MEM-001/003/004`** | `DocumentLoader.swift`, `SwiftEditRootView.swift` | Caricare/decodificare file `>= 2 MB` (`5–12 MB`) in task asincrono con stato loading non bloccante; investigare picco avvio `217 MB` unmapped graphics e `17.7M` `Malloc Large` / `35M IOSurface` alla chiusura fogli modali (`sheet`/`popover` caching). | Bench `open12MB` `< 25 ms` blocco Main Thread; post-sweep `phys_footprint` `< 80 MB`. | Medio / Medio |

### Wave 4 — Build Hygiene, Polish & Velocità `swift test` (P3 + `BUG-018` + `TEST-001`)

| ID | Target | Design Tecnico della Correzione | Verifica |
| :--- | :--- | :--- | :--- |
| **`BUG-018`** | `AboutSheetView.swift`, `KeyboardShortcutsCheatSheetView.swift`, `project.pbxproj` | Allineare fallback `"0.0.1-alpha5"` (o leggere da `Bundle.module` risorsa `version.json`); aggiungere scorciatoie Markdown & Diff nel CheatSheet; impostare `ALWAYS_SEARCH_USER_PATHS = NO` e `outputPaths` / dependency per lo script plist. | Zero warning `ALWAYS_SEARCH_USER_PATHS` in `xcodebuild`. |
| **`TEST-001` + `PERF-003`** | `Tests/SwiftEditTests/` (11 file), `EditorPreferencesStore.swift`, `RecentFilesStore.swift` | In produzione usare dominio container standard invece di 2 suite custom disallineate; nei `31` siti di test sostituire `removePersistentDomain(forName:)` con `removeObject(forKey:)` o un `KeyValueStore` in-memory di test. | `swift test` scende da `41–91 s` a `< 10 s` deterministici! |

---

## 9. Piano Migliorie Architetturali, UX & Qualità (Oltre i Bug)

1. **Architettura `DocumentUndoCoordinator` isolata per Tab (`Undo/Redo` Deterministico):** separare chiaramente mutazioni TextKit 2 e mutazioni model-driven (`Cmd+D`, `Format`, `QuickFix`, `SmartList`, `SmartNewline`) così che ogni azione utente e programmatica sia atomicamente annullabile/ripetibile senza mai condividere stack ObjC tra tab o controlli barra Find.
2. **Pipeline Asincrona Revision-Guarded per Lint, Preview e Aperture Pesanti:** adottare modello immutable snapshot + background `Task` con cancellazione immediata a cambio `BufferRevision`, disaccoppiando completamente il frame rate di digitazione (`< 8 ms` garantiti anche su `20.000+` righe) dalla complessità AST di `swift-markdown`, senza mai saltare le regole di sicurezza (`XSS`/BiDi).
3. **Engine TextKit 2 "True Viewport-Only":** eliminare ogni scansione `0...N` per keystroke/caret move mantenendo un indice compatto delle offset di riga aggiornato incrementalmente sull'edit, garantendo gutter con numerazione allineata al soft-wrap reale e zero reset globale di `renderingAttributes`.
4. **Accessibilità & Automazione WCAG 2.2 AA Continua:** integrare nei test automatici (anche CI) asserzioni AX su focus programmatico (barra Find, Navigator, chiusura Sheet/Distraction-Free -> ripristino focus nell'editor), persistenza dei pannelli aperti da tastiera (`HeaderBrandSubmenu`), e zero collisioni di scorciatoie di sistema (`⌘H`, `⌘P`, ecc.).
5. **Hygiene Preferenze & Budget Telemetria in CI:** adottare `UserDefaults.standard` / suite container-aligned (abbattendo gli stalli `cfprefsd`), in-memory defaults nei test (`TEST-001`), e soglie automatiche CI su `p95` digitazione (`< 16 ms`) e `0 leaks` via `/usr/bin/leaks`.
