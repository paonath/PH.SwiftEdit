---
project_name: "PH.SwiftEdit"
version: "1.2.0"
ratified: "2026-11-17"
last_amended: "2026-11-17"
primary_stack: "Swift 6.4+ / macOS 26+ & iOS 26+ Readiness (SwiftPM + SwiftUI + TextKit 2)"
spec_root: "openspec"
single_reference_lock: true
---

# Constitution: PH.SwiftEdit

## Routing Matrix

| Area | Prefix | Status | Index | Owners | Scope & Core Tenet |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `01-architecture/` | `AR` | `active` | `constitution/01-architecture/index.md` | `swift-macos-expert`, `oop-architecture-expert` | `SwiftEditCore` (`.macOS(.v26), .iOS(.v26)`), `SwiftEditUI` (`#if os`), `AppIcon.appiconset`, `nbgv` (`AR-001..014`) |
| `02-domain/` | `BC` | `active` | `constitution/02-domain/index.md` | `ddd-expert`, `swift-macos-expert`, `spec-sdlc-expert` | `DocumentCore` (`Cmd+D`), `MarkdownLintAndFormat`, `SearchDiffAndBracketEngine`, `WorkspaceAndTabSession` (`BC-001..012`) |
| `03-ui-ux/` | `UI` | `active` | `constitution/03-ui-ux/index.md` | `swift-macos-expert` | Logo E2 Purple tokens (`#0B0614`/`#A78BFA`/`#C4B5FD`->`#7C3AED`), `#FFFFFF`/`#000000` inverted editor, Zoom `50%..300%` (`UI-001..012`) |
| `04-data-persistence/` | `DATA` | `active` | `constitution/04-data-persistence/index.md` | `swift-macos-expert`, `cyber-security-expert` | Zero DB, explicit `Cmd+S`, Notepad++ `SessionRecovery` + GC, binary save/tab ban (`DomainError.binaryFileSaveForbidden`) (`DATA-001..008`) |
| `05-api-contracts/` | `API` | `not-applicable` | `constitution/05-api-contracts/index.md` | `spec-sdlc-expert`, `swift-macos-expert`, `cyber-security-expert` | Dormant macOS/iOS IPC guardrails (`AppIntents`/`XPC`/CLI require `MINOR` amendment) (`API-001..008`) |
| `06-testing-fitness/` | `TEST` | `active` | `constitution/06-testing-fitness/index.md` | `swift-macos-expert`, `test-quality-auditor`, `spec-sdlc-expert` | `[RED]->[GREEN]->[REFACTOR]` via `swift test` (`Swift Testing`), static SwiftPM & `AppIcon` fitness, thin `XCUITest` (`TEST-001..008`) |
| `07-security-privacy/` | `SEC` | `active` | `constitution/07-security-privacy/index.md` | `cyber-security-expert` | App Sandbox least-privilege, dotfile symlink safety, `0700`/`0600` `SessionRecovery` (`<= 64 MiB`), binary non-retention (`SEC-001..012`) |
| `08-sdd-governance/` | `SDD` | `active` | `constitution/08-sdd-governance/index.md` | `spec-sdlc-expert`, `qa-agent` | 6-artifact `[<PREFIX>-###]` traceability, structural-first tasks, SemVer amendments, `--converge` (`SDD-001..010`) |

## Sync Impact Report

| Version | Date | Touched Rules | Sync Status |
| :--- | :--- | :--- | :--- |
| `1.0.0` | `2026-11-17` | `AR-001..SDD-010 ratified via 001_project-constitution bootstrap` | `index.yml synced` |
| `1.1.0` | `2026-11-17` | `AR-001..014, BC-001..012, UI-001..012, DATA-001..008, TEST-003..008, SEC-001..012 (Rework 1.1)` | `index.yml synced` |
| `1.2.0` | `2026-11-17` | `AR-001, UI-001, UI-002, TEST-007, SDD-003 (Concept E2 Brand Logo & macOS/iOS AppIcon.appiconset integration)` | `index.yml synced` |
