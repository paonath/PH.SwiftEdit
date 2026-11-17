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

/// Authoritative document line-break convention preserved on save while normalized to `\n` inside `DocumentSession`.
public enum LineEnding: String, CaseIterable, Codable, Sendable {
    case lf = "\n"
    case crlf = "\r\n"

    /// Detects `.crlf` when at least one `\r\n` sequence is present, defaulting to `.lf`.
    public static func detect(in rawText: String) -> LineEnding {
        rawText.contains("\r\n") ? .crlf : .lf
    }

    /// Converts `\r\n` and bare `\r` sequences into canonical `\n` line breaks for in-memory editing.
    public static func normalizeToLF(_ rawText: String) -> String {
        rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Re-applies the document's wire line-break convention prior to byte encoding.
    public func apply(toCanonicalLF canonicalLF: String) -> String {
        self == .crlf ? canonicalLF.replacingOccurrences(of: "\n", with: "\r\n") : canonicalLF
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

/// Typed domain error contract enforced fail-closed across `SwiftEditCore` (`BC-012`, `DATA-002`, `DATA-003`, `SEC-012`).
public enum DomainError: Error, Equatable, Sendable {
    case fileTooLarge(byteCount: UInt64)
    case binaryFileSaveForbidden
    case unsupportedEncoding
    case invalidTextRange(TextRange)
    case securityScopeViolation(path: String)
    case ioFailure(String)
}

/// Immutable domain event emitted synchronously by `DocumentSession` upon accepted buffer mutations (`BC-003`).
public enum DomainEvent: Equatable, Sendable {
    case textEdited(DocumentID, BufferRevision, TextRange)
    case commandDDuplicated(DocumentID, BufferRevision, TextRange)
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
