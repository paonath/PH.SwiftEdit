---
area: "07-security-privacy"
file: "authn-authz-and-boundaries.md"
rules: ["SEC-001", "SEC-002", "SEC-003", "SEC-004"]
---

# 07-security-privacy/authn-authz-and-boundaries (SEC-001..SEC-004)

## Context
- authn_authz: `macOS App Sandbox Least-Privilege Entitlements and Security-Scoped Bookmarks`
- transport_policy: `100% Offline Zero-Network Isolation (network.client and network.server forbidden)`

## Rules
- **SEC-001**: The Xcode `.entitlements` manifest SHALL enable exclusively `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-write`, and `com.apple.security.files.bookmarks.app-scope` while forbidding network, `files.all`, `temporary-exception`, and library-validation-relaxation entitlements.
- **SEC-002**: Filesystem adapters resolving security-scoped bookmarks SHALL bracket every scoped URL access with `startAccessingSecurityScopedResource()` and a deterministic `defer { stopAccessingSecurityScopedResource() }` release on all normal and throwing exits.
- **SEC-003**: IF a target save path or local Markdown asset resolves via `resolvingSymlinksInPath()` outside the active user-granted URL scope or traverses an untrusted symbolic link during write, THEN the filesystem adapter SHALL abort the operation with `DomainError.securityScopeViolation`.
- **SEC-004**: The application runtime SHALL execute 100% offline with zero outbound or inbound socket connections while restricting `NSWorkspace` external URI handoffs to user-confirmed `https`, `http`, or `mailto` targets.
