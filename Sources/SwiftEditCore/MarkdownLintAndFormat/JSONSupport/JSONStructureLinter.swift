import Foundation

/// Iterative stack-based structural linter for `.json` and `.jsonl` snapshots (`REQ-010`, `BC-004`, `CWE-674`, `SEC-012`).
///
/// Enforces `maxDepth = 128` iteratively with zero recursion (`CWE-674`) and caps diagnostics at `maxDiagnostics = 128` (`CWE-400`).
public enum JSONStructureLinter {
    public static let maxDepth = 128
    public static let maxDiagnostics = 128

    /// Validates JSON or JSON Lines syntax iteratively with zero recursion, reporting `JSN003` when nesting exceeds `maxDepth` (`128`).
    public static func lint(snapshot: DocumentSnapshot, isJSONLines: Bool = false) -> [MarkdownLintDiagnostic] {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return [] }
        let trimmed = snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let effectiveJSONL = isJSONLines || (snapshot.text.contains("\n") && looksLikeJSONLines(trimmed))
        if effectiveJSONL {
            return lintJSONLines(snapshot: snapshot, enforceDepthCap: true)
        }
        return validateSingleJSONPayload(text: snapshot.text, baseLine: 1, baseUTF16Offset: 0, enforceDepthCap: true)
    }

    private static func looksLikeJSONLines(_ trimmed: String) -> Bool {
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return false }
        return lines.allSatisfy { l in
            let t = l.trimmingCharacters(in: .whitespaces)
            return (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]"))
        }
    }

    private static func lintJSONLines(snapshot: DocumentSnapshot, enforceDepthCap: Bool = false) -> [MarkdownLintDiagnostic] {
        let index = MarkdownLineIndex(text: snapshot.text)
        var diagnostics: [MarkdownLintDiagnostic] = []
        for line in 0..<index.lineCount {
            guard diagnostics.count < maxDiagnostics else { break }
            let range = index.lineRange(line)
            guard range.length > 0 else { continue }
            let slice = index.lineSlice(line)
            let lineText = String(decoding: slice, as: UTF16.self)
            if lineText.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let lineDiags = validateSingleJSONPayload(
                text: lineText,
                baseLine: line + 1,
                baseUTF16Offset: range.location,
                enforceDepthCap: enforceDepthCap
            )
            diagnostics.append(contentsOf: lineDiags.prefix(maxDiagnostics - diagnostics.count))
        }
        return diagnostics
    }
}

extension JSONStructureLinter {
    fileprivate enum ContainerKind {
        case object
        case array
    }

    fileprivate enum ExpectedToken {
        case valueOrClose
        case valueOnly
        case keyOrClose
        case keyOnly
        case colon
        case commaOrClose
    }

    fileprivate struct ScannerState {
        let units: [UInt16]
        let baseLine: Int
        let baseOffset: Int
        let enforceDepthCap: Bool
        var cursor: Int = 0
        var line: Int
        var stack: [ContainerKind] = []
        var expected: ExpectedToken = .valueOnly
        var hasRootValue = false

        init(units: [UInt16], baseLine: Int, baseOffset: Int, enforceDepthCap: Bool) {
            self.units = units
            self.baseLine = baseLine
            self.baseOffset = baseOffset
            self.enforceDepthCap = enforceDepthCap
            self.line = baseLine
        }
    }

    fileprivate static func validateSingleJSONPayload(
        text: String,
        baseLine: Int,
        baseUTF16Offset: Int,
        enforceDepthCap: Bool
    ) -> [MarkdownLintDiagnostic] {
        var state = ScannerState(
            units: Array(text.utf16),
            baseLine: baseLine,
            baseOffset: baseUTF16Offset,
            enforceDepthCap: enforceDepthCap
        )
        while skipJSONWhitespace(&state) {
            if let diag = advanceJSONToken(&state) {
                return [diag]
            }
        }
        if !state.stack.isEmpty {
            return [makeDiagnostic(.jsonSyntaxError, line: state.line, at: max(0, state.units.count - 1), baseOffset: baseUTF16Offset, detail: "Unclosed JSON container at end of document")]
        }
        if !state.hasRootValue || state.expected == .valueOnly || state.expected == .keyOnly || state.expected == .colon {
            return [makeDiagnostic(.jsonSyntaxError, line: state.line, at: max(0, state.units.count - 1), baseOffset: baseUTF16Offset, detail: "Incomplete JSON value")]
        }
        return []
    }

    private static func skipJSONWhitespace(_ state: inout ScannerState) -> Bool {
        while state.cursor < state.units.count {
            let u = state.units[state.cursor]
            if u == 0x20 || u == 0x09 {
                state.cursor += 1
            } else if u == 0x0A {
                state.line += 1
                state.cursor += 1
            } else if u == 0x0D {
                state.line += 1
                state.cursor += (state.cursor + 1 < state.units.count && state.units[state.cursor + 1] == 0x0A) ? 2 : 1
            } else {
                return true
            }
        }
        return false
    }

    private static func advanceJSONToken(_ state: inout ScannerState) -> MarkdownLintDiagnostic? {
        if state.hasRootValue && state.stack.isEmpty {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unexpected trailing token after top-level JSON value")
        }
        let u = state.units[state.cursor]
        switch u {
        case 0x7B, 0x5B, 0x7D, 0x5D, 0x3A, 0x2C:
            return consumeStructuralDelimiter(u, state: &state)
        case 0x22:
            return consumeString(&state)
        default:
            return consumeScalarValue(&state)
        }
    }

