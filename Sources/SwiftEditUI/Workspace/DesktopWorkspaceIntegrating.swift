import Foundation
import SwiftEditCore

#if os(macOS)
import AppKit
#endif

/// Value type tracking a sidebar file or folder staged for Cut (`move`) or Copy (`copy` with collision suffix) (`BC-012`).
public struct SidebarFileClipboard: Equatable, Sendable {
    public let sourceURL: URL
    public let mode: PasteMode

    public init(sourceURL: URL, mode: PasteMode) {
        self.sourceURL = sourceURL.standardizedFileURL
        self.mode = mode
    }
}

/// Allowlisted macOS terminal application metadata discovered on the host (`SEC-004`).
public struct KnownTerminalApp: Identifiable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}

/// Catalog of allowlisted macOS terminal applications for directory-only `NSWorkspace` launches (`CWE-78`, `SEC-004`).
public enum TerminalCatalog {
    public static let iTerm2BundleIdentifier = "com.googlecode.iterm2"
    public static let appleTerminalBundleIdentifier = "com.apple.Terminal"

    public static let knownTerminals: [KnownTerminalApp] = [
        KnownTerminalApp(bundleIdentifier: iTerm2BundleIdentifier, displayName: "iTerm2"),
        KnownTerminalApp(bundleIdentifier: appleTerminalBundleIdentifier, displayName: "Terminal"),
        KnownTerminalApp(bundleIdentifier: "dev.warp.Warp-Stable", displayName: "Warp"),
        KnownTerminalApp(bundleIdentifier: "com.mitchellh.ghostty", displayName: "Ghostty"),
        KnownTerminalApp(bundleIdentifier: "com.github.wez.wezterm", displayName: "WezTerm"),
        KnownTerminalApp(bundleIdentifier: "org.alacritty", displayName: "Alacritty"),
        KnownTerminalApp(bundleIdentifier: "net.kovidgoyal.kitty", displayName: "Kitty"),
        KnownTerminalApp(bundleIdentifier: "co.zeit.hyper", displayName: "Hyper"),
    ]

    public static let allowedBundleIdentifiers: Set<String> = Set(knownTerminals.map(\.bundleIdentifier))

    /// Default macOS host probe returning `true` when `NSWorkspace` finds an installed app matching `bundleIdentifier`.
    @MainActor
    public static func isApplicationInstalled(bundleIdentifier: String) -> Bool {
        #if os(macOS)
        guard allowedBundleIdentifiers.contains(bundleIdentifier) else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        #else
        return false
        #endif
    }

    /// Discovers installed allowlisted terminals using `isInstalled` (unit-testable headless seam).
    public static func installedTerminals(
        isInstalled: (String) -> Bool
    ) -> [KnownTerminalApp] {
        knownTerminals.filter { isInstalled($0.bundleIdentifier) }
    }

    /// Discovers installed allowlisted terminals on the running macOS system.
    @MainActor
    public static func installedTerminals() -> [KnownTerminalApp] {
        installedTerminals { isApplicationInstalled(bundleIdentifier: $0) }
    }

    /// Resolves the target terminal bundle ID from `preferredBundleID` (`nil` = Auto, preferring `iTerm2` if installed) and installed bundle IDs.
    public static func resolveBundleID(
        preferredBundleID: String?,
        installedBundleIDs: Set<String>
    ) -> String {
        if let preferredBundleID,
           allowedBundleIdentifiers.contains(preferredBundleID),
           installedBundleIDs.contains(preferredBundleID) {
            return preferredBundleID
        }
        if installedBundleIDs.contains(iTerm2BundleIdentifier) {
            return iTerm2BundleIdentifier
        }
        return appleTerminalBundleIdentifier
    }
}

/// Verified directory-only terminal launch descriptor produced by `DesktopWorkspaceValidator` (`SEC-004`).
public struct TerminalLaunchResolution: Equatable, Sendable {
    public static let iTerm2BundleIdentifier = TerminalCatalog.iTerm2BundleIdentifier
    public static let appleTerminalBundleIdentifier = TerminalCatalog.appleTerminalBundleIdentifier
    public static let allowedTerminalBundleIdentifiers: Set<String> = TerminalCatalog.allowedBundleIdentifiers

    public let directoryURL: URL
    public let bundleIdentifier: String

    public init(directoryURL: URL, bundleIdentifier: String) {
        self.directoryURL = directoryURL
        self.bundleIdentifier = bundleIdentifier
    }
}

