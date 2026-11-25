import Foundation

/// Anti-Corruption Layer service loading and saving `DocumentSession` values while enforcing `10 MiB`/`64 MiB` size gates (`DATA-002`) and `8 KiB` binary quarantine (`DATA-003`, `SEC-012`).
public struct DocumentLoader: Sendable {
    /// Threshold (`10 MiB`) above which text sessions enter `isDegradedPlainText` mode disabling full-buffer AST/diff passes (`BC-011`, `DATA-002`).
    public static let degradedModeThresholdBytes: UInt64 = 10 * 1024 * 1024
    /// Hard pre-allocation ceiling (`64 MiB`) above which loading fails with `DomainError.fileTooLarge` (`DATA-002`).
    public static let maxAllowedFileBytes: UInt64 = 64 * 1024 * 1024

    public let fileSystem: any FileSystemProviding

    public init(fileSystem: any FileSystemProviding) {
        self.fileSystem = fileSystem
    }

    /// Inspects file size and `8 KiB` prefix bytes before decoding into a `DocumentSession` (`Throws: DomainError.fileTooLarge`, `unsupportedEncoding`, `securityScopeViolation`).
    public func load(from url: URL, withinScope scopeURL: URL? = nil) throws -> DocumentSession {
        let attrs = try fileSystem.fileAttributes(at: url, withinScope: scopeURL)
        if attrs.byteSize > Self.maxAllowedFileBytes {
            throw DomainError.fileTooLarge(byteCount: attrs.byteSize)
        }
        let prefix = try fileSystem.readData(at: url, maxBytes: DocumentCodec.binaryProbeBytes, withinScope: scopeURL)
        if DocumentCodec.isBinaryPrefix(prefix) {
            let cappedData = try fileSystem.readData(
                at: url,
                maxBytes: DocumentCodec.maxBinaryInspectionBytes,
                withinScope: scopeURL
            )
            let preview = DocumentCodec.decodeBinaryInspectionPreview(cappedData)
            return DocumentSession(
                fileURL: url,
                text: preview.text,
                encoding: preview.encoding,
                lineEnding: preview.lineEnding,
                isDirty: false,
                isDegradedPlainText: true,
                isBinaryReadOnly: true
            )
        }

        let isDegraded = attrs.byteSize > Self.degradedModeThresholdBytes
        let data = try fileSystem.readData(at: url, maxBytes: nil, withinScope: scopeURL)
        let decoded = try DocumentCodec.decode(data)
        return DocumentSession(
            fileURL: url,
            text: decoded.text,
            encoding: decoded.encoding,
            lineEnding: decoded.lineEnding,
            isDirty: false,
            isDegradedPlainText: isDegraded,
            isBinaryReadOnly: decoded.isBinaryReadOnly
        )
    }

    /// Encodes and atomically writes a non-binary `DocumentSession`, rejecting binary read-only buffers with `DomainError.binaryFileSaveForbidden` (`DATA-003`, `DATA-004`).
    public func save(_ session: DocumentSession, to url: URL, withinScope scopeURL: URL? = nil) throws -> DocumentSession {
        if session.isBinaryReadOnly {
            throw DomainError.binaryFileSaveForbidden
        }
        let encoded = try DocumentCodec.encode(
            session.text,
            encoding: session.encoding,
            lineEnding: session.lineEnding
        )
        try fileSystem.writeAtomic(data: encoded, to: url, withinScope: scopeURL)
        return session.markingClean(savedAt: url)
    }

    /// Re-decodes an existing file at `url` using an explicit `TextEncoding` within `scopeURL` (`Reopen with Encoding`, `REQ-012`, `SEC-003`).
    public func load(from url: URL, explicitEncoding: TextEncoding, withinScope scopeURL: URL? = nil) throws -> DocumentSession {
        let attrs = try fileSystem.fileAttributes(at: url, withinScope: scopeURL)
        if attrs.isSymbolicLink {
            throw DomainError.securityScopeViolation(path: url.path)
        }
        if attrs.byteSize > Self.maxAllowedFileBytes {
            throw DomainError.fileTooLarge(byteCount: attrs.byteSize)
        }
        let isDegraded = attrs.byteSize > Self.degradedModeThresholdBytes
        let data = try fileSystem.readData(at: url, maxBytes: nil, withinScope: scopeURL)
        let decoded = try DocumentCodec.decode(data, explicitEncoding: explicitEncoding)
        return DocumentSession(
            fileURL: url,
            text: decoded.text,
            encoding: decoded.encoding,
            lineEnding: decoded.lineEnding,
            isDirty: false,
            isDegradedPlainText: isDegraded,
            isBinaryReadOnly: false
        )
    }
}
