import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

private extension GFMPreviewBlock {
    var isTableBlock: Bool {
        if case .table = self { return true }
        return false
    }

    var isInertScriptBlock: Bool {
        if case .inertHTML(let raw, _) = self { return raw.contains("<script>") }
        return false
    }
}

private extension ImageAdmission {
    var isAdmittedCase: Bool {
        if case .admitted = self { return true }
        return false
    }

    var isTooManyImagesBlocked: Bool {
        if case .blocked(.tooManyImages) = self { return true }
        return false
    }
}

@Suite("PreviewDiffLineEndingHardeningTests")
struct PreviewDiffLineEndingHardeningTests {

    @Test("P6: HTML block stops before adjacent GFM table, ordered lists number 1..N, CR Cmd+D emits zero raw CR, same-length lineIndex invalidates, and modified diff highlights LHS+RHS")
    @MainActor
    func p6PreviewHTMLTableOrderedListsCRAndModifiedDiff() throws {
        // GIVEN 1: HTML block immediately followed by GFM table (no blank line) and ordered list items
        let md = """
        <div>hello</div>
        | H1 | H2 |
        |---|---|
        | A | B |

        1. First item
        2. Second item
        """
        let doc = MarkdownPreviewProjector.project(snapshot: DocumentSession(text: md).snapshot, showPreview: true)
        let unwrappedDoc = try #require(doc)
        let hasTable = unwrappedDoc.blocks.contains(where: \.isTableBlock)
        let marker1 = MarkdownPreviewProjector.listMarkerText(ordered: true, taskChecked: nil, ordinal: MarkdownPreviewProjector.orderedOrdinal(at: unwrappedDoc.blocks.count - 2, in: unwrappedDoc.blocks))
        let marker2 = MarkdownPreviewProjector.listMarkerText(ordered: true, taskChecked: nil, ordinal: MarkdownPreviewProjector.orderedOrdinal(at: unwrappedDoc.blocks.count - 1, in: unwrappedDoc.blocks))

        // GIVEN 2: single-line Classic Mac CR session + Cmd+D + CR previewSourceLine
        var crSession = DocumentSession(text: "single", lineEnding: .cr)
        _ = try crSession.duplicateLineOrSelection(selection: TextRange(location: 2, length: 0))
        let encodedCR = try DocumentCodec.encode(crSession.text, encoding: .utf8, lineEnding: .cr)
        let crRecovery = FileManager.default.temporaryDirectory.appendingPathComponent("cr-model-rec-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: crRecovery) }
        let crModel = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: crRecovery,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        crModel.newUntitledTab()
        crModel.handleEditorTextChanged("one\rtwo\rthree")
        crModel.handleSelectionChanged(TextRange(location: 9, length: 0))

        // GIVEN 3: Coordinator cached lineIndex on same-length edit across revisions
        let docID = DocumentID()
        let coord = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { _ in .notApplicable }
        )
        let idx1 = coord.lineIndex(for: "# a\n**b**", documentID: docID, revision: BufferRevision(1))
        let idx2 = coord.lineIndex(for: "plain txt", documentID: docID, revision: BufferRevision(2))

        // GIVEN 4: Modified line diff alignment
        let diffCoord = DiffPaneCoordinator()
        diffCoord.compare(
            lhs: DocumentSession(text: "alpha\nbeta\ngamma").snapshot,
            rhs: DocumentSession(text: "alpha\nbeta-updated\ngamma").snapshot
        )
        let modifiedRow = try #require(diffCoord.rows.first { $0.lhsText == "beta" && $0.rhsText == "beta-updated" })

        // THEN all five defects (BUG-014..016, BUG-019, BUG-020) resolve cleanly
        #expect(hasTable == true)
        #expect(marker1 == "1.")
        #expect(marker2 == "2.")
        #expect(!crSession.text.contains("\r"))
        #expect(crSession.text == "single\nsingle")
        #expect(encodedCR == Data("single\rsingle".utf8))
        #expect(crModel.previewSourceLine == 3)
        #expect(idx1.lineStarts != idx2.lineStarts || idx1.fences.count != idx2.fences.count || MarkdownSyntaxHighlighter.spans(index: idx2, visibleRange: TextRange(location: 0, length: 9)).isEmpty)
        #expect(MarkdownSyntaxHighlighter.spans(index: idx1, visibleRange: TextRange(location: 0, length: 9)).isEmpty == false)
        #expect(MarkdownSyntaxHighlighter.spans(index: idx2, visibleRange: TextRange(location: 0, length: 9)).isEmpty == true)
        #expect(modifiedRow.lhsKind == .removed)
        #expect(modifiedRow.rhsKind == .inserted)
    }

