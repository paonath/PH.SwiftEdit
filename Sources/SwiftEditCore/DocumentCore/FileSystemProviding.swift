import Foundation

/// Pre-allocation filesystem metadata used to enforce `10 MiB`/`64 MiB` size gates and symlink checks before reading buffer bytes.
public struct FileAttributesDescriptor: Equatable, Sendable {
    public let byteSize: UInt64
    public let isSymbolicLink: Bool

    public init(byteSize: UInt64, isSymbolicLink: Bool = false) {
        self.byteSize = byteSize
        self.isSymbolicLink = isSymbolicLink
    }
}

/// Narrow `Sendable` filesystem port isolating `SwiftEditCore` from unisolated disk I/O (`AR-007`, `TEST-004`).
public protocol FileSystemProviding: Sendable {
    /// Returns byte size and symlink metadata for `url`, validating confinement inside `scopeURL` when supplied.
    func fileAttributes(at url: URL, withinScope scopeURL: URL?) throws -> FileAttributesDescriptor
    /// Reads up to `maxBytes` (or the entire file when `nil`) from `url` within optional `scopeURL`.
    func readData(at url: URL, maxBytes: Int?, withinScope scopeURL: URL?) throws -> Data
    /// Atomically writes `data` to `url` via temporary sibling replacement within optional `scopeURL` (`DATA-004`).
    func writeAtomic(data: Data, to url: URL, withinScope scopeURL: URL?) throws
    /// Creates a new subdirectory `name` inside `parentURL` within optional `scopeURL`.
    @discardableResult
    func createDirectory(named name: String, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL
    /// Creates a new file `name` with `contents` inside `parentURL` within optional `scopeURL`.
    @discardableResult
    func createFile(named name: String, contents: Data, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL
    /// Renames an existing file or directory at `itemURL` to single-segment `newName` within optional `scopeURL`.
    @discardableResult
    func renameItem(at itemURL: URL, toName newName: String, withinScope scopeURL: URL?) throws -> URL
    /// Moves (`cut`) or copies (`copy` with collision suffixing) `sourceURL` into `destinationDirectoryURL` within optional `scopeURL`.
    @discardableResult
    func pasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, mode: PasteMode, withinScope scopeURL: URL?) throws -> URL
    /// Moves `itemURL` to the system Trash (never permanently deleting) within optional `scopeURL`.
    func trashItem(at itemURL: URL, withinScope scopeURL: URL?) throws
}

/// Thread-safe in-memory `FileSystemProviding` fake supporting parallel `Swift Testing` suites and virtual byte-size simulation (`TEST-003`, `TEST-004`).
public final class InMemoryFileSystemFake: FileSystemProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data] = [:]
    private var directories: Set<String> = ["/"]
    private var virtualSizes: [String: UInt64] = [:]
    private(set) public var trashedPaths: [String] = []

    public init() {}

    public func seed(url: URL, data: Data, virtualByteSize: UInt64? = nil) {
        lock.lock()
        defer { lock.unlock() }
        let key = url.standardizedFileURL.path
        files[key] = data
        if let virtualByteSize {
            virtualSizes[key] = virtualByteSize
        } else {
            virtualSizes.removeValue(forKey: key)
        }
    }

    public func storedData(at url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return files[url.standardizedFileURL.path]
    }

    public func removeFile(at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        let key = url.standardizedFileURL.path
        files.removeValue(forKey: key)
        virtualSizes.removeValue(forKey: key)
    }

    public func fileAttributes(at url: URL, withinScope scopeURL: URL?) throws -> FileAttributesDescriptor {
        _ = scopeURL
        lock.lock()
        defer { lock.unlock() }
        let key = url.standardizedFileURL.path
        guard let data = files[key] else {
            throw DomainError.ioFailure("Missing in-memory file at \(key)")
        }
        let size = virtualSizes[key] ?? UInt64(data.count)
        return FileAttributesDescriptor(byteSize: size)
    }

    public func readData(at url: URL, maxBytes: Int?, withinScope scopeURL: URL?) throws -> Data {
        _ = scopeURL
        lock.lock()
        defer { lock.unlock() }
        let key = url.standardizedFileURL.path
        guard let data = files[key] else {
            throw DomainError.ioFailure("Missing in-memory file at \(key)")
        }
        if let maxBytes, data.count > maxBytes {
            return data.prefix(maxBytes)
        }
        return data
    }

    public func writeAtomic(data: Data, to url: URL, withinScope scopeURL: URL?) throws {
        _ = scopeURL
        lock.lock()
        defer { lock.unlock() }
        let key = url.standardizedFileURL.path
        files[key] = data
        virtualSizes[key] = UInt64(data.count)
    }

    @discardableResult
    public func createDirectory(named name: String, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        _ = scopeURL
        let validName = try SidebarItemNameValidator.validate(name)
        let targetURL = parentURL.appendingPathComponent(validName).standardizedFileURL
        lock.lock()
        defer { lock.unlock() }
        if files[targetURL.path] != nil || directories.contains(targetURL.path) {
            throw DomainError.destinationAlreadyExists(path: targetURL.path)
        }
        directories.insert(targetURL.path)
        return targetURL
    }

    @discardableResult
    public func createFile(named name: String, contents: Data, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        _ = scopeURL
        let validName = try SidebarItemNameValidator.validate(name)
        let targetURL = parentURL.appendingPathComponent(validName).standardizedFileURL
        lock.lock()
        defer { lock.unlock() }
        if files[targetURL.path] != nil || directories.contains(targetURL.path) {
            throw DomainError.destinationAlreadyExists(path: targetURL.path)
        }
        files[targetURL.path] = contents
        virtualSizes[targetURL.path] = UInt64(contents.count)
        return targetURL
    }

    @discardableResult
    public func renameItem(at itemURL: URL, toName newName: String, withinScope scopeURL: URL?) throws -> URL {
        _ = scopeURL
        let validName = try SidebarItemNameValidator.validate(newName)
        let sourceKey = itemURL.standardizedFileURL.path
        let destURL = itemURL.standardizedFileURL.deletingLastPathComponent().appendingPathComponent(validName).standardizedFileURL
        lock.lock()
        defer { lock.unlock() }
        if files[destURL.path] != nil || directories.contains(destURL.path) {
            throw DomainError.destinationAlreadyExists(path: destURL.path)
        }
        if let existingData = files.removeValue(forKey: sourceKey) {
            files[destURL.path] = existingData
            virtualSizes[destURL.path] = virtualSizes.removeValue(forKey: sourceKey) ?? UInt64(existingData.count)
            return destURL
        }
        if directories.remove(sourceKey) != nil {
            directories.insert(destURL.path)
            return destURL
        }
        throw DomainError.ioFailure("Missing item at \(sourceKey)")
    }

    @discardableResult
    public func pasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, mode: PasteMode, withinScope scopeURL: URL?) throws -> URL {
        _ = scopeURL
        let srcPath = sourceURL.standardizedFileURL.path
        let dstDirPath = destinationDirectoryURL.standardizedFileURL.path
        if dstDirPath == srcPath || dstDirPath.hasPrefix(srcPath + "/") {
            throw DomainError.invalidPasteTarget(path: destinationDirectoryURL.path)
        }
        let originalName = try SidebarItemNameValidator.validate(sourceURL.lastPathComponent)
        lock.lock()
        defer { lock.unlock() }
        guard let srcData = files[srcPath] else {
            throw DomainError.ioFailure("Missing in-memory paste source at \(srcPath)")
        }
        let chosenName: String
        switch mode {
        case .cut:
            let candidatePath = destinationDirectoryURL.appendingPathComponent(originalName).standardizedFileURL.path
            if files[candidatePath] != nil || directories.contains(candidatePath) {
                throw DomainError.destinationAlreadyExists(path: candidatePath)
            }
            chosenName = originalName
        case .copy:
            chosenName = try SidebarCollisionSuffixAllocator.firstAvailableName(for: originalName) { candidate in
                let path = destinationDirectoryURL.appendingPathComponent(candidate).standardizedFileURL.path
                return files[path] != nil || directories.contains(path)
            }
        }
        let targetURL = destinationDirectoryURL.appendingPathComponent(chosenName).standardizedFileURL
        files[targetURL.path] = srcData
        virtualSizes[targetURL.path] = virtualSizes[srcPath] ?? UInt64(srcData.count)
        if mode == .cut {
            files.removeValue(forKey: srcPath)
            virtualSizes.removeValue(forKey: srcPath)
        }
        return targetURL
    }

    public func trashItem(at itemURL: URL, withinScope scopeURL: URL?) throws {
        let itemPath = itemURL.standardizedFileURL.path
        if let scopeURL {
            let scopePath = scopeURL.standardizedFileURL.path
            if itemPath == scopePath || !(itemPath.hasPrefix(scopePath + "/")) {
                throw DomainError.securityScopeViolation(path: itemURL.path)
            }
        }
        lock.lock()
        defer { lock.unlock() }
        let removedFile = files.removeValue(forKey: itemPath) != nil
        virtualSizes.removeValue(forKey: itemPath)
        let removedDir = directories.remove(itemPath) != nil
        guard removedFile || removedDir else {
            throw DomainError.ioFailure("Missing in-memory trash target at \(itemPath)")
        }
        trashedPaths.append(itemPath)
    }
}

