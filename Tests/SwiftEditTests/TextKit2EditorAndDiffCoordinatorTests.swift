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
