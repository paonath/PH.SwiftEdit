import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("ListIndentationWorkbenchTests")
struct ListIndentationWorkbenchTests {

    private static var tmp: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".tmp/test-results/listindent-\(UUID().uuidString)", isDirectory: true)
    }

    @MainActor
    private static func makeModel(recovery: URL) -> (SwiftEditWorkbenchModel, String) {
        let suite = "it.ph.SwiftEdit.test.listindent.\(UUID().uuidString)"
        let model = SwiftEditWorkbenchModel(
            preferencesSuiteName: suite,
            recentFilesSuiteName: "\(suite).recent",
            recoveryDirectoryURL: recovery,
            systemDarkDetector: { false },
            savePanelProvider: { _ in nil }
        )
        return (model, suite)
    }

    @Test("P5: applyListIndentation nests in exactly one BufferRevision, translates the caret, and coalesces edits into one replacement")
    @MainActor
    func p5WorkbenchAppliesTabInOneRevision() throws {
        // GIVEN a Markdown tab ending with an empty third item and the caret at its end
        let dir = Self.tmp
        let (model, suite) = Self.makeModel(recovery: dir)
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: dir)
        }
        let text = "1. a\n2. b\n3. "
        model.handleEditorTextChanged(text)
        model.handleSelectionChanged(TextRange(location: (text as NSString).length, length: 0))
        let revisionBefore = try #require(model.activeDocumentSession?.revision)

        // WHEN pressing Tab through the workbench and coalescing a multi-line batch
        let handled = model.applyListIndentation(outdent: false)
        let session = try #require(model.activeDocumentSession)
        let multiText = "- root\n* a\n* b"
        let multi = MarkdownSmartListEngine.evaluateIndent(
            in: DocumentSession(text: multiText).snapshot,
            selection: TextRange(location: 7, length: (multiText as NSString).length - 7),
            outdent: false,
            isMarkdownDocument: true
        )
        var coalescedResult: String?
        if case .edit(let edit) = multi {
            let single = edit.coalescedEdit(in: multiText)
            coalescedResult = (multiText as NSString).replacingCharacters(
                in: NSRange(location: single.range.location, length: single.range.length),
                with: single.replacement
            )
        }

        // THEN the text nests, one revision elapsed, the caret moved four columns, and coalescing equals the multi-edit result
        #expect(handled == true)
        #expect(session.text == "1. a\n2. b\n    1. ")
        #expect(session.revision == revisionBefore.next())
        #expect(model.currentSelection.location == 17)
        #expect(coalescedResult == "- root\n    * a\n    * b")
    }

    @Test("N4 [Security]: binary read-only and non-Markdown tabs are not mutated by list indentation")
    @MainActor
    func n4BinaryAndNonMarkdownAreNotMutated() throws {
        // GIVEN an inspected binary file and an opened notes.swift buffer containing a list-like line
        let dir = Self.tmp
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let binaryURL = dir.appendingPathComponent("payload.bin")
        try Data([0x2D, 0x20, 0x00, 0x41]).write(to: binaryURL)
        let swiftURL = dir.appendingPathComponent("notes.swift")
        try Data("- a\n- b".utf8).write(to: swiftURL)
        let (model, suite) = Self.makeModel(recovery: dir.appendingPathComponent("rec"))
        defer {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: dir)
        }

        // WHEN pressing Tab on each
        model.openFile(at: swiftURL, withinScope: dir)
        model.handleSelectionChanged(TextRange(location: 7, length: 0))
        let swiftSession = try #require(model.activeDocumentSession)
        let swiftHandled = model.applyListIndentation(outdent: false)
        let swiftAfter = try #require(model.activeDocumentSession)

        model.openFile(at: binaryURL, withinScope: dir)
        let beforeBinary = try #require(model.activeDocumentSession)
        let binaryHandled = model.applyListIndentation(outdent: false)
        let afterBinary = try #require(model.activeDocumentSession)

        // THEN neither is handled and text and revisions stay identical
        #expect(swiftHandled == false)
        #expect(swiftAfter.text == swiftSession.text)
        #expect(swiftAfter.revision == swiftSession.revision)
        #expect(binaryHandled == false)
        #expect(afterBinary.text == beforeBinary.text)
        #expect(afterBinary.revision == beforeBinary.revision)
    }
}

@Suite("ListIndentationUndoTests")
struct ListIndentationUndoTests {

    @Test("P5 (Undo): coordinator applies Tab as one coalesced insertText so a single undo restores the original text")
    @MainActor
    func singleUndoRestoresOriginal() throws {
        // GIVEN an editable TextKit 2 text view inside a window holding a list with a selected three-line block
        let text = "- root\n* a\n* b\n+ c"
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.allowsUndo = true
        textView.isEditable = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: true)
        window.contentView = textView
        textView.string = text
        textView.setSelectedRange(NSRange(location: 7, length: (text as NSString).length - 7))
        let snapshot = DocumentSession(text: text).snapshot
        let coordinator = TextKit2EditorView.Coordinator(
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSmartNewline: { _ in nil },
            onListIndent: { outdent in
                MarkdownSmartListEngine.evaluateIndent(
                    in: snapshot,
                    selection: TextRange(location: 7, length: (text as NSString).length - 7),
                    outdent: outdent,
                    isMarkdownDocument: true
                )
            }
        )

        // WHEN Tab is handled and then a single undo is performed
        let handled = coordinator.handleListIndent(in: textView, outdent: false)
        let indented = textView.string
        let undoManager = try #require(textView.undoManager)
        undoManager.undo()

        // THEN the whole block was indented and one undo restores the original text
        #expect(handled == true)
        #expect(indented == "- root\n    * a\n    * b\n    + c")
        #expect(textView.string == text)
    }
}
