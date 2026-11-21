import Foundation
import Testing
@testable import SwiftEditCore

@Suite("MyersFileCompareDiffTests")
struct MyersFileCompareDiffTests {

    @Test("P3: computeMyersDiff produces minimal unchanged, removed, and inserted DiffHunk sequence with 1-based line numbers")
    func p3MyersLineDiffProducesMinimalHunksAndLineNumbers() throws {
        // GIVEN baseline and modified snapshots
        let lhs = DocumentSession(text: "alpha\nbeta\ngamma").snapshot
        let rhs = DocumentSession(revision: BufferRevision(3), text: "alpha\nbeta-updated\ngamma\ndelta").snapshot

        // WHEN computing Myers diff
        let result = try #require(SearchDiffAndBracketEngine.computeMyersDiff(lhs: lhs, rhs: rhs).completedValue)

        // THEN minimal shortest-edit-script hunks and 1-based line numbers are returned
        let expectedHunks = [
            DiffHunk(kind: .unchanged, lineText: "alpha", lhsLineNumber: 1, rhsLineNumber: 1),
            DiffHunk(kind: .removed, lineText: "beta", lhsLineNumber: 2, rhsLineNumber: nil),
            DiffHunk(kind: .inserted, lineText: "beta-updated", lhsLineNumber: nil, rhsLineNumber: 2),
            DiffHunk(kind: .unchanged, lineText: "gamma", lhsLineNumber: 3, rhsLineNumber: 3),
            DiffHunk(kind: .inserted, lineText: "delta", lhsLineNumber: nil, rhsLineNumber: 4),
        ]
        #expect(result.lhsID == lhs.id)
        #expect(result.lhsRevision == BufferRevision(1))
        #expect(result.rhsID == rhs.id)
        #expect(result.rhsRevision == BufferRevision(3))
        #expect(result.hasDifferences == true)
        #expect(result.hunks == expectedHunks)
    }

    @Test("N5: computeMyersDiff reports hasDifferences == false and unchanged hunks on identical snapshots and handles empty buffers")
    func n5IdenticalAndEmptySnapshotsProduceDeterministicResults() throws {
        // GIVEN identical non-empty snapshots and an empty vs single-line pair
        let identicalA = DocumentSession(text: "same\ncontent").snapshot
        let identicalB = DocumentSession(text: "same\ncontent").snapshot
        let emptySnapshot = DocumentSession(text: "").snapshot
        let singleLineSnapshot = DocumentSession(text: "only-rhs").snapshot

        // WHEN computing Myers diff
        let identicalResult = try #require(SearchDiffAndBracketEngine.computeMyersDiff(lhs: identicalA, rhs: identicalB).completedValue)
        let bothEmptyResult = try #require(SearchDiffAndBracketEngine.computeMyersDiff(lhs: emptySnapshot, rhs: emptySnapshot).completedValue)
        let fromEmptyResult = try #require(SearchDiffAndBracketEngine.computeMyersDiff(lhs: emptySnapshot, rhs: singleLineSnapshot).completedValue)

        // THEN identical snapshots report zero differences and empty-to-non-empty reports a single insertion
        #expect(identicalResult.hasDifferences == false)
        #expect(identicalResult.hunks == [
            DiffHunk(kind: .unchanged, lineText: "same", lhsLineNumber: 1, rhsLineNumber: 1),
            DiffHunk(kind: .unchanged, lineText: "content", lhsLineNumber: 2, rhsLineNumber: 2),
        ])
        #expect(bothEmptyResult.hasDifferences == false)
        #expect(bothEmptyResult.hunks.isEmpty)
        #expect(fromEmptyResult.hasDifferences == true)
        #expect(fromEmptyResult.hunks == [
            DiffHunk(kind: .inserted, lineText: "only-rhs", lhsLineNumber: nil, rhsLineNumber: 1),
        ])
    }

    @Test("N6 [Security]: computeMyersDiff aborts on > 10 MiB inputs, degraded/binary snapshots, or > 500 ms clock timeouts")
    func n6SecurityDiffSizeBinaryDegradedAndTimeoutGuards() {
        // GIVEN snapshots violating binary, degraded, 10 MiB UTF-8 byte ceiling, and 500 ms clock deadline constraints
        let normalA = DocumentSession(text: "line1\nline2\nline3").snapshot
        let normalB = DocumentSession(text: "diff1\ndiff2\ndiff3").snapshot
        let binarySnapshot = DocumentSession(text: "bin", isBinaryReadOnly: true).snapshot
        let degradedSnapshot = DocumentSession(text: "degraded", isDegradedPlainText: true).snapshot
        let overTenMiBCount = 10_485_761
        let oversizedSnapshot = DocumentSession(text: String(repeating: "a", count: overTenMiBCount)).snapshot
        let expiringClock = DeterministicClockFake(elapsedSequence: [0, 501])

        // WHEN evaluating Myers diff across each guarded condition
        let binaryOutcome = SearchDiffAndBracketEngine.computeMyersDiff(lhs: normalA, rhs: binarySnapshot)
        let degradedOutcome = SearchDiffAndBracketEngine.computeMyersDiff(lhs: degradedSnapshot, rhs: normalB)
        let oversizedOutcome = SearchDiffAndBracketEngine.computeMyersDiff(lhs: normalA, rhs: oversizedSnapshot)
        let timedOutOutcome = SearchDiffAndBracketEngine.computeMyersDiff(lhs: normalA, rhs: normalB, clock: expiringClock)

        // THEN all four abuse cases abort cleanly with degradedOrTimedOut
        #expect(binaryOutcome.degradedReason == .binarySnapshot)
        #expect(degradedOutcome.degradedReason == .degradedPlainTextSnapshot)
        #expect(oversizedOutcome.degradedReason == .inputTooLarge(byteCount: overTenMiBCount))
        #expect(timedOutOutcome.degradedReason == .deadlineExceeded(limitMilliseconds: 500))
    }
}
