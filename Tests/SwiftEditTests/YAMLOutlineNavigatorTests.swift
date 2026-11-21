import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("YAMLOutlineNavigatorTests")
@MainActor
struct YAMLOutlineNavigatorTests {

    @Test("P5: top-level keys are listed and confirming 'volumes' jumps to line 5")
    func p5TopLevelKeysAndJump() throws {
        // GIVEN an open YAML tab
        let text = "version: 2\nservices:\n  web:\n    image: x\nvolumes: {}"
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("compose.yml", text)])
        defer { try? FileManager.default.removeItem(at: dir) }
        // WHEN the navigator opens and the third entry is confirmed
        model.toggleDocumentNavigator()
        let titles = model.navigatorState?.filtered.map(\.title)
        let badges = model.navigatorState?.filtered.map(\.badge)
        model.navigatorState?.select(index: 2)
        model.confirmDocumentNavigator()
        // THEN the outline lists the three top-level keys and the caret moves to the start of line 5
        #expect(titles == ["version", "services", "volumes"])
        #expect(badges == ["KEY", "KEY", "KEY"])
        #expect(model.currentSelection.location == ("version: 2\nservices:\n  web:\n    image: x\n" as NSString).length)
        #expect(model.navigatorState == nil)
    }

    @Test("N5: nested keys, comments, top-level list items and block scalar bodies are excluded")
    func n5ExclusionsAndCap() {
        // GIVEN a YAML document mixing excluded constructs with one real top-level key
        let text = "# key: no\n- name: a\n  web:\n    x: 1\nscript: |\n  fake: key\n"
        let many = (0..<6000).map { "k\($0): 1" }.joined(separator: "\n")
        // WHEN outlines are computed
        let outline = YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: text))
        let capped = YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: many))
        // THEN only 'script' is listed and the cap holds
        #expect(outline.map(\.title) == ["script"])
        #expect(capped.count == 5000)
    }

    @Test("N5b: the navigator never opens on plain-text tabs and stale offsets are clamped")
    func n5bPlainTabsAndStaleOffsetClamp() {
        // GIVEN a plain-text tab and a navigator state holding an offset beyond the document
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("notes.txt", "a: 1\n")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let stale = DocumentNavigatorState(headings: [MarkdownHeading(level: 1, title: "gone", utf16Offset: 999, kind: .yamlKey)])
        // WHEN the navigator is toggled and the stale state is confirmed against a 5-unit document
        model.toggleDocumentNavigator()
        // THEN the plain tab never opens the navigator and the stale offset clamps to the length
        #expect(model.navigatorState == nil)
        #expect(stale.confirm(documentLength: 5) == 5)
    }
}