    @Test("N9 [Security]: Document with 70 valid images across 70 separate paragraphs enforces aggregate 64-image cap (CWE-400) and script before table stays inert")
    func n9DocumentWide64ImageCapAndInertScriptBeforeTable() throws {
        // GIVEN 70 separate image paragraphs and an in-memory filesystem hosting a valid 1x1 PNG
        let scope = URL(fileURLWithPath: "/tmp/ws-cap")
        let docDir = scope
        let fs = InMemoryFileSystemFake()
        let pngData = Self.make1x1PNGData()
        let imgURL = scope.appendingPathComponent("pic.png")
        fs.seed(url: imgURL, data: pngData)

        let gate = PreviewResourceAndLinkGate(fileSystem: fs, scopeRoot: scope, documentDirectory: docDir)
        let md70 = (1...70).map { "Paragraph \($0) ![img\($0)](pic.png)" }.joined(separator: "\n\n")
        let preview70 = try #require(MarkdownPreviewProjector.project(snapshot: DocumentSession(text: md70).snapshot, showPreview: true))

        // WHEN allocating document-wide image indices across all 70 blocks
        let perBlockAdmittedIndices = MarkdownPreviewProjector.documentImageIndices(for: preview70.blocks)
        let outcomes = perBlockAdmittedIndices.flatMap { blockRefs in
            blockRefs.map { ref, docImgIndex in gate.admitImage(reference: ref, admittedCount: docImgIndex) }
        }
        let admittedTotal = outcomes.filter(\.isAdmittedCase).count
        let tooManyTotal = outcomes.filter(\.isTooManyImagesBlocked).count

        let scriptThenTable = "<script>alert(1)</script>\n| H |\n|---|\n| V |"
        let scriptDoc = try #require(MarkdownPreviewProjector.project(snapshot: DocumentSession(text: scriptThenTable).snapshot, showPreview: true))
        let hasInertScript = scriptDoc.blocks.contains(where: \.isInertScriptBlock)
        let hasAdjacentTable = scriptDoc.blocks.contains(where: \.isTableBlock)

        // THEN exactly 64 images are admitted document-wide and 6 are blocked (.tooManyImages), while script+table stay cleanly separated
        #expect(outcomes.count == 70)
        #expect(admittedTotal == PreviewResourceAndLinkGate.maxImagesPerDocument)
        #expect(tooManyTotal == 6)
        #expect(hasInertScript == true)
        #expect(hasAdjacentTable == true)
    }

    @Test("N7: DocumentSession.applyEdit on LineEnding.cr normalizes mixed CRLF and CR insertions without raw CR artifacts")
    func n7MixedRawCarriageReturnInjectionNormalizesSafelyInApplyEdit() throws {
        // GIVEN a single-line Classic Mac CR session with normalized in-memory text
        var crSession = DocumentSession(text: "alpha", lineEnding: .cr)

        // WHEN applying a programmatic edit containing mixed CRLF and lone CR separators and computing cursor metrics
        let editEvent = try crSession.applyEdit(replacing: TextRange(location: 5, length: 0), with: "\r\nbeta\rgamma")
        let metrics = try CursorMetricsCalculator.metrics(in: crSession.text, caretLocation: crSession.text.utf16.count)
        let encodedCR = try DocumentCodec.encode(crSession.text, encoding: .utf8, lineEnding: crSession.lineEnding)

        // THEN in-memory text contains zero raw CR bytes, CursorMetricsCalculator counts all 3 lines, and CR serialization remains intact
        #expect(!crSession.text.contains("\r"))
        #expect(crSession.text == "alpha\nbeta\ngamma")
        #expect(editEvent == .textEdited(crSession.id, BufferRevision(2), TextRange(location: 5, length: 11)))
        #expect(metrics.line == 3)
        #expect(metrics.column == 6)
        #expect(encodedCR == Data("alpha\rbeta\rgamma".utf8))
    }

    private static func make1x1PNGData() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }
}
