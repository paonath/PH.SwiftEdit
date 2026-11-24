import Foundation

/// Line-level edit classification produced by `SearchDiffAndBracketEngine.computeMyersDiff` (`AR-012`, `BC-006`).
public enum DiffHunkKind: String, Codable, Equatable, Sendable {
    case unchanged
    case inserted
    case removed
}

/// Single line-level diff entry carrying 1-based line numbers for `lhs` and/or `rhs` (`AR-012`, `BC-006`).
public struct DiffHunk: Equatable, Sendable {
    public let kind: DiffHunkKind
    public let lineText: String
    public let lhsLineNumber: Int?
    public let rhsLineNumber: Int?

    public init(kind: DiffHunkKind, lineText: String, lhsLineNumber: Int?, rhsLineNumber: Int?) {
        self.kind = kind
        self.lineText = lineText
        self.lhsLineNumber = lhsLineNumber
        self.rhsLineNumber = rhsLineNumber
    }
}

/// Stateless two-snapshot File Compare diff output tagged with both `(DocumentID, BufferRevision)` pairs (`AR-012`, `BC-006`).
public struct FileCompareDiffResult: Equatable, Sendable {
    public let lhsID: DocumentID
    public let lhsRevision: BufferRevision
    public let rhsID: DocumentID
    public let rhsRevision: BufferRevision
    public let hunks: [DiffHunk]
    public let hasDifferences: Bool

    public init(
        lhsID: DocumentID,
        lhsRevision: BufferRevision,
        rhsID: DocumentID,
        rhsRevision: BufferRevision,
        hunks: [DiffHunk],
        hasDifferences: Bool
    ) {
        self.lhsID = lhsID
        self.lhsRevision = lhsRevision
        self.rhsID = rhsID
        self.rhsRevision = rhsRevision
        self.hunks = hunks
        self.hasDifferences = hasDifferences
    }
}

extension SearchDiffAndBracketEngine {
    /// Maximum UTF-8 byte length (`10 MiB` = `10_485_760` bytes) permitted per snapshot before Myers diff aborts (`BC-011`, `SEC-012`).
    public static let maxDiffUTF8Bytes: Int = 10 * 1024 * 1024
    /// Cooperative wall-clock deadline (`500 ms`) enforced across Myers edit-graph expansion (`AR-013`, `BC-011`, `SEC-012`).
    public static let diffDeadlineMilliseconds: Int = 500

    /// Computes a deterministic line-level Myers shortest-edit-script diff between `lhs` and `rhs` snapshots (`AR-012`, `AR-013`, `BC-006`, `BC-011`, `SEC-012`).
    ///
    /// Security & complexity invariants:
    /// - Rejects `isBinaryReadOnly` snapshots immediately with `.degradedOrTimedOut(.binarySnapshot)`.
    /// - Rejects `isDegradedPlainText` snapshots immediately with `.degradedOrTimedOut(.degradedPlainTextSnapshot)`.
    /// - Rejects any snapshot whose UTF-8 byte count exceeds `maxDiffUTF8Bytes` (`10 MiB`) with `.degradedOrTimedOut(.inputTooLarge)`.
    /// - Polls `clock.elapsedMilliseconds()` before splitting lines and on every Myers `d`-contour iteration, aborting with `.degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: 500))` when exceeded.
    public static func computeMyersDiff(
        lhs: DocumentSnapshot,
        rhs: DocumentSnapshot,
        clock: any ElapsedTimeProviding = ContinuousClockElapsedTimer()
    ) -> EngineEvaluationOutcome<FileCompareDiffResult> {
        if let rejected = preflightDiffCheck(lhs: lhs, rhs: rhs, clock: clock) {
            return .degradedOrTimedOut(rejected)
        }

        let lhsLines = splitDiffLines(lhs.text)
        let rhsLines = splitDiffLines(rhs.text)

        guard let hunksAndFlag = diffWithTrimmedAffixes(lhs: lhsLines, rhs: rhsLines, clock: clock) else {
            return .degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: diffDeadlineMilliseconds))
        }

        return .completed(FileCompareDiffResult(
            lhsID: lhs.id,
            lhsRevision: lhs.revision,
            rhsID: rhs.id,
            rhsRevision: rhs.revision,
            hunks: hunksAndFlag.hunks,
            hasDifferences: hunksAndFlag.hasDifferences
        ))
    }
}

