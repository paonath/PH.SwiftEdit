import Foundation
import Testing
@testable import SwiftEditCore

@Suite("CoreCoverageBoostTests")
struct CoreCoverageBoostTests {

    @Test("InMemoryKeyValueStore and UserDefaultsPreferencesStore cover all typed getters, coercions, and removals")
    func preferencesProvidingFullCoverage() {
        let mem = InMemoryKeyValueStore()
        mem.set("hello", forKey: "s")
        mem.set(NSNumber(value: 42), forKey: "num")
        mem.set("123", forKey: "intStr")
        mem.set("3.25", forKey: "dblStr")
        mem.set("true", forKey: "boolStr")
        mem.set(true, forKey: "boolRaw")
        mem.set(7.5, forKey: "dblRaw")
        mem.set(Data("xyz".utf8), forKey: "bin")

        #expect(mem.string(forKey: "s") == "hello")
        #expect(mem.string(forKey: "num") == "42")
        #expect(mem.string(forKey: "missing") == nil)
        #expect(mem.integer(forKey: "num") == 42)
        #expect(mem.integer(forKey: "intStr") == 123)
        #expect(mem.integer(forKey: "missing") == 0)
        #expect(mem.double(forKey: "dblRaw") == 7.5)
        #expect(mem.double(forKey: "num") == 42.0)
        #expect(mem.double(forKey: "dblStr") == 3.25)
        #expect(mem.double(forKey: "missing") == 0.0)
        #expect(mem.bool(forKey: "boolRaw") == true)
        #expect(mem.bool(forKey: "num") == true)
        #expect(mem.bool(forKey: "boolStr") == true)
        #expect(mem.bool(forKey: "missing") == false)
        #expect(mem.data(forKey: "bin") == Data("xyz".utf8))
        #expect(mem.object(forKey: "s") as? String == "hello")
        mem.removeObject(forKey: "s")
        #expect(mem.object(forKey: "s") == nil)
        mem.set(nil, forKey: "num")
        #expect(mem.object(forKey: "num") == nil)
    }

