import Foundation
import Testing
@testable import SwiftEditCore

@Suite("NestedBracketAndBacktickEngineTests")
struct NestedBracketAndBacktickEngineTests {

    @Test("P1: BracketMatcher computes 0-based nestingDepth and enclosingPairs on nested {} [] () and BacktickHighlightScanner detects inline and multiline backtick spans")
    func p1NestedBracketsDepthAndInlinePlusFencedBackticks() throws {
        // GIVEN a snapshot with mixed nested brackets and both inline and multiline fenced backticks
        let nestedExpr = "scrivo{ho le graffe, le quadre[dentro le quadre ho le tonde(qua) e (pure qua)]}"
        let fullText = "\(nestedExpr)\nInline `token` and ``nested `tick` `` end.\n```swift\nlet x = 1\n```"
        let snapshot = DocumentSession(text: fullText).snapshot
        let caretInsideQua = (fullText as NSString).range(of: "(qua)").location + 1

        // WHEN evaluating brackets and scanning backticks
        let brackets = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: snapshot, caretLocation: caretInsideQua).completedValue)
        let backticks = try #require(BacktickHighlightScanner.scan(in: snapshot).completedValue)

        // THEN depths match 0 for {}, 1 for [], 2 for both (), enclosingPairs lists outer-to-inner, and backtick spans cover inline and fenced blocks
        #expect(brackets.unbalancedBrackets.isEmpty)
        #expect(brackets.matchedPairs.map(\.openSymbol) == ["{", "[", "(", "("])
        #expect(brackets.matchedPairs.map(\.nestingDepth) == [0, 1, 2, 2])
        #expect(brackets.enclosingPairs.map(\.openSymbol) == ["{", "[", "("])
        #expect(brackets.enclosingPairs.map(\.nestingDepth) == [0, 1, 2])
        #expect(brackets.activePair?.openSymbol == "(")
        #expect(brackets.activePair?.nestingDepth == 2)

        try #require(backticks.spans.count == 3)
        #expect(backticks.spans.map(\.kind) == [.inlineCode, .inlineCode, .fencedMultiline])
        let nsText = fullText as NSString
        #expect(nsText.substring(with: NSRange(location: backticks.spans[0].range.location, length: backticks.spans[0].range.length)) == "`token`")
        #expect(nsText.substring(with: NSRange(location: backticks.spans[1].range.location, length: backticks.spans[1].range.length)) == "``nested `tick` ``")
        #expect(nsText.substring(with: NSRange(location: backticks.spans[2].range.location, length: backticks.spans[2].range.length)) == "```swift\nlet x = 1\n```")
    }

    @Test("N1: Unclosed inline backticks, unclosed triple-backtick fences, and mismatched nested brackets report deterministically without crashing")
    func n1UnclosedBackticksAndUnbalancedNestedBrackets() throws {
        // GIVEN snapshots with unclosed inline backtick, unclosed multiline fence, and mismatched brackets
        let orphanInline = DocumentSession(text: "text `orphan without close").snapshot
        let unclosedFence = DocumentSession(text: "header\n```swift\nlet a = 1").snapshot
        let mismatchedBrackets = DocumentSession(text: "{ [ ) }").snapshot

        // WHEN scanning backticks and evaluating brackets
        let orphanResult = try #require(BacktickHighlightScanner.scan(in: orphanInline).completedValue)
        let fenceResult = try #require(BacktickHighlightScanner.scan(in: unclosedFence).completedValue)
        let bracketResult = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: mismatchedBrackets).completedValue)

        // THEN orphan inline emits no span, unclosed fence terminates cleanly at buffer end, and mismatched brackets report exact offsets
        #expect(orphanResult.spans.isEmpty)
        #expect(fenceResult.spans.count == 1)
        #expect(fenceResult.spans[0].kind == .fencedMultiline)
        #expect(fenceResult.spans[0].range == TextRange(location: 7, length: (unclosedFence.text as NSString).length - 7))
        #expect(bracketResult.unbalancedBrackets.isEmpty == false)
        #expect(bracketResult.unbalancedBrackets.map(\.symbol) == ["{", "[", ")", "}"])
    }

    @Test("N2 [Security]: Overlong lines exceeding 4096 UTF-16 code units or binary read-only snapshots degrade safely in both scanners")
    func n2SecurityOverlongLineAndBinarySnapshotGuards() {
        // GIVEN an overlong 4097-unit line and a binary read-only snapshot
        let overlongSnapshot = DocumentSession(text: "ok\n" + String(repeating: "`", count: 4097)).snapshot
        let binarySnapshot = DocumentSession(text: "```swift\n{}\n```", isBinaryReadOnly: true).snapshot

        // WHEN scanning backticks and evaluating brackets
        let overlongBackticks = BacktickHighlightScanner.scan(in: overlongSnapshot)
        let binaryBackticks = BacktickHighlightScanner.scan(in: binarySnapshot)
        let overlongBrackets = SearchDiffAndBracketEngine.evaluateBrackets(in: overlongSnapshot)
        let binaryBrackets = SearchDiffAndBracketEngine.evaluateBrackets(in: binarySnapshot)

        // THEN all four calls fail closed with degradedOrTimedOut
        #expect(overlongBackticks == .degradedOrTimedOut(.lineLengthExceeded(line: 2, utf16Length: 4097)))
        #expect(binaryBackticks == .degradedOrTimedOut(.binarySnapshot))
        #expect(overlongBrackets == .degradedOrTimedOut(.lineLengthExceeded(line: 2, utf16Length: 4097)))
        #expect(binaryBrackets == .degradedOrTimedOut(.binarySnapshot))
    }
}
