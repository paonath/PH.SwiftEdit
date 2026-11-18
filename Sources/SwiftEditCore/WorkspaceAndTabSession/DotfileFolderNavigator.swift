import Foundation

/// Narrow `Sendable` seam wrapping macOS/iOS security-scoped URL access so balanced `start`/`stop` lifecycles can be verified deterministically (`AR-007`, `DATA-007`, `SEC-002`, `TEST-004`).
public protocol SecurityScopedResourceAccessing: Sendable {
    func startAccessing(url: URL) -> Bool
    func stopAccessing(url: URL)
}

/// Production `SecurityScopedResourceAccessing` adapter forwarding to `URL.startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`.
public struct SystemSecurityScopedResourceAccessor: SecurityScopedResourceAccessing, Sendable {
    public init() {}

    public func startAccessing(url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    public func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

/// Immutable descriptor for a single shallow workspace directory child entry, including hidden dotfiles (`BC-007`, `DATA-007`).
public struct FolderEntryDescriptor: Equatable, Sendable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let isHiddenDotfile: Bool

    public init(name: String, url: URL, isDirectory: Bool, isHiddenDotfile: Bool) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.isHiddenDotfile = isHiddenDotfile
    }
}

/// Shallow workspace directory navigator surfacing regular files and hidden dotfiles (`.env`, `.gitignore`) sorted directories-first (`BC-007`, `DATA-007`, `SEC-002`, `SEC-003`, `SEC-012`).
///
/// Security invariants:
/// - Brackets every enumeration with `startAccessing(url:)` and a deterministic `defer { stopAccessing(url:) }` release on all normal and throwing paths (`SEC-002`).
/// - Verifies both `directoryURL` and every enumerated child entry via `resolvingSymlinksInPath()` against the canonical granted workspace root, aborting with `DomainError.securityScopeViolation` upon any symlink escape (`SEC-003`, `CWE-22`).
public struct DotfileFolderNavigator: Sendable {
    private let securityScope: any SecurityScopedResourceAccessing

    public init(securityScope: any SecurityScopedResourceAccessing = SystemSecurityScopedResourceAccessor()) {
        self.securityScope = securityScope
    }

    /// Enumerates direct children of `directoryURL` (including hidden dotfiles) within `scopeURL` while bracketing access with `startAccessing` / `defer { stopAccessing }`.
    /// - Throws: `DomainError.securityScopeViolation` when `directoryURL` or any child symlink resolves outside `scopeURL` (or `directoryURL` when `scopeURL` is `nil`).
    public func listEntries(in directoryURL: URL, withinScope scopeURL: URL? = nil) throws -> [FolderEntryDescriptor] {
        let didAccess = securityScope.startAccessing(url: directoryURL)
        defer {
            if didAccess {
                securityScope.stopAccessing(url: directoryURL)
            }
        }

        let canonicalScopePath = (scopeURL ?? directoryURL).resolvingSymlinksInPath().standardizedFileURL.path
        try Self.verifyConfinement(of: directoryURL, canonicalScopePath: canonicalScopePath)

        let childURLs: [URL]
        do {
            childURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }

        var descriptors: [FolderEntryDescriptor] = []
        descriptors.reserveCapacity(childURLs.count)

        for rawChildURL in childURLs {
            let name = rawChildURL.lastPathComponent
            guard name != "." && name != ".." else { continue }
            let reportedChildURL = directoryURL.appendingPathComponent(name)
            try Self.verifyConfinement(of: reportedChildURL, canonicalScopePath: canonicalScopePath)

            let resolvedChild = reportedChildURL.resolvingSymlinksInPath()
            let isDir = (try? resolvedChild.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            descriptors.append(FolderEntryDescriptor(
                name: name,
                url: reportedChildURL,
                isDirectory: isDir,
                isHiddenDotfile: name.hasPrefix(".")
            ))
        }

        return descriptors.sorted(by: Self.compareEntries)
    }

    private static func verifyConfinement(of candidateURL: URL, canonicalScopePath: String) throws {
        let resolvedPath = candidateURL.resolvingSymlinksInPath().standardizedFileURL.path
        let isConfined = resolvedPath == canonicalScopePath || resolvedPath.hasPrefix(canonicalScopePath + "/")
        if !isConfined {
            throw DomainError.securityScopeViolation(path: candidateURL.path)
        }
    }

    private static func compareEntries(_ lhs: FolderEntryDescriptor, _ rhs: FolderEntryDescriptor) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }
        let lhsLower = lhs.name.lowercased()
        let rhsLower = rhs.name.lowercased()
        if lhsLower != rhsLower {
            return lhsLower < rhsLower
        }
        return lhs.name < rhs.name
    }
}
