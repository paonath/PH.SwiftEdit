import Foundation

/// Serializable MRU recent-file descriptor storing standardized path metadata and a security-scoped bookmark blob without retaining document contents (`BC-007`, `DATA-008`, `SEC-011`).
public struct RecentFileEntry: Codable, Equatable, Sendable {
    public let standardizedPath: String
    public let displayName: String
    public let bookmarkData: Data
    public let lastOpenedAt: Date

    public init(standardizedPath: String, displayName: String, bookmarkData: Data, lastOpenedAt: Date) {
        self.standardizedPath = standardizedPath
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
    }
}

/// Narrow `Sendable` seam abstracting security-scoped bookmark creation and resolution (`AR-007`, `SEC-002`, `TEST-004`).
public protocol SecurityScopedBookmarkCoding: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> URL
}

/// Production `SecurityScopedBookmarkCoding` adapter backed by `URL` security-scoped bookmark APIs on macOS and minimal bookmarks on iOS.
public struct SystemSecurityScopedBookmarkCoder: SecurityScopedBookmarkCoding, Sendable {
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        do {
            #if os(macOS)
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            return try url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #endif
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    public func resolveBookmark(_ data: Data) throws -> URL {
        var isStale = false
        do {
            #if os(macOS)
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #endif
            _ = isStale
            return resolved
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }
}

/// Deduplicated 10-entry MRU recent-files store backed by `PreferencesProviding` (`DATA-004`, `DATA-007`, `DATA-008`, `PERF-003`, `SEC-002`, `SEC-011`, `SEC-012`).
public struct RecentFilesStore: Sendable {
    public static let maxEntries: Int = 10
    public static let recentFilesKey: String = "swiftedit.recentFiles"
    public static let maxPersistedPayloadBytes: Int = 1_048_576

    public let suiteName: String?
    private let store: any PreferencesProviding
    private let fileSystem: any FileSystemProviding
    private let bookmarkCoder: any SecurityScopedBookmarkCoding
    private let securityScope: any SecurityScopedResourceAccessing
    private let now: @Sendable () -> Date

    /// Creates a `RecentFilesStore` backed by an explicit `PreferencesProviding` seam (`InMemoryKeyValueStore` in tests) and injected I/O and clock seams.
    public init(
        store: any PreferencesProviding,
        fileSystem: any FileSystemProviding = LocalFileSystemAdapter(),
        bookmarkCoder: any SecurityScopedBookmarkCoding = SystemSecurityScopedBookmarkCoder(),
        securityScope: any SecurityScopedResourceAccessing = SystemSecurityScopedResourceAccessor(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.suiteName = nil
        self.store = store
        self.fileSystem = fileSystem
        self.bookmarkCoder = bookmarkCoder
        self.securityScope = securityScope
        self.now = now
    }

    /// Creates a `RecentFilesStore` bound to an optional `UserDefaults` suite (or `.standard` when `nil`) and injected I/O and clock seams.
    public init(
        suiteName: String? = nil,
        fileSystem: any FileSystemProviding = LocalFileSystemAdapter(),
        bookmarkCoder: any SecurityScopedBookmarkCoding = SystemSecurityScopedBookmarkCoder(),
        securityScope: any SecurityScopedResourceAccessing = SystemSecurityScopedResourceAccessor(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.suiteName = suiteName
        self.store = UserDefaultsPreferencesStore(suiteName: suiteName)
        self.fileSystem = fileSystem
        self.bookmarkCoder = bookmarkCoder
        self.securityScope = securityScope
        self.now = now
    }

    /// Validates `url` as an existing non-binary file (`<= 64 MiB`), deduplicates by standardized path, moves it to index `0`, and caps the list at `10`.
    /// - Throws: `DomainError.binaryFileSaveForbidden` for binary files, `DomainError.fileTooLarge` above `64 MiB`, or `DomainError.securityScopeViolation`.
    @discardableResult
    public func record(url: URL, withinScope scopeURL: URL? = nil) throws -> [RecentFileEntry] {
        try probeEligibleTextFile(at: url, withinScope: scopeURL)
        let standardizedURL = url.standardizedFileURL
        let bookmark = try bookmarkCoder.makeBookmark(for: standardizedURL)
        let freshEntry = RecentFileEntry(
            standardizedPath: standardizedURL.path,
            displayName: standardizedURL.lastPathComponent,
            bookmarkData: bookmark,
            lastOpenedAt: now()
        )
        let updated = Self.deduplicateAndCap(inserting: freshEntry, into: entries())
        persist(updated)
        return updated
    }

    /// Returns existing recent entries ordered most-recent-first, omitting deleted files and purging corrupted or `> 1 MiB` `UserDefaults` payloads fail-closed (`SEC-011`, `SEC-012`).
    public func entries() -> [RecentFileEntry] {
        loadPersistedEntries().filter { entry in
            let url = URL(fileURLWithPath: entry.standardizedPath)
            return (try? fileSystem.fileAttributes(at: url, withinScope: nil)) != nil
        }
    }

    /// Resolves `entry.bookmarkData`, brackets access with `startAccessing` / `defer { stopAccessing }`, verifies path parity (`CWE-345`), and prunes stale or spoofed entries (`DATA-007`, `SEC-002`, `SEC-012`).
    /// - Throws: `DomainError.securityScopeViolation` when the bookmark resolves to a different path than recorded, or `DomainError` when stale/missing/binary.
    public func resolve(entry: RecentFileEntry) throws -> URL {
        let resolvedURL: URL
        do {
            resolvedURL = try bookmarkCoder.resolveBookmark(entry.bookmarkData)
        } catch let error as DomainError {
            prune(standardizedPath: entry.standardizedPath)
            throw error
        } catch {
            prune(standardizedPath: entry.standardizedPath)
            throw DomainError.ioFailure(error.localizedDescription)
        }

        let didAccess = securityScope.startAccessing(url: resolvedURL)
        defer {
            if didAccess {
                securityScope.stopAccessing(url: resolvedURL)
            }
        }

        let resolvedStandardized = resolvedURL.standardizedFileURL
        guard resolvedStandardized.path == entry.standardizedPath else {
            prune(standardizedPath: entry.standardizedPath)
            throw DomainError.securityScopeViolation(path: resolvedStandardized.path)
        }

        do {
            try probeEligibleTextFile(at: resolvedStandardized, withinScope: nil)
        } catch {
            prune(standardizedPath: entry.standardizedPath)
            throw error
        }

        return resolvedStandardized
    }

    /// Immediately erases all persisted bookmark blobs from the configured preferences store (`SEC-011`).
    public func clear() {
        store.removeObject(forKey: Self.recentFilesKey)
    }

    private func loadPersistedEntries() -> [RecentFileEntry] {
        guard store.object(forKey: Self.recentFilesKey) != nil else {
            return []
        }
        guard let rawData = store.data(forKey: Self.recentFilesKey),
              rawData.count <= Self.maxPersistedPayloadBytes,
              let decoded = try? JSONDecoder().decode([RecentFileEntry].self, from: rawData) else {
            store.removeObject(forKey: Self.recentFilesKey)
            return []
        }
        return decoded
    }

    private func prune(standardizedPath: String) {
        let remaining = loadPersistedEntries().filter { $0.standardizedPath != standardizedPath }
        if remaining.isEmpty {
            clear()
        } else {
            persist(remaining)
        }
    }

    private func probeEligibleTextFile(at url: URL, withinScope scopeURL: URL?) throws {
        let attrs = try fileSystem.fileAttributes(at: url, withinScope: scopeURL)
        if attrs.byteSize > DocumentLoader.maxAllowedFileBytes {
            throw DomainError.fileTooLarge(byteCount: attrs.byteSize)
        }
        let prefix = try fileSystem.readData(at: url, maxBytes: DocumentCodec.binaryProbeBytes, withinScope: scopeURL)
        if DocumentCodec.isBinaryPrefix(prefix) {
            throw DomainError.binaryFileSaveForbidden
        }
    }

    private static func deduplicateAndCap(inserting entry: RecentFileEntry, into existing: [RecentFileEntry]) -> [RecentFileEntry] {
        var combined = [entry]
        combined.append(contentsOf: existing.filter { $0.standardizedPath != entry.standardizedPath })
        if combined.count > maxEntries {
            return Array(combined.prefix(maxEntries))
        }
        return combined
    }

    private func persist(_ list: [RecentFileEntry]) {
        guard let encoded = try? JSONEncoder().encode(list) else { return }
        store.set(encoded, forKey: Self.recentFilesKey)
    }
}
