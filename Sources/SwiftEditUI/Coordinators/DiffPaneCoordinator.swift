import Foundation
import Observation
import SwiftEditCore

/// Single aligned row for VS Code-style Side-by-Side File Compare views (`UI-007`, `REQ-005`).
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

    /// `true` when either side represents an insertion, deletion, or modification (`REQ-005`).
    public var isChanged: Bool {
        lhsKind != .unchanged || rhsKind != .unchanged
    }

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

/// `@MainActor @Observable` coordinator projecting Myers `DiffHunk` sequences into Side-by-Side comparison rows, hunk cursors (`F7`/`Shift+F7`), and context-folded `Only Differences` views (`UI-005`, `UI-007`, `REQ-005`).
@MainActor
@Observable
public final class DiffPaneCoordinator {
    public static let foldedContextLines = 2

    public private(set) var rows: [SideBySideDiffRow] = []
    public private(set) var displayedRows: [SideBySideDiffRow] = []
    public private(set) var hunkRowIndices: [Int] = []
    public private(set) var activeHunkIndex: Int = -1
    public private(set) var onlyDifferences: Bool = false
    public private(set) var hasDifferences: Bool = false
    public private(set) var degradedReason: DegradedEvaluationReason?
    @ObservationIgnored private var lastComparedKey: (lhsID: DocumentID, lhsRev: BufferRevision, rhsID: DocumentID, rhsRev: BufferRevision)?

    public init() {}

    /// Target row index inside `displayedRows` for the active hunk cursor, or `nil` when no differences exist (`REQ-005`).
    public var activeScrollRowIndex: Int? {
        guard activeHunkIndex >= 0, activeHunkIndex < hunkRowIndices.count else { return nil }
        return hunkRowIndices[activeHunkIndex]
    }

    /// Updates `onlyDifferences` and recomputes `displayedRows` and `hunkRowIndices` (`REQ-005`).
    public func setOnlyDifferences(_ enabled: Bool) {
        guard onlyDifferences != enabled else { return }
        onlyDifferences = enabled
        rebuildDisplayedProjection()
    }

    /// Advances `activeHunkIndex` to the next contiguous difference hunk with wrap-around; safe no-op when empty (`REQ-005`, `N6`).
    public func selectNextHunk() {
        guard !hunkRowIndices.isEmpty else { return }
        activeHunkIndex = (max(0, activeHunkIndex) + 1) % hunkRowIndices.count
    }

    /// Moves `activeHunkIndex` to the previous contiguous difference hunk with wrap-around; safe no-op when empty (`REQ-005`, `N6`).
    public func selectPreviousHunk() {
        guard !hunkRowIndices.isEmpty else { return }
        let base = max(0, activeHunkIndex)
        activeHunkIndex = (base - 1 + hunkRowIndices.count) % hunkRowIndices.count
    }

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
        rebuildDisplayedProjection()
    }

    /// Releases computed diff rows and hunk cursor state when closing the diff pane or closing tabs (`MEM-003`).
    public func clear() {
        lastComparedKey = nil
        rows = []
        displayedRows = []
        hunkRowIndices = []
        activeHunkIndex = -1
        hasDifferences = false
        degradedReason = nil
    }

    private func rebuildDisplayedProjection() {
        if onlyDifferences {
            displayedRows = Self.filterRowsWithContext(rows, contextRadius: Self.foldedContextLines)
        } else {
            displayedRows = rows
        }
        hunkRowIndices = Self.computeHunkStartIndices(in: displayedRows)
        activeHunkIndex = hunkRowIndices.isEmpty ? -1 : 0
    }

    private static func filterRowsWithContext(_ source: [SideBySideDiffRow], contextRadius: Int) -> [SideBySideDiffRow] {
        guard !source.isEmpty else { return [] }
        var keep = Array(repeating: false, count: source.count)
        for idx in source.indices where source[idx].isChanged {
            let lo = max(0, idx - contextRadius)
            let hi = min(source.count - 1, idx + contextRadius)
            for k in lo...hi { keep[k] = true }
        }
        var out: [SideBySideDiffRow] = []
        for idx in source.indices where keep[idx] {
            out.append(source[idx])
        }
        return out
    }

    private static func computeHunkStartIndices(in targetRows: [SideBySideDiffRow]) -> [Int] {
        var starts: [Int] = []
        var inChangedRun = false
        for idx in targetRows.indices {
            if targetRows[idx].isChanged {
                if !inChangedRun {
                    starts.append(idx)
                    inChangedRun = true
                }
            } else {
                inChangedRun = false
            }
        }
        return starts
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
