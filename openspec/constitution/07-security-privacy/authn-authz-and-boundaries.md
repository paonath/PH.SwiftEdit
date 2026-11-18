---
area: "07-security-privacy"
file: "authn-authz-and-boundaries.md"
rules: ["SEC-001", "SEC-002", "SEC-003", "SEC-004"]
---

# 07-security-privacy/authn-authz-and-boundaries (SEC-001..SEC-004)

## Context
- authn_authz: `macOS/iOS App Sandbox Least-Privilege Entitlements and Security-Scoped File/Folder Bookmarks`
- transport_policy: `100% Offline Zero-Socket & Zero-Subprocess Isolation + Confined NSWorkspace Finder/Terminal/iTerm2 Handoff`

## Rules
- **SEC-001**: Platform `.entitlements` manifests SHALL enable exclusively App Sandbox user-selected read-write and app-scoped bookmark keys on macOS or document-picker sandbox confinement on iOS while forbidding network, `files.all`, `temporary-exception`, and library-validation-relaxation entitlements.
- **SEC-002**: Filesystem and Folder Navigator adapters resolving security-scoped URLs SHALL bracket every scoped access with `startAccessingSecurityScopedResource()` and a deterministic `defer { stopAccessingSecurityScopedResource() }` release on all normal and throwing exits.
- **SEC-003**: IF a save target, Folder Navigator node, or local Markdown asset resolves via `resolvingSymlinksInPath()` outside the active user-granted URL scope or traverses an untrusted symbolic link, THEN the filesystem adapter SHALL abort the operation with `DomainError.securityScopeViolation`.
- **SEC-004**: The application runtime on macOS and iOS SHALL execute 100% offline with zero socket connections and zero subprocesses while restricting external handoffs to user-confirmed `https`, `http`, or `mailto` URIs and symlink-confined `NSWorkspace` `Finder` reveals or verified directory-only Terminal launches (`com.googlecode.iterm2`, `com.apple.Terminal`).
