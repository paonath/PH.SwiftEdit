import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TextKit2EditorDecompositionTests")
struct TextKit2EditorDecompositionTests {

    private static let viewsDir: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/SwiftEditUI/Views")

    @Test("P4: Decomposed TextKit 2 editor files stay <= 800 lines and TextKit2ViewportHighlightApplier clamps and intersects visible UTF-16 ranges")
    func p4DecomposedEditorFilesStayWithinBudgetAndViewportApplierIntersectsRanges() throws {
        // GIVEN the decomposed TextKit 2 editor files under Sources/SwiftEditUI/Views/
        let expectedFiles = [
            "TextKit2EditorView.swift",
            "SwiftEditNSTextViewAndUndoRegistry.swift",
            "EditorRenderingAttributes.swift",
            "TextKit2ViewportHighlightApplier.swift",
            "TextKit2EditorCoordinator.swift",
            "TextKit2EditorCoordinator+GhostCompletionAndCommands.swift",
        ]

        // WHEN checking file existence, line counts, and viewport range intersection helper
        for fileName in expectedFiles {
            let fileURL = Self.viewsDir.appendingPathComponent(fileName)
            #expect(FileManager.default.fileExists(atPath: fileURL.path), "Missing decomposed editor file \(fileName)")
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lineCount = source.components(separatedBy: "\n").count
            #expect(lineCount <= 800, "\(fileName) has \(lineCount) lines (> 800)")
        }

        // THEN visible viewport intersection returns true for overlapping spans and clamps cleanly
        let visible = NSRange(location: 100, length: 50)
        #expect(TextKit2ViewportHighlightApplier.intersectsVisible(location: 120, length: 10, visibleRange: visible) == true)
        #expect(TextKit2ViewportHighlightApplier.clampedRange(location: 95, length: 20, storageLength: 105) == NSRange(location: 95, length: 10))
    }

