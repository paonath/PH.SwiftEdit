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

    private enum CompactDiffOp {
        case unchanged(Int)
        case removed(Int)
        case inserted(Int)
    }

    private static func preflightDiffCheck(
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
    private static func splitDiffLines(_ text: String) -> [Substring] {
        guard !text.isEmpty else { return [] }
        let utf8 = text.utf8
        var lines: [Substring] = []
        lines.reserveCapacity(max(16, utf8.count / 40))
        var lineStart = utf8.startIndex
        var idx = lineStart
        while idx < utf8.endIndex {
            let b = utf8[idx]
            if b == 0x0A {
                lines.append(text[lineStart..<idx])
                idx = utf8.index(after: idx)
                lineStart = idx
            } else if b == 0x0D {
                lines.append(text[lineStart..<idx])
                let next = utf8.index(after: idx)
                if next < utf8.endIndex && utf8[next] == 0x0A {
                    idx = utf8.index(after: next)
                } else {
                    idx = next
                }
                lineStart = idx
            } else {
                idx = utf8.index(after: idx)
            }
        }
        lines.append(text[lineStart..<utf8.endIndex])
        return lines
    }

    private static func diffWithTrimmedAffixes(
        lhs: [Substring],
        rhs: [Substring],
        clock: any ElapsedTimeProviding
    ) -> (hunks: [DiffHunk], hasDifferences: Bool)? {
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

        let midLhsStart = prefixCount
        let midLhsEnd = lhs.count - suffixCount
        let midRhsStart = prefixCount
        let midRhsEnd = rhs.count - suffixCount
        let midN = midLhsEnd - midLhsStart
        let midM = midRhsEnd - midRhsStart

        let midOps: [CompactDiffOp]
        if midN == 0 && midM == 0 {
            if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
                return nil
            }
            midOps = []
        } else if midN == 0 {
            if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
                return nil
            }
            var ops: [CompactDiffOp] = []
            ops.reserveCapacity(midM)
            for j in 0..<midM { ops.append(.inserted(j)) }
            midOps = ops
        } else if midM == 0 {
            if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
                return nil
            }
            var ops: [CompactDiffOp] = []
            ops.reserveCapacity(midN)
            for i in 0..<midN { ops.append(.removed(i)) }
            midOps = ops
        } else {
            // Intern middle lines to dense Int IDs so Myers snake loops compare Int == Int with zero ARC / Unicode overhead.
            var internTable: [Substring: Int] = Dictionary(minimumCapacity: midN + midM)
            var nextID = 0
            var lhsIDs: [Int] = []
            lhsIDs.reserveCapacity(midN)
            for i in midLhsStart..<midLhsEnd {
                let line = lhs[i]
                if let existing = internTable[line] {
                    lhsIDs.append(existing)
                } else {
                    internTable[line] = nextID
                    lhsIDs.append(nextID)
                    nextID += 1
                }
            }
            var rhsIDs: [Int] = []
            rhsIDs.reserveCapacity(midM)
            for j in midRhsStart..<midRhsEnd {
                let line = rhs[j]
                if let existing = internTable[line] {
                    rhsIDs.append(existing)
                } else {
                    internTable[line] = nextID
                    rhsIDs.append(nextID)
                    nextID += 1
                }
            }
            guard let computed = myersShortestEditScript(lhsIDs: lhsIDs, rhsIDs: rhsIDs, clock: clock) else {
                return nil
            }
            midOps = computed
        }

        var hunks: [DiffHunk] = []
        hunks.reserveCapacity(prefixCount + midOps.count + suffixCount)
        var lhsLine = 1
        var rhsLine = 1
        var hasDifferences = false

        for index in 0..<prefixCount {
            hunks.append(DiffHunk(kind: .unchanged, lineText: String(lhs[index]), lhsLineNumber: lhsLine, rhsLineNumber: rhsLine))
            lhsLine += 1
            rhsLine += 1
        }
        for op in midOps {
            switch op {
            case .unchanged(let relIdx):
                hunks.append(DiffHunk(kind: .unchanged, lineText: String(lhs[midLhsStart + relIdx]), lhsLineNumber: lhsLine, rhsLineNumber: rhsLine))
                lhsLine += 1
                rhsLine += 1
            case .removed(let relIdx):
                hasDifferences = true
                hunks.append(DiffHunk(kind: .removed, lineText: String(lhs[midLhsStart + relIdx]), lhsLineNumber: lhsLine, rhsLineNumber: nil))
                lhsLine += 1
            case .inserted(let relIdx):
                hasDifferences = true
                hunks.append(DiffHunk(kind: .inserted, lineText: String(rhs[midRhsStart + relIdx]), lhsLineNumber: nil, rhsLineNumber: rhsLine))
                rhsLine += 1
            }
        }
        let suffixStart = lhs.count - suffixCount
        for index in suffixStart..<lhs.count {
            hunks.append(DiffHunk(kind: .unchanged, lineText: String(lhs[index]), lhsLineNumber: lhsLine, rhsLineNumber: rhsLine))
            lhsLine += 1
            rhsLine += 1
        }

        return (hunks, hasDifferences)
    }

    /// Runs Myers SES packing only the `d` active diagonals per step into a single flat triangular `[Int]` arena (`O(D²/2)` space, zero per-step CoW array copies).
    private static func myersShortestEditScript(
        lhsIDs: [Int],
        rhsIDs: [Int],
        clock: any ElapsedTimeProviding
    ) -> [CompactDiffOp]? {
        if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
            return nil
        }
        let n = lhsIDs.count
        let m = rhsIDs.count
        let maxD = n + m
        let offset = maxD
        var v = Array(repeating: 0, count: 2 * maxD + 1)
        // Flat triangular arena: step `d >= 1` stores the `d` live diagonals from step `d - 1`
        // at base index `d * (d - 1) / 2`, where diagonal `k` in `-(d-1)...(d-1)` sits at `base + (k + (d - 1)) >> 1`.
        var traceArena: [Int] = []
        traceArena.reserveCapacity(min(maxD * 8, 4096))
        var finalD = 0

        outer: for d in 0...maxD {
            if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
                return nil
            }
            if d > 0 {
                let prevLimit = d - 1
                var kPrev = -prevLimit
                while kPrev <= prevLimit {
                    traceArena.append(v[offset + kPrev])
                    kPrev += 2
                }
            }
            var k = -d
            while k <= d {
                var x: Int
                if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
                    x = v[offset + k + 1]
                } else {
                    x = v[offset + k - 1] + 1
                }
                var y = x - k
                while x < n && y < m && lhsIDs[x] == rhsIDs[y] {
                    x += 1
                    y += 1
                }
                v[offset + k] = x
                if x >= n && y >= m {
                    finalD = d
                    break outer
                }
                k += 2
            }
        }

        return backtrackMyersArena(traceArena: traceArena, finalD: finalD, n: n, m: m)
    }

    private static func backtrackMyersArena(
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
                while x > 0 && y > 0 {
                    x -= 1
                    y -= 1
                    ops.append(.unchanged(x))
                }
                break
            }

            let base = (d * (d - 1)) >> 1
            let prevLimit = d - 1
            let k = x - y
            let prevK: Int
            if k == -d {
                prevK = k + 1
            } else if k == d {
                prevK = k - 1
            } else {
                let leftVal = traceArena[base + ((k - 1 + prevLimit) >> 1)]
                let rightVal = traceArena[base + ((k + 1 + prevLimit) >> 1)]
                prevK = (leftVal < rightVal) ? (k + 1) : (k - 1)
            }

            let prevX = traceArena[base + ((prevK + prevLimit) >> 1)]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                ops.append(.unchanged(x))
            }

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
}