/// Production `FileSystemProviding` adapter enforcing `resolvingSymlinksInPath()` workspace confinement (`SEC-003`) and `NSFileCoordinator` atomic writes (`DATA-004`).
public struct LocalFileSystemAdapter: FileSystemProviding, Sendable {
    public static let defaultMaxCopyItems: Int = 1_000
    public static let defaultMaxCopyBytes: UInt64 = 256 * 1024 * 1024

    private let trasher: any ItemTrashing
    private let maxCopyItems: Int
    private let maxCopyBytes: UInt64

    public init(
        trasher: any ItemTrashing = FileManagerTrasher(),
        maxCopyItems: Int = LocalFileSystemAdapter.defaultMaxCopyItems,
        maxCopyBytes: UInt64 = LocalFileSystemAdapter.defaultMaxCopyBytes
    ) {
        self.trasher = trasher
        self.maxCopyItems = maxCopyItems
        self.maxCopyBytes = maxCopyBytes
    }

    public func fileAttributes(at url: URL, withinScope scopeURL: URL?) throws -> FileAttributesDescriptor {
        try verifyScopeConfinement(for: url, withinScope: scopeURL, mustExist: true)
        let fm = FileManager.default
        let rawAttrs: [FileAttributeKey: Any]
        do {
            rawAttrs = try fm.attributesOfItem(atPath: url.path)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
        let isSymlink = (rawAttrs[.type] as? FileAttributeType) == .typeSymbolicLink
        let resolvedAttrs: [FileAttributeKey: Any]
        do {
            resolvedAttrs = isSymlink ? try fm.attributesOfItem(atPath: url.resolvingSymlinksInPath().path) : rawAttrs
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
        let size = (resolvedAttrs[.size] as? UInt64) ?? 0
        return FileAttributesDescriptor(byteSize: size, isSymbolicLink: isSymlink)
    }

    public func readData(at url: URL, maxBytes: Int?, withinScope scopeURL: URL?) throws -> Data {
        try verifyScopeConfinement(for: url, withinScope: scopeURL, mustExist: true)
        do {
            if let maxBytes {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                return try handle.read(upToCount: maxBytes) ?? Data()
            }
            return try Data(contentsOf: url)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    public func writeAtomic(data: Data, to url: URL, withinScope scopeURL: URL?) throws {
        try verifyScopeConfinement(for: url, withinScope: scopeURL, mustExist: false)
        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordinationError {
            throw DomainError.ioFailure(coordinationError.localizedDescription)
        }
        if let writeError {
            throw DomainError.ioFailure(writeError.localizedDescription)
        }
    }

    /// Creates a new directory `name` inside `parentURL` after verifying `resolvingSymlinksInPath()` confinement (`CWE-22`/`CWE-59`, `SEC-003`).
    @discardableResult
    public func createDirectory(named name: String, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try verifyScopeConfinement(for: parentURL, withinScope: scopeURL, mustExist: true)
        let destinationURL = try resolveNewChildURL(named: name, in: parentURL)
        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false)
            return destinationURL
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    /// Creates a non-overwriting file `name` inside `parentURL` after verifying `resolvingSymlinksInPath()` confinement (`CWE-22`/`CWE-59`, `SEC-003`).
    @discardableResult
    public func createFile(named name: String, contents: Data, in parentURL: URL, withinScope scopeURL: URL?) throws -> URL {
        try verifyScopeConfinement(for: parentURL, withinScope: scopeURL, mustExist: true)
        let destinationURL = try resolveNewChildURL(named: name, in: parentURL)
        do {
            try contents.write(to: destinationURL, options: .withoutOverwriting)
            return destinationURL
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    /// Renames `itemURL` to single-segment `newName` inside its confined parent while refusing mutation of the granted `scopeURL` root (`SEC-002`, `SEC-003`).
    @discardableResult
    public func renameItem(at itemURL: URL, toName newName: String, withinScope scopeURL: URL?) throws -> URL {
        try verifyNotScopeRootAndConfined(itemURL: itemURL, withinScope: scopeURL)
        let parentURL = itemURL.standardizedFileURL.deletingLastPathComponent()
        try verifyScopeConfinement(for: parentURL, withinScope: scopeURL, mustExist: true)
        let destinationURL = try resolveNewChildURL(named: newName, in: parentURL)
        do {
            try FileManager.default.moveItem(at: itemURL, to: destinationURL)
            return destinationURL
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    /// Moves (`cut`) or copies (`copy` with collision suffixing) `sourceURL` into `destinationDirectoryURL` while enforcing symlink-free tree pre-scans, item/byte ceilings (`CWE-400`), and workspace confinement (`CWE-22`/`CWE-59`, `SEC-003`, `SEC-012`).
    @discardableResult
    public func pasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, mode: PasteMode, withinScope scopeURL: URL?) throws -> URL {
        try verifyPasteEndpoints(from: sourceURL, toDirectory: destinationDirectoryURL, mode: mode, withinScope: scopeURL)
        let originalName = try SidebarItemNameValidator.validate(sourceURL.lastPathComponent)
        switch mode {
        case .cut:
            return try movePasteItem(from: sourceURL, toDirectory: destinationDirectoryURL, named: originalName)
        case .copy:
            return try copyPasteItem(from: sourceURL, toDirectory: destinationDirectoryURL, named: originalName)
        }
    }

    /// Moves `itemURL` to the system Trash via `ItemTrashing` (never permanently deleting) after verifying workspace confinement and scope-root protection (`CWE-73`, `SEC-003`, `SEC-012`).
    public func trashItem(at itemURL: URL, withinScope scopeURL: URL?) throws {
        try verifyNotScopeRootAndConfined(itemURL: itemURL, withinScope: scopeURL)
        try trasher.trashItem(at: itemURL.standardizedFileURL)
    }

    private func preScanCopySourceTree(at sourceURL: URL) throws {
        let fm = FileManager.default
        let rootAttrs = try readAttributesOrIOFailure(at: sourceURL, fileManager: fm)
        let rootType = rootAttrs[.type] as? FileAttributeType
        if rootType == .typeSymbolicLink {
            throw DomainError.securityScopeViolation(path: sourceURL.path)
        }
        if rootType != .typeDirectory {
            var itemCount = 0
            var totalBytes: UInt64 = 0
            try accountCopyEntry(attributes: rootAttrs, at: sourceURL, itemCount: &itemCount, totalBytes: &totalBytes)
            return
        }
        try scanCopyDirectoryTree(at: sourceURL, fileManager: fm)
    }

    private func verifyNotScopeRootAndConfined(itemURL: URL, withinScope scopeURL: URL?) throws {
        if let scopeURL {
            let canonicalScope = scopeURL.resolvingSymlinksInPath().standardizedFileURL.path
            let canonicalItem = itemURL.resolvingSymlinksInPath().standardizedFileURL.path
            if canonicalItem == canonicalScope {
                throw DomainError.securityScopeViolation(path: itemURL.path)
            }
        }
        try verifyScopeConfinement(for: itemURL, withinScope: scopeURL, mustExist: true)
    }

    private func resolveNewChildURL(named rawName: String, in parentURL: URL) throws -> URL {
        let validName = try SidebarItemNameValidator.validate(rawName)
        let targetURL = parentURL.appendingPathComponent(validName).standardizedFileURL
        if Self.itemExistsIncludingDanglingSymlink(atPath: targetURL.path) {
            throw DomainError.destinationAlreadyExists(path: targetURL.path)
        }
        return targetURL
    }

    private static func itemExistsIncludingDanglingSymlink(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path) || (try? FileManager.default.attributesOfItem(atPath: path)) != nil
    }

    private func verifyScopeConfinement(for url: URL, withinScope scopeURL: URL?, mustExist: Bool) throws {
        let reportedPath = url.path
        let fm = FileManager.default
        let isSymlink = ((try? fm.attributesOfItem(atPath: reportedPath))?[.type] as? FileAttributeType) == .typeSymbolicLink
        guard let scopeURL else {
            if isSymlink {
                throw DomainError.securityScopeViolation(path: reportedPath)
            }
            return
        }
        let canonicalScope = scopeURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetToResolve = (mustExist || isSymlink || fm.fileExists(atPath: reportedPath))
            ? url
            : url.deletingLastPathComponent()
        let resolvedPath = targetToResolve.resolvingSymlinksInPath().standardizedFileURL.path
        let isInsideScope = resolvedPath == canonicalScope || resolvedPath.hasPrefix(canonicalScope + "/")
        if !isInsideScope {
            throw DomainError.securityScopeViolation(path: reportedPath)
        }
    }
}

private extension LocalFileSystemAdapter {
    func readAttributesOrIOFailure(at url: URL, fileManager: FileManager) throws -> [FileAttributeKey: Any] {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    func scanCopyDirectoryTree(at sourceURL: URL, fileManager: FileManager) throws {
        guard let enumerator = fileManager.enumerator(atPath: sourceURL.path) else {
            throw DomainError.ioFailure("Unable to enumerate copy source at \(sourceURL.path)")
        }
        var itemCount = 0
        var totalBytes: UInt64 = 0
        while let relativeSubpath = enumerator.nextObject() as? String {
            let childURL = sourceURL.appendingPathComponent(relativeSubpath)
            let childAttrs = try fileManager.attributesOfItem(atPath: childURL.path)
            try accountCopyEntry(attributes: childAttrs, at: childURL, itemCount: &itemCount, totalBytes: &totalBytes)
        }
    }

    func accountCopyEntry(
        attributes: [FileAttributeKey: Any],
        at itemURL: URL,
        itemCount: inout Int,
        totalBytes: inout UInt64
    ) throws {
        let itemType = attributes[.type] as? FileAttributeType
        if itemType == .typeSymbolicLink {
            throw DomainError.securityScopeViolation(path: itemURL.path)
        }
        itemCount += 1
        if itemCount > maxCopyItems {
            throw DomainError.batchLimitExceeded(maxBytes: maxCopyBytes)
        }
        guard itemType != .typeDirectory else { return }
        let itemSize = (attributes[.size] as? UInt64) ?? 0
        let (nextTotal, overflow) = totalBytes.addingReportingOverflow(itemSize)
        if overflow || nextTotal > maxCopyBytes {
            throw DomainError.batchLimitExceeded(maxBytes: maxCopyBytes)
        }
        totalBytes = nextTotal
    }

    func verifyPasteEndpoints(
        from sourceURL: URL,
        toDirectory destinationDirectoryURL: URL,
        mode: PasteMode,
        withinScope scopeURL: URL?
    ) throws {
        if mode == .cut {
            try verifyNotScopeRootAndConfined(itemURL: sourceURL, withinScope: scopeURL)
        } else {
            try verifyScopeConfinement(for: sourceURL, withinScope: scopeURL, mustExist: true)
        }
        try verifyScopeConfinement(for: destinationDirectoryURL, withinScope: scopeURL, mustExist: true)
        let canonicalSource = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalDestDir = destinationDirectoryURL.resolvingSymlinksInPath().standardizedFileURL.path
        if canonicalDestDir == canonicalSource || canonicalDestDir.hasPrefix(canonicalSource + "/") {
            throw DomainError.invalidPasteTarget(path: destinationDirectoryURL.path)
        }
    }

    func movePasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, named originalName: String) throws -> URL {
        let candidateURL = destinationDirectoryURL.appendingPathComponent(originalName).standardizedFileURL
        if Self.itemExistsIncludingDanglingSymlink(atPath: candidateURL.path) {
            throw DomainError.destinationAlreadyExists(path: candidateURL.path)
        }
        do {
            try FileManager.default.moveItem(at: sourceURL, to: candidateURL)
            return candidateURL
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }

    func copyPasteItem(from sourceURL: URL, toDirectory destinationDirectoryURL: URL, named originalName: String) throws -> URL {
        try preScanCopySourceTree(at: sourceURL)
        let chosenName = try SidebarCollisionSuffixAllocator.firstAvailableName(for: originalName) { candidate in
            let candidatePath = destinationDirectoryURL.appendingPathComponent(candidate).standardizedFileURL.path
            return Self.itemExistsIncludingDanglingSymlink(atPath: candidatePath)
        }
        let destinationURL = destinationDirectoryURL.appendingPathComponent(chosenName).standardizedFileURL
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw DomainError.ioFailure(error.localizedDescription)
        }
    }
}
