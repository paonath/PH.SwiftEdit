import Foundation
import Testing
@testable import SwiftEditCore

final class DeterministicClockFake: ElapsedTimeProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Int]
    private var index: Int = 0

    init(elapsedSequence: [Int]) {
        self.values = elapsedSequence
    }

    func elapsedMilliseconds() -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard !values.isEmpty else { return 0 }
        let current = values[min(index, values.count - 1)]
        index += 1
        return current
    }
}

@Suite("MarkdownLintAndFormatTests")
struct MarkdownLintAndFormatTests {

    @Test("P1: MarkdownLintAndFormatEngine.lint detects missingHeadingSpace, emptyLinkTarget, and unbalancedFencedCodeBlock via swift-markdown AST")
    func p1LintDetectsMalformedHeadingsEmptyLinksAndUnclosedCodeFences() throws {
        // GIVEN a Markdown snapshot with #Heading, empty [](), and an unclosed ``` fence
        let markdown = """
        #HeadingWithoutSpace
        Visit []() now.
        ```swift
        let x = 1
        """
        let session = DocumentSession(text: markdown)

        // WHEN executing AST + structural linting
        let outcome = MarkdownLintAndFormatEngine.lint(snapshot: session.snapshot)

        // THEN all three lint rules are reported with exact 1-based line numbers
        let expected = [
            MarkdownLintDiagnostic(rule: .missingHeadingSpace, line: 1, message: "ATX heading requires a space after '#' markers"),
            MarkdownLintDiagnostic(rule: .emptyLinkTarget, line: 2, message: "Markdown link or image has an empty destination"),
            MarkdownLintDiagnostic(rule: .unbalancedFencedCodeBlock, line: 3, message: "Opening code fence is not closed"),
        ]
        #expect(outcome == .completed(MarkdownLintResult(
            documentID: session.id,
            revision: session.revision,
            diagnostics: expected
        )))
    }

    @Test("P1: formatDocument normalizes headings, list markers, and trailing spaces while preserving fenced code blocks and applies in 1 BufferRevision step")
    func p1FormatDocumentPreservesCodeFencesAndAppliesSingleRevisionBatch() throws {
        // GIVEN a Markdown session with malformed heading/list spacing and an untouched fenced code block
        let raw = """
        #Title   
        *   First item  
        ```swift
        #NotAHeading   
        *   keepSpacing  
        ```
        """
        var session = DocumentSession(text: raw)
        let snap = session.snapshot

        // WHEN computing formatDocument edits and applying them atomically
        let outcome = MarkdownLintAndFormatEngine.formatDocument(snapshot: snap)
        let batch = try #require(outcome.completedValue)
        let event = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)

        // THEN outside lines are canonicalized, fenced code block body is preserved verbatim, and revision increments once to 2
        let expectedFormatted = """
        # Title
        - First item
        ```swift
        #NotAHeading   
        *   keepSpacing  
        ```
        """
        #expect(session.text == expectedFormatted)
        #expect(session.revision == BufferRevision(2))
        #expect(session.isDirty == true)
        #expect(event == .formatBatchApplied(session.id, BufferRevision(2), editCount: batch.edits.count))
    }

    @Test("P1: formatSection formats only lines intersecting the target TextRange and leaves surrounding lines untouched")
    func p1FormatSectionRestrictsEditsToSelectedSection() throws {
        // GIVEN a two-section Markdown document where only the second line is selected
        let raw = "#UntouchedTop\n*   SelectedItem  \n#UntouchedBottom"
        var session = DocumentSession(text: raw)
        let snap = session.snapshot
        let secondLineRange = SwiftEditCore.TextRange(location: 14, length: 18)

        // WHEN running formatSection on secondLineRange and applying the batch
        let outcome = try MarkdownLintAndFormatEngine.formatSection(snapshot: snap, range: secondLineRange)
        let batch = try #require(outcome.completedValue)
        _ = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)

        // THEN only the second line is formatted while line 1 and line 3 remain untouched
        #expect(session.text == "#UntouchedTop\n- SelectedItem\n#UntouchedBottom")
        #expect(session.revision == BufferRevision(2))
    }

    @Test("N1: applyTextEdits rejects stale BufferRevision and overlapping or out-of-bounds TextEdit ranges without mutating session")
    func n1StaleRevisionAndInvalidEditBatchesAreRejectedWithoutMutation() {
        // GIVEN a DocumentSession at BufferRevision(2)
        var session = DocumentSession(revision: BufferRevision(2), text: "hello world")
        let staleEdit = [TextEdit(range: SwiftEditCore.TextRange(location: 0, length: 5), replacement: "HI")]
        let overlappingEdits = [
            TextEdit(range: SwiftEditCore.TextRange(location: 0, length: 5), replacement: "A"),
            TextEdit(range: SwiftEditCore.TextRange(location: 3, length: 4), replacement: "B"),
        ]

        // WHEN / THEN stale revision throws staleBufferRevision and overlapping ranges throw invalidTextRange
        #expect(throws: DomainError.staleBufferRevision(expected: BufferRevision(1), actual: BufferRevision(2))) {
            _ = try session.applyTextEdits(staleEdit, expectedRevision: BufferRevision(1))
        }
        #expect(throws: DomainError.invalidTextRange(SwiftEditCore.TextRange(location: 3, length: 4))) {
            _ = try session.applyTextEdits(overlappingEdits, expectedRevision: BufferRevision(2))
        }
        #expect(session.text == "hello world")
        #expect(session.revision == BufferRevision(2))
    }

    @Test("P1: Safe relative, fragment, https, http, and mailto Markdown links produce zero security diagnostics")
    func p1SafeRelativeAndHttpsLinksProduceZeroSecurityDiagnostics() throws {
        // GIVEN a Markdown snapshot with allowlisted relative, fragment, https, http, and mailto links
        let markdown = """
        [Docs](docs/design/color-schemes-and-zed-layout.md)
        [Section](#architecture)
        [Swift](https://swift.org)
        [HTTP](http://example.com)
        [Mail](mailto:security@example.com)
        """
        let session = DocumentSession(text: markdown)

        // WHEN evaluating lint
        let outcome = MarkdownLintAndFormatEngine.lint(snapshot: session.snapshot)
        let result = try #require(outcome.completedValue)

        // THEN zero diagnostics are emitted
        #expect(result.diagnostics.isEmpty)
    }

    @Test("N2 [Security]: javascript:, file:, and data: links emit unsafeLinkScheme diagnostics")
    func n2SecurityUnsafeLinkSchemesEmitDiagnostics() throws {
        // GIVEN a Markdown snapshot containing dangerous URI schemes in links and images
        let markdown = """
        [XSS](javascript:alert(1))
        [Local](file:///etc/passwd)
        ![Data](data:text/html;base64,PHNjcmlwdD4=)
        """
        let session = DocumentSession(text: markdown)

        // WHEN evaluating lint
        let outcome = MarkdownLintAndFormatEngine.lint(snapshot: session.snapshot)
        let result = try #require(outcome.completedValue)

        // THEN all three dangerous targets are flagged as unsafeLinkScheme
        #expect(result.diagnostics.map(\.rule) == [.unsafeLinkScheme, .unsafeLinkScheme, .unsafeLinkScheme])
        #expect(result.diagnostics.map(\.line) == [1, 2, 3])
    }

    @Test("N2 [Security]: AST depth > 128, degraded/binary snapshots, and > 250 ms clock budgets return degradedOrTimedOut")
    func n2SecurityComplexityDegradedBinaryAndClockTimeoutGuards() throws {
        // GIVEN snapshots violating depth, degraded, binary, and 250 ms budget constraints
        let deepMarkdown = String(repeating: "> ", count: 130) + "deep"
        let deepSnapshot = DocumentSession(text: deepMarkdown).snapshot
        let degradedSnapshot = DocumentSession(text: "# Title", isDegradedPlainText: true).snapshot
        var binarySession = DocumentSession(text: "# Binary", isBinaryReadOnly: true)
        let binarySnapshot = binarySession.snapshot
        let normalSnapshot = DocumentSession(text: "# Title\n\nParagraph").snapshot
        let expiredLintClock = DeterministicClockFake(elapsedSequence: [0, 251])
        let expiredFormatClock = DeterministicClockFake(elapsedSequence: [0, 251])

        // WHEN running lint, formatDocument, formatSection, and applyTextEdits
        let deepLint = MarkdownLintAndFormatEngine.lint(snapshot: deepSnapshot)
        let deepFormat = MarkdownLintAndFormatEngine.formatDocument(snapshot: deepSnapshot)
        let degradedLint = MarkdownLintAndFormatEngine.lint(snapshot: degradedSnapshot)
        let degradedSection = try MarkdownLintAndFormatEngine.formatSection(
            snapshot: degradedSnapshot,
            range: SwiftEditCore.TextRange(location: 0, length: 7)
        )
        let binaryLint = MarkdownLintAndFormatEngine.lint(snapshot: binarySnapshot)
        let binaryFormat = MarkdownLintAndFormatEngine.formatDocument(snapshot: binarySnapshot)
        let timedOutLint = MarkdownLintAndFormatEngine.lint(snapshot: normalSnapshot, clock: expiredLintClock)
        let timedOutFormat = MarkdownLintAndFormatEngine.formatDocument(snapshot: normalSnapshot, clock: expiredFormatClock)

        // THEN every complexity, quarantine, or deadline violation returns degradedOrTimedOut and binary edits throw
        #expect(deepLint == .degradedOrTimedOut(.astDepthExceeded(maxDepth: 128)))
        #expect(deepFormat == .degradedOrTimedOut(.astDepthExceeded(maxDepth: 128)))
        #expect(degradedLint == .degradedOrTimedOut(.degradedPlainTextSnapshot))
        #expect(degradedSection == .degradedOrTimedOut(.degradedPlainTextSnapshot))
        #expect(binaryLint == .degradedOrTimedOut(.binarySnapshot))
        #expect(binaryFormat == .degradedOrTimedOut(.binarySnapshot))
        #expect(timedOutLint == .degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: 250)))
        #expect(timedOutFormat == .degradedOrTimedOut(.deadlineExceeded(limitMilliseconds: 250)))
        #expect(throws: DomainError.binaryFileSaveForbidden) {
            _ = try binarySession.applyTextEdits([], expectedRevision: binarySnapshot.revision)
        }
    }
}
