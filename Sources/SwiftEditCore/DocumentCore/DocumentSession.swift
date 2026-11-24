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

    /// Updates the document's wire `LineEnding` (`LF`, `CRLF`, `CR`) and marks `isDirty` when changed (`DATA-004`).
    /// - Throws: `DomainError.binaryFileSaveForbidden` when `isBinaryReadOnly` is `true`.
    public mutating func setLineEnding(_ newLineEnding: LineEnding) throws {
        try ensureEditable()
        guard lineEnding != newLineEnding else { return }
        lineEnding = newLineEnding
        revision = revision.next()
        isDirty = true
    }

    /// Replaces the UTF-16 `range` with `replacement`, normalizing raw `\r\n`/`\r` line breaks to `\n` on LF-normalized buffers, incrementing `revision`, marking `isDirty`, and returning `.textEdited` (`BUG-016`, `BC-003`).
    /// - Throws: `DomainError.binaryFileSaveForbidden` when `isBinaryReadOnly` is `true`, or `DomainError.invalidTextRange` when `range` is out of bounds.
    @discardableResult
    public mutating func applyEdit(replacing range: TextRange, with replacement: String) throws -> DomainEvent {
        try ensureEditable()
        let effectiveReplacement = normalizedReplacementIfNeeded(replacement)
        if range.location == 0 && (text.isEmpty ? range.length == 0 : (range.length > 0 && range.length == text.utf16.count)) {
            text = effectiveReplacement
        } else {
            let stringRange = try resolveStringRange(for: range)
            text.replaceSubrange(stringRange, with: effectiveReplacement)
        }
        revision = revision.next()
        isDirty = true
        let editedSpan = TextRange(location: range.location, length: effectiveReplacement.utf16.count)
        return .textEdited(id, revision, editedSpan)
    }

    /// Canonicalizes `\r\n` and bare `\r` in `replacement` to `\n` whenever the in-memory buffer is LF-normalized (`!containsCRLF`), avoiding raw carriage-return artifacts while preserving wire `LineEnding` on save (`BUG-016`).
    private func normalizedReplacementIfNeeded(_ replacement: String) -> String {
        guard replacement.utf8.contains(0x0D), !Self.containsCRLF(in: text) else {
            return replacement
        }
        return LineEnding.normalizeToLF(replacement)
    }

    /// Replaces the entire buffer in `O(1)` when `newText` differs from `text`, avoiding redundant full-document UTF-16 length scans on large-buffer typing (`PERF-006`).
    @discardableResult
    public mutating func replaceFullTextIfChanged(_ newText: String) throws -> Bool {
        try ensureEditable()
        guard text != newText else { return false }
        text = newText
        revision = revision.next()
        isDirty = true
        return true
    }

    /// Executes `Cmd+D`: duplicates the current line when `selection.length == 0`, or inserts the selected substring on a new line immediately after the cursor line when `selection.length > 0` (`AR-012`, `BC-003`).
    /// - Throws: `DomainError.binaryFileSaveForbidden` when `isBinaryReadOnly` is `true`, or `DomainError.invalidTextRange` when `selection` is out of bounds.
    @discardableResult
    public mutating func duplicateLineOrSelection(selection: TextRange) throws -> DomainEvent {
        try ensureEditable()
        let selectionRange = try resolveStringRange(for: selection)
        let separator = activeSeparator

        if selection.length == 0 {
            let lineStartIdx = Self.lineStartIndex(beforeOrAt: selectionRange.lowerBound, in: text)
            let lineEndIdx = Self.lineEndIndex(atOrAfter: selectionRange.lowerBound, in: text)
            let lineContent = String(text[lineStartIdx..<lineEndIdx])
            let columnOffset = text.utf16.distance(from: lineStartIdx, to: selectionRange.lowerBound)
            let trailingUTF16 = text.utf16.distance(from: selectionRange.lowerBound, to: lineEndIdx)
            let lineEndUTF16 = selection.location + trailingUTF16

            text.replaceSubrange(lineEndIdx..<lineEndIdx, with: separator + lineContent)
            revision = revision.next()
            isDirty = true
            let newCaret = TextRange(location: lineEndUTF16 + separator.utf16.count + columnOffset, length: 0)
            return .commandDDuplicated(id, revision, newCaret)
        }

        let selectedSubstring = String(text[selectionRange])
        let endLineEndIdx = Self.lineEndIndex(atOrAfter: selectionRange.upperBound, in: text)
        let trailingUTF16 = text.utf16.distance(from: selectionRange.upperBound, to: endLineEndIdx)
        let endLineEndUTF16 = selection.upperBound + trailingUTF16

        text.replaceSubrange(endLineEndIdx..<endLineEndIdx, with: separator + selectedSubstring)
        revision = revision.next()
        isDirty = true
        let insertedSelection = TextRange(
            location: endLineEndUTF16 + separator.utf16.count,
            length: selectedSubstring.utf16.count
        )
        return .commandDDuplicated(id, revision, insertedSelection)
    }

    /// Applies a non-overlapping batch of `TextEdit` replacements atomically in a single `BufferRevision` transition in linear `O(N + M log M)` time (`BC-003`, `BC-004`).
    /// - Throws: `DomainError.binaryFileSaveForbidden` on binary read-only buffers, `DomainError.staleBufferRevision` when `expectedRevision` differs from `revision`, or `DomainError.invalidTextRange` when any edit range is out of bounds or overlaps another edit.
    @discardableResult
    public mutating func applyTextEdits(_ edits: [TextEdit], expectedRevision: BufferRevision) throws -> DomainEvent {
        try ensureEditable()
        guard expectedRevision == revision else {
            throw DomainError.staleBufferRevision(expected: expectedRevision, actual: revision)
        }

        guard !edits.isEmpty else {
            revision = revision.next()
            isDirty = true
            return .formatBatchApplied(id, revision, editCount: 0)
        }

        let sortedEdits = try Self.docSessionValidateAndSortEdits(edits)
        var contiguousText = text
        contiguousText.makeContiguousUTF8()
        let updatedText = try contiguousText.utf8.withContiguousStorageIfAvailable { buf in
            try Self.docSessionApplySortedEdits(sortedEdits, to: buf)
        }!

        text = updatedText
        revision = revision.next()
        isDirty = true
        return .formatBatchApplied(id, revision, editCount: edits.count)
    }
}

