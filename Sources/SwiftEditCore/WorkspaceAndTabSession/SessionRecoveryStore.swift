import Foundation

/// Serializable `session-manifest.json` payload recording open Notepad++ text tabs, pinned flags, caret offsets, and active tab selection (`DATA-005`).
public struct SessionRecoveryManifest: Equatable, Codable, Sendable {
    public let tabs: [TabDescriptor]
    public let activeTabID: DocumentID?

    public init(tabs: [TabDescriptor], activeTabID: DocumentID?) {
        self.tabs = tabs
        self.activeTabID = activeTabID
    }
}

/// Serializable `<UUID>.recovery` text draft snapshot preserving buffer text, `BufferRevision`, `TextEncoding`, and `LineEnding` across crashes (`DATA-005`).
public struct RecoveredDocumentSnapshot: Equatable, Codable, Sendable {
    public let id: DocumentID
    public let revision: BufferRevision
    public let text: String
    public let encoding: TextEncoding
    public let lineEnding: LineEnding

    public init(
        id: DocumentID,
        revision: BufferRevision,
        text: String,
        encoding: TextEncoding,
        lineEnding: LineEnding
    ) {
        self.id = id
        self.revision = revision
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
    }
}

/// Anti-Corruption Layer persistence store managing `Application Support/PH.SwiftEdit/SessionRecovery/` (`DATA-001`, `DATA-003`, `DATA-005`, `DATA-006`, `SEC-003`, `SEC-007`, `SEC-011`, `SEC-012`).
///
/// Security & GDPR Art. 5(1)(c) invariants:
/// - Rejects `isBinaryReadOnly` snapshots immediately with `DomainError.binaryFileSaveForbidden`.
/// - Enforces POSIX `0700` directory permissions, `0600` file permissions (`FileProtectionType.complete` on iOS), and `isExcludedFromBackup = true`.
/// - Enforces an aggregate `maxQuotaBytes` (`64 MiB` = `67_108_864` bytes by default) ceiling (`DomainError.sessionRecoveryQuotaExceeded`), accounting for in-place snapshot overwrites.
/// - Rejects symbolic links on `recoveryDirectoryURL` and child files (`DomainError.securityScopeViolation`).
/// - Synchronously unlinks `<UUID>.recovery` on tab close and purges unreferenced orphan files at startup.
public struct SessionRecoveryStore: Sendable {
    /// Default `64 MiB` (`67_108_864` bytes) aggregate storage ceiling for `SessionRecovery/` (`SEC-007`).
    public static let defaultMaxQuotaBytes: UInt64 = 64 * 1024 * 1024

    public let recoveryDirectoryURL: URL
    public let maxQuotaBytes: UInt64

    public init(recoveryDirectoryURL: URL, maxQuotaBytes: UInt64 = SessionRecoveryStore.defaultMaxQuotaBytes) {
        self.recoveryDirectoryURL = recoveryDirectoryURL
        self.maxQuotaBytes = maxQuotaBytes
    }

    /// URL of `session-manifest.json` inside `recoveryDirectoryURL`.
    public var manifestFileURL: URL {
        recoveryDirectoryURL.appendingPathComponent("session-manifest.json")
    }

    /// Deterministic `<UUID>.recovery` URL for `id` inside `recoveryDirectoryURL`.
    public func snapshotFileURL(for id: DocumentID) -> URL {
        recoveryDirectoryURL.appendingPathComponent("\(id.rawValue.uuidString).recovery")
    }

    /// Atomically persists `manifest` to `session-manifest.json` with `0700`/`0600` POSIX permissions, quota verification, and backup exclusion.
    public func saveManifest(_ manifest: SessionRecoveryManifest) throws {
        try ensureProtectedRecoveryDirectory()
        let encoded = try encodeJSON(manifest)
        try enforceDirectoryQuota(adding: UInt64(encoded.count), replacing: manifestFileURL)
        try writeProtectedFileAtomically(data: encoded, to: manifestFileURL)
    }

    /// Loads `session-manifest.json`, returning `nil` when absent or throwing `DomainError.corruptedRecoveryManifest` on malformed JSON.
    public func loadManifest() throws -> SessionRecoveryManifest? {
        try verifyNotSymbolicLink(at: recoveryDirectoryURL)
        let fm = FileManager.default
        guard fm.fileExists(atPath: manifestFileURL.path) else {
            return nil
        }
        try verifyNotSymbolicLink(at: manifestFileURL)
        return try decodeJSON(SessionRecoveryManifest.self, from: manifestFileURL)
    }

    /// Atomically writes `<UUID>.recovery` for a dirty or unbacked text `DocumentSnapshot`.
    /// - Throws: `DomainError.binaryFileSaveForbidden` on binary snapshots, `DomainError.sessionRecoveryQuotaExceeded` when exceeding `maxQuotaBytes`, or `DomainError.securityScopeViolation` on symlinks.
    public func saveRecoverySnapshot(_ snapshot: DocumentSnapshot) throws {
        if snapshot.isBinaryReadOnly {
            throw DomainError.binaryFileSaveForbidden
        }
        try ensureProtectedRecoveryDirectory()
        let destination = snapshotFileURL(for: snapshot.id)
        try verifyNotSymbolicLink(at: destination)

        let payload = RecoveredDocumentSnapshot(
            id: snapshot.id,
            revision: snapshot.revision,
            text: snapshot.text,
            encoding: snapshot.encoding,
            lineEnding: snapshot.lineEnding
        )
        let encoded = try encodeJSON(payload)
        try enforceDirectoryQuota(adding: UInt64(encoded.count), replacing: destination)
        try writeProtectedFileAtomically(data: encoded, to: destination)
    }

