import Foundation

/// Line-oriented structural YAML linter for `.yaml` tabs and Markdown frontmatter (`BC-004`, `SEC-012`).
///
/// Rules: `YML001` tab indentation, `YML002` duplicate key in one mapping, `YML003` inconsistent indentation step,
/// `YML004` unterminated Markdown frontmatter, `YML005` nesting deeper than `YAMLSupportLimits.maxDepth` (reported once,
/// deeper lines are skipped). Output is capped at `YAMLSupportLimits.maxDiagnostics`; messages name keys but never
/// values, so secrets stored in YAML never reach the diagnostics UI (`SEC-006`). Work is a single `O(N)` pass with an
/// explicit stack (no recursion).
public enum YAMLStructureLinter {

    /// Lints a whole `.yaml` snapshot, or only the line-1 frontmatter block of a Markdown snapshot.
    public static func lint(snapshot: DocumentSnapshot, frontmatterOnly: Bool = false) -> [MarkdownLintDiagnostic] {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText, !snapshot.text.isEmpty else { return [] }
        if frontmatterOnly {
            // Bounded prefix index: frontmatter linting never scales with the Markdown body (`PERF-B2`).
            guard let prefix = FrontmatterLocator.prefixIndex(of: snapshot.text) else { return [] }
            return lint(index: prefix, frontmatterOnly: true)
        }
        return lint(index: MarkdownLineIndex(text: snapshot.text), frontmatterOnly: false)
    }

    /// Variant reusing a revision-cached `MarkdownLineIndex`.
    public static func lint(index: MarkdownLineIndex, frontmatterOnly: Bool = false) -> [MarkdownLintDiagnostic] {
        guard !index.units.isEmpty else { return [] }
        guard frontmatterOnly else { return lintLines(index, 0..<index.lineCount) }
        let count = index.frontmatterLineCount
        if count == 0 {
            guard opensFrontmatter(index) else { return [] }
            return [MarkdownLintDiagnostic(
                rule: .yamlUnterminatedFrontmatter, line: 1,
                message: "YML004 Frontmatter opened with '---' is not closed within \(YAMLFrontmatterScanner.maxLines) lines",
                range: index.lineRange(0)
            )]
        }
        return lintLines(index, 1..<(count - 1))
    }

    private static func opensFrontmatter(_ index: MarkdownLineIndex) -> Bool {
        guard index.lineCount > 1 else { return false }
        return YAMLLineTokenizer.tokens(line: index.lineSlice(0)).first?.kind == .documentMarker
            && index.lineSlice(0).first == YAMLLineTokenizer.dash
    }

    private struct Level {
        let indent: Int
        var keys: Set<String>
    }

    private static func lintLines(_ index: MarkdownLineIndex, _ lines: Range<Int>) -> [MarkdownLintDiagnostic] {
        var out: [MarkdownLintDiagnostic] = []
        var stack: [Level] = []
        var step: Int?
        var blockScalarIndent: Int?
        var depthReported = false
        var depthCutoffIndent: Int?

        func report(_ rule: MarkdownLintRuleID, _ line: Int, _ message: String, _ range: TextRange) {
            guard out.count < YAMLSupportLimits.maxDiagnostics else { return }
            out.append(MarkdownLintDiagnostic(rule: rule, line: line + 1, message: "\(rule.code) \(message)", range: range))
        }

        for line in lines {
            if out.count >= YAMLSupportLimits.maxDiagnostics { break }
            let range = index.lineRange(line)
            guard range.length > 0, range.length <= YAMLSupportLimits.maxLineUTF16 else { continue }
            let slice = index.lineSlice(line)
            var indent = 0
            var hasTab = false
            for u in slice {
                if u == YAMLLineTokenizer.space { indent += 1 } else if u == YAMLLineTokenizer.tab { hasTab = true; indent += 1 } else { break }
            }
            guard indent < slice.count else { continue } // blank line
            if let scalarIndent = blockScalarIndent {
                if indent > scalarIndent { continue }
                blockScalarIndent = nil
            }
            if let cutoff = depthCutoffIndent {
                if indent > cutoff { continue }
                depthCutoffIndent = nil
            }
            if hasTab {
                report(.yamlTabIndentation, line, "Indentation uses a tab character; YAML requires spaces", TextRange(location: range.location, length: indent))
                continue
            }
            let tokens = YAMLLineTokenizer.tokens(line: slice)
            guard let first = tokens.first, first.kind != .comment, first.kind != .documentMarker else { continue }
            let hasDash = first.kind == .listDash
            guard let keyToken = tokens.first(where: { $0.kind == .key }) else { continue }
            let column = keyToken.range.location
            let keyText = normalizedKey(slice, keyToken.range)
            let keyRange = TextRange(location: range.location + keyToken.range.location, length: keyToken.range.length)

            while let top = stack.last, top.indent > column || (hasDash && top.indent >= column) { stack.removeLast() }
            if let top = stack.last, top.indent == column {
                if stack[stack.count - 1].keys.contains(keyText) {
                    report(.yamlDuplicateKey, line, "Duplicate key '\(keyText)' in the same mapping", keyRange)
                } else {
                    stack[stack.count - 1].keys.insert(keyText)
                }
            } else {
                let parentIndent = stack.last?.indent ?? 0
                if !hasDash, !stack.isEmpty {
                    let delta = column - parentIndent
                    if let step, delta != step {
                        report(.yamlInconsistentIndent, line, "Indentation step of \(delta) spaces differs from the document step of \(step)", keyRange)
                    } else if step == nil {
                        step = delta
                    }
                } else if !hasDash, stack.isEmpty, column > 0 {
                    report(.yamlInconsistentIndent, line, "Top-level key is indented by \(column) spaces", keyRange)
                }
                if stack.count >= YAMLSupportLimits.maxDepth {
                    if !depthReported {
                        depthReported = true
                        report(.yamlNestingTooDeep, line, "Nesting deeper than \(YAMLSupportLimits.maxDepth) levels is not inspected", keyRange)
                    }
                    depthCutoffIndent = stack.last?.indent
                    continue
                }
                stack.append(Level(indent: column, keys: [keyText]))
            }
            if tokens.last(where: { $0.kind != .comment })?.kind == .blockScalarIndicator { blockScalarIndent = indent }
        }
        return out
    }

    /// Key text without surrounding quotes, used only for duplicate detection and messages.
    private static func normalizedKey(_ slice: ArraySlice<UInt16>, _ range: TextRange) -> String {
        let start = slice.startIndex + range.location
        var units = Array(slice[start..<(start + range.length)])
        if units.count >= 2, let f = units.first, f == units.last, f == YAMLLineTokenizer.dquote || f == YAMLLineTokenizer.squote {
            units = Array(units.dropFirst().dropLast())
        }
        return String(decoding: units, as: UTF16.self)
    }
}
