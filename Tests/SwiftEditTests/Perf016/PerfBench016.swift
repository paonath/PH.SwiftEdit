import AppKit
import Foundation
@testable import SwiftEditCore
@testable import SwiftEditUI

/// Benchmark fixtures and helpers for change `016` (`REQ-011`, `TEST-005`).
///
/// Methodology: every benchmark compares the optimized path against an in-process reference of the pre-refactor path on
/// the same fixture and build, using the median of `runs` `ContinuousClock` samples, so thresholds are machine-independent.
enum PerfBench016 {
    static let lineCount = 20_000

    /// 20,000-line Markdown fixture with frontmatter, headings, lists, inline code and links (~1 MB).
    static let markdown: String = {
        "---\ntitle: Bench\ntags: [a, b]\n---\n" + (0..<lineCount).map { i in
            i % 10 == 0 ? "## Heading \(i)" : "- item **\(i)** with `code` and [link](https://x.y/\(i))"
        }.joined(separator: "\n")
    }()

    /// 20,000-line YAML fixture with nested mappings and comments.
    static let yaml: String = {
        (0..<lineCount).map { i in i % 5 == 0 ? "key\(i):" : "  child\(i): value \(i) # c" }.joined(separator: "\n")
    }()

    /// Returns `text` as TextKit hands it over: an `NSString`-bridged Swift `String` read back from a text view.
    @MainActor
    static func bridgedFromTextView(_ text: String) -> (NSTextView, String) {
        let textView = NSTextView()
        textView.string = text
        return (textView, textView.string)
    }

    /// Median wall time in milliseconds of `runs` executions of `body`.
    static func medianMilliseconds(runs: Int = 15, _ body: () -> Void) -> Double {
        let clock = ContinuousClock()
        var samples: [Double] = []
        samples.reserveCapacity(runs)
        for _ in 0..<runs {
            let d = clock.measure(body)
            samples.append(Double(d.components.seconds) * 1_000 + Double(d.components.attoseconds) / 1e15)
        }
        return samples.sorted()[runs / 2]
    }

    /// Deterministic 64-bit FNV-1a fingerprint used by golden equivalence checks.
    static func fingerprint(_ value: Any) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in String(describing: value).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

/// Golden behavioral fingerprints captured BEFORE performance pass 1 (`N11`).
enum PerfGolden016 {
    static let recorded: [String: UInt64] = [
        "frontmatter": 3855822002301108325, "gutter": 11860002414274336196, "lint.markdown": 17751757224689353408,
        "lint.yaml": 675868731199239589, "outline.markdown": 3888972219280982894, "outline.yaml": 2668794176289243962,
        "smartEdits": 4867229877339570063, "spans.markdown": 6899874283710100662, "spans.yaml": 16993897896420750088,
        "statusbar": 6560422114123526740,
    ]

    /// Smaller (2,000-line) golden fixtures keep the equivalence suite fast in debug builds.
    static let markdown = "---\ntitle: Golden\ntags: [a, \"b, c\"]\n---\n" + (0..<2_000).map { i in
        switch i % 8 {
        case 0: return "## Heading \(i)"
        case 1: return "- [x] task **\(i)** ~~old~~"
        case 2: return "```swift\nlet x = \(i)\n```"
        case 3: return "> quote with `code` and ![img](./a\(i).png)"
        case 4: return "| a | b |"
        case 5: return "1. item\(i)  "
        case 6: return "text [link](https://x.y/\(i)) <b>html</b>"
        default: return ""
        }
    }.joined(separator: "\n")

    static let yaml = (0..<2_000).map { i in
        switch i % 7 {
        case 0: return "key\(i):"
        case 1: return "  child: \"quoted # \(i)\" # c"
        case 2: return "  list:"
        case 3: return "    - item\(i)"
        case 4: return "  anchor: &a\(i) value"
        case 5: return "  block: |"
        default: return "    body \(i)"
        }
    }.joined(separator: "\n")

    /// Current fingerprints of every observable output the performance passes may touch.
    @MainActor
    static func current() -> [String: UInt64] {
        let md = DocumentSession(text: markdown).snapshot
        let yml = DocumentSession(text: yaml).snapshot
        let mdIndex = MarkdownLineIndex(text: markdown)
        let ymlIndex = MarkdownLineIndex(text: yaml)
        func viewports(_ index: MarkdownLineIndex, _ language: DocumentLanguage) -> [[MarkdownSyntaxSpan]] {
            [0, index.lineCount / 2, max(0, index.lineCount - 40)].map { start in
                let from = index.lineRange(start).location
                let to = index.lineRange(min(index.lineCount - 1, start + 39)).upperBound
                return DocumentSyntaxHighlighter.spans(index: index, visibleRange: TextRange(location: from, length: to - from), language: language)
            }
        }
        let carets = [0, 1, 37, (markdown as NSString).length / 2, (markdown as NSString).length]
        return [
            "spans.markdown": PerfBench016.fingerprint(viewports(mdIndex, .markdown)),
            "spans.yaml": PerfBench016.fingerprint(viewports(ymlIndex, .yaml)),
            "lint.markdown": PerfBench016.fingerprint(SwiftEditWorkbenchModel.lintDiagnostics(for: md, language: .markdown)),
            "lint.yaml": PerfBench016.fingerprint(SwiftEditWorkbenchModel.lintDiagnostics(for: yml, language: .yaml)),
            "outline.markdown": PerfBench016.fingerprint(MarkdownHeadingOutlineEngine.outline(for: markdown)),
            "outline.yaml": PerfBench016.fingerprint(YAMLOutlineEngine.outline(index: ymlIndex)),
            "gutter": PerfBench016.fingerprint(carets.map { LineNumberGutterProjection.evaluate(text: markdown, caretLocation: $0, fontSizePoints: 13) }),
            "statusbar": PerfBench016.fingerprint(carets.map { StatusBarMetricsProjection.evaluate(snapshot: md, caretLocation: $0) }),
            "frontmatter": PerfBench016.fingerprint(FrontmatterPropertyParser.parse(snapshot: md).map { ($0.properties, $0.isReadOnly, $0.closingDelimiterLine, $0.closingDelimiterOffset) } as Any),
            "smartEdits": PerfBench016.fingerprint([
                YAMLSmartIndentEngine.evaluateNewline(in: yml, caretLocation: ("key0:" as NSString).length, language: .yaml) as Any,
                MarkdownSmartNewlineEngine.evaluateNewline(in: md, caretLocation: carets[3], isMarkdownDocument: true) as Any,
            ]),
        ]
    }
}
