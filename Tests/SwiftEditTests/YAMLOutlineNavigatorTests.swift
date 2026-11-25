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

    @Test("P5b: YAML files with leading, middle, consecutive, and trailing blank lines across LF, CRLF, and CR list all top-level keys without crashing")
    func p5bBlankLinesAcrossLineEndingsDoNotCrash() {
        // GIVEN YAML documents with blank lines across LF, CRLF, and CR endings (reproducing 0.1.8-beta1 crash)
        let lfText = "\n\nversion: 2\n\nservices:\n  web:\n    image: x\n\n\nvolumes: {}\n\n"
        let crlfText = "\r\nversion: 2\r\n\r\nvolumes: {}\r\n"
        let (model, dir) = YAMLWorkbenchHarness.makeModel(opening: [("blank.yml", lfText)])
        defer { try? FileManager.default.removeItem(at: dir) }

        // WHEN outlines are computed and the Document Navigator opens and confirms 'volumes'
        let lfOutline = YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: lfText))
        let crlfOutline = YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: crlfText))
        model.toggleDocumentNavigator()
        let navTitles = model.navigatorState?.filtered.map(\.title)
        model.navigatorState?.select(index: 2)
        model.confirmDocumentNavigator()

        // THEN all top-level keys are extracted with exact UTF-16 offsets and zero traps
        #expect(lfOutline.map(\.title) == ["version", "services", "volumes"])
        #expect(crlfOutline.map(\.title) == ["version", "volumes"])
        #expect(navTitles == ["version", "services", "volumes"])
        let expectedOffset = ("\n\nversion: 2\n\nservices:\n  web:\n    image: x\n\n\n" as NSString).length
        #expect(model.currentSelection.location == expectedOffset)
    }

    @Test("N5c: empty, blank-line-only, and whitespace-only YAML documents return empty outlines safely")
    func n5cEmptyAndBlankOnlyYAMLReturnEmptyOutline() {
        #expect(YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: "")).isEmpty)
        #expect(YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: "\n\n\r\n\r")).isEmpty)
        #expect(YAMLOutlineEngine.outline(index: MarkdownLineIndex(text: "   \n\t\n  \r\n")).isEmpty)
    }
}