/// Pure validator enforcing `resolvingSymlinksInPath()` confinement, directory-only resolution (`CWE-78`), and allowlisted terminal bundle identifiers (`SEC-003`, `SEC-004`).
public enum DesktopWorkspaceValidator {
    /// Verifies that `targetURL` exists and resolves via `resolvingSymlinksInPath()` inside `scopeURL` (`CWE-22`, `CWE-59`, `SEC-003`).
    public static func verifyItemConfinement(targetURL: URL, withinScope scopeURL: URL?) throws {
        let standardized = targetURL.standardizedFileURL
        let resolvedPath = standardized.resolvingSymlinksInPath().standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw DomainError.securityScopeViolation(path: standardized.path)
        }
        if let scopeURL {
            let canonicalScope = scopeURL.resolvingSymlinksInPath().standardizedFileURL.path
            let isConfined = (canonicalScope == "/")
                ? resolvedPath.hasPrefix("/")
                : (resolvedPath == canonicalScope || resolvedPath.hasPrefix(canonicalScope + "/"))
            if !isConfined {
                throw DomainError.securityScopeViolation(path: standardized.path)
            }
        }
    }

    /// Verifies that `folderURL` is confined inside `scopeURL` and resolves to an existing directory (never a regular or executable file) (`CWE-78`, `SEC-003`, `SEC-004`).
    public static func verifyDirectoryConfinement(folderURL: URL, withinScope scopeURL: URL?) throws {
        let standardized = folderURL.standardizedFileURL
        try verifyItemConfinement(targetURL: standardized, withinScope: scopeURL)
        let resolvedPath = standardized.resolvingSymlinksInPath().standardizedFileURL.path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDir), isDir.boolValue else {
            throw DomainError.securityScopeViolation(path: standardized.path)
        }
    }

    /// Resolves `targetURL` to its verified directory (if `targetURL` is a file such as `.sh`/`.command`, resolves to its parent directory), enforces workspace confinement, and validates the terminal bundle allowlist (`CWE-78`, `SEC-003`, `SEC-004`).
    public static func resolveTerminalLaunch(
        targetURL: URL,
        withinScope scopeURL: URL?,
        explicitBundleIdentifier: String?,
        isITerm2Installed: Bool,
        isITerm2Preferred: Bool
    ) throws -> TerminalLaunchResolution {
        let standardized = targetURL.standardizedFileURL
        try verifyItemConfinement(targetURL: standardized, withinScope: scopeURL)

        let resolvedTarget = standardized.resolvingSymlinksInPath().standardizedFileURL
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolvedTarget.path, isDirectory: &isDir)

        let candidateDirectory: URL
        if exists && isDir.boolValue {
            candidateDirectory = URL(fileURLWithPath: resolvedTarget.path, isDirectory: true).standardizedFileURL
        } else {
            let parentPath = resolvedTarget.deletingLastPathComponent().standardizedFileURL.path
            candidateDirectory = URL(fileURLWithPath: parentPath, isDirectory: true).standardizedFileURL
        }

        try verifyDirectoryConfinement(folderURL: candidateDirectory, withinScope: scopeURL)

        let bundleID: String
        if let explicitBundleIdentifier {
            guard TerminalLaunchResolution.allowedTerminalBundleIdentifiers.contains(explicitBundleIdentifier) else {
                throw DomainError.securityScopeViolation(path: explicitBundleIdentifier)
            }
            bundleID = explicitBundleIdentifier
        } else if isITerm2Installed && isITerm2Preferred {
            bundleID = TerminalLaunchResolution.iTerm2BundleIdentifier
        } else {
            bundleID = TerminalLaunchResolution.appleTerminalBundleIdentifier
        }

        return TerminalLaunchResolution(directoryURL: candidateDirectory, bundleIdentifier: bundleID)
    }

    /// Overload honoring `PreferredTerminalApp`: `.auto` defaults to macOS `Terminal.app` (`BUG-017`), `.terminal` forces `Terminal.app`, `.iTerm2` selects iTerm2 when installed, and explicit allowlisted bundle IDs remain strictly validated (`SEC-003`).
    public static func resolveTerminalLaunch(
        targetURL: URL,
        withinScope scopeURL: URL?,
        explicitBundleIdentifier: String? = nil,
        preferredTerminal: PreferredTerminalApp = .auto,
        isITerm2Installed: Bool
    ) throws -> TerminalLaunchResolution {
        let resolvedExplicit: String?
        if let explicitBundleIdentifier {
            resolvedExplicit = explicitBundleIdentifier
        } else if preferredTerminal == .terminal {
            resolvedExplicit = TerminalLaunchResolution.appleTerminalBundleIdentifier
        } else {
            resolvedExplicit = nil
        }
        return try resolveTerminalLaunch(
            targetURL: targetURL,
            withinScope: scopeURL,
            explicitBundleIdentifier: resolvedExplicit,
            isITerm2Installed: isITerm2Installed,
            isITerm2Preferred: preferredTerminal == .iTerm2 && isITerm2Installed
        )
    }
}