private extension SearchDiffAndBracketEngine {
    enum CompactDiffOp {
        case unchanged(Int)
        case removed(Int)
        case inserted(Int)
    }

    struct TrimmedDiffBounds {
        let prefixCount: Int
        let suffixCount: Int
        let midLhsRange: Range<Int>
        let midRhsRange: Range<Int>
    }

    static func preflightDiffCheck(
        lhs: DocumentSnapshot,
        rhs: DocumentSnapshot,
        clock: any ElapsedTimeProviding
    ) -> DegradedEvaluationReason? {
        if lhs.isBinaryReadOnly || rhs.isBinaryReadOnly {
            return .binarySnapshot
        }
        if lhs.isDegradedPlainText || rhs.isDegradedPlainText {
            return .degradedPlainTextSnapshot
        }
        let lhsBytes = lhs.text.utf8.count
        if lhsBytes > maxDiffUTF8Bytes {
            return .inputTooLarge(byteCount: lhsBytes)
        }
        let rhsBytes = rhs.text.utf8.count
        if rhsBytes > maxDiffUTF8Bytes {
            return .inputTooLarge(byteCount: rhsBytes)
        }
        if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
            return .deadlineExceeded(limitMilliseconds: diffDeadlineMilliseconds)
        }
        return nil
    }

    /// Splits `text` into zero-copy `Substring` lines treating `\r\n`, `\n`, and bare `\r` as line breaks without normalizing/copying the buffer.
    static func splitDiffLines(_ text: String) -> [Substring] {
        guard !text.isEmpty else { return [] }
        let utf8 = text.utf8
        var lines: [Substring] = []
        lines.reserveCapacity(max(16, utf8.count / 40))
        var lineStart = utf8.startIndex
        var idx = lineStart
        while idx < utf8.endIndex {
            let b = utf8[idx]
            let next = utf8.index(after: idx)
            if b == 0x0A {
                lines.append(text[lineStart..<idx])
                idx = next
                lineStart = idx
            } else if b == 0x0D {
                lines.append(text[lineStart..<idx])
                let isCRLF = next < utf8.endIndex && utf8[next] == 0x0A
                idx = isCRLF ? utf8.index(after: next) : next
                lineStart = idx
            } else {
                idx = next
            }
        }
        lines.append(text[lineStart..<utf8.endIndex])
        return lines
    }

    static func diffWithTrimmedAffixes(
        lhs: [Substring],
        rhs: [Substring],
        clock: any ElapsedTimeProviding
    ) -> (hunks: [DiffHunk], hasDifferences: Bool)? {
        let bounds = myersTrimCommonAffixes(lhs: lhs, rhs: rhs)
        guard let midOps = myersComputeMiddleOps(
            lhs: lhs,
            midLhsRange: bounds.midLhsRange,
            rhs: rhs,
            midRhsRange: bounds.midRhsRange,
            clock: clock
        ) else {
            return nil
        }
        return myersMaterializeDiffHunks(lhs: lhs, rhs: rhs, bounds: bounds, midOps: midOps)
    }

    static func myersTrimCommonAffixes(lhs: [Substring], rhs: [Substring]) -> TrimmedDiffBounds {
        var prefixCount = 0
        let minCount = min(lhs.count, rhs.count)
        while prefixCount < minCount && lhs[prefixCount] == rhs[prefixCount] {
            prefixCount += 1
        }
        var suffixCount = 0
        while (prefixCount + suffixCount) < minCount
            && lhs[lhs.count - 1 - suffixCount] == rhs[rhs.count - 1 - suffixCount] {
            suffixCount += 1
        }
        return TrimmedDiffBounds(
            prefixCount: prefixCount,
            suffixCount: suffixCount,
            midLhsRange: prefixCount..<(lhs.count - suffixCount),
            midRhsRange: prefixCount..<(rhs.count - suffixCount)
        )
    }

    static func myersComputeMiddleOps(
        lhs: [Substring],
        midLhsRange: Range<Int>,
        rhs: [Substring],
        midRhsRange: Range<Int>,
        clock: any ElapsedTimeProviding
    ) -> [CompactDiffOp]? {
        guard clock.elapsedMilliseconds() <= diffDeadlineMilliseconds else { return nil }
        let midN = midLhsRange.count
        let midM = midRhsRange.count
        if midN == 0 && midM == 0 {
            return []
        }
        if midN == 0 {
            return (0..<midM).map { .inserted($0) }
        }
        if midM == 0 {
            return (0..<midN).map { .removed($0) }
        }

        var internTable: [Substring: Int] = Dictionary(minimumCapacity: midN + midM)
        var nextID = 0
        let lhsIDs = myersInternLines(lhs, range: midLhsRange, internTable: &internTable, nextID: &nextID)
        let rhsIDs = myersInternLines(rhs, range: midRhsRange, internTable: &internTable, nextID: &nextID)
        return myersShortestEditScript(lhsIDs: lhsIDs, rhsIDs: rhsIDs, clock: clock)
    }

    static func myersInternLines(
        _ lines: [Substring],
        range: Range<Int>,
        internTable: inout [Substring: Int],
        nextID: inout Int
    ) -> [Int] {
        var ids: [Int] = []
        ids.reserveCapacity(range.count)
        for index in range {
            let line = lines[index]
            if let existing = internTable[line] {
                ids.append(existing)
            } else {
                internTable[line] = nextID
                ids.append(nextID)
                nextID += 1
            }
        }
        return ids
    }

    static func myersMaterializeDiffHunks(
        lhs: [Substring],
        rhs: [Substring],
        bounds: TrimmedDiffBounds,
        midOps: [CompactDiffOp]
    ) -> (hunks: [DiffHunk], hasDifferences: Bool) {
        var hunks: [DiffHunk] = []
        hunks.reserveCapacity(bounds.prefixCount + midOps.count + bounds.suffixCount)
        var lhsLine = 1
        var rhsLine = 1
        var hasDifferences = false

        myersAppendUnchangedSlice(lhs, range: 0..<bounds.prefixCount, lhsLine: &lhsLine, rhsLine: &rhsLine, into: &hunks)
        for op in midOps {
            myersAppendMiddleOp(
                op,
                lhs: lhs,
                midLhsStart: bounds.midLhsRange.lowerBound,
                rhs: rhs,
                midRhsStart: bounds.midRhsRange.lowerBound,
                lhsLine: &lhsLine,
                rhsLine: &rhsLine,
                hasDifferences: &hasDifferences,
                into: &hunks
            )
        }
        myersAppendUnchangedSlice(
            lhs,
            range: (lhs.count - bounds.suffixCount)..<lhs.count,
            lhsLine: &lhsLine,
            rhsLine: &rhsLine,
            into: &hunks
        )
        return (hunks, hasDifferences)
    }

    static func myersAppendUnchangedSlice(
        _ lhs: [Substring],
        range: Range<Int>,
        lhsLine: inout Int,
        rhsLine: inout Int,
        into hunks: inout [DiffHunk]
    ) {
        for index in range {
            hunks.append(DiffHunk(
                kind: .unchanged,
                lineText: String(lhs[index]),
                lhsLineNumber: lhsLine,
                rhsLineNumber: rhsLine
            ))
            lhsLine += 1
            rhsLine += 1
        }
    }

    static func myersAppendMiddleOp(
        _ op: CompactDiffOp,
        lhs: [Substring],
        midLhsStart: Int,
        rhs: [Substring],
        midRhsStart: Int,
        lhsLine: inout Int,
        rhsLine: inout Int,
        hasDifferences: inout Bool,
        into hunks: inout [DiffHunk]
    ) {
        switch op {
        case .unchanged(let relIdx):
            hunks.append(DiffHunk(
                kind: .unchanged,
                lineText: String(lhs[midLhsStart + relIdx]),
                lhsLineNumber: lhsLine,
                rhsLineNumber: rhsLine
            ))
            lhsLine += 1
            rhsLine += 1
        case .removed(let relIdx):
            hasDifferences = true
            hunks.append(DiffHunk(
                kind: .removed,
                lineText: String(lhs[midLhsStart + relIdx]),
                lhsLineNumber: lhsLine,
                rhsLineNumber: nil
            ))
            lhsLine += 1
        case .inserted(let relIdx):
            hasDifferences = true
            hunks.append(DiffHunk(
                kind: .inserted,
                lineText: String(rhs[midRhsStart + relIdx]),
                lhsLineNumber: nil,
                rhsLineNumber: rhsLine
            ))
            rhsLine += 1
        }
    }
}

