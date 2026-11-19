import Foundation

/// Visual classification distinguishing inline backtick code spans from multiline fenced backtick blocks (`AR-004`).
public enum BacktickSpanKind: Equatable, Sendable {
    case inlineCode
    case fencedMultiline
}

/// Immutable UTF-16 range identifying an inline or multiline backtick-delimited code region (`AR-004`, `BC-006`).
public struct BacktickHighlightSpan: Equatable, Sendable {
    /// 0-based UTF-16 span covering the opening backticks, content, and closing backticks (or EOF for an unclosed fence).
    public let range: TextRange
    /// Whether the span represents an inline code span (`` `...` ``) or a multiline fenced block (`` ```...``` ``).
    public let kind: BacktickSpanKind

    public init(range: TextRange, kind: BacktickSpanKind) {
        self.range = range
        self.kind = kind
    }
}

/// Revision-tagged backtick highlight scan output for an immutable `DocumentSnapshot` (`AR-004`, `BC-006`).
public struct BacktickHighlightResult: Equatable, Sendable {
    public let documentID: DocumentID
    public let revision: BufferRevision
    /// Non-overlapping spans sorted in ascending UTF-16 offset order.
    public let spans: [BacktickHighlightSpan]

    public init(documentID: DocumentID, revision: BufferRevision, spans: [BacktickHighlightSpan]) {
        self.documentID = documentID
        self.revision = revision
        self.spans = spans
    }
}

/// Linear single-pass UTF-16 scanner detecting inline backtick spans (`` `...` ``) and multiline fenced code blocks (`` ```...``` ``) (`AR-004`, `BC-011`, `SEC-012`).
///
/// Security & complexity invariants (`CWE-400`, `BC-011`, `SEC-012`):
/// - Rejects `isBinaryReadOnly` snapshots immediately with `.degradedOrTimedOut(.binarySnapshot)`.
/// - Reuses `SearchDiffAndBracketEngine.firstOverlongLine` to abort any buffer containing a line exceeding `4096` UTF-16 code units with `.degradedOrTimedOut(.lineLengthExceeded)`.
/// - Runs strictly in linear $O(n)$ time without backtracking regular expressions.
public enum BacktickHighlightScanner {
    private static let backtickUnit: UInt16 = 0x60 // '`'
    private static let spaceUnit: UInt16 = 0x20
    private static let tabUnit: UInt16 = 0x09
    private static let lfUnit: UInt16 = 0x0A
    private static let crUnit: UInt16 = 0x0D

    /// Scans `snapshot` for multiline fenced backtick blocks and inline backtick code spans.
    /// - Parameter snapshot: Immutable document snapshot to analyze.
    /// - Returns: `.completed(BacktickHighlightResult)` or `.degradedOrTimedOut` when binary or line-length limits trigger.
    public static func scan(in snapshot: DocumentSnapshot) -> EngineEvaluationOutcome<BacktickHighlightResult> {
        if snapshot.isBinaryReadOnly {
            return .degradedOrTimedOut(.binarySnapshot)
        }
        if let overlong = SearchDiffAndBracketEngine.firstOverlongLine(
            in: snapshot.text,
            limit: SearchDiffAndBracketEngine.maxBracketScanLineUTF16Length
        ) {
            return .degradedOrTimedOut(.lineLengthExceeded(line: overlong.line, utf16Length: overlong.utf16Length))
        }

        let units = Array(snapshot.text.utf16)
        let spans = scanUnits(units)
        return .completed(BacktickHighlightResult(
            documentID: snapshot.id,
            revision: snapshot.revision,
            spans: spans
        ))
    }

    private struct BacktickRun {
        let offset: Int
        let length: Int
    }

