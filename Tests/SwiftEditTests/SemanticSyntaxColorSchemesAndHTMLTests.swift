import Foundation
import Testing
@testable import SwiftEditCore
@testable import SwiftEditUI

#if os(macOS)
import AppKit

@Suite("Semantic Syntax Color Schemes & Native HTML Highlighting")
struct SemanticSyntaxColorSchemesAndHTMLTests {

    @Test("P1: All 4 SyntaxColorScheme presets resolve distinct Light/Black palettes, persist in EditorPreferencesStore, and style HTML, Markdown, YAML, JSON, and Log")
    @MainActor
    func p1AllSchemesResolvePersistAndStyleFiveLanguages() {
        let kv = InMemoryKeyValueStore()
        let store = EditorPreferencesStore(store: kv)
        for scheme in SyntaxColorScheme.allCases {
            #expect(!scheme.displayName.isEmpty)
            #expect(!scheme.subtitle.isEmpty)
            store.save(EditorPreferences(appearanceMode: .black, syntaxColorScheme: scheme))
            #expect(store.load().syntaxColorScheme == scheme)
        }

        let model = SwiftEditWorkbenchModel(
            preferencesStore: kv,
            recentFilesStore: InMemoryKeyValueStore(),
            recoveryDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("scheme-\(UUID().uuidString)")
        )
        model.newUntitledTab()
        model.handleEditorTextChanged("# Hello\n")
        let initialRevision = model.activeDocumentSession?.revision

        model.syntaxColorScheme = .catppuccin
        #expect(model.palette.syntaxColors.scheme == .catppuccin)
        #expect(model.activeDocumentSession?.revision == initialRevision)

        let fonts = EditorRenderingFonts(fontSizePoints: 13)
        let catTable = EditorRenderingAttributeTable(palette: model.palette, fonts: fonts)
        model.syntaxColorScheme = .github
        let ghTable = EditorRenderingAttributeTable(palette: model.palette, fonts: fonts)
        model.syntaxColorScheme = .tokyoNight
        let tnTable = EditorRenderingAttributeTable(palette: model.palette, fonts: fonts)

        // Verify semantic slots across all 5 languages (HTML, Markdown, YAML, JSON, Log)
        let kinds: [MarkdownSyntaxKind] = [
            .htmlTag, .htmlAttribute, .htmlString, .htmlComment, .htmlEntity, .htmlDoctype,
            .heading(level: 1), .link, .yamlKey, .yamlComment,
            .jsonKey, .jsonString, .jsonNumber, .jsonLiteral, .jsonPunctuation,
            .logLevel(.error), .logTimestamp, .logGuid, .logString, .logException,
        ]
        for kind in kinds {
            #expect(!catTable.attributes(for: kind).isEmpty)
            #expect(!ghTable.attributes(for: kind).isEmpty)
            #expect(!tnTable.attributes(for: kind).isEmpty)
        }
        #expect(SyntaxColorSchemePalette.resolve(scheme: .catppuccin, mode: .light) != SyntaxColorSchemePalette.resolve(scheme: .github, mode: .light))
        #expect(SyntaxColorSchemePalette.resolve(scheme: .github, mode: .black) != SyntaxColorSchemePalette.resolve(scheme: .tokyoNight, mode: .black))
    }

    @Test("P2: DocumentLanguage.html classifies .html/.htm and HTMLSyntaxHighlighter emits doctype, comment, tag, attribute, string, and entity spans in viewport")
    func p2HTMLDocumentLanguageAndViewportHighlighting() {
        #expect(DocumentLanguage.resolve(filename: "index.html") == .html)
        #expect(DocumentLanguage.resolve(filename: "PAGE.HTM") == .html)
        #expect(DocumentLanguage.html.statusBarLabel == "HTML")

        let html = """
        <!DOCTYPE html>
        <!-- header comment -->
        <section class="hero" data-id=42>&copy; Hello &amp; Welcome</section>
        <br/>
        """
        let index = MarkdownLineIndex(text: html)
        let allSpans = DocumentSyntaxHighlighter.spans(
            index: index,
            visibleRange: TextRange(location: 0, length: index.units.count),
            language: .html
        )
        let kinds = allSpans.map(\.kind)
        #expect(kinds.contains(.htmlDoctype))
        #expect(kinds.contains(.htmlComment))
        #expect(kinds.contains(.htmlTag))
        #expect(kinds.contains(.htmlAttribute))
        #expect(kinds.contains(.htmlString))
        #expect(kinds.contains(.htmlEntity))
    }

    @Test("N1 [Security]: All 4 schemes meet WCAG AA >= 4.5:1 on #FFFFFF/#000000, malformed prefs fail closed, and binary/overlong/unterminated HTML degrades safely")
    func n1WCAGContrastMalformedPrefsAndAdversarialHTML() {
        let white = RGBAColorToken(hex: "#FFFFFF")
        let black = RGBAColorToken(hex: "#000000")
        for scheme in SyntaxColorScheme.allCases {
            let light = SyntaxColorSchemePalette.resolve(scheme: scheme, mode: .light)
            for token in light.allForegroundTokens {
                #expect(token.contrastRatio(against: white) >= 4.5, "Light \(scheme.rawValue) contrast < 4.5")
            }
            let dark = SyntaxColorSchemePalette.resolve(scheme: scheme, mode: .black)
            for token in dark.allForegroundTokens {
                #expect(token.contrastRatio(against: black) >= 4.5, "Black \(scheme.rawValue) contrast < 4.5")
            }
        }

        // Malformed stored scheme fails closed to .swiftEditDefault
        let kv = InMemoryKeyValueStore()
        kv.set("bogus_scheme_999", forKey: EditorPreferencesStore.syntaxColorSchemeKey)
        #expect(EditorPreferencesStore(store: kv).load().syntaxColorScheme == .swiftEditDefault)

        // Binary, degraded, and double-extension .html files force .plainText
        #expect(DocumentLanguage.resolve(filename: "index.html", isBinary: true) == .plainText)
        #expect(DocumentLanguage.resolve(filename: "index.html", isDegraded: true) == .plainText)
        #expect(DocumentLanguage.resolve(filename: "index.html.bak") == .plainText)

        // Overlong (>4096) and unterminated comment/quote lines degrade cleanly without trapping (`SEC-012`)
        let overlong = "<div title=\"" + String(repeating: "a", count: 4200) + "\"></div>"
        let overlongIndex = MarkdownLineIndex(text: overlong)
        #expect(HTMLSyntaxHighlighter.spans(index: overlongIndex, visibleRange: TextRange(location: 0, length: overlongIndex.units.count)).isEmpty)

        let malformed = "<!-- unclosed comment\n<div class=\"unterminated &notanentity <"
        let malformedIndex = MarkdownLineIndex(text: malformed)
        let spans = HTMLSyntaxHighlighter.spans(index: malformedIndex, visibleRange: TextRange(location: 0, length: malformedIndex.units.count))
        #expect(spans.contains { $0.kind == .htmlComment })
        #expect(spans.contains { $0.kind == .htmlString })
    }
}
#endif
