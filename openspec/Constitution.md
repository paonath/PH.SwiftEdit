---
project_name: "PH.SwiftEdit"
version: "1.0.0"
ratified: "2026-11-17"
last_amended: "2026-11-17"
primary_stack: "Swift 6.4+ / macOS 26+ (SwiftPM + SwiftUI + AppKit TextKit 2)"
spec_root: "openspec"
single_reference_lock: true
---

# Constitution: PH.SwiftEdit

## Routing Matrix

| Area | Prefix | Status | Index | Owners | Scope & Core Tenet |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `01-architecture/` | `AR` | `active` | `constitution/01-architecture/index.md` | `swift-macos-expert`, `oop-architecture-expert` | 2-target SwiftPM (`SwiftEditCore`, `SwiftEditUI`), `.macOS(.v26)`, Swift 6 strict concurrency, `swift-markdown` (`AR-001..014`) |
| `02-domain/` | `BC` | `active` | `constitution/02-domain/index.md` | `ddd-expert`, `swift-macos-expert`, `spec-sdlc-expert` | 4 value-type Bounded Contexts, negative ownership anti-IDE/DB/LSP, `10 MiB` / `64 MiB` guardrails (`BC-001..012`) |
| `03-ui-ux/` | `UI` | `active` | `constitution/03-ui-ux/index.md` | `swift-macos-expert` | macOS HIG tokens, `@MainActor` `@Observable`, TextKit 2 viewport (`<= 16 ms`), VoiceOver, Trojan Source badges (`UI-001..012`) |
| `04-data-persistence/` | `DATA` | `active` | `constitution/04-data-persistence/index.md` | `swift-macos-expert`, `cyber-security-expert` | Zero DB, explicit `Cmd+S` atomic writes, BOM/CRLF fidelity, `NSFilePresenter` conflict safety (`DATA-001..008`) |
| `05-api-contracts/` | `API` | `not-applicable` | `constitution/05-api-contracts/index.md` | `spec-sdlc-expert`, `swift-macos-expert`, `cyber-security-expert` | Dormant macOS IPC guardrails (`AppIntents`/`XPC`/CLI require `MINOR` amendment) (`API-001..008`) |
| `06-testing-fitness/` | `TEST` | `active` | `constitution/06-testing-fitness/index.md` | `swift-macos-expert`, `test-quality-auditor`, `spec-sdlc-expert` | `[RED]->[GREEN]->[REFACTOR]` via `swift test` (`Swift Testing`), static SwiftPM fitness, thin `XCUITest` (`TEST-001..008`) |
| `07-security-privacy/` | `SEC` | `active` | `constitution/07-security-privacy/index.md` | `cyber-security-expert` | macOS App Sandbox least-privilege, zero-network/telemetry, scoped bookmarks, symlink safety, `Rule G3` (`SEC-001..012`) |
| `08-sdd-governance/` | `SDD` | `active` | `constitution/08-sdd-governance/index.md` | `spec-sdlc-expert`, `qa-agent` | 6-artifact `[<PREFIX>-###]` traceability, structural-first tasks, SemVer amendments, `--converge` (`SDD-001..010`) |

## Sync Impact Report

| Version | Date | Touched Rules | Sync Status |
| :--- | :--- | :--- | :--- |
| `1.0.0` | `2026-11-17` | `AR-001..SDD-010 ratified via 001_project-constitution bootstrap` | `index.yml synced` |
