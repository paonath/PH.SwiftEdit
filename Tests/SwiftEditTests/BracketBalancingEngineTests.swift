import Foundation
import Testing
@testable import SwiftEditCore

@Suite("BracketBalancingEngineTests")
struct BracketBalancingEngineTests {

    @Test("P2: evaluateBrackets matches nested (), {}, and [] pairs and resolves activePair at or inside caret offset")
    func p2NestedBalancedBracketsAndActiveCaretResolution() throws {
        // GIVEN a snapshot with nested (), [], and {} delimiters
        let source = "func demo(a: [Int]) { return (a[0]) }"
        let session = DocumentSession(text: source)
        let snapshot = session.snapshot

        // WHEN evaluating brackets with caret on '{' (offset 20), on ']' (offset 17), and enclosed inside '[0]' (offset 32)
        let atBrace = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: snapshot, caretLocation: 20).completedValue)
        let atBracket = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: snapshot, caretLocation: 17).completedValue)
        let enclosed = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: snapshot, caretLocation: 32).completedValue)

        // THEN all five nested pairs are matched in order, unbalancedBrackets is empty, and activePair matches each caret context
        let expectedPairs = [
            BracketPairSpan(openOffset: 9, closeOffset: 18, openSymbol: "(", closeSymbol: ")"),
            BracketPairSpan(openOffset: 13, closeOffset: 17, openSymbol: "[", closeSymbol: "]"),
            BracketPairSpan(openOffset: 20, closeOffset: 36, openSymbol: "{", closeSymbol: "}"),
            BracketPairSpan(openOffset: 29, closeOffset: 34, openSymbol: "(", closeSymbol: ")"),
            BracketPairSpan(openOffset: 31, closeOffset: 33, openSymbol: "[", closeSymbol: "]"),
        ]
        #expect(atBrace.matchedPairs == expectedPairs)
        #expect(atBrace.unbalancedBrackets.isEmpty)
        #expect(atBrace.activePair == BracketPairSpan(openOffset: 20, closeOffset: 36, openSymbol: "{", closeSymbol: "}"))
        #expect(atBracket.activePair == BracketPairSpan(openOffset: 13, closeOffset: 17, openSymbol: "[", closeSymbol: "]"))
        #expect(enclosed.activePair == BracketPairSpan(openOffset: 31, closeOffset: 33, openSymbol: "[", closeSymbol: "]"))
    }

    @Test("N3: evaluateBrackets reports stray closing, mismatched, and unclosed brackets with exact UTF-16 offsets")
    func n3MismatchedAndUnclosedBracketsAreReportedInOrder() throws {
        // GIVEN snapshots containing stray '}', unclosed '({', and mismatched '(1 + 2]'
        let brokenSession = DocumentSession(text: "let broken = [(1 + 2)] } ({ unclosed")
        let mismatchedSession = DocumentSession(text: "(1 + 2]")

        // WHEN evaluating brackets
        let brokenResult = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: brokenSession.snapshot).completedValue)
        let mismatchedResult = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: mismatchedSession.snapshot).completedValue)

        // THEN valid inner pairs still match while unbalanced delimiters are reported in ascending UTF-16 offset order
        #expect(brokenResult.matchedPairs == [
            BracketPairSpan(openOffset: 13, closeOffset: 21, openSymbol: "[", closeSymbol: "]"),
            BracketPairSpan(openOffset: 14, closeOffset: 20, openSymbol: "(", closeSymbol: ")"),
        ])
        #expect(brokenResult.unbalancedBrackets == [
            UnbalancedBracket(offset: 23, symbol: "}"),
            UnbalancedBracket(offset: 25, symbol: "("),
            UnbalancedBracket(offset: 26, symbol: "{"),
        ])
        #expect(mismatchedResult.matchedPairs.isEmpty)
        #expect(mismatchedResult.unbalancedBrackets == [
            UnbalancedBracket(offset: 0, symbol: "("),
            UnbalancedBracket(offset: 6, symbol: "]"),
        ])
    }

    @Test("N4 [Security]: evaluateBrackets aborts on lines exceeding 4096 UTF-16 code units or binary read-only snapshots")
    func n4SecurityOverlongLineAndBinarySnapshotGuards() throws {
        // GIVEN an exact-limit 4096-unit line, an overlong 4097-unit line on line 2, and a binary read-only snapshot
        let exactLimitLine = String(repeating: "a", count: 4094) + "()"
        let exactSnapshot = DocumentSession(text: exactLimitLine).snapshot
        let overlongText = "let ok = (1)\n" + String(repeating: "(", count: 4097)
        let overlongSnapshot = DocumentSession(text: overlongText).snapshot
        let binarySnapshot = DocumentSession(text: "(binary)", isBinaryReadOnly: true).snapshot

        // WHEN evaluating brackets across all three snapshots
        let exactOutcome = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: exactSnapshot).completedValue)
        let overlongOutcome = SearchDiffAndBracketEngine.evaluateBrackets(in: overlongSnapshot)
        let binaryOutcome = SearchDiffAndBracketEngine.evaluateBrackets(in: binarySnapshot)

        // THEN 4096 succeeds while 4097 and binary snapshots fail closed with degradedOrTimedOut
        #expect(exactOutcome.matchedPairs == [BracketPairSpan(openOffset: 4094, closeOffset: 4095, openSymbol: "(", closeSymbol: ")")])
        #expect(overlongOutcome == .degradedOrTimedOut(.lineLengthExceeded(line: 2, utf16Length: 4097)))
        #expect(binaryOutcome == .degradedOrTimedOut(.binarySnapshot))
    }
}
