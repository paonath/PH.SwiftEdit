import Foundation
import Testing
@testable import SwiftEditCore

@Suite("DocumentLanguageTests")
struct DocumentLanguageTests {

    @Test(
        "P1: extensions map to Markdown, YAML and Plain Text with status bar labels",
        arguments: [
            ("README.md", DocumentLanguage.markdown, "Markdown"),
            ("Untitled", DocumentLanguage.markdown, "Markdown"),
            ("config.yml", DocumentLanguage.yaml, "YAML"),
            ("Deploy.YAML", DocumentLanguage.yaml, "YAML"),
            ("notes.txt", DocumentLanguage.plainText, "Plain Text"),
        ]
    )
    func p1ExtensionsMapToLanguages(filename: String, expected: DocumentLanguage, label: String) {
        // GIVEN a tab filename
        // WHEN the language is resolved
        let language = DocumentLanguage.resolve(filename: filename)
        // THEN it matches the expected language and status bar label
        #expect(language == expected)
        #expect(language.statusBarLabel == label)
    }

    @Test(
        "N1: double extensions, dotfiles and bare names never enable YAML features",
        arguments: [
            ("config.yml.bak", DocumentLanguage.plainText),
            (".yamllint", DocumentLanguage.plainText),
            ("yml", DocumentLanguage.plainText),
            ("notes.yaml.md", DocumentLanguage.markdown),
        ]
    )
    func n1AmbiguousNamesResolveSafely(filename: String, expected: DocumentLanguage) {
        // GIVEN an ambiguous filename
        // WHEN the language is resolved
        let language = DocumentLanguage.resolve(filename: filename)
        // THEN only the final extension decides
        #expect(language == expected)
    }

    @Test("N1b: binary and degraded snapshots force Plain Text even for .yml")
    func n1bBinaryAndDegradedForcePlainText() {
        // GIVEN a binary and a degraded .yml buffer
        // WHEN the language is resolved with the quarantine flags
        let binary = DocumentLanguage.resolve(filename: "data.yml", isBinary: true)
        let degraded = DocumentLanguage.resolve(filename: "data.yml", isDegraded: true)
        // THEN both are plain text
        #expect(binary == .plainText)
        #expect(degraded == .plainText)
    }

    @Test("P1b: tabs cache their language and refresh it on rename")
    func p1bTabCachesLanguageAndRefreshesOnRename() throws {
        // GIVEN a workspace tab opened as notes.md
        var workspace = WorkspaceTabSession()
        let session = DocumentSession(text: "a: 1")
        try workspace.openOrActivate(snapshot: session.snapshot, title: "notes.md")
        let before = workspace.tabs.first?.language
        // WHEN the tab is renamed to config.yaml
        try workspace.updateTabState(id: session.id, title: "config.yaml")
        // THEN the cached language follows the new name
        #expect(before == .markdown)
        #expect(workspace.tabs.first?.language == .yaml)
    }
}
