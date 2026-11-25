import Foundation

/// Case-sensitivity, whole-word, and selection-scope configuration for literal document search and replace (`BC-004`, `BC-011`, `REQ-008`).
public struct SearchOptions: Equatable, Sendable {
    public let isCaseSensitive: Bool
    public let isWholeWord: Bool
    public let searchRange: TextRange?

    public init(
        isCaseSensitive: Bool = false,
        isWholeWord: Bool = false,
        searchRange: TextRange? = nil
    ) {
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWord = isWholeWord
        self.searchRange = searchRange
    }
}

/// Literal-only search, batch replace-all, and 1-based line navigation engine operating over immutable `DocumentSnapshot` values (`AR-004`, `BC-004`, `BC-006`, `BC-011`, `SEC-012`).
///
/// Security invariants:
/// - Evaluates exclusively literal `NSString` comparisons (zero regular expressions, eliminating `CWE-1333` catastrophic backtracking).
/// - Rejects binary (`binarySnapshot`), degraded plain-text (`degradedPlainTextSnapshot`), `> 1024` UTF-16 unit queries (`inputTooLarge`), and `> 100,000` match floods (`matchLimitExceeded`, `CWE-400`).
public enum DocumentSearchEngine {
    public static let maxQueryUTF16Units: Int = 1024
    public static let defaultMaxMatches: Int = 100_000

    /// Finds all non-overlapping literal occurrences of `query` in `snapshot.text` as UTF-16 `TextRange` spans.
    public static func find(
        query: String,
        in snapshot: DocumentSnapshot,
        options: SearchOptions = SearchOptions(),
        maxMatches: Int = DocumentSearchEngine.defaultMaxMatches
    ) -> EngineEvaluationOutcome<[TextRange]> {
        if let guardFailure = precheck(query: query, snapshot: snapshot) {
            return .degradedOrTimedOut(guardFailure)
        }
        guard !query.isEmpty else {
            return .completed([])
        }

        // Zero-bridging raw UTF-8 fast path for unconstrained non-whole-word ASCII queries.
        if !options.isWholeWord, options.searchRange == nil, query.utf8.allSatisfy({ $0 < 0x80 }) {
            if let fastResult = findASCIIUTF8(
                query: query,
                in: snapshot.text,
                isCaseSensitive: options.isCaseSensitive,
                maxMatches: maxMatches
            ) {
                return fastResult
            }
        }

        let nsText = snapshot.text as NSString
        let totalLength = nsText.length
        guard let initialBounds = docSearchResolveSearchBounds(options.searchRange, totalLength: totalLength) else {
            return .completed([])
        }
        let compareOptions: NSString.CompareOptions = options.isCaseSensitive ? [.literal] : [.caseInsensitive, .literal]
        let boundsEnd = initialBounds.location + initialBounds.length
        var searchRange = initialBounds
        var matches: [TextRange] = []

        while searchRange.length > 0 {
            let found = nsText.range(of: query, options: compareOptions, range: searchRange)
            guard found.location != NSNotFound && found.length > 0 else {
                break
            }
            if options.isWholeWord, !docSearchHasWordBoundaries(in: nsText, location: found.location, length: found.length, totalLength: totalLength) {
                let stepStart = found.location + 1
                guard stepStart < boundsEnd else { break }
                searchRange = NSRange(location: stepStart, length: boundsEnd - stepStart)
                continue
            }
            if matches.count >= maxMatches {
                return .degradedOrTimedOut(.matchLimitExceeded(maxMatches: maxMatches))
            }
            matches.append(TextRange(location: found.location, length: found.length))
            let nextStart = found.location + found.length
            guard nextStart <= boundsEnd else {
                break
            }
            searchRange = NSRange(location: nextStart, length: boundsEnd - nextStart)
        }

        return .completed(matches)
    }

    /// Produces a non-overlapping `[TextEdit]` batch replacing every literal occurrence of `query` with `replacement` for atomic execution via `DocumentSession.applyTextEdits`.
    public static func replaceAll(
        query: String,
        with replacement: String,
        in snapshot: DocumentSnapshot,
        options: SearchOptions = SearchOptions(),
        maxMatches: Int = DocumentSearchEngine.defaultMaxMatches
    ) -> EngineEvaluationOutcome<[TextEdit]> {
        switch find(query: query, in: snapshot, options: options, maxMatches: maxMatches) {
        case .completed(let ranges):
            return .completed(ranges.map { TextEdit(range: $0, replacement: replacement) })
        case .degradedOrTimedOut(let reason):
            return .degradedOrTimedOut(reason)
        }
    }