    @Test("JSONPreferencesStore covers cross-type getters, ensurePersisted, default paths, and malformed JSON fail-closed")
    func jsonPreferencesStoreFullCoverage() throws {
        #expect(JSONPreferencesStore.defaultConfigDirectoryURL().lastPathComponent == ".SwiftEdit")
        #expect(JSONPreferencesStore.defaultSettingsFileURL().lastPathComponent == "settings.json")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("json-cov-\(UUID().uuidString)")
        let file = dir.appendingPathComponent(".SwiftEdit/settings.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        // Malformed JSON fails closed to empty dictionary
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not-json".utf8).write(to: file)
        let broken = JSONPreferencesStore(fileURL: file)
        #expect(broken.string(forKey: "any") == nil)

        // Write mixed types and exercise cross-type coercions
        broken.performBatch {
            broken.set(true, forKey: "b")
            broken.set(42, forKey: "i")
            broken.set(3.5, forKey: "d")
            broken.set("99", forKey: "s")
            broken.set(Data("raw".utf8), forKey: "bin")
            broken.set(URL(fileURLWithPath: "/tmp/a"), forKey: "other")
        }
        broken.ensurePersisted()

        #expect(broken.string(forKey: "b") == "true")
        #expect(broken.string(forKey: "i") == "42")
        #expect(broken.string(forKey: "d") == "3.5")
        #expect(broken.integer(forKey: "d") == 3)
        #expect(broken.integer(forKey: "b") == 1)
        #expect(broken.integer(forKey: "s") == 99)
        #expect(broken.integer(forKey: "missing") == 0)
        #expect(broken.double(forKey: "i") == 42.0)
        #expect(broken.double(forKey: "b") == 1.0)
        #expect(broken.double(forKey: "s") == 99.0)
        #expect(broken.double(forKey: "missing") == 0.0)
        #expect(broken.bool(forKey: "i") == true)
        #expect(broken.bool(forKey: "d") == true)
        #expect(broken.bool(forKey: "s") == true)
        #expect(broken.bool(forKey: "missing") == false)
        #expect(broken.data(forKey: "bin") == Data("raw".utf8))
        #expect(broken.data(forKey: "i") == nil)
        #expect(broken.object(forKey: "b") as? Bool == true)
        #expect(broken.object(forKey: "i") as? Int == 42)
        #expect(broken.object(forKey: "d") as? Double == 3.5)
        #expect(broken.object(forKey: "s") as? String == "99")
        #expect(broken.object(forKey: "bin") as? Data == Data("raw".utf8))
        #expect(broken.object(forKey: "missing") == nil)

        // Reload from disk verifies JSONValue decoding of Bool, Int, Double, String
        let reloaded = JSONPreferencesStore(fileURL: file)
        #expect(reloaded.bool(forKey: "b") == true)
        #expect(reloaded.integer(forKey: "i") == 42)
        #expect(reloaded.double(forKey: "d") == 3.5)
        #expect(reloaded.string(forKey: "s") == "99")
    }

    @Test("CursorMetricsCalculator, UTF16LineBreakScanner, and DocumentTextIndex cover LF/CRLF/CR, surrogates, and boundaries")
    func cursorAndLineBreakFullCoverage() throws {
        // Mixed LF, CRLF, CR, accented UTF-8, and 4-byte emoji surrogate pair
        let mixed = "aé😀\r\nb\rc\n"
        let ranges = UTF16LineBreakScanner.lineContentRanges(in: mixed)
        #expect(ranges.count == 4)
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 0, in: mixed) == nil)
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 1, in: mixed) == ranges[0])
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 2, in: mixed) == ranges[1])
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 3, in: mixed) == ranges[2])
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 4, in: mixed) == ranges[3])
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 5, in: mixed) == nil)
        #expect(UTF16LineBreakScanner.lineContentRange(forLine: 1, in: "") == TextRange(location: 0, length: 0))

        // Caret between \r and \n (offset 5 in "aé😀\r\n" -> a(1)+é(1)+😀(2)+\r(1) = 5)
        let midCRLF = try CursorMetricsCalculator.metrics(in: mixed, caretLocation: 5)
        #expect(midCRLF.line == 2 && midCRLF.column == 1)
        let idx = DocumentTextIndex(text: mixed)
        #expect(idx.lineContentRange(atUTF16Offset: 0) == ranges[0])
        #expect(idx.lineContentRange(atUTF16Offset: 5) == ranges[0])
        #expect(idx.lineContentRange(atUTF16Offset: 6) == ranges[1])
        #expect(idx.lineContentRange(atUTF16Offset: 8) == ranges[2])

        // Out-of-bounds caret throws
        #expect(throws: DomainError.self) {
            _ = try CursorMetricsCalculator.metrics(in: mixed, caretLocation: 999)
        }
    }

    @Test("MarkdownSourceLineTable and YAMLFrontmatterScanner cover bounds, --- and ... delimiters, and unterminated blocks")
    func markdownSourceLineTableAndFrontmatterScanner() {
        let md = "---\ntitle: A\n...\n# Heading\n"
        let table = MarkdownSourceLineTable(text: md)
        #expect(table.lineCount == 5)
        #expect(table.range(ofLine: 0) == nil)
        #expect(table.range(ofLine: 1) == TextRange(location: 0, length: 3))
        #expect(table.range(ofLine: 4)?.length == 9)
        #expect(table.range(ofLine: 99) == nil)
        #expect(YAMLFrontmatterScanner.maskedLineCount(in: table.index) == 3)

        let unterminated = MarkdownLineIndex(text: "---\nkey: val\nno close")
        #expect(YAMLFrontmatterScanner.maskedLineCount(in: unterminated) == 0)
    }

    @Test("BracketMatcher covers nested pairs, unmatched delimiters, escaped strings, overlong lines, and active/enclosing resolution")
    func bracketMatcherFullCoverage() throws {
        let code = """
        func demo(a: [Int], b: String = "(\\"])") {
            let map = ["k": (1 + [2, 3])]
            let unmatched = (
        }
        ]
        """
        let snap = DocumentSession(text: code).snapshot
        let base = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: snap, caretLocation: 0).completedValue)
        #expect(!base.matchedPairs.isEmpty)
        #expect(!base.unbalancedBrackets.isEmpty)

        // Probe caret at open, inside, close, and outside positions across the buffer
        for offset in stride(from: 0, through: code.utf16.count, by: 3) {
            let res = try #require(SearchDiffAndBracketEngine.evaluateBrackets(in: snap, caretLocation: offset).completedValue)
            #expect(res.unbalancedBrackets.count == base.unbalancedBrackets.count)
        }

        // Overlong line guard
        let longLine = "ok\n" + String(repeating: "a", count: 150) + "\nend"
        let over = SearchDiffAndBracketEngine.firstOverlongLine(in: longLine, limit: 100)
        #expect(over?.line == 2)
        #expect(over?.utf16Length == 150)
        #expect(SearchDiffAndBracketEngine.firstOverlongLine(in: "short\r\nlines\rhere", limit: 20) == nil)
    }

    @Test("MarkdownAllConstructsLinter covers headings, fences, lists, tables, emphasis, raw HTML, and entity-encoded unsafe URLs")
    func markdownAllConstructsLinterFullCoverage() {
        let richMD = """
        # Title 1
        # Duplicate H1

        ### Skipped H2

        Some trailing spaces   
        \tTab indented line

        * List A
        - List B
        + List C

        1. First
        3. Skipped number

        > Quote line 1
        >
        > Quote line 2

        ```
        fenced without language
        ```

        ~~~swift
        let y = 2
        ~~~

        | H1 | H2 |
        | --- | --- |
        | only one col |

        [bad1](&#x6a;avascript:alert(1))
        [bad2](&#106;avascript:alert(2))
        [bad3](vbscript:msgbox(1))
        ![img1](data:image/svg+xml;base64,PHN2Zz4=)
        ![img2](../escape.png)
        ![img3]()
        [empty]()
        [ref][missing-ref]

        [dup]: https://example.com/1
        [dup]: https://example.com/2

        **bold** __alt__ *italic* _alt_ ~~strike~~ `code` <https://example.com> <script>alert(1)</script>

        ---
        ***
        ___
        """
        let snap = DocumentSession(text: richMD).snapshot
        let result = MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: .allConstructs).completedValue!
        #expect(!result.diagnostics.isEmpty)
        #expect(result.diagnostics.contains(where: { $0.rule == .unsafeLinkScheme }))
        #expect(result.diagnostics.contains(where: { $0.rule == .unsafeImagePath }))
    }
}
