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
}

/// Thread-safe in-memory `FileSystemProviding` fake supporting parallel `Swift Testing` suites and virtual byte-size simulation (`TEST-003`, `TEST-004`).
public final class InMemoryFileSystemFake: FileSystemProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data] = [:]
    private var virtualSizes: [String: UInt64] = [:]

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
}

/// Production `FileSystemProviding` adapter enforcing `resolvingSymlinksInPath()` workspace confinement (`SEC-003`) and `NSFileCoordinator` atomic writes (`DATA-004`).
public struct LocalFileSystemAdapter: FileSystemProviding, Sendable {
    public init() {}

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
