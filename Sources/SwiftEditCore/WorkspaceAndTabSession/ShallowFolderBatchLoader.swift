import Foundation

/// Immutable shallow batch-open plan computed prior to opening any workspace tab (`BC-007`, `BC-011`, `DATA-003`).
public struct BatchOpenPlan: Equatable, Sendable {
    public let files: [URL]
    public let skippedBinaryCount: Int
    public let skippedFolderCount: Int
    public let totalBytes: UInt64
    /// `true` when `files.count > confirmationThreshold` (`50` by default), requiring explicit user confirmation before opening tabs.
    public let requiresConfirmation: Bool

    public init(
        files: [URL],
        skippedBinaryCount: Int,
        skippedFolderCount: Int,
        totalBytes: UInt64,
        requiresConfirmation: Bool
    ) {
        self.files = files
        self.skippedBinaryCount = skippedBinaryCount
        self.skippedFolderCount = skippedFolderCount
        self.totalBytes = totalBytes
        self.requiresConfirmation = requiresConfirmation
    }
}

/// Evaluates first-level directory entries via `DotfileFolderNavigator`, selecting regular non-binary files (`<= 64 MiB`) and gating batches above `50` files (`BC-007`, `DATA-002`, `DATA-003`, `SEC-002`, `SEC-003`).
public struct ShallowFolderBatchLoader: Sendable {
    public static let confirmationFileCountThreshold: Int = 50
    public static let defaultMaxBatchBytes: UInt64 = 256 * 1024 * 1024

    private let navigator: DotfileFolderNavigator
    private let fileSystem: any FileSystemProviding
    private let confirmationThreshold: Int
    private let maxBatchBytes: UInt64

    public init(
        navigator: DotfileFolderNavigator = DotfileFolderNavigator(),
        fileSystem: any FileSystemProviding = LocalFileSystemAdapter(),
        confirmationThreshold: Int = ShallowFolderBatchLoader.confirmationFileCountThreshold,
        maxBatchBytes: UInt64 = ShallowFolderBatchLoader.defaultMaxBatchBytes
    ) {
        self.navigator = navigator
        self.fileSystem = fileSystem
        self.confirmationThreshold = confirmationThreshold
        self.maxBatchBytes = maxBatchBytes
    }

    /// Builds an immutable `BatchOpenPlan` for first-level regular non-binary files in `folder` within `scopeURL`.
    ///
    /// Security invariants (`CWE-22`, `CWE-400`, `BC-011`, `SEC-002`, `SEC-003`, `SEC-012`):
    /// - Any escaping symlink aborts the entire batch via `DotfileFolderNavigator` (`DomainError.securityScopeViolation`) before opening any file while keeping security-scoped access balanced.
    /// - Enforces a `64 MiB` per-file skip and a cumulative `maxBatchBytes` (`256 MiB` default) memory ceiling (`DomainError.batchLimitExceeded`).
    public func plan(folder: URL, withinScope scopeURL: URL? = nil) throws -> BatchOpenPlan {
        let effectiveScope = scopeURL ?? folder
        let (listing, regularFileFlags) = try navigator.listEntriesInternal(
            in: folder,
            withinScope: scopeURL,
            symlinkPolicy: .failClosed,
            probeBinary: false
        )
        let entries = listing.entries
        var eligibleFiles: [URL] = []
        eligibleFiles.reserveCapacity(entries.count)
        var skippedBinaryCount = 0
        var skippedFolderCount = 0
        var totalBytes: UInt64 = 0

        for entry in entries {
            if entry.isDirectory {
                skippedFolderCount += 1
                continue
            }
            guard regularFileFlags[entry.url] ?? Self.isRegularFile(at: entry.url) else {
                continue
            }
            let attrs = try fileSystem.fileAttributes(at: entry.url, withinScope: effectiveScope)
            if attrs.byteSize > DocumentLoader.maxAllowedFileBytes {
                continue
            }
            if attrs.byteSize > 0 {
                let prefix = try fileSystem.readData(
                    at: entry.url,
                    maxBytes: DocumentCodec.binaryProbeBytes,
                    withinScope: effectiveScope
                )
                if DocumentCodec.isBinaryPrefix(prefix) {
                    skippedBinaryCount += 1
                    continue
                }
            }
            let (updatedTotal, overflow) = totalBytes.addingReportingOverflow(attrs.byteSize)
            if overflow || updatedTotal > maxBatchBytes {
                throw DomainError.batchLimitExceeded(maxBytes: maxBatchBytes)
            }
            totalBytes = updatedTotal
            eligibleFiles.append(entry.url)
        }

        return BatchOpenPlan(
            files: eligibleFiles,
            skippedBinaryCount: skippedBinaryCount,
            skippedFolderCount: skippedFolderCount,
            totalBytes: totalBytes,
            requiresConfirmation: eligibleFiles.count > confirmationThreshold
        )
    }

    private static func isRegularFile(at url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        return (try? resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
    }
}