private extension SearchDiffAndBracketEngine {
    /// Runs Myers SES packing only the `d` active diagonals per step into a single flat triangular `[Int]` arena (`O(D²/2)` space, zero per-step CoW array copies).
    static func myersShortestEditScript(
        lhsIDs: [Int],
        rhsIDs: [Int],
        clock: any ElapsedTimeProviding
    ) -> [CompactDiffOp]? {
        guard clock.elapsedMilliseconds() <= diffDeadlineMilliseconds else { return nil }
        let n = lhsIDs.count
        let m = rhsIDs.count
        let maxD = n + m
        let offset = maxD
        var v = Array(repeating: 0, count: 2 * maxD + 1)
        var traceArena: [Int] = []
        traceArena.reserveCapacity(min(maxD * 8, 4096))
        var finalD = 0

        for d in 0...maxD {
            if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
                return nil
            }
            myersAppendPreviousContour(d: d, offset: offset, v: v, into: &traceArena)
            if myersAdvanceContour(d: d, offset: offset, lhsIDs: lhsIDs, rhsIDs: rhsIDs, v: &v) {
                finalD = d
                break
            }
        }

        return backtrackMyersArena(traceArena: traceArena, finalD: finalD, n: n, m: m)
    }

    static func myersAppendPreviousContour(
        d: Int,
        offset: Int,
        v: [Int],
        into traceArena: inout [Int]
    ) {
        guard d > 0 else { return }
        let prevLimit = d - 1
        var kPrev = -prevLimit
        while kPrev <= prevLimit {
            traceArena.append(v[offset + kPrev])
            kPrev += 2
        }
    }

    static func myersAdvanceContour(
        d: Int,
        offset: Int,
        lhsIDs: [Int],
        rhsIDs: [Int],
        v: inout [Int]
    ) -> Bool {
        let n = lhsIDs.count
        let m = rhsIDs.count
        var k = -d
        while k <= d {
            var x = myersInitialX(forDiagonal: k, d: d, offset: offset, v: v)
            var y = x - k
            while x < n && y < m && lhsIDs[x] == rhsIDs[y] {
                x += 1
                y += 1
            }
            v[offset + k] = x
            if x >= n && y >= m {
                return true
            }
            k += 2
        }
        return false
    }

    @inline(__always)
    static func myersInitialX(forDiagonal k: Int, d: Int, offset: Int, v: [Int]) -> Int {
        if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
            return v[offset + k + 1]
        }
        return v[offset + k - 1] + 1
    }

    static func backtrackMyersArena(
        traceArena: [Int],
        finalD: Int,
        n: Int,
        m: Int
    ) -> [CompactDiffOp] {
        var ops: [CompactDiffOp] = []
        ops.reserveCapacity(max(n, m) + finalD)
        var x = n
        var y = m

        for d in stride(from: finalD, through: 0, by: -1) {
            if d == 0 {
                myersUnwindSnake(toX: 0, toY: 0, x: &x, y: &y, into: &ops)
                break
            }
            let base = (d * (d - 1)) >> 1
            let prevLimit = d - 1
            let prevK = myersPreviousDiagonal(k: x - y, d: d, base: base, prevLimit: prevLimit, traceArena: traceArena)
            let prevX = traceArena[base + ((prevK + prevLimit) >> 1)]
            let prevY = prevX - prevK

            myersUnwindSnake(toX: prevX, toY: prevY, x: &x, y: &y, into: &ops)
            if x == prevX {
                y -= 1
                ops.append(.inserted(y))
            } else {
                x -= 1
                ops.append(.removed(x))
            }
        }

        ops.reverse()
        return ops
    }

    static func myersPreviousDiagonal(
        k: Int,
        d: Int,
        base: Int,
        prevLimit: Int,
        traceArena: [Int]
    ) -> Int {
        if k == -d { return k + 1 }
        if k == d { return k - 1 }
        let leftVal = traceArena[base + ((k - 1 + prevLimit) >> 1)]
        let rightVal = traceArena[base + ((k + 1 + prevLimit) >> 1)]
        return (leftVal < rightVal) ? (k + 1) : (k - 1)
    }

    static func myersUnwindSnake(
        toX targetX: Int,
        toY targetY: Int,
        x: inout Int,
        y: inout Int,
        into ops: inout [CompactDiffOp]
    ) {
        while x > targetX && y > targetY {
            x -= 1
            y -= 1
            ops.append(.unchanged(x))
        }
    }
}
