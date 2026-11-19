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

        let nsText = snapshot.text as NSString
        let totalLength = nsText.length
        let compareOptions: NSString.CompareOptions = options.isCaseSensitive ? [.literal] : [.caseInsensitive]
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

    /// Resolves a 1-based `lineNumber` (`1...lineCount`) to its UTF-16 line-content `TextRange` (excluding trailing line terminators), or `nil` when out of bounds or binary.
    public static func goToLine(_ lineNumber: Int, in snapshot: DocumentSnapshot) -> TextRange? {
        guard !snapshot.isBinaryReadOnly, lineNumber >= 1 else {
            return nil
        }
        let lineRanges = UTF16LineBreakScanner.lineContentRanges(in: snapshot.text)
        guard lineNumber <= lineRanges.count else {
            return nil
        }
        return lineRanges[lineNumber - 1]
    }
}
