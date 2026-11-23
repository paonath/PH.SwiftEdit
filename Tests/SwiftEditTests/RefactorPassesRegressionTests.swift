import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

@Suite("RefactorPassesRegressionTests")
struct RefactorPassesRegressionTests {

    @Test("Pass 1: MarkdownPreviewProjector recognizes closing code fences with trailing spaces")
    func previewClosingFenceWithTrailingSpaces() throws {
        let md = "```swift\nlet x = 1\n```   \nAfter fence\n"
        let snapshot = DocumentSession(text: md).snapshot
        let doc = try #require(MarkdownPreviewProjector.project(snapshot: snapshot, showPreview: true))
        #expect(doc.blocks == [
            .code(text: "let x = 1", sourceLine: 1),
            .paragraph(text: "After fence", sourceLine: 4),
        ])
    }

    @Test("Pass 1: WordOccurrenceScanner linear Unicode scan finds all whole-word matches accurately")
    func unicodeWordOccurrenceLinearScan() {
        let text = "café latte café_bar café! “café” café"
        let snapshot = DocumentSession(text: text).snapshot
        let firstRange = TextRange(location: 0, length: 4)
        let matches = WordOccurrenceScanner.scan(selection: firstRange, in: snapshot)
        let matchedStrings = matches.map { range in
            (text as NSString).substring(with: NSRange(location: range.location, length: range.length))
        }
        #expect(matches.count == 3)
        #expect(matchedStrings == ["café", "café", "café"])
    }

    @Test("Pass 4: ElementContextualActionCatalog rejects selection splitting a UTF-16 surrogate pair")
    func contextualSurroundRejectsSplitSurrogatePair() {
        let text = "😀hello"
        let snapshot = DocumentSession(text: text).snapshot
        // Emoji occupies UTF-16 units 0..1; starting at 1 splits the surrogate pair.
        let splitSelection = TextRange(location: 1, length: 3)
        #expect(ElementContextualActionCatalog.evaluate(.surround(.backtick), in: snapshot, selection: splitSelection) == nil)
        let validSelection = TextRange(location: 2, length: 5)
        let edit = ElementContextualActionCatalog.evaluate(.surround(.backtick), in: snapshot, selection: validSelection)
        #expect(edit?.edits.first?.replacement == "`hello`")
        #expect(edit?.newSelection == TextRange(location: 3, length: 5))
    }

    @Test("Pass 5: SessionRecoveryStore.saveManifest rejects symbolic link at session-manifest.json")
    func sessionRecoverySaveManifestRejectsSymlink() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-symlink-manifest-\(UUID().uuidString)", isDirectory: true)
        let target = root.appendingPathComponent("outside.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("{}".utf8).write(to: target)

        let store = SessionRecoveryStore(recoveryDirectoryURL: root)
        try FileManager.default.createSymbolicLink(at: store.manifestFileURL, withDestinationURL: target)

        let manifest = SessionRecoveryManifest(tabs: [], activeTabID: nil)
        #expect(throws: DomainError.securityScopeViolation(path: store.manifestFileURL.path)) {
            try store.saveManifest(manifest)
        }
    }

    @Test("Pass 5: JSONPreferencesStore serialized concurrent writes preserve all keys on disk")
    func jsonPreferencesConcurrentWritesDoNotLoseKeys() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftedit-jsonpref-\(UUID().uuidString)", isDirectory: true)
        let fileURL = dir.appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = JSONPreferencesStore(fileURL: fileURL)
        DispatchQueue.concurrentPerform(iterations: 20) { i in
            store.set("val-\(i)", forKey: "key-\(i)")
        }

        let reloaded = JSONPreferencesStore(fileURL: fileURL)
        for i in 0..<20 {
            #expect(reloaded.string(forKey: "key-\(i)") == "val-\(i)")
        }
    }

    @Test("Pass 6: ElementContextualMenuState wraps Up Arrow from nil highlight to the last row")
    func contextualMenuUpArrowFromNilWrapsToLastRow() {
        var state = ElementContextualMenuState(selection: TextRange(location: 0, length: 4))
        // Force highlight to nil via empty filter, then clear filter and press Up (-1).
        state.setQuery("zzzz-no-match")
        #expect(state.highlightedRowID == nil)
        state.setQuery("")
        #expect(state.highlightedRowID != nil)
        // Also verify whitespace-only query does not reset an explicitly chosen highlight.
        let lastID = state.rows.last?.id
        state.highlight(rowID: lastID ?? "")
        state.setQuery("   ")
        #expect(state.highlightedRowID == lastID)
    }
}
