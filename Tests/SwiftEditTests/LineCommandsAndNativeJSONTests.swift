import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)

@Suite("Unit 6: Atomic Line Commands, Trim on Save & Native JSON/JSONL Support (REQ-009, REQ-010)")
struct LineCommandsAndNativeJSONTests {

    @Test("P9 & N10: Move Line Up/Down, Delete Line, Join Lines, Sort Lines Asc/Desc, Trim Trailing Whitespace + Save Pref, and boundary/binary guards")
    @MainActor
    func p9AndN10AtomicLineCommandsTrimOnSaveAndGuards() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LineCmds-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let prefsStore = InMemoryKeyValueStore()
        let model = SwiftEditWorkbenchModel(
            preferencesStore: prefsStore,
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent(".recovery", isDirectory: true)
        )
        model.newUntitledTab()
        model.setActiveDocumentLineEnding(.crlf)
        model.handleEditorTextChanged("beta\r\nalpha\r\ngamma  \t\r\n")

        // N10 boundary: Move Line Up at line 1 is a safe no-op
        model.handleSelectionChanged(TextRange(location: 0, length: 0))
        let revBeforeBoundary = model.activeDocumentSession?.revision
        model.moveActiveLinesUp()
        #expect(model.activeDocumentSession?.revision == revBeforeBoundary)

        // 1. Move Line Down on line 1 swaps "beta" below "alpha" in 1 revision preserving CRLF
        model.moveActiveLinesDown()
        #expect(model.activeDocumentSession?.text == "alpha\r\nbeta\r\ngamma  \t\r\n")
        #expect(model.activeDocumentSession?.lineEnding == .crlf)

        // 2. Move Line Up moves "beta" back to line 1
        model.moveActiveLinesUp()
        #expect(model.activeDocumentSession?.text == "beta\r\nalpha\r\ngamma  \t\r\n")

        // 3. Sort Lines Ascending & Descending across full selection
        let fullLen = (model.activeDocumentSession?.text as NSString?)?.length ?? 0
        model.handleSelectionChanged(TextRange(location: 0, length: fullLen))
        model.sortActiveLines(ascending: true)
        #expect(model.activeDocumentSession?.text.hasPrefix("alpha\r\nbeta\r\ngamma") == true)
        model.handleSelectionChanged(TextRange(location: 0, length: (model.activeDocumentSession?.text as NSString?)?.length ?? 0))
        model.sortActiveLines(ascending: false)
        #expect(model.activeDocumentSession?.text.hasPrefix("gamma  \t\r\nbeta\r\nalpha") == true)

        // 4. Join Lines (`Ctrl+J`) joins line 1 and line 2 with single space
        model.handleSelectionChanged(TextRange(location: 0, length: 0))
        model.joinActiveLines()
        #expect(model.activeDocumentSession?.text.hasPrefix("gamma beta\r\nalpha") == true)

        // 5. Delete Line (`Ctrl+Shift+K`) removes active line
        model.handleSelectionChanged(TextRange(location: 0, length: 0))
        model.deleteActiveLines()
        #expect(model.activeDocumentSession?.text.hasPrefix("alpha") == true)

        // 6. Trim Trailing Whitespace on Save persists in EditorPreferencesStore and strips spaces on save
        model.trimTrailingWhitespaceOnSave = true
        let reloadedPrefs = EditorPreferencesStore(store: prefsStore).load()
        #expect(reloadedPrefs.trimTrailingWhitespaceOnSave == true)

