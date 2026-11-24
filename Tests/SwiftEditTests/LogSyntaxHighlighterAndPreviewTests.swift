import Foundation
import Testing
@testable import SwiftEditCore

@Suite("LogSyntaxHighlighterAndPreviewTests")
struct LogSyntaxHighlighterAndPreviewTests {

    @Test("P8: LogSyntaxHighlighter, MarkdownPreviewProjector, and CursorMetricsCalculator stay within cyclomatic <= 15 and cognitive <= 25 while preserving outputs")
    func p8CoreScannerSubPassesPreserveSemanticsUnderComplexityCeiling() throws {
        // GIVEN a multi-token log line, a fenced + table + alert Markdown document, and live core scanner files
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let targetFiles = [
            "Sources/SwiftEditCore/LogSupport/LogSyntaxHighlighter.swift",
            "Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownPreviewProjector.swift",
            "Sources/SwiftEditCore/DocumentCore/CursorMetricsCalculator.swift",
            "Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLinterInlineSecurityPass.swift",
            "Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownAuthoringCommands.swift",
            "Sources/SwiftEditCore/MarkdownLintAndFormat/MarkdownLintAndFormatEngine.swift",
            "Sources/SwiftEditCore/DocumentCore/DocumentSession.swift",
        ]
        let sources: [(filePath: String, content: String)] = try targetFiles.map { rel in
            (rel, try String(contentsOf: repoRoot.appendingPathComponent(rel), encoding: .utf8))
        }

        let logSample = "2026-11-24T13:00:00Z [ERROR] [pid:42] GET https://example.com/api/v1 -> 500 requestId=deadbeef-1234-5678-9abc-def012345678 \"boom\" host=10.0.0.1 /var/log/app.log\n"
        let logIndex = MarkdownLineIndex(text: logSample)
        let logSpans = LogSyntaxHighlighter.spans(
            index: logIndex,
            visibleRange: TextRange(location: 0, length: logSample.utf16.count)
        )

        let mdSample = """
        ---
        title: Spec
        ---
        # Heading

        > [!NOTE]
        > Callout body

        | Col A | Col B |
        | :--- | ---: |
        | 1 | 2 |

        ```swift
        let x = 1
        ```
        """
        let session = DocumentSession(text: mdSample)
        let previewDoc = MarkdownPreviewProjector.project(snapshot: session.snapshot, showPreview: true, isMarkdownDocument: true)
        let metrics = try CursorMetricsCalculator.metrics(in: mdSample, caretLocation: 12)

        // WHEN checking complexity budgets across those 7 core files
        let violations = CodeModularityFitnessScanner.verifyMethodComplexityBudgets(
            sources: sources,
            maxCyclomatic: 15,
            maxCognitive: 25
        )

        // THEN all spans, preview blocks, and cursor metrics remain intact AND zero methods exceed 15 / 25
        #expect(!logSpans.isEmpty)
        #expect((previewDoc?.blocks.count ?? 0) >= 4)
        #expect(metrics.line >= 1)
        #expect(violations.isEmpty, "Core complexity violations:\n\(violations.map(\.description).joined(separator: "\n"))")
    }
}