    private static func consumeStructuralDelimiter(_ u: UInt16, state: inout ScannerState) -> MarkdownLintDiagnostic? {
        switch u {
        case 0x7B, 0x5B:
            return consumeOpenContainer(u, state: &state)
        case 0x7D, 0x5D:
            return consumeCloseContainer(u, state: &state)
        case 0x3A:
            return consumeColon(&state)
        default:
            return consumeComma(&state)
        }
    }

    private static func consumeColon(_ state: inout ScannerState) -> MarkdownLintDiagnostic? {
        guard state.expected == .colon else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unexpected ':'")
        }
        state.cursor += 1
        state.expected = .valueOnly
        return nil
    }

    private static func consumeOpenContainer(_ u: UInt16, state: inout ScannerState) -> MarkdownLintDiagnostic? {
        guard state.expected == .valueOnly || state.expected == .valueOrClose else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unexpected opening delimiter")
        }
        if state.enforceDepthCap && state.stack.count >= maxDepth {
            return makeDiagnostic(.jsonNestingTooDeep, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Nesting exceeds \(maxDepth) levels")
        }
        let kind: ContainerKind = (u == 0x7B) ? .object : .array
        state.stack.append(kind)
        state.cursor += 1
        state.expected = (kind == .object) ? .keyOrClose : .valueOrClose
        state.hasRootValue = true
        return nil
    }

    private static func consumeCloseContainer(_ u: UInt16, state: inout ScannerState) -> MarkdownLintDiagnostic? {
        if state.expected == .keyOnly || state.expected == .valueOnly {
            return makeDiagnostic(.jsonTrailingComma, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Trailing comma before closing delimiter")
        }
        guard state.expected == .keyOrClose || state.expected == .valueOrClose || state.expected == .commaOrClose,
              let top = state.stack.popLast() else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unexpected closing delimiter")
        }
        let matches = (top == .object && u == 0x7D) || (top == .array && u == 0x5D)
        guard matches else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Mismatched closing delimiter")
        }
        state.cursor += 1
        state.expected = .commaOrClose
        return nil
    }

    private static func consumeComma(_ state: inout ScannerState) -> MarkdownLintDiagnostic? {
        guard state.expected == .commaOrClose, let top = state.stack.last else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unexpected ','")
        }
        state.cursor += 1
        state.expected = (top == .object) ? .keyOnly : .valueOnly
        return nil
    }

    private static func consumeString(_ state: inout ScannerState) -> MarkdownLintDiagnostic? {
        let isKey = (state.expected == .keyOrClose || state.expected == .keyOnly)
        guard isKey || state.expected == .valueOnly || state.expected == .valueOrClose else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unexpected string literal")
        }
        let openPos = state.cursor
        state.cursor += 1
        while state.cursor < state.units.count {
            let ch = state.units[state.cursor]
            if ch == 0x22 {
                state.cursor += 1
                state.hasRootValue = true
                state.expected = isKey ? .colon : .commaOrClose
                return nil
            }
            if ch < 0x20 {
                return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Unescaped control character in JSON string")
            }
            if ch == 0x5C {
                state.cursor += 1
                guard state.cursor < state.units.count else { break }
            }
            state.cursor += 1
        }
        return makeDiagnostic(.jsonSyntaxError, line: state.line, at: openPos, baseOffset: state.baseOffset, detail: "Unterminated JSON string literal")
    }

    private static func consumeScalarValue(_ state: inout ScannerState) -> MarkdownLintDiagnostic? {
        guard state.expected == .valueOnly || state.expected == .valueOrClose else {
            return makeDiagnostic(.jsonSyntaxError, line: state.line, at: state.cursor, baseOffset: state.baseOffset, detail: "Expected object key or delimiter")
        }
        let start = state.cursor
        let u = state.units[start]
        if u == 0x2D || (u >= 0x30 && u <= 0x39) {
            while state.cursor < state.units.count, isJSONNumberChar(state.units[state.cursor]) {
                state.cursor += 1
            }
            let raw = String(decoding: state.units[start..<state.cursor], as: UTF16.self)
            guard Double(raw) != nil else {
                return makeDiagnostic(.jsonSyntaxError, line: state.line, at: start, baseOffset: state.baseOffset, detail: "Malformed JSON number")
            }
            state.hasRootValue = true
            state.expected = .commaOrClose
            return nil
        }
        for literal in ["true", "false", "null"] {
            let litUnits = Array(literal.utf16)
            if start + litUnits.count <= state.units.count,
               Array(state.units[start..<(start + litUnits.count)]) == litUnits {
                state.cursor += litUnits.count
                state.hasRootValue = true
                state.expected = .commaOrClose
                return nil
            }
        }
        return makeDiagnostic(.jsonSyntaxError, line: state.line, at: start, baseOffset: state.baseOffset, detail: "Invalid JSON token")
    }

    private static func isJSONNumberChar(_ u: UInt16) -> Bool {
        (u >= 0x30 && u <= 0x39) || u == 0x2E || u == 0x65 || u == 0x45 || u == 0x2B || u == 0x2D
    }

    private static func makeDiagnostic(
        _ rule: MarkdownLintRuleID,
        line: Int,
        at cursor: Int,
        baseOffset: Int,
        detail: String
    ) -> MarkdownLintDiagnostic {
        MarkdownLintDiagnostic(
            rule: rule,
            line: line,
            message: "\(rule.code) \(detail)",
            range: TextRange(location: baseOffset + max(0, cursor), length: 1)
        )
    }
}
