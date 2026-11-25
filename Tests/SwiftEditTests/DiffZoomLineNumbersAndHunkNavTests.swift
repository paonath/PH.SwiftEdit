import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)
import AppKit

@Suite("Unit 3: Zoom-Scaled Diff View, Line Numbers & Hunk Navigation (REQ-005)")
struct DiffZoomLineNumbersAndHunkNavTests {

    @Test("P5: Diff metrics scale linearly across 50%..300%, preserve >=24pt targets, expose LHS/RHS line numbers, navigate hunks with F7/Shift+F7, and fold context in Only Differences mode")
    @MainActor
    func p5DiffZoomScalingLineNumbersHunkNavigationAndContextFolding() throws {
        let m50 = ZoomedChromeMetrics(zoomPercent: 50)
        let m100 = ZoomedChromeMetrics(zoomPercent: 100)
        let m200 = ZoomedChromeMetrics(zoomPercent: 200)
        let m300 = ZoomedChromeMetrics(zoomPercent: 300)

        #expect(m50.diffFontSize == m100.diffFontSize * 0.5)
        #expect(m200.diffFontSize == m100.diffFontSize * 2.0)
        #expect(m300.diffFontSize == m100.diffFontSize * 3.0)
        #expect(m200.diffHeaderFontSize == m100.diffHeaderFontSize * 2.0)
        #expect(m50.diffActionTarget >= 24)

        let lhsLines = (1...20).map { "line \($0)" }
        var rhsLines = lhsLines
        rhsLines[1] = "line 2 modified"
        rhsLines[17] = "line 18 modified"

        let lhs = DocumentSession(text: lhsLines.joined(separator: "\n")).snapshot
        let rhs = DocumentSession(text: rhsLines.joined(separator: "\n")).snapshot

        let coord = DiffPaneCoordinator()
        coord.compare(lhs: lhs, rhs: rhs)

        #expect(coord.rows.count == 20)
        #expect(coord.displayedRows.count == 20)
        #expect(coord.rows[1].lhsLineNumber == 2 && coord.rows[1].rhsLineNumber == 2)
        #expect(coord.hunkRowIndices == [1, 17])
        #expect(coord.activeHunkIndex == 0)
        #expect(coord.activeScrollRowIndex == 1)

        coord.selectNextHunk()
        #expect(coord.activeHunkIndex == 1)
        #expect(coord.activeScrollRowIndex == 17)

        // Wrap around forward & backward
        coord.selectNextHunk()
        #expect(coord.activeHunkIndex == 0)
        coord.selectPreviousHunk()
        #expect(coord.activeHunkIndex == 1)

        // Only Differences folds unchanged runs beyond ±2 context lines around each hunk
        coord.setOnlyDifferences(true)
        #expect(coord.displayedRows.count < 20)
        #expect(coord.displayedRows.contains { $0.rhsText == "line 2 modified" })
        #expect(coord.displayedRows.contains { $0.rhsText == "line 18 modified" })
        #expect(coord.displayedRows.contains { $0.lhsLineNumber == 10 } == false)
        #expect(coord.hunkRowIndices.count == 2)
    }

    @Test("N6: Identical and degraded comparisons keep hunkRowIndices empty and F7/Shift+F7 navigation is a safe no-op")
    @MainActor
    func n6IdenticalAndDegradedDiffSafeNoOp() throws {
        let sameA = DocumentSession(text: "alpha\nbeta\ngamma").snapshot
        let sameB = DocumentSession(text: "alpha\nbeta\ngamma").snapshot

        let coord = DiffPaneCoordinator()
        coord.compare(lhs: sameA, rhs: sameB)
        #expect(coord.hasDifferences == false)
        #expect(coord.hunkRowIndices.isEmpty)
        #expect(coord.activeHunkIndex == -1)
        #expect(coord.activeScrollRowIndex == nil)

        coord.selectNextHunk()
        coord.selectPreviousHunk()
        #expect(coord.activeHunkIndex == -1)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("diff-\(UUID().uuidString)")
        )
        model.newUntitledTab()
        model.toggleDiffPane()
        model.selectNextDiffHunk()
        model.selectPreviousDiffHunk()
        #expect(model.diffCoordinator.activeHunkIndex == -1)
        model.toggleDiffOnlyDifferences()
        #expect(model.diffCoordinator.onlyDifferences == true)
    }
}
#endif
