import Foundation

/// Strongly-typed document identifier shared across `SwiftEditCore` bounded contexts without exposing mutable buffer references (`BC-006`).
public struct DocumentID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// Monotonically increasing buffer revision counter tagging every `DocumentSnapshot` and `DomainEvent` (`AR-008`, `BC-004`).
public struct BufferRevision: Hashable, Comparable, Codable, Sendable {
    public let value: UInt64

    public init(_ value: UInt64) {
        self.value = value
    }

    public func next() -> BufferRevision {
        BufferRevision(value + 1)
    }

    public static func < (lhs: BufferRevision, rhs: BufferRevision) -> Bool {
        lhs.value < rhs.value
    }
}

/// Lossless text encodings supported across load and explicit atomic save (`DATA-004`).
public enum TextEncoding: String, CaseIterable, Codable, Sendable {
    case utf8
    case utf8WithBOM
    case utf16LEWithBOM
    case utf16BEWithBOM

    private static let emptyBOM: [UInt8] = []
    private static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let utf16LEBOM: [UInt8] = [0xFF, 0xFE]
    private static let utf16BEBOM: [UInt8] = [0xFE, 0xFF]

    /// Leading byte-order mark bytes emitted on serialization (`[]` for BOM-less UTF-8).
    public var bomBytes: [UInt8] {
        switch self {
        case .utf8: return Self.emptyBOM
        case .utf8WithBOM: return Self.utf8BOM
        case .utf16LEWithBOM: return Self.utf16LEBOM
        case .utf16BEWithBOM: return Self.utf16BEBOM
        }
    }
}

/// Authoritative three-way document line-break convention (`LF`, `CRLF`, Classic Mac `CR`) preserved on save while normalized to `\n` inside `DocumentSession` (`DATA-004`).
public enum LineEnding: String, CaseIterable, Codable, Sendable {
    case lf = "\n"
    case crlf = "\r\n"
    /// Classic Mac `\r` (`U+000D`) line break evaluated strictly after `\r\n` so Windows `CRLF` files are never misclassified (`DATA-004`).
    case cr = "\r"

    /// Detects the wire line ending by scanning UTF-8 bytes with deterministic precedence `crlf > cr > lf`.
    /// - Parameter rawText: Decoded string prior to canonical `\n` normalization.
    /// - Returns: `.crlf` if any `U+000D U+000A` pair exists, `.cr` if any bare `U+000D` exists, otherwise `.lf`.
    public static func detect(in rawText: String) -> LineEnding {
        if let result = rawText.utf8.withContiguousStorageIfAvailable({ buf -> LineEnding in
            guard let base = buf.baseAddress, !buf.isEmpty else { return .lf }
            let count = buf.count
            var pos = 0
            var sawBareCR = false
            while pos < count {
                guard let hit = memchr(base + pos, 0x0D, count - pos) else {
                    break
                }
                let crIdx = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
                if crIdx + 1 < count && base[crIdx + 1] == 0x0A {
                    return .crlf
                }
                sawBareCR = true
                pos = crIdx + 1
            }
            return sawBareCR ? .cr : .lf
        }) {
            return result
        }
        let bytes = rawText.utf8
        var index = bytes.startIndex
        var sawBareCR = false
        while index < bytes.endIndex {
            let b = bytes[index]
            let nextIndex = bytes.index(after: index)
            if b == 0x0D {
                if nextIndex < bytes.endIndex && bytes[nextIndex] == 0x0A {
                    return .crlf
                }
                sawBareCR = true
            }
            index = nextIndex
        }
        return sawBareCR ? .cr : .lf
    }

