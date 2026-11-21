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
- **SEC-001**: Platform `.entitlements` manifests SHALL enable exclusively App Sandbox user-selected read-write, app-scoped bookmark, and (on macOS) `com.apple.security.network.client` strictly for user-initiated GitHub Releases HTTPS update checks while forbidding `network.server`, `files.all`, `temporary-exception`, and library-validation-relaxation entitlements.
- **SEC-002**: Filesystem and Folder Navigator adapters resolving security-scoped URLs SHALL bracket every scoped access with `startAccessingSecurityScopedResource()` and a deterministic `defer { stopAccessingSecurityScopedResource() }` release on all normal and throwing exits.
- **SEC-003**: IF a save target, Folder Navigator node, or local Markdown asset resolves via `resolvingSymlinksInPath()` outside the active user-granted URL scope or traverses an untrusted symbolic link, THEN the filesystem adapter SHALL abort the operation with `DomainError.securityScopeViolation`.
- **SEC-004**: Document editing and preview run 100% offline with zero socket connections outside manual `Check for Updates…` HTTPS GET requests to `api.github.com` and with zero subprocesses while restricting external handoffs to user-confirmed `https`, `http`, or `mailto` URIs and symlink-confined `NSWorkspace` `Finder` reveals or verified directory-only allowlisted Terminal launches (`com.googlecode.iterm2`, `com.apple.Terminal`, `dev.warp.Warp-Stable`, `com.mitchellh.ghostty`, `com.github.wez.wezterm`, `org.alacritty`, `net.kovidgoyal.kitty`, `co.zeit.hyper`).
