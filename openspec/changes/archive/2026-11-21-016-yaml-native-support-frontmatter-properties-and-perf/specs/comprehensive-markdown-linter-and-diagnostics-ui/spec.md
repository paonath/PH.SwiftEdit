# Spec Delta: comprehensive-markdown-linter-and-diagnostics-ui

## Purpose
Extends lint status classification so YAML tabs report an Active status driven by the structural YAML linter instead of Lint Off, while plain-text tabs stay Off, degraded buffers stay Paused, and security errors are never suppressed.

## ADDED Requirements

## MODIFIED Requirements

### Requirement: REQ-003 Lint Status Classification and Active-Line Suppression
WHEN classifying document lint state or filtering active-line diagnostics, the workbench lint policy SHALL report Off for plain-text tabs, Paused for degraded buffers, Active for Markdown tabs (26-rule linter plus frontmatter `YML001..YML005`) and YAML tabs (`YAMLStructureLinter`) retaining security error counts during background recomputation (`ActiveLintStatus`), and hide only non-security caret-line warnings via `ActiveLineLintSuppressionPolicy` [BC-004][DATA-003].

Security-Waiver: additive only — the Off state is narrowed from "non-Markdown" to "plain-text" so YAML tabs gain diagnostics; Paused, security-count retention (`P6`) and security non-suppression (`N5`) are preserved unchanged and binary tabs remain Off.

#### Scenario: P7 YAML Tabs Report Active Status From the Structural Linter
- **Path**: P7
- **Trait**: positive
- **GIVEN** a `config.yml` tab with a duplicate top-level key and a tab-indented line
- **WHEN** `ActiveLintStatus.classify(language:snapshot:diagnosticCount:)` runs after `YAMLStructureLinter` completes
- **THEN** the result is `.active(count: 2)` and the status bar shows the existing Active label `⚠ Lint: 2`

#### Scenario: N8 Plain Text and Binary YAML Tabs Remain Off
- **Path**: N8
- **Trait**: negative
- **GIVEN** a `Main.swift` tab and a binary `data.yml` tab containing `0x00`
- **WHEN** `ActiveLintStatus.classify` runs for each
- **THEN** both results are `.off`, no YAML linter runs, and the diagnostics popover is dismissed

## REMOVED Requirements

## RENAMED Requirements
