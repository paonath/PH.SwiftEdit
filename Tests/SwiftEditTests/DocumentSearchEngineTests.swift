import Foundation
import Testing
@testable import SwiftEditCore

@Suite("DocumentSearchEngineTests")
struct DocumentSearchEngineTests {

    @Test("P8: Literal find, replaceAll batch via applyTextEdits, and goToLine operate on UTF-16 ranges without mutating the snapshot")
    func p8FindReplaceAllAndGoToLineAcrossMixedLineBreaks() throws {
        // GIVEN a mutable DocumentSession and its immutable snapshot with mixed LF and CRLF breaks
        var session = DocumentSession(text: "Alpha beta\nalpha BETA\r\ngamma")
        let snapshot = session.snapshot

        // WHEN finding 'alpha' case-insensitively and case-sensitively, building a replaceAll batch, and jumping to line 3
        let insensitive = DocumentSearchEngine.find(query: "alpha", in: snapshot, options: SearchOptions(isCaseSensitive: false))
        let sensitive = DocumentSearchEngine.find(query: "alpha", in: snapshot, options: SearchOptions(isCaseSensitive: true))
        let editsOutcome = DocumentSearchEngine.replaceAll(
            query: "alpha",
            with: "omega",
            in: snapshot,
            options: SearchOptions(isCaseSensitive: false)
        )
        let edits = try #require(editsOutcome.completedValue)
        let event = try session.applyTextEdits(edits, expectedRevision: snapshot.revision)
        let lineThreeRange = DocumentSearchEngine.goToLine(3, in: snapshot)

        // THEN ranges match exact UTF-16 spans, snapshot stays unchanged, session advances once, and line 3 resolves to (23, 5)
        #expect(insensitive == .completed([TextRange(location: 0, length: 5), TextRange(location: 11, length: 5)]))
        #expect(sensitive == .completed([TextRange(location: 11, length: 5)]))
        #expect(snapshot.text == "Alpha beta\nalpha BETA\r\ngamma")
        #expect(session.text == "omega beta\nomega BETA\r\ngamma")
        #expect(event == .formatBatchApplied(session.id, BufferRevision(2), editCount: 2))
        #expect(lineThreeRange == TextRange(location: 23, length: 5))
    }

    @Test("N8: Empty search queries return empty results and out-of-range goToLine requests return nil")
    func n8EmptyQueryAndOutOfRangeLineNumbersAreInert() {
        // GIVEN a three-line snapshot
        let snapshot = DocumentSession(text: "one\ntwo\nthree").snapshot

        // WHEN searching/replacing with an empty query and resolving lines 0 and 4
        let findEmpty = DocumentSearchEngine.find(query: "", in: snapshot)
        let replaceEmpty = DocumentSearchEngine.replaceAll(query: "", with: "x", in: snapshot)
        let lineZero = DocumentSearchEngine.goToLine(0, in: snapshot)
        let lineFour = DocumentSearchEngine.goToLine(4, in: snapshot)

        // THEN find and replaceAll return empty collections and invalid line numbers return nil
        #expect(findEmpty == .completed([]))
        #expect(replaceEmpty == .completed([]))
        #expect(lineZero == nil)
        #expect(lineFour == nil)
    }

    @Test("N9 [Security]: Oversized query (>1024 UTF-16 units), match flood (>100,000), binary snapshot, and degraded snapshot fail closed")
    func n9SecurityOversizedQueryMatchFloodBinaryAndDegradedSnapshotsDegrade() {
        // GIVEN a 1025-unit query, a 100,001-match snapshot, a binary snapshot, and a degraded plain-text snapshot
        let normalSnapshot = DocumentSession(text: "alpha").snapshot
        let oversizedQuery = String(repeating: "a", count: 1025)
        let floodSnapshot = DocumentSession(text: String(repeating: "a", count: 100_001)).snapshot
        let binarySnapshot = DocumentSession(text: "alpha", isBinaryReadOnly: true).snapshot
        let degradedSnapshot = DocumentSession(text: "alpha", isDegradedPlainText: true).snapshot

        // WHEN executing find across each guarded boundary
        let oversizedOutcome = DocumentSearchEngine.find(query: oversizedQuery, in: normalSnapshot)
        let floodOutcome = DocumentSearchEngine.find(query: "a", in: floodSnapshot)
        let binaryOutcome = DocumentSearchEngine.find(query: "alpha", in: binarySnapshot)
        let degradedOutcome = DocumentSearchEngine.find(query: "alpha", in: degradedSnapshot)

        // THEN each call returns degradedOrTimedOut with its exact typed reason and zero ranges
        #expect(oversizedOutcome == .degradedOrTimedOut(.inputTooLarge(byteCount: 1025)))
        #expect(floodOutcome == .degradedOrTimedOut(.matchLimitExceeded(maxMatches: 100_000)))
        #expect(binaryOutcome == .degradedOrTimedOut(.binarySnapshot))
        #expect(degradedOutcome == .degradedOrTimedOut(.degradedPlainTextSnapshot))
    }
}