    @Test("P4 & N5: TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded applies highlights once and skips unchanged signature")
    @MainActor
    func p4n5ViewportHighlightApplierUpdatesSignatureAndSkipsUnchangedPass() {
        // GIVEN a TextKit 2 SwiftEditNSTextView with buffer text and a Coordinator
        let textContentStorage = NSTextContentStorage()
        let textLayoutManager = NSTextLayoutManager()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 600, height: 400))
        textLayoutManager.textContainer = textContainer
        let textView = SwiftEditNSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: textContainer)
        textView.string = "func demo() { return (1 + 2) }"

        let coordinator = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { _ in .notApplicable }
        )
        let palette = PurpleThemePalette.resolve(appearance: .black, systemPrefersDark: true)
        let projection = EditorHighlightProjection(
            activeLineRange: SwiftEditCore.TextRange(location: 0, length: 30),
            bracketPairs: [BracketPairSpan(openOffset: 9, closeOffset: 10, openSymbol: "(", closeSymbol: ")", nestingDepth: 0)]
        )
        let docID = DocumentID()
        let rev = BufferRevision(1)

        // WHEN applying highlights the first time (P4) and then repeating with identical inputs (N5)
        let firstApplied = TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded(
            to: textView,
            coordinator: coordinator,
            documentID: docID,
            bufferRevision: rev,
            palette: palette,
            fontSizePoints: 14,
            highlightProjection: projection,
            lintDiagnostics: [],
            force: false
        )
        let secondApplied = TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded(
            to: textView,
            coordinator: coordinator,
            documentID: docID,
            bufferRevision: rev,
            palette: palette,
            fontSizePoints: 14,
            highlightProjection: projection,
            lintDiagnostics: [],
            force: false
        )

        // THEN P4 applies and records the signature, while N5 returns false without redundant work
        #expect(firstApplied == true)
        #expect(coordinator.lastHighlightSnapshot != nil)
        #expect(secondApplied == false)
    }

    @Test("N5: Out-of-viewport ranges and invalid lengths return false or nil without mutating storage")
    func n5OutOfViewportAndInvalidRangesAreRejected() {
        // GIVEN a visible UTF-16 viewport range [100, 150)
        let visible = NSRange(location: 100, length: 50)

        // WHEN testing disjoint spans and out-of-bounds/zero lengths
        let beforeViewport = TextKit2ViewportHighlightApplier.intersectsVisible(location: 10, length: 20, visibleRange: visible)
        let afterViewport = TextKit2ViewportHighlightApplier.intersectsVisible(location: 150, length: 10, visibleRange: visible)
        let zeroLength = TextKit2ViewportHighlightApplier.clampedRange(location: 10, length: 0, storageLength: 200)
        let pastEnd = TextKit2ViewportHighlightApplier.clampedRange(location: 250, length: 5, storageLength: 200)

        // THEN non-intersecting and invalid spans are rejected
        #expect(beforeViewport == false)
        #expect(afterViewport == false)
        #expect(zeroLength == nil)
        #expect(pastEnd == nil)
    }

    @Test("P4: EditorRenderingAttributeTable, PurpleThemePalette, SwiftEditNSTextView, TextKit2EditorView (<= 20) and ZoomedChromeMetrics (<= 18) satisfy flattened nominal budgets")
    @MainActor
    func p4EditorViewsThemeAndMetricsSatisfyFlattenedNominalMemberBudgets() throws {
        // GIVEN the 6 editor/theme Swift files under Sources/SwiftEditUI/
        let uiRoot = Self.viewsDir.deletingLastPathComponent()
        let coordinatorSource = try String(contentsOf: Self.viewsDir.appendingPathComponent("TextKit2EditorCoordinator.swift"), encoding: .utf8)
        let attrTableSource = try String(contentsOf: Self.viewsDir.appendingPathComponent("EditorRenderingAttributes.swift"), encoding: .utf8)
        let textViewSource = try String(contentsOf: Self.viewsDir.appendingPathComponent("SwiftEditNSTextViewAndUndoRegistry.swift"), encoding: .utf8)
        let editorViewSource = try String(contentsOf: Self.viewsDir.appendingPathComponent("TextKit2EditorView.swift"), encoding: .utf8)
        let themeSource = try String(contentsOf: uiRoot.appendingPathComponent("Theme/PurpleThemeAndZoom.swift"), encoding: .utf8)
        let metricsSource = try String(contentsOf: uiRoot.appendingPathComponent("Theme/ZoomedChromeMetrics.swift"), encoding: .utf8)

        let budget25 = CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 25)
        let budget20 = CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 20)
        let budget18 = CodeModularityBudgets(maxFileLines: 800, maxNominalBlockLines: 400, maxNominalMembers: 18)

        // WHEN scanning each file against its tightened nominal member ceiling
        let coordinatorViolations = CodeModularityFitnessScanner.scanSource(content: coordinatorSource, filePath: "TextKit2EditorCoordinator.swift", budgets: budget25)
        let attrViolations = CodeModularityFitnessScanner.scanSource(content: attrTableSource, filePath: "EditorRenderingAttributes.swift", budgets: budget20)
        let textViewViolations = CodeModularityFitnessScanner.scanSource(content: textViewSource, filePath: "SwiftEditNSTextViewAndUndoRegistry.swift", budgets: budget20)
        let editorViewViolations = CodeModularityFitnessScanner.scanSource(content: editorViewSource, filePath: "TextKit2EditorView.swift", budgets: budget20)
        let themeViolations = CodeModularityFitnessScanner.scanSource(content: themeSource, filePath: "PurpleThemeAndZoom.swift", budgets: budget20)
        let metricsViolations = CodeModularityFitnessScanner.scanSource(content: metricsSource, filePath: "ZoomedChromeMetrics.swift", budgets: budget18)

        let palette = PurpleThemePalette.resolve(appearance: .light, systemPrefersDark: false)
        let metrics = ZoomedChromeMetrics(zoomPercent: 125)

        // THEN all editor/theme nominal blocks satisfy their <=18..20 budgets and preserve token and zoom accessors
        #expect(coordinatorViolations.isEmpty, "Expected <= 25 members in TextKit2EditorCoordinator, got: \(coordinatorViolations)")
        #expect(attrViolations.isEmpty, "Expected <= 20 members in EditorRenderingAttributes, got: \(attrViolations)")
        #expect(textViewViolations.isEmpty, "Expected <= 20 members in SwiftEditNSTextView, got: \(textViewViolations)")
        #expect(editorViewViolations.isEmpty, "Expected <= 20 members in TextKit2EditorView, got: \(editorViewViolations)")
        #expect(themeViolations.isEmpty, "Expected <= 20 members in PurpleThemePalette, got: \(themeViolations)")
        #expect(metricsViolations.isEmpty, "Expected <= 18 members in ZoomedChromeMetrics, got: \(metricsViolations)")
        #expect(palette.mode == .light)
        #expect(palette.logErrorForeground != palette.editorCanvasBackground)
        #expect(palette.bidiWarningForeground != palette.bidiWarningBackground)
        #expect(metrics.scaledValues.count == 12)
    }
}
