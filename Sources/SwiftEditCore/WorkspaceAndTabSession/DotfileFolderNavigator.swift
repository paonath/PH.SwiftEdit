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

/// Policy governing symbolic links inside a workspace directory that resolve outside the granted sandbox scope (`BUG-017`, `SEC-003`).
public enum EscapingSymlinkPolicy: Equatable, Sendable {
    /// Throws `DomainError.securityScopeViolation` on the first child symlink pointing outside scope (default strict mode).
    case failClosed
    /// Skips escaping child symlinks prior to any file-attribute or `8 KiB` probe and reports how many were skipped (`BUG-017`).
    case skipAndReport
}

/// Result returned by `DotfileFolderNavigator.listEntriesWithDiagnostics(in:withinScope:symlinkPolicy:)` (`BUG-017`).
public struct FolderListingResult: Equatable, Sendable {
    public let entries: [FolderEntryDescriptor]
    public let skippedExternalSymlinkCount: Int

    public init(entries: [FolderEntryDescriptor], skippedExternalSymlinkCount: Int) {
        self.entries = entries
        self.skippedExternalSymlinkCount = skippedExternalSymlinkCount
    }
}

/// Shallow workspace directory navigator surfacing regular files and hidden dotfiles (`.env`, `.gitignore`) sorted directories-first (`BC-007`, `DATA-007`, `SEC-002`, `SEC-003`, `SEC-012`).
///
/// Security invariants:
/// - Brackets every enumeration with `startAccessing(url:)` and a deterministic `defer { stopAccessing(url:) }` release on all normal and throwing paths (`SEC-002`).
/// - Verifies `directoryURL` first (always fail-closed) and every enumerated child entry via `resolvingSymlinksInPath()` strictly BEFORE any resource or `8 KiB` binary probe (`SEC-003`, `CWE-22`).
public struct DotfileFolderNavigator: Sendable {
    private let securityScope: any SecurityScopedResourceAccessing
    private let fileSystem: (any FileSystemProviding)?

    public init(
        securityScope: any SecurityScopedResourceAccessing = SystemSecurityScopedResourceAccessor(),
        fileSystem: (any FileSystemProviding)? = nil
    ) {
        self.securityScope = securityScope
        self.fileSystem = fileSystem
    }

    /// Enumerates direct children of `directoryURL` (including hidden dotfiles) within `scopeURL` under `.failClosed` symlink confinement while bracketing access with `startAccessing` / `defer { stopAccessing }`.
    /// - Throws: `DomainError.securityScopeViolation` when `directoryURL` or any child symlink resolves outside `scopeURL` (or `directoryURL` when `scopeURL` is `nil`).
    public func listEntries(in directoryURL: URL, withinScope scopeURL: URL? = nil) throws -> [FolderEntryDescriptor] {
        try listEntriesWithDiagnostics(in: directoryURL, withinScope: scopeURL, symlinkPolicy: .failClosed).entries
    }

    /// Enumerates direct children of `directoryURL` within `scopeURL` applying `symlinkPolicy` and reporting any skipped out-of-scope child symlinks (`BUG-017`, `SEC-003`).
    ///
    /// - Invariant: `directoryURL` itself is ALWAYS verified fail-closed before enumeration even under `.skipAndReport`, and each child's `verifyConfinement` executes strictly BEFORE `resourceValues` or `8 KiB` binary prefix reads (`CWE-22`).
    public func listEntriesWithDiagnostics(
        in directoryURL: URL,
        withinScope scopeURL: URL? = nil,
        symlinkPolicy: EscapingSymlinkPolicy = .failClosed
    ) throws -> FolderListingResult {
        try listEntriesInternal(
            in: directoryURL,
            withinScope: scopeURL,
            symlinkPolicy: symlinkPolicy,
            probeBinary: true
        ).listing
    }

    func listEntriesInternal(
        in directoryURL: URL,
        withinScope scopeURL: URL? = nil,
        symlinkPolicy: EscapingSymlinkPolicy = .failClosed,
        probeBinary: Bool
    ) throws -> (listing: FolderListingResult, regularFileFlags: [URL: Bool]) {
        let didAccess = securityScope.startAccessing(url: directoryURL)
        defer {
            if didAccess {
                securityScope.stopAccessing(url: directoryURL)
            }
        }

        let effectiveScope = scopeURL ?? directoryURL
        let canonicalScopePath = effectiveScope.resolvingSymlinksInPath().standardizedFileURL.path
        try Self.verifyConfinement(of: directoryURL, canonicalScopePath: canonicalScopePath)

        let childURLs = try Self.dotfileEnumerateChildURLs(in: directoryURL)
        var sortable: [(entry: FolderEntryDescriptor, lowerName: String)] = []
        sortable.reserveCapacity(childURLs.count)
        var regularFileFlags: [URL: Bool] = [:]
        if !probeBinary {
            regularFileFlags.reserveCapacity(childURLs.count)
        }
        var skippedCount = 0

        for rawChildURL in childURLs {
            try dotfileAppendChildIfConfined(
                rawChildURL,
                in: directoryURL,
                effectiveScope: effectiveScope,
                canonicalScopePath: canonicalScopePath,
                symlinkPolicy: symlinkPolicy,
                probeBinary: probeBinary,
                skippedCount: &skippedCount,
                regularFileFlags: &regularFileFlags,
                sortable: &sortable
            )
        }

        sortable.sort(by: Self.dotfilePrecedesInListingOrder)
        let listing = FolderListingResult(
            entries: sortable.map(\.entry),
            skippedExternalSymlinkCount: skippedCount
        )
        return (listing, regularFileFlags)
    }

