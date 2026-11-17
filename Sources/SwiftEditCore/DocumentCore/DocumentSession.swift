import Foundation

/// Value-type Aggregate Root of `DocumentCore` governing text edits, `Cmd+D` duplication, encoding/line-ending fidelity, and binary quarantine (`BC-003`, `BC-004`).
public struct DocumentSession: Equatable, Sendable {
    public let id: DocumentID
    public private(set) var fileURL: URL?
    public private(set) var revision: BufferRevision
    public private(set) var text: String
    public private(set) var encoding: TextEncoding
    public private(set) var lineEnding: LineEnding
    public private(set) var isDirty: Bool
    public let isDegradedPlainText: Bool
    public let isBinaryReadOnly: Bool

    /// Returns `false` for binary read-only buffers so binary files can never be pinned (`BC-008`, `DATA-003`).
    public var isPinnable: Bool { !isBinaryReadOnly }
    /// Returns `false` for binary read-only buffers to prevent `SessionRecovery` retention (`SEC-011`).
    public var isEligibleForSessionRecovery: Bool { !isBinaryReadOnly }

    public init(
        id: DocumentID = DocumentID(),
        fileURL: URL? = nil,
        revision: BufferRevision = BufferRevision(1),
        text: String,
        encoding: TextEncoding = .utf8,
        lineEnding: LineEnding = .lf,
        isDirty: Bool = false,
        isDegradedPlainText: Bool = false,
        isBinaryReadOnly: Bool = false
    ) {
        self.id = id
        self.fileURL = fileURL
        self.revision = revision
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
        self.isDegradedPlainText = isDegradedPlainText
        self.isBinaryReadOnly = isBinaryReadOnly
    }

    /// Immutable snapshot projection of the current session state and `BufferRevision`.
    public var snapshot: DocumentSnapshot {
        DocumentSnapshot(
            id: id,
            revision: revision,
            text: text,
            encoding: encoding,
            lineEnding: lineEnding,
            isDegradedPlainText: isDegradedPlainText,
            isBinaryReadOnly: isBinaryReadOnly
        )
    }

    public func markingClean(savedAt url: URL) -> DocumentSession {
        DocumentSession(
            id: id,
            fileURL: url,
            revision: revision,
            text: text,
            encoding: encoding,
            lineEnding: lineEnding,
            isDirty: false,
            isDegradedPlainText: isDegradedPlainText,
            isBinaryReadOnly: isBinaryReadOnly
        )
    }

    /// Replaces the UTF-16 `range` with `replacement`, increments `revision`, marks `isDirty`, and returns `.textEdited`.
    /// - Throws: `DomainError.binaryFileSaveForbidden` when `isBinaryReadOnly` is `true`, or `DomainError.invalidTextRange` when `range` is out of bounds.
    @discardableResult
    public mutating func applyEdit(replacing range: TextRange, with replacement: String) throws -> DomainEvent {
        try ensureEditable()
        let stringRange = try resolveStringRange(for: range)
        text.replaceSubrange(stringRange, with: replacement)
        revision = revision.next()
        isDirty = true
        let editedSpan = TextRange(location: range.location, length: replacement.utf16.count)
        return .textEdited(id, revision, editedSpan)
    }

    /// Executes `Cmd+D`: duplicates the current line when `selection.length == 0`, or inserts the selected substring on a new line immediately after the cursor line when `selection.length > 0` (`AR-012`, `BC-003`).
    /// - Throws: `DomainError.binaryFileSaveForbidden` when `isBinaryReadOnly` is `true`, or `DomainError.invalidTextRange` when `selection` is out of bounds.
    @discardableResult
    public mutating func duplicateLineOrSelection(selection: TextRange) throws -> DomainEvent {
        try ensureEditable()
        let selectionRange = try resolveStringRange(for: selection)
        let separator = activeSeparator
        let units = Array(text.utf16)

        if selection.length == 0 {
            let bounds = Self.lineContentBounds(containingUTF16Offset: selection.location, in: units)
            let lineRange = try resolveStringRange(for: TextRange(location: bounds.start, length: bounds.end - bounds.start))
            let lineContent = String(text[lineRange])
            let insertionPoint = try resolveStringRange(for: TextRange(location: bounds.end, length: 0))
            text.replaceSubrange(insertionPoint, with: separator + lineContent)
            revision = revision.next()
            isDirty = true
            let columnOffset = selection.location - bounds.start
            let newCaret = TextRange(location: bounds.end + separator.utf16.count + columnOffset, length: 0)
            return .commandDDuplicated(id, revision, newCaret)
        }

        let selectedSubstring = String(text[selectionRange])
        let endLineBounds = Self.lineContentBounds(containingUTF16Offset: selection.upperBound, in: units)
        let insertionPoint = try resolveStringRange(for: TextRange(location: endLineBounds.end, length: 0))
        text.replaceSubrange(insertionPoint, with: separator + selectedSubstring)
        revision = revision.next()
        isDirty = true
        let insertedSelection = TextRange(
            location: endLineBounds.end + separator.utf16.count,
            length: selectedSubstring.utf16.count
        )
        return .commandDDuplicated(id, revision, insertedSelection)
    }

    private static func lineContentBounds(containingUTF16Offset offset: Int, in units: [UInt16]) -> (start: Int, end: Int) {
        var lineStart = offset
        while lineStart > 0 && units[lineStart - 1] != 0x0A && units[lineStart - 1] != 0x0D {
            lineStart -= 1
        }
        var lineEnd = offset
        while lineEnd < units.count && units[lineEnd] != 0x0D && units[lineEnd] != 0x0A {
            lineEnd += 1
        }
        return (lineStart, lineEnd)
    }

    private var activeSeparator: String {
        if text.contains("\r\n") {
            return "\r\n"
        }
        if text.contains("\n") {
            return "\n"
        }
        return lineEnding.rawValue
    }

    /// Fail-closed mutability guard blocking edits and `Cmd+D` duplication on binary read-only inspection buffers (`BC-012`, `DATA-003`, `SEC-012`).
    private func ensureEditable() throws {
        if isBinaryReadOnly {
            throw DomainError.binaryFileSaveForbidden
        }
    }

    private func resolveStringRange(for range: TextRange) throws -> Range<String.Index> {
        guard range.location >= 0,
              range.length >= 0,
              range.upperBound <= text.utf16.count,
              let swiftRange = Range(NSRange(location: range.location, length: range.length), in: text) else {
            throw DomainError.invalidTextRange(range)
        }
        return swiftRange
    }
}
