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

/// Immutable descriptor for a single shallow workspace directory child entry, including hidden dotfiles and bounded binary classification (`BC-007`, `DATA-003`, `DATA-007`).
public struct FolderEntryDescriptor: Equatable, Sendable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let isHiddenDotfile: Bool
    /// `true` when a regular non-directory file contains `0x00` within its first `8 KiB` (`DocumentCodec.binaryProbeBytes`) (`DATA-003`).
    public let isBinary: Bool

    public init(
        name: String,
        url: URL,
        isDirectory: Bool,
        isHiddenDotfile: Bool,
        isBinary: Bool = false
    ) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.isHiddenDotfile = isHiddenDotfile
        self.isBinary = isBinary
    }
}

/// Resolved parent-directory transition for left-sidebar `...` up-navigation (`BC-007`, `DATA-007`, `SEC-002`, `SEC-003`).
public struct ParentDirectoryResolution: Equatable, Sendable {
    public let parentURL: URL
    public let updatedScopeRootURL: URL

    public init(parentURL: URL, updatedScopeRootURL: URL) {
        self.parentURL = parentURL
        self.updatedScopeRootURL = updatedScopeRootURL
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
            let resourceValues = try? resolvedChild.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let isDir = resourceValues?.isDirectory ?? false
            let isRegularFile = resourceValues?.isRegularFile ?? false
            let isBinary = (!isDir && isRegularFile) ? Self.probeIsBinaryRegularFile(at: resolvedChild) : false
            descriptors.append(FolderEntryDescriptor(
                name: name,
                url: reportedChildURL,
                isDirectory: isDir,
                isHiddenDotfile: name.hasPrefix("."),
                isBinary: isBinary
            ))
        }

        return descriptors.sorted(by: Self.compareEntries)
    }

    /// Reads at most `DocumentCodec.binaryProbeBytes` (`8 KiB`) from a confinement-verified regular file to classify NUL-bearing binaries without loading full payloads (`CWE-400`, `DATA-003`, `SEC-003`).
    private static func probeIsBinaryRegularFile(at resolvedURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: resolvedURL) else {
            return false
        }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: DocumentCodec.binaryProbeBytes) else {
            return false
        }
        return DocumentCodec.isBinaryPrefix(prefix)
    }

    /// Resolves the parent directory URL (`...`) for `currentDirectoryURL` when not at `"/"` and either inside `scopeURL` or readable under user permissions (`BC-007`, `DATA-007`, `SEC-002`, `SEC-003`).
    ///
    /// Security invariants (`CWE-22`, `CWE-59`, `SEC-002`, `SEC-003`):
    /// - Rejects any candidate parent that is itself a symbolic link or where `currentDirectoryURL` / `candidateParent` resolves outside the ancestor/descendant lineage of `scopeURL`.
    /// - Brackets external parent permission probing with `startAccessing(url:)` and a deterministic `defer { stopAccessing(url:) }` release.
    /// - Throws: `DomainError.securityScopeViolation` when a symbolic link attempts to redirect parent traversal outside the permitted hierarchy.
    public func resolveParentDirectory(
        from currentDirectoryURL: URL,
        withinScope scopeURL: URL?,
        isParentReadable: (URL) -> Bool = { url in
            (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil
        }
    ) throws -> ParentDirectoryResolution? {
        let standardizedCurrent = currentDirectoryURL.standardizedFileURL
        guard standardizedCurrent.path != "/" else {
            return nil
        }

        let candidateParent = standardizedCurrent.deletingLastPathComponent().standardizedFileURL
        if Self.isSymbolicLink(atPath: standardizedCurrent.path) || Self.isSymbolicLink(atPath: candidateParent.path) {
            throw DomainError.securityScopeViolation(path: candidateParent.path)
        }

        let currentScope = (scopeURL ?? standardizedCurrent).standardizedFileURL
        let canonicalScopePath = currentScope.resolvingSymlinksInPath().standardizedFileURL.path
        let candidateParentResolved = candidateParent.resolvingSymlinksInPath().standardizedFileURL
        let candidateParentResolvedPath = candidateParentResolved.path

        let isInsideCurrentScope = Self.isDescendantOrEqual(path: candidateParentResolvedPath, ancestorPath: canonicalScopePath)
        let isAncestorOfCurrentScope = Self.isDescendantOrEqual(path: canonicalScopePath, ancestorPath: candidateParentResolvedPath)

        guard isInsideCurrentScope || isAncestorOfCurrentScope else {
            throw DomainError.securityScopeViolation(path: candidateParent.path)
        }

        if isInsideCurrentScope {
            return ParentDirectoryResolution(
                parentURL: candidateParentResolved,
                updatedScopeRootURL: currentScope.resolvingSymlinksInPath().standardizedFileURL
            )
        }

        let didAccess = securityScope.startAccessing(url: candidateParentResolved)
        defer {
            if didAccess {
                securityScope.stopAccessing(url: candidateParentResolved)
            }
        }

        guard isParentReadable(candidateParentResolved) else {
            return nil
        }

        return ParentDirectoryResolution(
            parentURL: candidateParentResolved,
            updatedScopeRootURL: candidateParentResolved
        )
    }

    private static func isSymbolicLink(atPath path: String) -> Bool {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    private static func isDescendantOrEqual(path: String, ancestorPath: String) -> Bool {
        if ancestorPath == "/" {
            return path.hasPrefix("/")
        }
        return path == ancestorPath || path.hasPrefix(ancestorPath + "/")
    }

    private static func verifyConfinement(of candidateURL: URL, canonicalScopePath: String) throws {
        let resolvedPath = candidateURL.resolvingSymlinksInPath().standardizedFileURL.path
        if !isDescendantOrEqual(path: resolvedPath, ancestorPath: canonicalScopePath) {
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
