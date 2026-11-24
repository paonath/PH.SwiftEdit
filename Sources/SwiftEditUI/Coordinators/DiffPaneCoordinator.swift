import Foundation
import Observation
import SwiftEditCore

/// Single aligned row for VS Code-style Side-by-Side File Compare views (`UI-007`).
public struct SideBySideDiffRow: Equatable, Sendable {
    public let lhsLineNumber: Int?
    public let lhsText: String?
    public let rhsLineNumber: Int?
    public let rhsText: String?
    public let kind: DiffHunkKind
    /// Left-hand pane semantic highlight kind (`BUG-020`: `.removed` for modified pairs).
    public let lhsKind: DiffHunkKind
    /// Right-hand pane semantic highlight kind (`BUG-020`: `.inserted` for modified pairs).
    public let rhsKind: DiffHunkKind

    public init(
        lhsLineNumber: Int?,
        lhsText: String?,
        rhsLineNumber: Int?,
        rhsText: String?,
        kind: DiffHunkKind,
        lhsKind: DiffHunkKind? = nil,
        rhsKind: DiffHunkKind? = nil
    ) {
        self.lhsLineNumber = lhsLineNumber
        self.lhsText = lhsText
        self.rhsLineNumber = rhsLineNumber
        self.rhsText = rhsText
        self.kind = kind
        self.lhsKind = lhsKind ?? ((kind == .inserted && lhsText != nil && rhsText != nil) ? .removed : kind)
        self.rhsKind = rhsKind ?? kind
    }
}

/// `@MainActor @Observable` coordinator projecting Myers `DiffHunk` sequences into Side-by-Side comparison rows (`UI-005`, `UI-007`, `REQ-009`).
@MainActor
@Observable
public final class DiffPaneCoordinator {
    public private(set) var rows: [SideBySideDiffRow] = []
    public private(set) var hasDifferences: Bool = false
    public private(set) var degradedReason: DegradedEvaluationReason?
    @ObservationIgnored private var lastComparedKey: (lhsID: DocumentID, lhsRev: BufferRevision, rhsID: DocumentID, rhsRev: BufferRevision)?

    public init() {}

    /// Evaluates `SearchDiffAndBracketEngine.computeMyersDiff` (with revision-pair memoization) and aligns adjacent `.removed`/`.inserted` pairs into Side-by-Side rows.
    public func compare(lhs: DocumentSnapshot, rhs: DocumentSnapshot) {
        if let last = lastComparedKey,
           last.lhsID == lhs.id, last.lhsRev == lhs.revision,
           last.rhsID == rhs.id, last.rhsRev == rhs.revision {
            return
        }
        switch SearchDiffAndBracketEngine.computeMyersDiff(lhs: lhs, rhs: rhs) {
        case .completed(let result):
            degradedReason = nil
            hasDifferences = result.hasDifferences
            rows = Self.alignSideBySideRows(from: result.hunks)
        case .degradedOrTimedOut(let reason):
            degradedReason = reason
            hasDifferences = false
            rows = []
        }
        lastComparedKey = (lhs.id, lhs.revision, rhs.id, rhs.revision)
    }

    /// Releases computed diff rows and error state when closing the diff pane or closing tabs (`MEM-003`).
    public func clear() {
        lastComparedKey = nil
        rows = []
        hasDifferences = false
        degradedReason = nil
    }

    private static func alignSideBySideRows(from hunks: [DiffHunk]) -> [SideBySideDiffRow] {
        var aligned: [SideBySideDiffRow] = []
        aligned.reserveCapacity(hunks.count)
        var index = 0
        while index < hunks.count {
            index = appendAlignedRow(from: hunks, at: index, into: &aligned)
        }
        return aligned
    }

    private static func appendAlignedRow(
        from hunks: [DiffHunk],
        at index: Int,
        into aligned: inout [SideBySideDiffRow]
    ) -> Int {
        let current = hunks[index]
        switch current.kind {
        case .unchanged:
            aligned.append(SideBySideDiffRow(
                lhsLineNumber: current.lhsLineNumber, lhsText: current.lineText,
                rhsLineNumber: current.rhsLineNumber, rhsText: current.lineText, kind: .unchanged
            ))
            return index + 1
        case .removed:
            if index + 1 < hunks.count, hunks[index + 1].kind == .inserted {
                let next = hunks[index + 1]
                aligned.append(SideBySideDiffRow(
                    lhsLineNumber: current.lhsLineNumber, lhsText: current.lineText,
                    rhsLineNumber: next.rhsLineNumber, rhsText: next.lineText,
                    kind: .inserted, lhsKind: .removed, rhsKind: .inserted
                ))
                return index + 2
            }
            aligned.append(SideBySideDiffRow(
                lhsLineNumber: current.lhsLineNumber, lhsText: current.lineText,
                rhsLineNumber: nil, rhsText: nil, kind: .removed
            ))
            return index + 1
        case .inserted:
            aligned.append(SideBySideDiffRow(
                lhsLineNumber: nil, lhsText: nil,
                rhsLineNumber: current.rhsLineNumber, rhsText: current.lineText, kind: .inserted
            ))
            return index + 1
        }
    }
}