    /// Loads `<UUID>.recovery` for `id`, returning `nil` when absent or throwing `DomainError.corruptedRecoveryManifest` on malformed JSON.
    public func loadRecoverySnapshot(for id: DocumentID) throws -> RecoveredDocumentSnapshot? {
        try verifyNotSymbolicLink(at: recoveryDirectoryURL)
        let url = snapshotFileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        try verifyNotSymbolicLink(at: url)
        return try decodeJSON(RecoveredDocumentSnapshot.self, from: url)
    }

    /// Synchronously unlinks `<UUID>.recovery` upon tab closure (`DATA-006`, `SEC-011`).
    public func removeRecoverySnapshot(for id: DocumentID) throws {
        try verifyNotSymbolicLink(at: recoveryDirectoryURL)
        let url = snapshotFileURL(for: id)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    /// Executes startup garbage collection deleting any `*.recovery` file not referenced in `referencedIDs`, returning the count of deleted files (`DATA-006`, `SEC-011`).
    @discardableResult
    public func purgeOrphanedSnapshots(keeping referencedIDs: Set<DocumentID>) throws -> Int {
        try verifyNotSymbolicLink(at: recoveryDirectoryURL)
        let fm = FileManager.default
        guard fm.fileExists(atPath: recoveryDirectoryURL.path) else {
            return 0
        }
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: recoveryDirectoryURL, includingPropertiesForKeys: nil)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }

        let validStems = Set(referencedIDs.map { $0.rawValue.uuidString.uppercased() })
        var purgedCount = 0
        for itemURL in entries where itemURL.pathExtension == "recovery" {
            let stem = itemURL.deletingPathExtension().lastPathComponent.uppercased()
            if !validStems.contains(stem) {
                do {
                    try fm.removeItem(at: itemURL)
                    purgedCount += 1
                } catch {
                    throw DomainError.ioFailure(error.localizedDescription)
                }
            }
        }
        return purgedCount
    }

    private func verifyNotSymbolicLink(at url: URL) throws {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           (attrs[.type] as? FileAttributeType) == .typeSymbolicLink {
            throw DomainError.securityScopeViolation(path: url.path)
        }
    }

    private func enforceDirectoryQuota(adding newBytes: UInt64, replacing targetURL: URL) throws {
        let currentUsage = try directoryByteUsage(excluding: targetURL)
        let projectedBytes = currentUsage + newBytes
        if projectedBytes > maxQuotaBytes {
            throw DomainError.sessionRecoveryQuotaExceeded(byteCount: projectedBytes)
        }
    }

    private func directoryByteUsage(excluding replacedURL: URL) throws -> UInt64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: recoveryDirectoryURL.path) else {
            return 0
        }
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: recoveryDirectoryURL, includingPropertiesForKeys: [.fileSizeKey])
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }

        let excludedName = replacedURL.lastPathComponent
        var total: UInt64 = 0
        for itemURL in entries where itemURL.lastPathComponent != excludedName {
            if let size = (try? itemURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size >= 0 {
                total += UInt64(size)
            } else if let attrs = try? fm.attributesOfItem(atPath: itemURL.path),
                      let size = attrs[.size] as? UInt64 {
                total += size
            }
        }
        return total
    }

    private func ensureProtectedRecoveryDirectory() throws {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: recoveryDirectoryURL.path) {
            if (attrs[.type] as? FileAttributeType) == .typeSymbolicLink {
                throw DomainError.securityScopeViolation(path: recoveryDirectoryURL.path)
            }
            let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue
            let excluded = (try? recoveryDirectoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup ?? false
            if perms == 0o700 && excluded {
                return
            }
        }
        do {
            try fm.createDirectory(
                at: recoveryDirectoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try verifyNotSymbolicLink(at: recoveryDirectoryURL)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: recoveryDirectoryURL.path)
            try markExcludedFromBackup(at: recoveryDirectoryURL)
        } catch let domainError as DomainError {
            throw domainError
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    private func writeProtectedFileAtomically(data: Data, to destinationURL: URL) throws {
        try verifyNotSymbolicLink(at: destinationURL)
        let fm = FileManager.default
        let tempURL = recoveryDirectoryURL.appendingPathComponent(".tmp-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempURL) }

        var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        #if os(iOS)
        attributes[.protectionKey] = FileProtectionType.complete
        #endif

        guard fm.createFile(atPath: tempURL.path, contents: data, attributes: attributes) else {
            throw DomainError.ioFailure("Unable to create protected recovery staging file")
        }

        do {
            if fm.fileExists(atPath: destinationURL.path) {
                _ = try fm.replaceItemAt(destinationURL, withItemAt: tempURL)
            } else {
                try fm.moveItem(at: tempURL, to: destinationURL)
            }
            try fm.setAttributes(attributes, ofItemAtPath: destinationURL.path)
            try markExcludedFromBackup(at: destinationURL)
        } catch let domainError as DomainError {
            throw domainError
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    private func markExcludedFromBackup(at url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(value)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let rawData: Data
        do {
            rawData = try Data(contentsOf: url)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(type, from: rawData)
        } catch {
            throw DomainError.corruptedRecoveryManifest
        }
    }
}
