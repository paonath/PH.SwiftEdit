---
name: debug-session-orchestrator
description: "Guides an agent through an end-to-end debug of an application (browser, server/process logs, source code), with an isolated on-disk session, persistent and redacted memory, sub-agent orchestration with context handoff, HAR export for complex network cases, and automatic retesting after the fix. Trigger it for UI bugs, network/API errors, authentication issues, or any unexpected behavior that needs to be reproduced and resolved in a traceable way."
---

# Debug Session Orchestrator (`debug-session-orchestrator` — Progressive Disclosure Router)

## Requirements & Core Mandates

- **Prerequisites**: Chromium with Remote Debugging Port active (or equivalent browser MCP tool) and `git`.
- The Debug Session Orchestrator SHALL isolate every debug session under `specs/debug/<session_name>/` and enforce `Single-Reference Lock` by loading one `workflows/NN-*/workflow.md` phase file at a time.
- The Debug Session Orchestrator SHALL discover project build tools, dev servers, log targets, and test runners from `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`, `.cursorrules`, `README.md`, or config manifests without guessing.
- WHEN authoring `debug_session_memory.md`, sub-agent briefings or findings, `debug_solution.md`, or auxiliary Markdown documents, the Debug Session Orchestrator SHALL load `the ears-syntax-standards skill` and `the bdd-gherkin-specifications skill`.
- WHILE persisting configuration or diagnostics, the Debug Session Orchestrator SHALL redact all secret values before writing to disk.
- WHEN conducting human Q&A, the Debug Session Orchestrator SHALL apply behavioral schemas without rigid lexical word-locking on user replies.

## Workflow Routing Table

Execute Phases `00` through `05` in strict sequential order (one workflow file in context at a time):

| Phase | Workflow | Scope |
|---|---|---|
| **00** | [00-disambiguation-init](workflows/00-disambiguation-init/workflow.md) | Clarity check & Q&A stop, `specs/debug/` collision check, `debug_session_memory.md` EARS/BDD init. |
| **01** | [01-context-workspace](workflows/01-context-workspace/workflow.md) | Convention discovery, stack/logging detection, mandatory secrets redaction, dirty workspace analysis. |
| **02** | [02-browser-setup](workflows/02-browser-setup/workflow.md) | Clean-profile Chromium launch, Remote Debugging Port attachment, Console/Network monitoring. |
| **03** | [03-execution-orchestration](workflows/03-execution-orchestration/workflow.md) | Reproduction, DOM/log/HAR capture, sub-agent context handoff, memory pruning, anti-loop stop gate. |
| **04** | [04-planning-choice](workflows/04-planning-choice/workflow.md) | Scope guardrails, architectural safety confirmation gate, root-cause report, interactive Option A/B prompt. |
| **05** | [05-resolution-execution](workflows/05-resolution-execution/workflow.md) | Branching execution: Path A (direct patch + mandatory browser retest) vs Path B (`debug_solution.md`). |

## Behavioral Scenarios

```gherkin
Feature: Isolated Debug Session Orchestration
  @REQ-DBG-001
  Scenario: Isolated reproduction with redacted memory and sub-agent context handoff
    Given an unambiguous bug report with action, expected behavior, and observed failure
    When the Debug Session Orchestrator initializes a session folder and delegates domain analysis
    Then the Debug Session Orchestrator hands off the redacted session memory and records EARS findings

  @REQ-DBG-002
  Scenario: Block secret persistence and pause on architectural boundary
    Given extracted environment configuration containing credential keys and a root cause in core logic
    When the Debug Session Orchestrator persists configuration and proposes the fix
    Then the Debug Session Orchestrator writes only variable names with file locations and requests confirmation
```
