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

        guard let rawOps = diffWithTrimmedAffixes(lhs: lhsLines, rhs: rhsLines, clock: clock) else {
            return .degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: diffDeadlineMilliseconds))
        }

        let (hunks, hasDifferences) = materializeDiffHunks(from: rawOps)

        return .completed(FileCompareDiffResult(
            lhsID: lhs.id,
            lhsRevision: lhs.revision,
            rhsID: rhs.id,
            rhsRevision: rhs.revision,
            hunks: hunks,
            hasDifferences: hasDifferences
        ))
    }

    private enum RawDiffOp {
        case unchanged(String)
        case removed(String)
        case inserted(String)
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

    private static func splitDiffLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return LineEnding.normalizeToLF(text).components(separatedBy: "\n")
    }

    private static func diffWithTrimmedAffixes(
        lhs: [String],
        rhs: [String],
        clock: any ElapsedTimeProviding
    ) -> [RawDiffOp]? {
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

        let midLhs = Array(lhs[prefixCount..<(lhs.count - suffixCount)])
        let midRhs = Array(rhs[prefixCount..<(rhs.count - suffixCount)])
        guard let midOps = myersShortestEditScript(lhs: midLhs, rhs: midRhs, clock: clock) else {
            return nil
        }

        var ops: [RawDiffOp] = []
        ops.reserveCapacity(prefixCount + midOps.count + suffixCount)

        for index in 0..<prefixCount {
            ops.append(.unchanged(lhs[index]))
        }
        ops.append(contentsOf: midOps)

        let suffixStart = lhs.count - suffixCount
        for index in suffixStart..<lhs.count {
            ops.append(.unchanged(lhs[index]))
        }

        return ops
    }

    private static func myersShortestEditScript(
        lhs: [String],
        rhs: [String],
        clock: any ElapsedTimeProviding
    ) -> [RawDiffOp]? {
        if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
            return nil
        }
        let n = lhs.count
        let m = rhs.count
        if n == 0 && m == 0 { return [] }
        if n == 0 { return rhs.map { .inserted($0) } }
        if m == 0 { return lhs.map { .removed($0) } }

        let maxD = n + m
        let offset = maxD
        var v = Array(repeating: 0, count: 2 * maxD + 1)
        var trace: [[Int]] = []

        outer: for d in 0...maxD {
            if clock.elapsedMilliseconds() > diffDeadlineMilliseconds {
                return nil
            }
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
                    x = v[offset + k + 1]
                } else {
                    x = v[offset + k - 1] + 1
                }
                var y = x - k
                while x < n && y < m && lhs[x] == rhs[y] {
                    x += 1
                    y += 1
                }
                v[offset + k] = x
                if x >= n && y >= m {
                    break outer
                }
            }
        }

        return backtrackMyersTrace(trace: trace, offset: offset, lhs: lhs, rhs: rhs)
    }

    private static func backtrackMyersTrace(
        trace: [[Int]],
        offset: Int,
        lhs: [String],
        rhs: [String]
    ) -> [RawDiffOp] {
        var reversedOps: [RawDiffOp] = []
        var x = lhs.count
        var y = rhs.count

        for d in (0..<trace.count).reversed() {
            if d == 0 {
                while x > 0 && y > 0 {
                    x -= 1
                    y -= 1
                    reversedOps.append(.unchanged(lhs[x]))
                }
                break
            }

            let vPrev = trace[d]
            let k = x - y
            let prevK: Int
            if k == -d || (k != d && vPrev[offset + k - 1] < vPrev[offset + k + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX = vPrev[offset + prevK]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                reversedOps.append(.unchanged(lhs[x]))
            }

            if x == prevX {
                y -= 1
                reversedOps.append(.inserted(rhs[y]))
            } else {
                x -= 1
                reversedOps.append(.removed(lhs[x]))
            }
        }

        return reversedOps.reversed()
    }

    private static func materializeDiffHunks(from ops: [RawDiffOp]) -> (hunks: [DiffHunk], hasDifferences: Bool) {
        var hunks: [DiffHunk] = []
        hunks.reserveCapacity(ops.count)
        var lhsLine = 1
        var rhsLine = 1
        var hasDifferences = false

        for op in ops {
            switch op {
            case .unchanged(let text):
                hunks.append(DiffHunk(kind: .unchanged, lineText: text, lhsLineNumber: lhsLine, rhsLineNumber: rhsLine))
                lhsLine += 1
                rhsLine += 1
            case .removed(let text):
                hasDifferences = true
                hunks.append(DiffHunk(kind: .removed, lineText: text, lhsLineNumber: lhsLine, rhsLineNumber: nil))
                lhsLine += 1
            case .inserted(let text):
                hasDifferences = true
                hunks.append(DiffHunk(kind: .inserted, lineText: text, lhsLineNumber: nil, rhsLineNumber: rhsLine))
                rhsLine += 1
            }
        }
        return (hunks, hasDifferences)
    }
}
