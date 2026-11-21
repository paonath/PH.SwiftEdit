---
name: webapp-testing
description: Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.
---

# Web Application Testing (`webapp-testing` — Progressive Disclosure Router)

Toolkit for comprehensive testing and debugging of local web applications using Playwright automation (`test-helper.js`).
Enforces `Single-Reference Lock`: load only the active `workflows/NN-*/workflow.md` file for the current testing or debugging task.

## When to Use This Skill

- Test frontend functionality and validate form submissions/flows in a real browser
- Verify UI behavior, element presence, and responsive design across viewports
- Debug web application issues, capture screenshots, and inspect browser console logs

## Core Capabilities

1. **Browser Automation**: Navigate URLs, click buttons/links, fill forms, select dropdowns, handle dialogs.
2. **Verification**: Assert element presence/visibility, verify text and URLs, test responsive layouts.
3. **Debugging**: Capture full-page screenshots, stream console logs, inspect network requests, handle errors.

## Workflow Routing Table

| Phase | Workflow | Scope |
|---|---|---|
| **01** | [01-browser-automation-and-verification](workflows/01-browser-automation-and-verification/workflow.md) | Prerequisites, navigation/form examples, explicit wait patterns, selector & incremental testing guidelines. |
| **02** | [02-ui-debugging-and-diagnostics](workflows/02-ui-debugging-and-diagnostics/workflow.md) | Screenshot capture, console log & error-handling patterns, resource cleanup (`browser.close()`), and `test-helper.js` helpers. |

## Limitations

- Requires a Node.js environment and a running local or accessible web server.
- Cannot test native mobile apps (use React Native Testing Library instead).

## Formal Requirements (EARS)

- The webapp-testing skill SHALL run Playwright verification checks against an active web server using explicit waits and clean browser resource disposal.
- WHEN a test step encounters a runtime error or assertion failure, the webapp-testing workflow SHALL record full-viewport screenshots and browser console logs via `test-helper.js`.
- IF the target web server is unreachable or an operation exceeds its configured timeout, THEN the webapp-testing harness SHALL close active browser sessions and report the failure diagnostic.

## BDD Scenarios

```gherkin
Feature: Local Web Application Verification

  @REQ-WAT-001
  Scenario: Successful user registration flow verification
    Given a running local web application route
    When the verification suite submits valid registration details
    Then the application transitions to the authenticated dashboard route

  @REQ-WAT-002
  Scenario: Timeout or unreachable server triggers failure capture and cleanup
    Given an unresponsive local application endpoint
    When the verification harness executes a diagnostic check
    Then failure diagnostics are captured and browser resources close cleanly
```
