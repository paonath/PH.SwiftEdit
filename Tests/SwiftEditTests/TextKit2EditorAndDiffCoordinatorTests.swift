import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("TextKit2EditorAndDiffCoordinatorTests")
struct TextKit2EditorAndDiffCoordinatorTests {

    @MainActor
    @Test("P2: WorkspaceEditorCoordinator and DiffPaneCoordinator coordinate scoped TextKit 2 transactions, Cmd+D, formatting, theme switches, Side-by-Side diffs, VoiceOver, and Reduce Motion")
    func p2MainActorTextKit2TransactionsCommandsThemeSwitchAndSideBySideDiff() {
        // GIVEN a @MainActor WorkspaceEditorCoordinator on a Markdown buffer and a DiffPaneCoordinator
        let initialSession = DocumentSession(text: "#Title\n(1 + 2)")
        let coordinator = WorkspaceEditorCoordinator(session: initialSession, title: "Readme.md", appearanceMode: .light)
        let diffCoordinator = DiffPaneCoordinator()

        let lhsSnap = DocumentSession(text: "alpha\nold").snapshot
        let rhsSnap = DocumentSession(text: "alpha\nnew\nextra").snapshot

        // WHEN formatting, duplicating line 2 via Cmd+D, switching to Black mode, highlighting viewport/caret, enabling Reduce Motion, and running Side-by-Side diff
        coordinator.formatDocument()
        coordinator.performCommandD(selection: SwiftEditCore.TextRange(location: 8, length: 0))
        coordinator.setAppearanceMode(.black)
        coordinator.updateCaretAndHighlightViewport(
            caretLocation: 8,
            viewportRange: SwiftEditCore.TextRange(location: 0, length: 7)
        )
        coordinator.setReduceMotionEnabled(true)
        diffCoordinator.compare(lhs: lhsSnap, rhs: rhsSnap)
        let a11y = coordinator.accessibilityDescriptor(activeTitle: "Readme.md")

        // THEN NSTextContentStorage holds the updated text via scoped transactions without extra reloads on theme switch, active bracket and diff rows resolve, and Reduce Motion / VoiceOver are exposed
        #expect(coordinator.activeSession.text == "# Title\n(1 + 2)\n(1 + 2)")
        #expect(coordinator.bufferAdapter.currentString == "# Title\n(1 + 2)\n(1 + 2)")
        #expect(coordinator.bufferAdapter.scopedTransactionCount >= 3)
        #expect(coordinator.bufferAdapter.lastHighlightedRange == SwiftEditCore.TextRange(location: 0, length: 7))
        #expect(coordinator.palette.mode == .black)
        #expect(coordinator.palette.editorCanvasBackground.hex == "#000000")
        #expect(coordinator.bufferReloadCount == 1)
        #expect(coordinator.activeBracketPair == BracketPairSpan(openOffset: 8, closeOffset: 14, openSymbol: "(", closeSymbol: ")"))
        #expect(coordinator.shouldAnimateTransitions == false)
        #expect(a11y.editorRoleLabel == "SwiftEdit TextKit 2 Editor")
        #expect(diffCoordinator.hasDifferences == true)
        #expect(diffCoordinator.rows == [
            SideBySideDiffRow(lhsLineNumber: 1, lhsText: "alpha", rhsLineNumber: 1, rhsText: "alpha", kind: .unchanged),
            SideBySideDiffRow(lhsLineNumber: 2, lhsText: "old", rhsLineNumber: 2, rhsText: "new", kind: .inserted),
            SideBySideDiffRow(lhsLineNumber: nil, lhsText: nil, rhsLineNumber: 3, rhsText: "extra", kind: .inserted),
        ])
    }

    @MainActor
    @Test("N3: Invoking Cmd+D or formatDocument on a binary read-only tab leaves buffer untouched and surfaces a non-destructive warning banner")
    func n3BinaryReadOnlyTabBlocksMutatingCommandsWithWarningBanner() {
        // GIVEN a WorkspaceEditorCoordinator inspecting a binary read-only DocumentSession
        let binarySession = DocumentSession(text: "89 50 4E 47", isBinaryReadOnly: true)
        let coordinator = WorkspaceEditorCoordinator(session: binarySession, title: "icon.png")

        // WHEN triggering Cmd+D and Format Document
        coordinator.performCommandD(selection: SwiftEditCore.TextRange(location: 0, length: 0))
        let afterCmdDBanner = coordinator.lastErrorBannerMessage
        coordinator.formatDocument()
        let a11y = coordinator.accessibilityDescriptor(activeTitle: "icon.png")

        // THEN buffer text and revision remain unchanged and non-destructive warnings + VoiceOver announcements are exposed
        #expect(coordinator.activeSession.text == "89 50 4E 47")
        #expect(coordinator.activeSession.revision == BufferRevision(1))
        #expect(afterCmdDBanner != nil)
        #expect(coordinator.lastErrorBannerMessage != nil)
        #expect(a11y.safetyWarningAnnouncement == "Read-only binary file inspection")
    }

    @MainActor
    @Test("N4 [Security]: projectMarkdownPreview classifies raw <script> and <iframe> HTML blocks as inert plain text while distinguishing fenced code blocks")
    func n4SecurityMarkdownPreviewRendersRawHTMLAsInertPlainText() {
        // GIVEN a Markdown snapshot containing a heading, paragraph, fenced HTML snippet, and raw <script>/<iframe> lines
        let markdown = """
        # Safe Heading
        Normal paragraph.
        ```html
        <script>insideCodeFence()</script>
        ```
        <script>alert(1)</script>
        <iframe src="https://evil.example"></iframe>
        """
        let session = DocumentSession(text: markdown)
        let coordinator = WorkspaceEditorCoordinator(session: session)

        // WHEN projecting native Markdown preview blocks
        let blocks = coordinator.projectMarkdownPreview(from: session.snapshot)

        // THEN fenced code remains .codeBlock while raw HTML tags are marked isInertPlainTextHTML == true as literal plain text
        #expect(blocks == [
            MarkdownPreviewBlock(kind: .heading, text: "Safe Heading", isInertPlainTextHTML: false),
            MarkdownPreviewBlock(kind: .paragraph, text: "Normal paragraph.", isInertPlainTextHTML: false),
            MarkdownPreviewBlock(kind: .codeBlock, text: "<script>insideCodeFence()</script>", isInertPlainTextHTML: false),
            MarkdownPreviewBlock(kind: .rawHTML, text: "<script>alert(1)</script>", isInertPlainTextHTML: true),
            MarkdownPreviewBlock(kind: .rawHTML, text: "<iframe src=\"https://evil.example\"></iframe>", isInertPlainTextHTML: true),
        ])
    }
}