    /// Resolves a 1-based `lineNumber` (`1...lineCount`) to its UTF-16 line-content `TextRange` (excluding trailing line terminators) in `O(1)` space without scanning past the target line.
    public static func goToLine(_ lineNumber: Int, in snapshot: DocumentSnapshot) -> TextRange? {
        guard !snapshot.isBinaryReadOnly, lineNumber >= 1 else {
            return nil
        }
        return UTF16LineBreakScanner.lineContentRange(forLine: lineNumber, in: snapshot.text)
    }
}

private extension DocumentSearchEngine {
    static func precheck(query: String, snapshot: DocumentSnapshot) -> DegradedEvaluationReason? {
        if snapshot.isBinaryReadOnly {
            return .binarySnapshot
        }
        if snapshot.isDegradedPlainText {
            return .degradedPlainTextSnapshot
        }
        let queryUTF16Count = query.utf16.count
        if queryUTF16Count > maxQueryUTF16Units {
            return .inputTooLarge(byteCount: queryUTF16Count)
        }
        return nil
    }

    static func docSearchResolveSearchBounds(_ customRange: TextRange?, totalLength: Int) -> NSRange? {
        guard let customRange else {
            return NSRange(location: 0, length: totalLength)
        }
        guard customRange.length > 0, customRange.location >= 0, customRange.location < totalLength else {
            return nil
        }
        let clampedLength = min(customRange.length, totalLength - customRange.location)
        return clampedLength > 0 ? NSRange(location: customRange.location, length: clampedLength) : nil
    }

    static func docSearchHasWordBoundaries(
        in nsText: NSString,
        location: Int,
        length: Int,
        totalLength: Int
    ) -> Bool {
        if location > 0, docSearchIsWordUnit(nsText.character(at: location - 1)) {
            return false
        }
        let end = location + length
        if end < totalLength, docSearchIsWordUnit(nsText.character(at: end)) {
            return false
        }
        return true
    }

