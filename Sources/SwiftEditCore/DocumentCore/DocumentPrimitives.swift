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

    /// Leading byte-order mark bytes emitted on serialization (`[]` for BOM-less UTF-8).
    public var bomBytes: [UInt8] {
        switch self {
        case .utf8: return []
        case .utf8WithBOM: return [0xEF, 0xBB, 0xBF]
        case .utf16LEWithBOM: return [0xFF, 0xFE]
        case .utf16BEWithBOM: return [0xFE, 0xFF]
        }
    }
}

/// Authoritative three-way document line-break convention (`LF`, `CRLF`, Classic Mac `CR`) preserved on save while normalized to `\n` inside `DocumentSession` (`DATA-004`).
public enum LineEnding: String, CaseIterable, Codable, Sendable {
    case lf = "\n"
    case crlf = "\r\n"
    /// Classic Mac `\r` (`U+000D`) line break evaluated strictly after `\r\n` so Windows `CRLF` files are never misclassified (`DATA-004`).
    case cr = "\r"

    /// Detects the wire line ending by scanning Unicode scalars with deterministic precedence `crlf > cr > lf`.
    /// - Parameter rawText: Decoded string prior to canonical `\n` normalization.
    /// - Returns: `.crlf` if any `U+000D U+000A` pair exists, `.cr` if any bare `U+000D` exists, otherwise `.lf`.
    public static func detect(in rawText: String) -> LineEnding {
        let scalars = rawText.unicodeScalars
        var index = scalars.startIndex
        var sawBareCR = false
        while index < scalars.endIndex {
            let scalar = scalars[index]
            let nextIndex = scalars.index(after: index)
            if scalar.value == 0x0D {
                if nextIndex < scalars.endIndex && scalars[nextIndex].value == 0x0A {
                    return .crlf
                }
                sawBareCR = true
            }
            index = nextIndex
        }
        return sawBareCR ? .cr : .lf
    }

    /// Normalizes `\r\n` pairs and bare `\r` scalars into single `\n` (`U+000A`) breaks in one scalar pass.
    public static func normalizeToLF(_ rawText: String) -> String {
        let scalars = rawText.unicodeScalars
        var output = String.UnicodeScalarView()
        output.reserveCapacity(scalars.count)
        var index = scalars.startIndex
        while index < scalars.endIndex {
            let scalar = scalars[index]
            let nextIndex = scalars.index(after: index)
            if scalar.value == 0x0D {
                output.append("\n")
                if nextIndex < scalars.endIndex && scalars[nextIndex].value == 0x0A {
                    index = scalars.index(after: nextIndex)
                    continue
                }
            } else {
                output.append(scalar)
            }
            index = nextIndex
        }
        return String(output)
    }

    /// Re-applies the document's wire line-break convention (`\n`, `\r\n`, or `\r`) prior to byte serialization.
    public func apply(toCanonicalLF canonicalLF: String) -> String {
        switch self {
        case .lf:
            return canonicalLF
        case .crlf:
            return canonicalLF.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:
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