    private func probeBinaryRegularFile(at resolvedURL: URL, withinScope scopeURL: URL) -> Bool {
        if let fileSystem {
            guard let prefix = try? fileSystem.readData(
                at: resolvedURL,
                maxBytes: DocumentCodec.binaryProbeBytes,
                withinScope: scopeURL
            ) else {
                return false
            }
            return DocumentCodec.isBinaryPrefix(prefix)
        }
        return Self.probeIsBinaryRegularFile(at: resolvedURL)
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
    /// Checks directory readability in `O(1)` via POSIX `opendir`/`closedir` without enumerating child entries.
    public static func isDirectoryReadable(_ url: URL) -> Bool {
        guard let dir = opendir(url.path) else { return false }
        closedir(dir)
        return true
    }

    public func resolveParentDirectory(
        from currentDirectoryURL: URL,
        withinScope scopeURL: URL?,
        isParentReadable: (URL) -> Bool = DotfileFolderNavigator.isDirectoryReadable
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
        let canonicalScopeURL = currentScope.resolvingSymlinksInPath().standardizedFileURL
        let canonicalScopePath = canonicalScopeURL.path
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
                updatedScopeRootURL: canonicalScopeURL
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
        _ = try verifyConfinementAndResolve(of: candidateURL, canonicalScopePath: canonicalScopePath)
    }

    private static func verifyConfinementAndResolve(of candidateURL: URL, canonicalScopePath: String) throws -> URL {
        let resolvedURL = candidateURL.resolvingSymlinksInPath().standardizedFileURL
        if !isDescendantOrEqual(path: resolvedURL.path, ancestorPath: canonicalScopePath) {
            throw DomainError.securityScopeViolation(path: candidateURL.path)
        }
        return resolvedURL
    }
}

private extension DotfileFolderNavigator {
    struct DotfileChildMetadata {
        let isDirectory: Bool
        let isRegularFile: Bool
        let fileSize: Int?
        let resolvedURLForProbe: URL
    }

    static func dotfileEnumerateChildURLs(in directoryURL: URL) throws -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                options: []
            )
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    func dotfileAppendChildIfConfined(
        _ rawChildURL: URL,
        in directoryURL: URL,
        effectiveScope: URL,
        canonicalScopePath: String,
        symlinkPolicy: EscapingSymlinkPolicy,
        probeBinary: Bool,
        skippedCount: inout Int,
        regularFileFlags: inout [URL: Bool],
        sortable: inout [(entry: FolderEntryDescriptor, lowerName: String)]
    ) throws {
        let name = rawChildURL.lastPathComponent
        guard name != "." && name != ".." else { return }
        let reportedChildURL = directoryURL.appendingPathComponent(name)

        guard let metadata = try Self.dotfileResolveChildMetadata(
            rawChildURL: rawChildURL,
            reportedChildURL: reportedChildURL,
            canonicalScopePath: canonicalScopePath,
            symlinkPolicy: symlinkPolicy,
            skippedCount: &skippedCount
        ) else {
            return
        }

        let isBinary = dotfileShouldMarkBinary(metadata, probeBinary: probeBinary, effectiveScope: effectiveScope)
        if !probeBinary {
            regularFileFlags[reportedChildURL] = metadata.isRegularFile
        }

        let descriptor = FolderEntryDescriptor(
            name: name,
            url: reportedChildURL,
            isDirectory: metadata.isDirectory,
            isHiddenDotfile: name.hasPrefix("."),
            isBinary: isBinary
        )
        sortable.append((descriptor, name.lowercased()))
    }

    static func dotfileResolveChildMetadata(
        rawChildURL: URL,
        reportedChildURL: URL,
        canonicalScopePath: String,
        symlinkPolicy: EscapingSymlinkPolicy,
        skippedCount: inout Int
    ) throws -> DotfileChildMetadata? {
        let prefetched = try? rawChildURL.resourceValues(
            forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        )
        if prefetched?.isSymbolicLink == false {
            return DotfileChildMetadata(
                isDirectory: prefetched?.isDirectory ?? false,
                isRegularFile: prefetched?.isRegularFile ?? false,
                fileSize: prefetched?.fileSize,
                resolvedURLForProbe: reportedChildURL
            )
        }

        let resolvedChild: URL
        do {
            resolvedChild = try verifyConfinementAndResolve(of: reportedChildURL, canonicalScopePath: canonicalScopePath)
        } catch DomainError.securityScopeViolation where symlinkPolicy == .skipAndReport {
            skippedCount += 1
            return nil
        }

        let resolvedValues = try? resolvedChild.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
        return DotfileChildMetadata(
            isDirectory: resolvedValues?.isDirectory ?? false,
            isRegularFile: resolvedValues?.isRegularFile ?? false,
            fileSize: resolvedValues?.fileSize,
            resolvedURLForProbe: resolvedChild
        )
    }

    func dotfileShouldMarkBinary(
        _ metadata: DotfileChildMetadata,
        probeBinary: Bool,
        effectiveScope: URL
    ) -> Bool {
        guard probeBinary, !metadata.isDirectory, metadata.isRegularFile, metadata.fileSize != 0 else {
            return false
        }
        return probeBinaryRegularFile(at: metadata.resolvedURLForProbe, withinScope: effectiveScope)
    }

    static func dotfilePrecedesInListingOrder(
        _ lhs: (entry: FolderEntryDescriptor, lowerName: String),
        _ rhs: (entry: FolderEntryDescriptor, lowerName: String)
    ) -> Bool {
        if lhs.entry.isDirectory != rhs.entry.isDirectory {
            return lhs.entry.isDirectory && !rhs.entry.isDirectory
        }
        if lhs.lowerName != rhs.lowerName {
            return lhs.lowerName < rhs.lowerName
        }
        return lhs.entry.name < rhs.entry.name
    }
}