    static func docSearchIsWordUnit(_ unit: unichar) -> Bool {
        if unit == 0x5F || (unit >= 0x30 && unit <= 0x39)
            || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A) {
            return true
        }
        guard unit >= 0x80, let scalar = UnicodeScalar(unit) else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
    }

    /// Scans contiguous UTF-8 bytes directly for an ASCII query without `NSString` bridging.
    /// Returns `nil` in case-insensitive mode if the text contains non-ASCII bytes so Unicode case folding falls back to `NSString`.
    static func findASCIIUTF8(
        query: String,
        in text: String,
        isCaseSensitive: Bool,
        maxMatches: Int
    ) -> EngineEvaluationOutcome<[TextRange]>? {
        text.utf8.withContiguousStorageIfAvailable { textBuf -> EngineEvaluationOutcome<[TextRange]>? in
            guard let textBase = textBuf.baseAddress else { return .completed([]) }
            let qBytes = Array(query.utf8)
            guard !qBytes.isEmpty, qBytes.count <= textBuf.count else { return .completed([]) }
            if isCaseSensitive {
                return docSearchFindCaseSensitiveASCII(
                    qBytes: qBytes,
                    textBase: textBase,
                    textCount: textBuf.count,
                    maxMatches: maxMatches
                )
            }
            return docSearchFindCaseInsensitiveASCII(
                qBytes: qBytes,
                textBase: textBase,
                textCount: textBuf.count,
                maxMatches: maxMatches
            )
        } ?? nil
    }

    @inline(__always)
    static func docSearchLowerASCIIByte(_ byte: UInt8) -> UInt8 {
        (byte >= 0x41 && byte <= 0x5A) ? (byte | 0x20) : byte
    }

    @inline(__always)
    static func docSearchUTF8Step(forLeadByte lead: UInt8) -> (bytes: Int, utf16: Int) {
        if lead < 0x80 { return (1, 1) }
        if lead < 0xE0 { return (2, 1) }
        if lead < 0xF0 { return (3, 1) }
        return (4, 2)
    }

    static func docSearchFindCaseInsensitiveASCII(
        qBytes: [UInt8],
        textBase: UnsafePointer<UInt8>,
        textCount: Int,
        maxMatches: Int
    ) -> EngineEvaluationOutcome<[TextRange]>? {
        let qLower = qBytes.map(docSearchLowerASCIIByte)
        var matches: [TextRange] = []
        matches.reserveCapacity(min(32, maxMatches))
        let limit = textCount - qLower.count
        var index = 0

        while index <= limit {
            guard let matched = docSearchMatchCaseInsensitiveAt(
                index: index,
                qLower: qLower,
                textBase: textBase
            ) else {
                return nil
            }
            if matched {
                if matches.count >= maxMatches {
                    return .degradedOrTimedOut(.matchLimitExceeded(maxMatches: maxMatches))
                }
                matches.append(TextRange(location: index, length: qLower.count))
                index += qLower.count
            } else {
                index += 1
            }
        }

        guard docSearchIsRemainingASCII(textBase: textBase, from: index, count: textCount) else {
            return nil
        }
        return .completed(matches)
    }

    static func docSearchMatchCaseInsensitiveAt(
        index: Int,
        qLower: [UInt8],
        textBase: UnsafePointer<UInt8>
    ) -> Bool? {
        let lead = textBase[index]
        if lead >= 0x80 { return nil }
        guard docSearchLowerASCIIByte(lead) == qLower[0] else { return false }
        let m = qLower.count
        if m == 1 { return true }
        let tail = textBase[index + m - 1]
        if tail >= 0x80 { return nil }
        guard docSearchLowerASCIIByte(tail) == qLower[m - 1] else { return false }
        return docSearchCompareMiddleCaseInsensitive(index: index, qLower: qLower, textBase: textBase)
    }

    static func docSearchCompareMiddleCaseInsensitive(
        index: Int,
        qLower: [UInt8],
        textBase: UnsafePointer<UInt8>
    ) -> Bool? {
        var j = 1
        let innerEnd = qLower.count - 1
        while j < innerEnd {
            let tb = textBase[index + j]
            if tb >= 0x80 { return nil }
            if docSearchLowerASCIIByte(tb) != qLower[j] { return false }
            j += 1
        }
        return true
    }

    static func docSearchIsRemainingASCII(
        textBase: UnsafePointer<UInt8>,
        from startIndex: Int,
        count: Int
    ) -> Bool {
        var i = startIndex
        while i < count {
            if textBase[i] >= 0x80 { return false }
            i += 1
        }
        return true
    }

    static func docSearchFindCaseSensitiveASCII(
        qBytes: [UInt8],
        textBase: UnsafePointer<UInt8>,
        textCount: Int,
        maxMatches: Int
    ) -> EngineEvaluationOutcome<[TextRange]> {
        qBytes.withUnsafeBufferPointer { qBuf in
            guard let qBase = qBuf.baseAddress else { return .completed([]) }
            return docSearchScanCaseSensitiveBuffer(
                qBase: qBase,
                queryLength: qBuf.count,
                textBase: textBase,
                textCount: textCount,
                maxMatches: maxMatches
            )
        }
    }

    static func docSearchScanCaseSensitiveBuffer(
        qBase: UnsafePointer<UInt8>,
        queryLength m: Int,
        textBase: UnsafePointer<UInt8>,
        textCount n: Int,
        maxMatches: Int
    ) -> EngineEvaluationOutcome<[TextRange]> {
        let firstByte = qBase[0]
        let lastByte = qBase[m - 1]
        var matches: [TextRange] = []
        matches.reserveCapacity(min(32, maxMatches))
        let limit = n - m
        var index = 0
        var utf16Offset = 0

        while index <= limit {
            let b = textBase[index]
            if b == firstByte,
               docSearchMatchesCaseSensitiveSlice(
                   at: index,
                   textBase: textBase,
                   qBase: qBase,
                   length: m,
                   lastByte: lastByte
               ) {
                if matches.count >= maxMatches {
                    return .degradedOrTimedOut(.matchLimitExceeded(maxMatches: maxMatches))
                }
                matches.append(TextRange(location: utf16Offset, length: m))
                index += m
                utf16Offset += m
            } else {
                let step = docSearchUTF8Step(forLeadByte: b)
                utf16Offset += step.utf16
                index += step.bytes
            }
        }
        return .completed(matches)
    }

    static func docSearchMatchesCaseSensitiveSlice(
        at index: Int,
        textBase: UnsafePointer<UInt8>,
        qBase: UnsafePointer<UInt8>,
        length m: Int,
        lastByte: UInt8
    ) -> Bool {
        if m == 1 { return true }
        guard textBase[index + m - 1] == lastByte else { return false }
        if m == 2 { return true }
        return memcmp(textBase.advanced(by: index + 1), qBase.advanced(by: 1), m - 2) == 0
    }
}