private extension DocumentSession {
    static func docSessionValidateAndSortEdits(_ edits: [TextEdit]) throws -> [TextEdit] {
        for edit in edits where edit.range.location < 0 || edit.range.length < 0 {
            throw DomainError.invalidTextRange(edit.range)
        }
        guard edits.count > 1 else { return edits }
        let sortedEdits = edits.sorted(by: docSessionPrecedesInRangeOrder)
        try docSessionEnsureNonOverlapping(sortedEdits)
        return sortedEdits
    }

    static func docSessionPrecedesInRangeOrder(_ lhs: TextEdit, _ rhs: TextEdit) -> Bool {
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        }
        return lhs.range.length < rhs.range.length
    }

    static func docSessionEnsureNonOverlapping(_ sortedEdits: [TextEdit]) throws {
        for index in 1..<sortedEdits.count {
            let previous = sortedEdits[index - 1]
            let current = sortedEdits[index]
            if docSessionEditsOverlap(previous: previous, current: current) {
                throw DomainError.invalidTextRange(current.range)
            }
        }
    }

    static func docSessionEditsOverlap(previous: TextEdit, current: TextEdit) -> Bool {
        if current.range.location < previous.range.upperBound {
            return true
        }
        return current.range.length == 0
            && previous.range.length == 0
            && current.range.location == previous.range.location
    }

    static func docSessionApplySortedEdits(
        _ sortedEdits: [TextEdit],
        to buf: UnsafeBufferPointer<UInt8>
    ) throws -> String {
        let resolved = try docSessionResolveByteRanges(for: sortedEdits, in: buf)
        return String(unsafeUninitializedCapacity: resolved.totalOutputBytes) { dst in
            docSessionWriteReconstructedUTF8(
                source: buf,
                sortedEdits: sortedEdits,
                byteRanges: resolved.ranges,
                into: dst
            )
        }
    }

    static func docSessionResolveByteRanges(
        for sortedEdits: [TextEdit],
        in buf: UnsafeBufferPointer<UInt8>
    ) throws -> (ranges: [(start: Int, end: Int)], totalOutputBytes: Int) {
        var byteRanges: [(start: Int, end: Int)] = []
        byteRanges.reserveCapacity(sortedEdits.count)
        var bytePos = 0
        var utf16Pos = 0
        var totalOutputBytes = buf.count

        for edit in sortedEdits {
            let startByte = try docSessionAdvanceUTF8Cursor(
                toUTF16Target: edit.range.location,
                for: edit.range,
                in: buf,
                bytePos: &bytePos,
                utf16Pos: &utf16Pos
            )
            let endByte = try docSessionAdvanceUTF8Cursor(
                toUTF16Target: edit.range.upperBound,
                for: edit.range,
                in: buf,
                bytePos: &bytePos,
                utf16Pos: &utf16Pos
            )
            byteRanges.append((startByte, endByte))
            totalOutputBytes += edit.replacement.utf8.count - (endByte - startByte)
        }
        return (byteRanges, totalOutputBytes)
    }

    static func docSessionAdvanceUTF8Cursor(
        toUTF16Target target: Int,
        for range: TextRange,
        in buf: UnsafeBufferPointer<UInt8>,
        bytePos: inout Int,
        utf16Pos: inout Int
    ) throws -> Int {
        while utf16Pos < target {
            guard bytePos < buf.count, let base = buf.baseAddress else {
                throw DomainError.invalidTextRange(range)
            }
            let step = docSessionUTF8SequenceStep(forLeadByte: base[bytePos])
            if utf16Pos + step.utf16 > target {
                throw DomainError.invalidTextRange(range)
            }
            bytePos += step.bytes
            utf16Pos += step.utf16
        }
        return bytePos
    }

    static func docSessionUTF8SequenceStep(forLeadByte lead: UInt8) -> (bytes: Int, utf16: Int) {
        if lead < 0x80 { return (1, 1) }
        if lead < 0xE0 { return (2, 1) }
        if lead < 0xF0 { return (3, 1) }
        return (4, 2)
    }

    static func docSessionWriteReconstructedUTF8(
        source: UnsafeBufferPointer<UInt8>,
        sortedEdits: [TextEdit],
        byteRanges: [(start: Int, end: Int)],
        into dst: UnsafeMutableBufferPointer<UInt8>
    ) -> Int {
        var dstPos = 0
        var srcPos = 0
        for idx in 0..<sortedEdits.count {
            let (startByte, endByte) = byteRanges[idx]
            docSessionCopySourceSlice(from: source, start: srcPos, length: startByte - srcPos, into: dst, dstPos: &dstPos)
            docSessionCopyReplacement(sortedEdits[idx].replacement, into: dst, dstPos: &dstPos)
            srcPos = endByte
        }
        docSessionCopySourceSlice(from: source, start: srcPos, length: source.count - srcPos, into: dst, dstPos: &dstPos)
        return dstPos
    }

    static func docSessionCopySourceSlice(
        from source: UnsafeBufferPointer<UInt8>,
        start: Int,
        length: Int,
        into dst: UnsafeMutableBufferPointer<UInt8>,
        dstPos: inout Int
    ) {
        guard length > 0, let base = source.baseAddress, let dstBase = dst.baseAddress else { return }
        (dstBase + dstPos).initialize(from: base + start, count: length)
        dstPos += length
    }

    static func docSessionCopyReplacement(
        _ replacement: String,
        into dst: UnsafeMutableBufferPointer<UInt8>,
        dstPos: inout Int
    ) {
        guard !replacement.isEmpty else { return }
        if let copied = replacement.utf8.withContiguousStorageIfAvailable({ repBuf -> Int in
            if !repBuf.isEmpty, let repBase = repBuf.baseAddress, let dstBase = dst.baseAddress {
                (dstBase + dstPos).initialize(from: repBase, count: repBuf.count)
            }
            return repBuf.count
        }) {
            dstPos += copied
            return
        }
        for byte in replacement.utf8 {
            dst.initializeElement(at: dstPos, to: byte)
            dstPos += 1
        }
    }
}