/// Explicit user preference for Terminal integration inside `MacOSWorkspaceAdapter` (`BUG-017`).
public enum PreferredTerminalApp: String, Codable, Equatable, CaseIterable, Sendable {
    /// Defaults to macOS `Terminal.app` (`com.apple.Terminal`) unless opted into `.iTerm2` (`BUG-017`).
    case auto
    case terminal
    case iTerm2
}

/// `@MainActor` desktop integration seam isolating `NSWorkspace` Finder and Terminal launches from unit tests (`AR-003`, `AR-007`, `SEC-004`, `TEST-004`).
@MainActor
public protocol DesktopWorkspaceIntegrating {
    func revealInFinder(itemURL: URL, withinScope scopeURL: URL?) throws
    func openFolderInFinder(folderURL: URL, withinScope scopeURL: URL?) throws
    @discardableResult
    func openInTerminal(
        targetURL: URL,
        withinScope scopeURL: URL?,
        explicitBundleIdentifier: String?
    ) throws -> TerminalLaunchResolution
}

/// Production macOS `DesktopWorkspaceIntegrating` adapter invoking `NSWorkspace` strictly on confined paths and verified directories with zero subprocesses (`CWE-78`, `SEC-003`, `SEC-004`).
@MainActor
public struct MacOSWorkspaceAdapter: DesktopWorkspaceIntegrating {
    public var preferredTerminal: PreferredTerminalApp
    public var preferredTerminalBundleID: String?

    public init(preferredTerminal: PreferredTerminalApp = .auto, preferredTerminalBundleID: String? = nil) {
        self.preferredTerminal = preferredTerminal
        self.preferredTerminalBundleID = preferredTerminalBundleID
    }

    /// Reveals `itemURL` in Finder after verifying workspace symlink confinement (`SEC-003`, `SEC-004`).
    public func revealInFinder(itemURL: URL, withinScope scopeURL: URL?) throws {
        try DesktopWorkspaceValidator.verifyItemConfinement(targetURL: itemURL, withinScope: scopeURL)
        #if os(macOS)
        let resolved = itemURL.resolvingSymlinksInPath().standardizedFileURL
        NSWorkspace.shared.activateFileViewerSelecting([resolved])
        #endif
    }

    /// Opens `folderURL` in Finder after verifying directory-only workspace confinement (`SEC-003`, `SEC-004`).
    public func openFolderInFinder(folderURL: URL, withinScope scopeURL: URL?) throws {
        try DesktopWorkspaceValidator.verifyDirectoryConfinement(folderURL: folderURL, withinScope: scopeURL)
        #if os(macOS)
        let resolved = folderURL.resolvingSymlinksInPath().standardizedFileURL
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: resolved.path)
        #endif
    }

    /// Launches the selected allowlisted terminal (defaulting `.auto` to `iTerm2` if installed, else `Terminal.app`) at the verified directory URL via `NSWorkspace` with zero subprocesses (`CWE-78`, `SEC-004`).
    @discardableResult
    public func openInTerminal(
        targetURL: URL,
        withinScope scopeURL: URL?,
        explicitBundleIdentifier: String? = nil
    ) throws -> TerminalLaunchResolution {
        #if os(macOS)
        let installedBundleIDs = Set(TerminalCatalog.installedTerminals().map(\.bundleIdentifier))
        let isITerm2Installed = installedBundleIDs.contains(TerminalLaunchResolution.iTerm2BundleIdentifier)
        let effectiveExplicitBundleID: String?
        if let explicitBundleIdentifier {
            effectiveExplicitBundleID = explicitBundleIdentifier
        } else if preferredTerminal == .auto {
            effectiveExplicitBundleID = TerminalCatalog.resolveBundleID(
                preferredBundleID: preferredTerminalBundleID,
                installedBundleIDs: installedBundleIDs
            )
        } else {
            effectiveExplicitBundleID = nil
        }

        let resolution = try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: targetURL,
            withinScope: scopeURL,
            explicitBundleIdentifier: effectiveExplicitBundleID,
            preferredTerminal: preferredTerminal,
            isITerm2Installed: isITerm2Installed
        )
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: resolution.bundleIdentifier) else {
            throw DomainError.ioFailure("Terminal application unavailable: \(resolution.bundleIdentifier)")
        }
        NSWorkspace.shared.open([resolution.directoryURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        return resolution
        #else
        return try DesktopWorkspaceValidator.resolveTerminalLaunch(
            targetURL: targetURL,
            withinScope: scopeURL,
            explicitBundleIdentifier: explicitBundleIdentifier,
            preferredTerminal: preferredTerminal,
            isITerm2Installed: false
        )
        #endif
    }
}
