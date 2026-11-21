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
        let firstHash: UInt64
        let firstRange: Range<Int>
        var smallKeys: [(hash: UInt64, range: Range<Int>)]?
        var table: [UInt64: Range<Int>]?
        var collisions: [UInt64: [Range<Int>]]?

        init(indent: Int, firstHash: UInt64, firstRange: Range<Int>) {
            self.indent = indent
            self.firstHash = firstHash
            self.firstRange = firstRange
        }

        mutating func containsOrInsert(hash: UInt64, range: Range<Int>, in units: [UInt16]) -> Bool {
            if hash == firstHash, slicesEqual(units, firstRange, range) { return true }
            if var table {
                if let existing = table[hash] {
                    if slicesEqual(units, existing, range) { return true }
                    if var list = collisions?[hash] {
                        for r in list where slicesEqual(units, r, range) { return true }
                        list.append(range)
                        collisions?[hash] = list
                    } else {
                        var map = collisions ?? [:]
                        map[hash] = [range]
                        collisions = map
                    }
                    return false
                }
                table[hash] = range
                self.table = table
                return false
            }
            if let small = smallKeys {
                for entry in small where entry.hash == hash && slicesEqual(units, entry.range, range) {
                    return true
                }
                if small.count < 8 {
                    var updated = small
                    updated.append((hash, range))
                    smallKeys = updated
                    return false
                }
                var map: [UInt64: Range<Int>] = Dictionary(minimumCapacity: 16)
                map[firstHash] = firstRange
                for entry in small {
                    insertPromoted(hash: entry.hash, range: entry.range, into: &map)
                }
                insertPromoted(hash: hash, range: range, into: &map)
                smallKeys = nil
                table = map
                return false
            }
            smallKeys = [(hash, range)]
            return false
        }

        private mutating func insertPromoted(hash: UInt64, range: Range<Int>, into map: inout [UInt64: Range<Int>]) {
            if map[hash] == nil {
                map[hash] = range
            } else {
                var col = collisions ?? [:]
                col[hash, default: []].append(range)
                collisions = col
            }
        }
    }

    private static func slicesEqual(_ units: [UInt16], _ lhs: Range<Int>, _ rhs: Range<Int>) -> Bool {
        let len = lhs.count
        guard len == rhs.count else { return false }
        var i = lhs.lowerBound
        var j = rhs.lowerBound
        let end = lhs.upperBound
        while i < end {
            if units[i] != units[j] { return false }
            i += 1
            j += 1
        }
        return true
    }

    private static func keyHash(_ units: [UInt16], range: Range<Int>) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for i in range {
            hash ^= UInt64(units[i])
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private static func lintLines(_ index: MarkdownLineIndex, _ lines: Range<Int>) -> [MarkdownLintDiagnostic] {
        var out: [MarkdownLintDiagnostic] = []
        var stack: [Level] = []
        var step: Int?
        var blockScalarIndent: Int?
        var depthReported = false
        var depthCutoffIndent: Int?
        let units = index.units

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
            let inspected = YAMLLineTokenizer.inspectStructure(line: slice, indent: indent)
            guard !inspected.isIgnored, let keyRelRange = inspected.keyRange else { continue }
            let hasDash = inspected.hasDash
            let column = keyRelRange.location
            let normRange = normalizedKeyRange(units, sliceStart: slice.startIndex, keyRelRange)
            let keyRange = TextRange(location: range.location + column, length: keyRelRange.length)
            let hash = keyHash(units, range: normRange)

            while let top = stack.last, top.indent > column || (hasDash && top.indent >= column) { stack.removeLast() }
            if let top = stack.last, top.indent == column {
                if stack[stack.count - 1].containsOrInsert(hash: hash, range: normRange, in: units) {
                    let keyText = String(decoding: units[normRange], as: UTF16.self)
                    report(.yamlDuplicateKey, line, "Duplicate key '\(keyText)' in the same mapping", keyRange)
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
                stack.append(Level(indent: column, firstHash: hash, firstRange: normRange))
            }
            if inspected.endsWithBlockScalar { blockScalarIndent = indent }
        }
        return out
    }

    /// Unquoted key range in `index.units`, used for zero-allocation duplicate detection and error messages.
    private static func normalizedKeyRange(_ units: [UInt16], sliceStart: Int, _ range: TextRange) -> Range<Int> {
        var start = sliceStart + range.location
        var end = start + range.length
        if end - start >= 2 {
            let f = units[start]
            if f == units[end - 1], f == YAMLLineTokenizer.dquote || f == YAMLLineTokenizer.squote {
                start += 1
                end -= 1
            }
        }
        return start..<end
    }
}