extension DocumentSession {
    /// Returns `false` for binary read-only buffers so binary files can never be pinned (`BC-008`, `DATA-003`).
    public var isPinnable: Bool { !isBinaryReadOnly }
    /// Returns `false` for binary read-only buffers to prevent `SessionRecovery` retention (`SEC-011`).
    public var isEligibleForSessionRecovery: Bool { !isBinaryReadOnly }

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

    /// Resolves the line-break string emitted by `Cmd+D`, canonicalizing lone CR (`.cr`) to `\n` in memory so `NStextView` never receives raw `\r` (`BUG-015`).
    private var activeSeparator: String {
        let defaultBreak = lineEnding == .crlf ? "\r\n" : "\n"
        if let fast = text.utf8.withContiguousStorageIfAvailable({ buf in
            Self.docSessionDetectContiguousSeparator(in: buf, defaultBreak: defaultBreak)
        }) {
            return fast
        }
        if text.contains("\r\n") { return "\r\n" }
        if text.contains("\n") { return "\n" }
        if text.contains("\r") { return "\r" }
        return defaultBreak
    }

    private static func docSessionDetectContiguousSeparator(
        in buf: UnsafeBufferPointer<UInt8>,
        defaultBreak: String
    ) -> String {
        guard let base = buf.baseAddress, !buf.isEmpty else { return defaultBreak }
        let count = buf.count
        var sawBareCR = false
        var pos = 0
        while pos < count, let hit = memchr(base + pos, 0x0D, count - pos) {
            let idx = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
            if idx + 1 < count && base[idx + 1] == 0x0A {
                return "\r\n"
            }
            sawBareCR = true
            pos = idx + 1
        }
        if memchr(base, 0x0A, count) != nil { return "\n" }
        return sawBareCR ? "\r" : defaultBreak
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
              let start = text.utf16.index(text.utf16.startIndex, offsetBy: range.location, limitedBy: text.utf16.endIndex),
              let end = text.utf16.index(start, offsetBy: range.length, limitedBy: text.utf16.endIndex),
              let scalarStart = start.samePosition(in: text.unicodeScalars),
              let scalarEnd = end.samePosition(in: text.unicodeScalars) else {
            throw DomainError.invalidTextRange(range)
        }
        return scalarStart..<scalarEnd
    }
}