        model.handleEditorTextChanged("keep clean   \r\nsecond\t\t\r\n")
        let targetURL = dir.appendingPathComponent("saved.md")
        model.saveDocument(to: targetURL)
        #expect(model.activeDocumentSession?.text == "keep clean\r\nsecond\r\n")
    }

    @Test("P10: DocumentLanguage.json resolves .json/.jsonl, highlights viewport tokens, lints syntax errors, and Pretty-Prints / Minifies JSON")
    @MainActor
    func p10NativeJSONLanguageHighlighterLinterAndFormatter() throws {
        #expect(DocumentLanguage.resolve(filename: "package.json") == .json)
        #expect(DocumentLanguage.resolve(filename: "events.jsonl") == .json)
        #expect(DocumentLanguage.resolve(filename: "package.json", isBinary: true) == .plainText)

        // 1. Viewport-only JSON syntax highlighting
        let sampleJSON = """
        {
          "name": "SwiftEdit",
          "count": 42,
          "enabled": true,
          "empty": null
        }
        """
        let snap = DocumentSession(text: sampleJSON).snapshot
        let spans = DocumentSyntaxHighlighter.spans(
            snapshot: snap,
            visibleRange: TextRange(location: 0, length: (sampleJSON as NSString).length),
            language: .json
        )
        #expect(spans.contains { $0.kind == .jsonKey })
        #expect(spans.contains { $0.kind == .jsonString })
        #expect(spans.contains { $0.kind == .jsonNumber })
        #expect(spans.contains { $0.kind == .jsonLiteral })

        // 2. JSONStructureLinter reports exact line/column diagnostic on malformed JSON
        let invalidSnap = DocumentSession(text: "{\n  \"ok\": 1,\n  \"bad\": [1, 2,\n}").snapshot
        let diags = JSONStructureLinter.lint(snapshot: invalidSnap)
        #expect(!diags.isEmpty)

        // 3. Pretty-Print and Minify on a .json tab in SwiftEditWorkbenchModel
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("JSON-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let jsonFile = dir.appendingPathComponent("config.json")
        try "{\"z\":1,\"a\":[true,false]}".write(to: jsonFile, atomically: true, encoding: .utf8)

        let model = SwiftEditWorkbenchModel(
            preferencesStore: InMemoryKeyValueStore(),
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: dir.appendingPathComponent(".recovery", isDirectory: true)
        )
        model.openFile(at: jsonFile, withinScope: dir)
        #expect(model.activeDocumentLanguage == .json)

        model.formatActiveJSONDocument()
        let formatted = try #require(model.activeDocumentSession?.text)
        #expect(formatted.contains("\n  \"a\""))
        #expect(formatted.contains("\"z\""))

        model.minifyActiveJSONDocument()
        let minified = try #require(model.activeDocumentSession?.text)
        #expect(!minified.contains("\n"))
        #expect(minified.contains("\"a\":[true,false]"))
    }

    @Test("N11 [Security]: >128 nested JSON emits JSN003 without recursion, malformed JSON refuses destructive format, >4096-unit lines skip highlight spans, and binary bad.json forces .plainText")
    @MainActor
    func n11JSONDepthCapMalformedGuardLongLineSkipAndBinaryLockout() throws {
        // 1. > 128 nested JSON arrays caught iteratively with .jsonNestingTooDeep (`CWE-674`)
        let deepJSON = String(repeating: "[", count: 135) + "1" + String(repeating: "]", count: 135)
        let deepSnap = DocumentSession(text: deepJSON).snapshot
        let deepDiags = JSONStructureLinter.lint(snapshot: deepSnap)
        #expect(deepDiags.contains { $0.rule == .jsonNestingTooDeep })

        // 2. Malformed JSON refuses Format / Minify without mutating buffer
        let badSnap = DocumentSession(text: "{\"broken\": [1, 2,}").snapshot
        #expect(JSONFormatter.prettyPrint(snapshot: badSnap) == nil)
        #expect(JSONFormatter.minify(snapshot: badSnap) == nil)

        // 3. > 4096 UTF-16 line skipped safely in JSONSyntaxHighlighter (`CWE-400`)
        let overlongLine = "{\"k\": \"" + String(repeating: "x", count: 4105) + "\"}"
        let overlongSnap = DocumentSession(text: overlongLine).snapshot
        let spans = DocumentSyntaxHighlighter.spans(
            snapshot: overlongSnap,
            visibleRange: TextRange(location: 0, length: (overlongLine as NSString).length),
            language: .json
        )
        #expect(spans.isEmpty)

        // 4. NUL-bearing bad.json resolves to .plainText and disables JSON format
        #expect(DocumentLanguage.resolve(filename: "bad.json", isBinary: true) == .plainText)
        #expect(DocumentLanguage.resolve(filename: "huge.jsonl", isDegraded: true) == .plainText)
    }
}
#endif
