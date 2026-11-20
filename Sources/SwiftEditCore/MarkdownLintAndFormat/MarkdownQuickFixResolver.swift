import Foundation

/// Result of a Quick-Fix / Fix All request (`BC-006`).
public enum QuickFixOutcome: Equatable, Sendable {
    case edit(MarkdownAuthoringEdit)
    /// The caller's `expectedRevision` no longer matches the snapshot (`CWE-362`).
    case stale
    case noFix
}

/// Idempotent, revision-pinned Fix All over the `.allConstructs` diagnostics (`BC-004`, `BC-006`, `BC-011`).
///
/// Overlapping or duplicate edits are dropped per pass, at most two bounded in-memory passes run, and the net change is returned as one minimal `TextEdit` so the UI performs a single `Cmd+Z` step. Security diagnostics never carry a fix, so those lines are never modified.
public enum MarkdownQuickFixResolver {
    public static let maxPasses = 2

    public static func fixAll(snapshot: DocumentSnapshot, expectedRevision: BufferRevision) -> QuickFixOutcome {
        guard snapshot.revision == expectedRevision else { return .stale }
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText else { return .noFix }
        var current = snapshot
        var text = snapshot.text
        for _ in 0..<maxPasses {
            guard let result = MarkdownLintAndFormatEngine.lint(snapshot: current, profile: .allConstructs).completedValue else { break }
            let edits = resolveNonOverlapping(result.diagnostics.compactMap(\.quickFix))
            guard !edits.isEmpty else { break }
            let next = apply(edits, to: text)
            if next == text { break }
            text = next
            current = DocumentSnapshot(id: snapshot.id, revision: snapshot.revision, text: text, encoding: snapshot.encoding, lineEnding: snapshot.lineEnding, isDegradedPlainText: false, isBinaryReadOnly: false)
        }
        guard text != snapshot.text else { return .noFix }
        let net = minimalEdit(from: snapshot.text, to: text)
        return .edit(MarkdownAuthoringEdit(edits: [net], newSelection: TextRange(location: net.range.location, length: 0)))
    }

    /// Sorts by location, removes duplicates, and keeps only non-overlapping edits (zero-length inserts at one location keep the first).
    static func resolveNonOverlapping(_ edits: [TextEdit]) -> [TextEdit] {
        let sorted = edits.enumerated().sorted {
            if $0.element.range.location != $1.element.range.location { return $0.element.range.location < $1.element.range.location }
            if $0.element.range.length != $1.element.range.length { return $0.element.range.length < $1.element.range.length }
            return $0.offset < $1.offset
        }.map(\.element)
        var kept: [TextEdit] = []
        var lastEnd = -1
        for edit in sorted {
            if let last = kept.last, last.range.location == edit.range.location, last.range.length == 0 || edit.range.length == 0 { continue }
            guard edit.range.location >= lastEnd else { continue }
            kept.append(edit)
            lastEnd = edit.range.upperBound
        }
        return kept
    }

    private static func apply(_ edits: [TextEdit], to text: String) -> String {
        let m = NSMutableString(string: text)
        for e in edits.sorted(by: { $0.range.location > $1.range.location }) {
            guard e.range.location >= 0, e.range.upperBound <= m.length else { continue }
            m.replaceCharacters(in: NSRange(location: e.range.location, length: e.range.length), with: e.replacement)
        }
        return m as String
    }

    private static func minimalEdit(from old: String, to new: String) -> TextEdit {
        let a = Array(old.utf16), b = Array(new.utf16)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let replacement = String(decoding: b[prefix..<(b.count - suffix)], as: UTF16.self)
        return TextEdit(range: TextRange(location: prefix, length: a.count - prefix - suffix), replacement: replacement)
    }
}

/// Lint status shown in the status bar (`UI-005`, `DATA-003`).
public enum ActiveLintStatus: Equatable, Sendable {
    case off, paused
    case active(count: Int)

    public var label: String {
        switch self {
        case .off: return "Lint: Off"
        case .paused: return "Lint: Paused"
        case .active(let count): return count == 0 ? "✓ Lint: 0" : "⚠ Lint: \(count)"
        }
    }

    /// Off for non-Markdown and binary snapshots, Paused for degraded buffers, Active otherwise.
    public static func classify(isMarkdownDocument: Bool, snapshot: DocumentSnapshot, diagnosticCount: Int) -> ActiveLintStatus {
        guard isMarkdownDocument, !snapshot.isBinaryReadOnly else { return .off }
        if snapshot.isDegradedPlainText { return .paused }
        return .active(count: diagnosticCount)
    }
}

/// Hides transient mid-typing warnings on the caret line only; unsafe link/image findings are never hidden (`SEC-004`).
public enum ActiveLineLintSuppressionPolicy {
    static let transientRules: Set<MarkdownLintRuleID> = [.trailingSpaces, .missingFenceLanguage, .tablePipeStyle, .tableColumnCountMismatch, .emptyLinkTarget, .missingImageAltText]

    public static func visibleDiagnostics(_ diagnostics: [MarkdownLintDiagnostic], caretLine: Int) -> [MarkdownLintDiagnostic] {
        diagnostics.filter { !($0.line == caretLine && transientRules.contains($0.rule)) }
    }
}