extension DocumentSession {
    fileprivate static func lineStartIndex(beforeOrAt index: String.Index, in text: String) -> String.Index {
        let utf8 = text.utf8
        var cursor = index
        while cursor > utf8.startIndex {
            let prev = utf8.index(before: cursor)
            let b = utf8[prev]
            if b == 0x0A || b == 0x0D {
                break
            }
            cursor = prev
        }
        return cursor
    }

    fileprivate static func lineEndIndex(atOrAfter index: String.Index, in text: String) -> String.Index {
        let utf8 = text.utf8
        var cursor = index
        while cursor < utf8.endIndex {
            let b = utf8[cursor]
            if b == 0x0A || b == 0x0D {
                break
            }
            cursor = utf8.index(after: cursor)
        }
        return cursor
    }

    fileprivate static func containsCRLF(in text: String) -> Bool {
        if let found = text.utf8.withContiguousStorageIfAvailable({ buf -> Bool in
            guard let base = buf.baseAddress, buf.count >= 2 else { return false }
            let count = buf.count
            var pos = 0
            while pos < count {
                guard let hit = memchr(base + pos, 0x0D, count - pos) else { return false }
                let idx = UnsafePointer(hit.assumingMemoryBound(to: UInt8.self)) - base
                if idx + 1 < count && base[idx + 1] == 0x0A {
                    return true
                }
                pos = idx + 1
            }
            return false
        }) {
            return found
        }
        return text.contains("\r\n")
    }
}