    /// Normalizes `\r\n` pairs and bare `\r` scalars into single `\n` (`U+000A`) breaks in one UTF-8 pass (zero-copy fast path when no `\r` is present).
    public static func normalizeToLF(_ rawText: String) -> String {
        if let fastResult = rawText.utf8.withContiguousStorageIfAvailable({ buf -> String? in
            guard let base = buf.baseAddress, !buf.isEmpty else { return rawText }
            let count = buf.count
            guard let firstHit = memchr(base, 0x0D, count) else {
                return rawText
            }
            let firstCR = UnsafePointer(firstHit.assumingMemoryBound(to: UInt8.self)) - base
            return String(unsafeUninitializedCapacity: count) { dst in
                var outLen = 0
                if firstCR > 0 {
                    dst.baseAddress!.update(from: base, count: firstCR)
                    outLen = firstCR
                }
                var i = firstCR
                while i < count {
                    let b = base[i]
                    if b == 0x0D {
                        dst[outLen] = 0x0A
                        outLen += 1
                        if i + 1 < count && base[i + 1] == 0x0A {
                            i += 2
                        } else {
                            i += 1
                        }
                    } else {
                        dst[outLen] = b
                        outLen += 1
                        i += 1
                    }
                }
                return outLen
            }
        }), let normalized = fastResult {
            return normalized
        }
        guard rawText.utf8.contains(0x0D) else { return rawText }
        var outBytes: [UInt8] = []
        outBytes.reserveCapacity(rawText.utf8.count)
        let bytes = rawText.utf8
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let b = bytes[index]
            let nextIndex = bytes.index(after: index)
            if b == 0x0D {
                outBytes.append(0x0A)
                if nextIndex < bytes.endIndex && bytes[nextIndex] == 0x0A {
                    index = bytes.index(after: nextIndex)
                    continue
                }
            } else {
                outBytes.append(b)
            }
            index = nextIndex
        }
        return String(decoding: outBytes, as: UTF8.self)
    }

    /// Re-applies the document's wire line-break convention (`\n`, `\r\n`, or `\r`) prior to byte serialization.
    public func apply(toCanonicalLF canonicalLF: String) -> String {
        switch self {
        case .lf:
            return canonicalLF
        case .crlf:
            if let fast = canonicalLF.utf8.withContiguousStorageIfAvailable({ buf -> String in
                guard let base = buf.baseAddress, !buf.isEmpty else { return canonicalLF }
                let count = buf.count
                guard let firstHit = memchr(base, 0x0A, count) else { return canonicalLF }
                var lfCount = 0
                var scanPos = UnsafePointer(firstHit.assumingMemoryBound(to: UInt8.self)) - base
                while scanPos < count {
                    lfCount += 1
                    let nextStart = scanPos + 1
                    guard nextStart < count, let hit = memchr(base + nextStart, 0x0A, count - nextStart) else {
                        break
                    }
                    scanPos = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
                }
                return String(unsafeUninitializedCapacity: count + lfCount) { dst in
                    let dstBase = dst.baseAddress!
                    var srcPos = 0
                    var dstPos = 0
                    var nextLF = UnsafePointer(firstHit.assumingMemoryBound(to: UInt8.self)) - base
                    while true {
                        let segLen = nextLF - srcPos
                        if segLen > 0 {
                            (dstBase + dstPos).update(from: base + srcPos, count: segLen)
                            dstPos += segLen
                        }
                        dstBase[dstPos] = 0x0D
                        dstBase[dstPos + 1] = 0x0A
                        dstPos += 2
                        srcPos = nextLF + 1
                        guard srcPos < count, let hit = memchr(base + srcPos, 0x0A, count - srcPos) else {
                            break
                        }
                        nextLF = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
                    }
                    let tail = count - srcPos
                    if tail > 0 {
                        (dstBase + dstPos).update(from: base + srcPos, count: tail)
                        dstPos += tail
                    }
                    return dstPos
                }
            }) {
                return fast
            }
            return canonicalLF.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:
            if let fast = canonicalLF.utf8.withContiguousStorageIfAvailable({ buf -> String in
                guard let base = buf.baseAddress, !buf.isEmpty else { return canonicalLF }
                let count = buf.count
                guard memchr(base, 0x0A, count) != nil else { return canonicalLF }
                return String(unsafeUninitializedCapacity: count) { dst in
                    for i in 0..<count {
                        let b = base[i]
                        dst[i] = (b == 0x0A) ? 0x0D : b
                    }
                    return count
                }
            }) {
                return fast
            }
            return canonicalLF.replacingOccurrences(of: "\n", with: "\r")
        }
    }
}

/// UTF-16 code-unit span (`location`, `length`) aligned with TextKit 2 / `NSRange` indexing.
public struct TextRange: Hashable, Codable, Sendable {
    public let location: Int
    public let length: Int

    public var upperBound: Int { location + length }

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

/// Single UTF-16 replacement span produced by `Format Document` or `Format Section` (`BC-004`).
public struct TextEdit: Hashable, Codable, Sendable {
    public let range: TextRange
    public let replacement: String

    public init(range: TextRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }
}

/// Typed domain error contract enforced fail-closed across `SwiftEditCore` (`BC-012`, `DATA-002`, `DATA-003`, `SEC-012`).
public enum DomainError: Error, Equatable, Sendable {
    case fileTooLarge(byteCount: UInt64)
    case binaryFileSaveForbidden
    case unsupportedEncoding
    case invalidTextRange(TextRange)
    case staleBufferRevision(expected: BufferRevision, actual: BufferRevision)
    case tabNotFound(DocumentID)
    case pinnedTabCloseForbidden(DocumentID)
    case sessionRecoveryQuotaExceeded(byteCount: UInt64)
    case corruptedRecoveryManifest
    case securityScopeViolation(path: String)
    case batchLimitExceeded(maxBytes: UInt64)
    case invalidItemName(String)
    case destinationAlreadyExists(path: String)
    case invalidPasteTarget(path: String)
    case ioFailure(String)
}

/// Immutable domain event emitted synchronously by `DocumentSession` upon accepted buffer mutations (`BC-003`).
public enum DomainEvent: Equatable, Sendable {
    case textEdited(DocumentID, BufferRevision, TextRange)
    case commandDDuplicated(DocumentID, BufferRevision, TextRange)
    case formatBatchApplied(DocumentID, BufferRevision, editCount: Int)
}

/// Immutable point-in-time projection of a `DocumentSession` consumed off `@MainActor` by lint, bracket, and diff engines (`BC-004`, `BC-006`).
public struct DocumentSnapshot: Equatable, Sendable {
    public let id: DocumentID
    public let revision: BufferRevision
    public let text: String
    public let encoding: TextEncoding
    public let lineEnding: LineEnding
    public let isDegradedPlainText: Bool
    public let isBinaryReadOnly: Bool

    public init(
        id: DocumentID,
        revision: BufferRevision,
        text: String,
        encoding: TextEncoding,
        lineEnding: LineEnding,
        isDegradedPlainText: Bool,
        isBinaryReadOnly: Bool
    ) {
        self.id = id
        self.revision = revision
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDegradedPlainText = isDegradedPlainText
        self.isBinaryReadOnly = isBinaryReadOnly
    }
}
