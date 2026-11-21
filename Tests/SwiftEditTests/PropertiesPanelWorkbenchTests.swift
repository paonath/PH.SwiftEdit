import AppKit
import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("PropertiesPanelWorkbenchTests")
@MainActor
struct PropertiesPanelWorkbenchTests {

    @Test("P9: a panel edit advances one revision, dirties the tab and is undone by a single Cmd+Z")
    func p9PanelEditSingleUndo() throws {
        // GIVEN a writable post.md with frontmatter
        let original = "---\ntitle: Hello\n---\n# Body\n"
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("post.md", original)])
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = try #require(model.activeDocumentSession)
        // WHEN the title is changed through the panel
        let visible = model.isPropertiesPanelVisible
        let result = model.applyPropertyOperation(.setValue(key: "title", value: .scalar("World")))
        let after = try #require(model.activeDocumentSession)
        // AND the editor adopts the model text and Cmd+Z is pressed once
        let registry = PerTabUndoManagerRegistry()
        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        textView.allowsUndo = true
        textView.isEditable = true
        let coordinator = TextKit2EditorView.Coordinator(onTextChange: { _ in }, onSelectionChange: { _ in }, onSmartNewline: { _ in nil }, onListIndent: { _ in .notApplicable })
        coordinator.undoRegistry = registry
        coordinator.activeDocumentID = after.id
        textView.delegate = coordinator
        textView.string = original
        coordinator.applyProgrammaticTextUpdate(after.text, to: textView, documentID: after.id)
        try #require(coordinator.undoManager(for: textView)).undo()
        // THEN the buffer shows the new title at the next revision, the tab is dirty, and one undo restores the original
        #expect(visible)
        #expect(result == .edit(TextEdit(range: TextRange(location: 4, length: 13), replacement: "title: World\n")))
        #expect(after.text == "---\ntitle: World\n---\n# Body\n")
        #expect(after.revision == before.revision.next())
        #expect(model.tabSession.tabs.first { $0.id == after.id }?.isDirty == true)
        #expect(model.propertiesModel?.properties.first?.kind == .scalar("World"))
        #expect(textView.string == original)
    }

    @Test("N9: the panel is hidden for YAML, plain, binary and frontmatter-less tabs")
    func n9PanelHiddenOutsideFrontmatterMarkdown() {
        // GIVEN tabs of each excluded kind
        let cases: [(String, String)] = [("a.yml", "---\na: 1\n---\n"), ("a.txt", "---\na: 1\n---\n"), ("plain.md", "# Title\n")]
        let visibilities = cases.map { file -> Bool in
            let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [file])
            defer { try? FileManager.default.removeItem(at: dir) }
            return model.isPropertiesPanelVisible
        }
        let (binaryModel, binaryDir) = YAMLWorkbenchHarness.makeModel(opening: [("bin.md", "---\na: 1\n---\n\u{0}\u{0}")])
        defer { try? FileManager.default.removeItem(at: binaryDir) }
        // WHEN visibility is evaluated
        // THEN the panel never shows and writes are rejected
        #expect(visibilities == [false, false, false])
        #expect(binaryModel.isPropertiesPanelVisible == false)
        #expect(binaryModel.applyPropertyOperation(.add(key: "b", value: .scalar("1"))) == .rejected(.readOnly))
    }

    @Test("N9b: read-only rows are locked and expose descriptive VoiceOver labels")
    func n9bReadOnlyRowsAndAccessibility() throws {
        // GIVEN a frontmatter with an editable scalar and a nested map
        let model = try #require(FrontmatterPropertyParser.parse(snapshot: DocumentSession(text: "---\ntitle: Hi\nmeta:\n  a: 1\n---\n").snapshot))
        // WHEN row descriptors are built
        let rows = model.properties.map { PropertiesPanelRow(property: $0, modelIsReadOnly: model.isReadOnly) }
        // THEN the nested map is locked with a descriptive label and the scalar is editable
        #expect(rows.map(\.isEditable) == [true, false])
        #expect(rows.map(\.accessibilityLabel) == ["title, value Hi", "meta, read-only nested mapping"])
        #expect(rows.map(\.displayValue) == ["Hi", "{…}"])
    }
}
