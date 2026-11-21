---
name: security-secret-scanner
description: "Scans workspace source files, configuration files, and uncommitted git diffs for potential exposed credentials, private keys, or API tokens. Triggers: security-secret-scanner, secret scan, scan secrets, check security, security audit."
---

# Security Secret Scanner

## Purpose

Automates pre-commit and on-demand security scanning across project files to prevent accidental leakage of sensitive credentials, API keys, private certificates, or unencrypted database passwords.

## Procedure

1. **Staged and Unstaged Diff Inspection**:
   - WHEN inspecting uncommitted changes, the security-secret-scanner skill SHALL scan `git diff HEAD` for credential patterns:
     - API Tokens: `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9_]{36}`, `eyJ[A-Za-z0-9_-]+\.`
     - Private Keys: `-----BEGIN RSA PRIVATE KEY-----`, `-----BEGIN PRIVATE KEY-----`
     - Connection Strings: `Server=.*;Database=.*;User Id=.*;Password=.*;`
2. **Environment File Audit**:
   - The security-secret-scanner skill SHALL verify that `.env` and `appsettings.Development.local.json` files remain untracked and ignored in `.gitignore`.
3. **Remediation**:
   - IF a credential literal or tracked environment file is detected, THEN the security-secret-scanner skill SHALL fail the audit and escalate remediation per the `security-secrets-policy` rule.
   - Flag any detected key or secret immediately to the user.

## Behavioral Scenarios

```gherkin
Feature: Security Secret Scanner
  @REQ-SEC-SCAN-001
  Scenario: Clean repository diff and ignored environment templates pass audit
    Given a workspace with clean uncommitted diffs and ignored environment configuration files
    When the security-secret-scanner evaluates repository state
    Then the scanner reports zero exposed credentials and allows progression

  @REQ-SEC-SCAN-002
  Scenario: Detected credential literal or tracked environment file fails closed
    Given an uncommitted diff contains an exposed access key pattern or tracked local secrets file
    When the security-secret-scanner evaluates repository state
    Then the scanner fails the audit and flags the secret finding immediately to the user
    And remediation follows the security-secrets-policy rule
```
