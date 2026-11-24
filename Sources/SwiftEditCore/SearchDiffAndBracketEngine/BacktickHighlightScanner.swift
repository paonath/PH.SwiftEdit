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
    private static let backtickByte: UInt8 = 0x60 // '`'
    private static let spaceByte: UInt8 = 0x20
    private static let tabByte: UInt8 = 0x09
    private static let lfByte: UInt8 = 0x0A
    private static let crByte: UInt8 = 0x0D

    /// Scans `snapshot` for multiline fenced backtick blocks and inline backtick code spans in a single zero-copy UTF-8 pass.
    /// - Parameter snapshot: Immutable document snapshot to analyze.
    /// - Returns: `.completed(BacktickHighlightResult)` or `.degradedOrTimedOut` when binary or line-length limits trigger.
    public static func scan(in snapshot: DocumentSnapshot) -> EngineEvaluationOutcome<BacktickHighlightResult> {
        if snapshot.isBinaryReadOnly {
            return .degradedOrTimedOut(.binarySnapshot)
        }

        let limit = SearchDiffAndBracketEngine.maxBracketScanLineUTF16Length
        var contiguous = snapshot.text
        contiguous.makeContiguousUTF8()

        let outcome: EngineEvaluationOutcome<[BacktickHighlightSpan]> = contiguous.utf8.withContiguousStorageIfAvailable { buf in
            scanUTF8(buf, limit: limit)
        }!

        switch outcome {
        case .completed(let spans):
            return .completed(BacktickHighlightResult(
                documentID: snapshot.id,
                revision: snapshot.revision,
                spans: spans
            ))
        case .degradedOrTimedOut(let reason):
            return .degradedOrTimedOut(reason)
        }
    }

    fileprivate struct BacktickRun {
        let offset: Int
        let length: Int
    }
}

private extension BacktickHighlightScanner {
    struct BacktickScanState {
        var spans: [BacktickHighlightSpan] = []
        var inlineRuns: [BacktickRun] = []
        var activeFenceStart: Int?
        var activeFenceLength = 0
        var lineNumber = 1
        var bytePos = 0
        var utf16Pos = 0
    }

    struct BacktickScannedLine {
        let byteStart: Int
        let byteEnd: Int
        let utf16Start: Int
        let utf16End: Int
        let hasBacktick: Bool
    }

    /// Single-pass UTF-8 scanner enforcing the UTF-16 line length ceiling while detecting fences and inline runs directly on contiguous bytes.
    static func scanUTF8(
        _ buf: UnsafeBufferPointer<UInt8>,
        limit: Int
    ) -> EngineEvaluationOutcome<[BacktickHighlightSpan]> {
        let count = buf.count
        guard let base = buf.baseAddress, count > 0 else {
            return .completed([])
        }

        var state = BacktickScanState()
        while state.bytePos < count {
            let line = backtickScanLineContent(
                base: base,
                count: count,
                bytePos: &state.bytePos,
                utf16Pos: &state.utf16Pos
            )
            let lineUTF16Length = line.utf16End - line.utf16Start
            if lineUTF16Length > limit {
                return .degradedOrTimedOut(.lineLengthExceeded(line: state.lineNumber, utf16Length: lineUTF16Length))
            }
            backtickConsumeLineTerminator(
                base: base,
                count: count,
                bytePos: &state.bytePos,
                utf16Pos: &state.utf16Pos
            )
            state.lineNumber += 1

            if line.hasBacktick {
                backtickProcessLineWithBackticks(base: base, line: line, state: &state)
            }
        }

        backtickFinalizeScanState(&state)
        return .completed(state.spans)
    }

    @inline(__always)
    static func backtickUTF8Step(forLeadByte lead: UInt8) -> (bytes: Int, utf16: Int) {
        if lead < 0x80 { return (1, 1) }
        if lead < 0xE0 { return (2, 1) }
        if lead < 0xF0 { return (3, 1) }
        return (4, 2)
    }

    static func backtickScanLineContent(
        base: UnsafePointer<UInt8>,
        count: Int,
        bytePos: inout Int,
        utf16Pos: inout Int
    ) -> BacktickScannedLine {
        let lineByteStart = bytePos
        let lineUTF16Start = utf16Pos
        var hasBacktick = false

        while bytePos < count {
            let b = base[bytePos]
            if b == lfByte || b == crByte {
                break
            }
            if b == backtickByte {
                hasBacktick = true
            }
            let step = backtickUTF8Step(forLeadByte: b)
            utf16Pos += step.utf16
            bytePos += step.bytes
        }

        return BacktickScannedLine(
            byteStart: lineByteStart,
            byteEnd: bytePos,
            utf16Start: lineUTF16Start,
            utf16End: utf16Pos,
            hasBacktick: hasBacktick
        )
    }

