import Foundation

/// Case-sensitivity configuration for literal document search and replace (`BC-004`, `BC-011`).
public struct SearchOptions: Equatable, Sendable {
    public let isCaseSensitive: Bool

    public init(isCaseSensitive: Bool = false) {
        self.isCaseSensitive = isCaseSensitive
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

        // Zero-bridging raw UTF-8 fast path for ASCII queries.
        if query.utf8.allSatisfy({ $0 < 0x80 }) {
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
        let compareOptions: NSString.CompareOptions = options.isCaseSensitive ? [.literal] : [.caseInsensitive, .literal]
        var searchRange = NSRange(location: 0, length: totalLength)
        var matches: [TextRange] = []

        while searchRange.length > 0 {
            let found = nsText.range(of: query, options: compareOptions, range: searchRange)
            guard found.location != NSNotFound && found.length > 0 else {
                break
            }
            if matches.count >= maxMatches {
                return .degradedOrTimedOut(.matchLimitExceeded(maxMatches: maxMatches))
            }
            matches.append(TextRange(location: found.location, length: found.length))
            let nextStart = found.location + found.length
            guard nextStart <= totalLength else {
                break
            }
            searchRange = NSRange(location: nextStart, length: totalLength - nextStart)
        }

        return .completed(matches)
    }

    /// Scans contiguous UTF-8 bytes directly for an ASCII query without `NSString` bridging.
    /// Returns `nil` in case-insensitive mode if the text contains non-ASCII bytes so Unicode case folding falls back to `NSString`.
    private static func findASCIIUTF8(
        query: String,
        in text: String,
        isCaseSensitive: Bool,
        maxMatches: Int
    ) -> EngineEvaluationOutcome<[TextRange]>? {
        text.utf8.withContiguousStorageIfAvailable { textBuf -> EngineEvaluationOutcome<[TextRange]>? in
            let n = textBuf.count
            guard let textBase = textBuf.baseAddress else { return .completed([]) }
            let qBytes = Array(query.utf8)
            let m = qBytes.count
            guard m > 0 && m <= n else { return .completed([]) }

            if !isCaseSensitive {
                var qLower = qBytes
                for idx in 0..<m {
                    let b = qLower[idx]
                    if b >= 0x41 && b <= 0x5A { qLower[idx] = b | 0x20 }
                }
                let firstLower = qLower[0]
                let firstUpper: UInt8 = (firstLower >= 0x61 && firstLower <= 0x7A) ? (firstLower & ~0x20) : firstLower
                let lastLower = qLower[m - 1]
                let lastUpper: UInt8 = (lastLower >= 0x61 && lastLower <= 0x7A) ? (lastLower & ~0x20) : lastLower

                var matches: [TextRange] = []
                matches.reserveCapacity(min(32, maxMatches))
                let limit = n - m
                var i = 0
                while i <= limit {
                    let b = textBase[i]
                    if b >= 0x80 { return nil }
                    if b == firstLower || b == firstUpper {
                        let tail = textBase[i + m - 1]
                        if tail >= 0x80 { return nil }
                        if m == 1 || tail == lastLower || tail == lastUpper {
                            var matched = true
                            var j = 1
                            let innerEnd = m - 1
                            while j < innerEnd {
                                var tb = textBase[i + j]
                                if tb >= 0x80 { return nil }
                                if tb >= 0x41 && tb <= 0x5A { tb |= 0x20 }
                                if tb != qLower[j] {
                                    matched = false
                                    break
                                }
                                j += 1
                            }
                            if matched {
                                if matches.count >= maxMatches {
                                    return .degradedOrTimedOut(.matchLimitExceeded(maxMatches: maxMatches))
                                }
                                matches.append(TextRange(location: i, length: m))
                                i += m
                                continue
                            }
                        }
                    }
                    i += 1
                }
                while i < n {
                    if textBase[i] >= 0x80 { return nil }
                    i += 1
                }
                return .completed(matches)
            } else {
                // Case-sensitive ASCII query: works on ANY UTF-8 buffer (ASCII or Unicode) because ASCII bytes never occur inside multi-byte sequences.
                let firstByte = qBytes[0]
                let lastByte = qBytes[m - 1]
                var matches: [TextRange] = []
                matches.reserveCapacity(min(32, maxMatches))
                let limit = n - m
                var i = 0
                var utf16Offset = 0

                return qBytes.withUnsafeBufferPointer { qBuf in
                    guard let qBase = qBuf.baseAddress else { return .completed([]) }
                    while i <= limit {
                        let b = textBase[i]
                        if b == firstByte {
                            let matched: Bool
                            if m == 1 {
                                matched = true
                            } else if textBase[i + m - 1] != lastByte {
                                matched = false
                            } else if m == 2 {
                                matched = true
                            } else {
                                matched = memcmp(textBase.advanced(by: i + 1), qBase.advanced(by: 1), m - 2) == 0
                            }
                            if matched {
                                if matches.count >= maxMatches {
                                    return .degradedOrTimedOut(.matchLimitExceeded(maxMatches: maxMatches))
                                }
                                matches.append(TextRange(location: utf16Offset, length: m))
                                i += m
                                utf16Offset += m
                                continue
                            }
                            utf16Offset += 1
                            i += 1
                        } else if b < 0x80 {
                            utf16Offset += 1
                            i += 1
                        } else if b < 0xE0 {
                            utf16Offset += 1
                            i += 2
                        } else if b < 0xF0 {
                            utf16Offset += 1
                            i += 3
                        } else {
                            utf16Offset += 2
                            i += 4
                        }
                    }
                    return .completed(matches)
                }
            }
        } ?? nil
    }

    private static func precheck(query: String, snapshot: DocumentSnapshot) -> DegradedEvaluationReason? {
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
