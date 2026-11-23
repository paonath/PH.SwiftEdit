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

    /// Single-pass `O(N + K)` reconstruction replacing the previous `O(K * N)` `NSMutableString` shifting loop (`edits` are sorted & non-overlapping).
    private static func apply(_ edits: [TextEdit], to text: String) -> String {
        guard !edits.isEmpty else { return text }
        let srcUnits = Array(text.utf16)
        let srcCount = srcUnits.count
        var estimatedLen = srcCount
        for e in edits where e.range.location >= 0 && e.range.upperBound <= srcCount {
            estimatedLen += e.replacement.utf16.count - e.range.length
        }
        var outUnits: [UInt16] = []
        outUnits.reserveCapacity(max(0, estimatedLen))
        var cursor = 0
        for e in edits {
            guard e.range.location >= cursor, e.range.upperBound <= srcCount else { continue }
            if e.range.location > cursor {
                outUnits.append(contentsOf: srcUnits[cursor..<e.range.location])
            }
            if !e.replacement.isEmpty {
                outUnits.append(contentsOf: e.replacement.utf16)
            }
            cursor = e.range.upperBound
        }
        if cursor < srcCount {
            outUnits.append(contentsOf: srcUnits[cursor..<srcCount])
        }
        return String(decoding: outUnits, as: UTF16.self)
    }

    private static func minimalEdit(from old: String, to new: String) -> TextEdit {
        let a = old.utf16
        let b = new.utf16
        var aStart = a.startIndex
        var bStart = b.startIndex
        var prefix = 0
        while aStart < a.endIndex, bStart < b.endIndex, a[aStart] == b[bStart] {
            aStart = a.index(after: aStart)
            bStart = b.index(after: bStart)
            prefix += 1
        }
        var aEnd = a.endIndex
        var bEnd = b.endIndex
        while aEnd > aStart, bEnd > bStart {
            let aPrev = a.index(before: aEnd)
            let bPrev = b.index(before: bEnd)
            if a[aPrev] != b[bPrev] { break }
            aEnd = aPrev
            bEnd = bPrev
        }
        let removedLen = a.distance(from: aStart, to: aEnd)
        let replacement = String(decoding: b[bStart..<bEnd], as: UTF16.self)
        return TextEdit(range: TextRange(location: prefix, length: removedLen), replacement: replacement)
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
        case .active(let count): return "Lint: \(count)" // plain text; the status bar draws the icon (V-01)
        }
    }

    /// Off for plain-text and binary snapshots, Paused for degraded buffers, Active for Markdown and YAML tabs (`REQ-003`).
    public static func classify(language: DocumentLanguage, snapshot: DocumentSnapshot, diagnosticCount: Int) -> ActiveLintStatus {
        guard language != .plainText, language != .log, !snapshot.isBinaryReadOnly else { return .off }
        if snapshot.isDegradedPlainText { return .paused }
        return .active(count: diagnosticCount)
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