    static func backtickConsumeLineTerminator(
        base: UnsafePointer<UInt8>,
        count: Int,
        bytePos: inout Int,
        utf16Pos: inout Int
    ) {
        guard bytePos < count else { return }
        let step = (base[bytePos] == crByte && bytePos + 1 < count && base[bytePos + 1] == lfByte) ? 2 : 1
        bytePos += step
        utf16Pos += step
    }

    static func backtickProcessLineWithBackticks(
        base: UnsafePointer<UInt8>,
        line: BacktickScannedLine,
        state: inout BacktickScanState
    ) {
        if let fenceStart = state.activeFenceStart {
            if isClosingFence(
                base: base,
                lineStart: line.byteStart,
                lineEnd: line.byteEnd,
                minBackticks: state.activeFenceLength
            ) {
                state.spans.append(BacktickHighlightSpan(
                    range: TextRange(location: fenceStart, length: line.utf16End - fenceStart),
                    kind: .fencedMultiline
                ))
                state.activeFenceStart = nil
                state.activeFenceLength = 0
            }
            return
        }

        if let opener = openingFence(
            base: base,
            lineStart: line.byteStart,
            lineEnd: line.byteEnd,
            lineUTF16Start: line.utf16Start
        ) {
            if !state.inlineRuns.isEmpty {
                state.spans.append(contentsOf: pairInlineRuns(state.inlineRuns))
                state.inlineRuns.removeAll(keepingCapacity: true)
            }
            state.activeFenceStart = opener.tickOffset
            state.activeFenceLength = opener.tickCount
            return
        }

        collectInlineRuns(
            base: base,
            lineStart: line.byteStart,
            lineEnd: line.byteEnd,
            lineUTF16Start: line.utf16Start,
            into: &state.inlineRuns
        )
    }

    static func backtickFinalizeScanState(_ state: inout BacktickScanState) {
        if let fenceStart = state.activeFenceStart {
            state.spans.append(BacktickHighlightSpan(
                range: TextRange(location: fenceStart, length: state.utf16Pos - fenceStart),
                kind: .fencedMultiline
            ))
        }
        if !state.inlineRuns.isEmpty {
            state.spans.append(contentsOf: pairInlineRuns(state.inlineRuns))
        }
    }

    static func openingFence(
        base: UnsafePointer<UInt8>,
        lineStart: Int,
        lineEnd: Int,
        lineUTF16Start: Int
    ) -> (tickOffset: Int, tickCount: Int)? {
        var idx = lineStart
        var leadingSpaces = 0
        while idx < lineEnd && base[idx] == spaceByte && leadingSpaces < 3 {
            idx += 1
            leadingSpaces += 1
        }
        let tickStart = idx
        while idx < lineEnd && base[idx] == backtickByte {
            idx += 1
        }
        let tickCount = idx - tickStart
        guard tickCount >= 3 else { return nil }
        while idx < lineEnd {
            if base[idx] == backtickByte {
                return nil
            }
            idx += 1
        }
        return (lineUTF16Start + leadingSpaces, tickCount)
    }

    static func isClosingFence(
        base: UnsafePointer<UInt8>,
        lineStart: Int,
        lineEnd: Int,
        minBackticks: Int
    ) -> Bool {
        var idx = lineStart
        var leadingSpaces = 0
        while idx < lineEnd && base[idx] == spaceByte && leadingSpaces < 3 {
            idx += 1
            leadingSpaces += 1
        }
        let tickStart = idx
        while idx < lineEnd && base[idx] == backtickByte {
            idx += 1
        }
        guard idx - tickStart >= minBackticks else { return false }
        while idx < lineEnd {
            let b = base[idx]
            if b != spaceByte && b != tabByte {
                return false
            }
            idx += 1
        }
        return true
    }

    static func collectInlineRuns(
        base: UnsafePointer<UInt8>,
        lineStart: Int,
        lineEnd: Int,
        lineUTF16Start: Int,
        into runs: inout [BacktickRun]
    ) {
        var idx = lineStart
        var utf16Offset = lineUTF16Start
        while idx < lineEnd {
            let b = base[idx]
            if b == backtickByte {
                let runUTF16Start = utf16Offset
                var runLen = 0
                while idx < lineEnd && base[idx] == backtickByte {
                    idx += 1
                    utf16Offset += 1
                    runLen += 1
                }
                runs.append(BacktickRun(offset: runUTF16Start, length: runLen))
            } else {
                let step = backtickUTF8Step(forLeadByte: b)
                utf16Offset += step.utf16
                idx += step.bytes
            }
        }
    }

    /// Pairs inline backtick runs in strictly linear $O(k)$ time using per-length position queues.
    static func pairInlineRuns(_ runs: [BacktickRun]) -> [BacktickHighlightSpan] {
        guard runs.count >= 2 else { return [] }
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