@Suite("GFMEditorPipelineWiringTests")
struct GFMEditorPipelineWiringTests {

    private static var tmp: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/gfmwiring-\(UUID().uuidString)", isDirectory: true)
    }

    @MainActor
    private static func makeModel(recovery: URL) -> SwiftEditWorkbenchModel {
        SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: recovery,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
    }

    private static func recoveryText(in dir: URL) -> String {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "recovery" }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    @Test("P6: Cmd+P toggles a default-OFF preview, the Tab chain prefers tables over lists, commands are one revision, recovery is debounced, and sourceLine follows the caret")
    @MainActor
    func p6PipelineWiring() async throws {
        let dir = Self.tmp
        let model = Self.makeModel(recovery: dir)
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        model.recoveryDebounceNanoseconds = 60_000_000

        // GIVEN a Markdown tab holding a table and a list, with the preview untouched
        let text = "| a | b |\n|---|---|\n| 1 | 2 |\n\n- one\n- two\n"
        model.newUntitledTab()
        model.handleEditorTextChanged(text)
        #expect(model.showMarkdownPreview == false)
        #expect(model.markdownPreviewDocument == nil)

        // WHEN toggling the preview on
        model.toggleMarkdownPreview()
        // THEN a projection with source lines exists, and toggling off drops it
        #expect(model.markdownPreviewDocument?.blocks.isEmpty == false)
        model.toggleMarkdownPreview()
        #expect(model.markdownPreviewDocument == nil)

        // WHEN the caret sits in the table the table engine handles Tab, in the list it defers to the list engine
        model.handleSelectionChanged(TextRange(location: 2, length: 0))
        if case .edit = model.tableTabOutcome(backward: false) {} else { Issue.record("table Tab not handled") }
        let listCaret = (text as NSString).range(of: "- two").location + 5
        model.handleSelectionChanged(TextRange(location: listCaret, length: 0))
        #expect(model.tableTabOutcome(backward: false) == .notApplicable)
        if case .edit = model.listIndentationOutcome(outdent: false) {} else { Issue.record("list Tab not handled") }
        #expect(model.previewSourceLine == 6)

        // WHEN applying Bold to a selection through the workbench
        model.handleSelectionChanged(TextRange(location: 2, length: 1))
        let before = try #require(model.activeDocumentSession?.revision)
        #expect(model.applyMarkdownCommand(.bold))
        let after = try #require(model.activeDocumentSession?.revision)
        #expect(after.value == before.value + 1)
        #expect(model.activeDocumentSession?.text.hasPrefix("| **a** |") == true)

        // THEN typing is not persisted immediately, but is after the debounce window
        model.handleEditorTextChanged("# zzzmarker")
        #expect(!Self.recoveryText(in: dir).contains("zzzmarker"))
        var persisted = false
        for _ in 0..<60 where !persisted {
            try await Task.sleep(nanoseconds: 50_000_000)
            persisted = Self.recoveryText(in: dir).contains("zzzmarker")
        }
        #expect(persisted)
    }

    @Test("N7 [Security]: binary tab disables the Markdown menu and preview without mutation")
    @MainActor
    func n7BinaryTabLockout() throws {
        let dir = Self.tmp
        let model = Self.makeModel(recovery: dir)
        defer {
            try? FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let binaryURL = dir.appendingPathComponent("payload.bin")
        try Data([0x50, 0x4B, 0x00, 0x04, 0x41]).write(to: binaryURL)
        model.openFile(at: binaryURL, withinScope: dir)
        model.showMarkdownPreview = true
        let revision = try #require(model.activeDocumentSession?.revision)

        #expect(model.isMarkdownMenuEnabled == false)
        #expect(model.markdownPreviewDocument == nil)
        #expect(model.applyMarkdownCommand(.bold) == false)
        #expect(model.tableTabOutcome(backward: false) == .notApplicable)
        #expect(model.activeDocumentSession?.revision == revision)
    }
}