    private static func scanUnits(_ units: [UInt16]) -> [BacktickHighlightSpan] {
        var spans: [BacktickHighlightSpan] = []
        var inlineRuns: [BacktickRun] = []

        var activeFenceStart: Int?
        var activeFenceLength = 0

        var lineStart = 0
        while lineStart < units.count {
            let (lineEnd, nextLineStart) = lineBounds(in: units, from: lineStart)

            if let fenceStart = activeFenceStart {
                if isClosingFence(in: units, lineStart: lineStart, lineEnd: lineEnd, minBackticks: activeFenceLength) {
                    spans.append(BacktickHighlightSpan(
                        range: TextRange(location: fenceStart, length: lineEnd - fenceStart),
                        kind: .fencedMultiline
                    ))
                    activeFenceStart = nil
                    activeFenceLength = 0
                }
            } else if let opener = openingFence(in: units, lineStart: lineStart, lineEnd: lineEnd) {
                if !inlineRuns.isEmpty {
                    spans.append(contentsOf: pairInlineRuns(inlineRuns))
                    inlineRuns.removeAll(keepingCapacity: true)
                }
                activeFenceStart = opener.tickOffset
                activeFenceLength = opener.tickCount
            } else {
                collectInlineRuns(in: units, from: lineStart, to: lineEnd, into: &inlineRuns)
            }

            lineStart = nextLineStart
        }

        if let fenceStart = activeFenceStart {
            spans.append(BacktickHighlightSpan(
                range: TextRange(location: fenceStart, length: units.count - fenceStart),
                kind: .fencedMultiline
            ))
        }
        if !inlineRuns.isEmpty {
            spans.append(contentsOf: pairInlineRuns(inlineRuns))
        }

        return spans.sorted { $0.range.location < $1.range.location }
    }

    private static func lineBounds(in units: [UInt16], from start: Int) -> (lineEnd: Int, nextLineStart: Int) {
        var idx = start
        while idx < units.count && units[idx] != lfUnit && units[idx] != crUnit {
            idx += 1
        }
        let lineEnd = idx
        if idx < units.count {
            if units[idx] == crUnit, idx + 1 < units.count, units[idx + 1] == lfUnit {
                idx += 2
            } else {
                idx += 1
            }
        }
        return (lineEnd, idx)
    }

    private static func openingFence(in units: [UInt16], lineStart: Int, lineEnd: Int) -> (tickOffset: Int, tickCount: Int)? {
        var idx = lineStart
        var leadingSpaces = 0
        while idx < lineEnd && units[idx] == spaceUnit && leadingSpaces < 3 {
            idx += 1
            leadingSpaces += 1
        }
        let tickStart = idx
        while idx < lineEnd && units[idx] == backtickUnit {
            idx += 1
        }
        let tickCount = idx - tickStart
        guard tickCount >= 3 else { return nil }
        // CommonMark info strings on backtick fences may not contain backticks.
        while idx < lineEnd {
            if units[idx] == backtickUnit {
                return nil
            }
            idx += 1
        }
        return (tickStart, tickCount)
    }

    private static func isClosingFence(in units: [UInt16], lineStart: Int, lineEnd: Int, minBackticks: Int) -> Bool {
        var idx = lineStart
        var leadingSpaces = 0
        while idx < lineEnd && units[idx] == spaceUnit && leadingSpaces < 3 {
            idx += 1
            leadingSpaces += 1
        }
        let tickStart = idx
        while idx < lineEnd && units[idx] == backtickUnit {
            idx += 1
        }
        guard idx - tickStart >= minBackticks else { return false }
        while idx < lineEnd {
            if units[idx] != spaceUnit && units[idx] != tabUnit {
                return false
            }
            idx += 1
        }
        return true
    }

    private static func collectInlineRuns(in units: [UInt16], from start: Int, to end: Int, into runs: inout [BacktickRun]) {
        var idx = start
        while idx < end {
            if units[idx] == backtickUnit {
                let runStart = idx
                while idx < end && units[idx] == backtickUnit {
                    idx += 1
                }
                runs.append(BacktickRun(offset: runStart, length: idx - runStart))
            } else {
                idx += 1
            }
        }
    }

    /// Pairs inline backtick runs in strictly linear $O(k)$ time using per-length position queues.
    private static func pairInlineRuns(_ runs: [BacktickRun]) -> [BacktickHighlightSpan] {
        var positionsByLength: [Int: [Int]] = [:]
        for (idx, run) in runs.enumerated() {
            positionsByLength[run.length, default: []].append(idx)
        }
        var cursorByLength: [Int: Int] = [:]
        var result: [BacktickHighlightSpan] = []

        var index = 0
        while index < runs.count {
            let opener = runs[index]
            let bucket = positionsByLength[opener.length] ?? []
            var cursor = cursorByLength[opener.length] ?? 0
            while cursor < bucket.count && bucket[cursor] <= index {
                cursor += 1
            }
            cursorByLength[opener.length] = cursor

            if cursor < bucket.count {
                let closerIndex = bucket[cursor]
                cursorByLength[opener.length] = cursor + 1
                let closer = runs[closerIndex]
                let spanLength = (closer.offset + closer.length) - opener.offset
                result.append(BacktickHighlightSpan(
                    range: TextRange(location: opener.offset, length: spanLength),
                    kind: .inlineCode
                ))
                index = closerIndex + 1
            } else {
                index += 1
            }
        }
        return result
    }
}
