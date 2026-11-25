import Foundation

/// Pure text transformation behind one `ElementContextualMenu` action (`REQ-020-04`).
///
/// New action families are added as new cases plus one `ElementContextualActionCatalog` group, without touching the UI.
public enum ElementContextualActionKind: Hashable, Sendable {
    case surround(SurroundStyle)
    /// Workbench action (not a text edit): send the selected text into the embedded terminal without pressing Return.
    case sendToTerminal
    /// Workbench action (not a text edit): duplicate the active document next to itself (`REQ-021-05`).
    case duplicateDocument
    /// Workbench action (not a text edit): expand the left Folder Navigator, navigate to the active document's containing directory, and select the file (`REQ-031-01`).
    case revealInFolderNavigator
    /// Workbench action (not a text edit): focus the active writable editor and dispatch native macOS Dictation (`startDictation:`) (`REQ-031-02`).
    case startDictationHere
}

/// Sanitized selection payload ready to be written into an embedded PTY without automatic execution (`CWE-78`, `CWE-150`, `CWE-400`).
public struct TerminalSelectionPayload: Equatable, Sendable {
    /// Upper bound on text sent to the embedded terminal (64 KiB) to avoid PTY stalls (`CWE-400`).
    public static let maxUTF16Length = 65_536

    /// Sanitized text with normalized `\n` line breaks, trailing line breaks removed, and unsafe control/ESC bytes stripped.
    public let text: String
    /// Number of lines in `text` (`>= 1`).
    public let lineCount: Int
    /// `true` when `text` spans more than one line (triggers explicit multiline warning before delivery).
    public var isMultiline: Bool { lineCount > 1 }

    /// Wire representation for PTY delivery: single-line text is sent as-is (no trailing Return);
    /// multiline text is framed with ANSI Bracketed Paste (`ESC[200~ ... ESC[201~`) when `bracketedPaste` is enabled.
    public func wireText(bracketedPaste: Bool) -> String {
        (isMultiline && bracketedPaste) ? "\u{1B}[200~\(text)\u{1B}[201~" : text
    }

    public init(text: String, lineCount: Int) {
        self.text = text
        self.lineCount = max(1, lineCount)
    }

    /// Extracts and sanitizes `selection` from `sourceText`, returning `nil` for binary, empty, overlong, or invalid ranges.
    public static func prepare(
        selection: TextRange,
        in sourceText: String,
        isBinaryReadOnly: Bool = false
    ) -> TerminalSelectionPayload? {
        guard let scalarRange = scalarSelectionRange(
            for: selection,
            in: sourceText,
            isBinaryReadOnly: isBinaryReadOnly
        ) else {
            return nil
        }
        let sanitized = sanitizeTerminalText(sourceText.unicodeScalars[scalarRange], capacity: selection.length)
        guard !sanitized.isEmpty else { return nil }
        let lines = sanitized.utf8.count(where: { $0 == 0x0A }) + 1
        return TerminalSelectionPayload(text: sanitized, lineCount: lines)
    }

    private static func scalarSelectionRange(
        for selection: TextRange,
        in sourceText: String,
        isBinaryReadOnly: Bool
    ) -> Range<String.UnicodeScalarView.Index>? {
        guard !isBinaryReadOnly,
              selection.location >= 0,
              selection.length > 0,
              selection.length <= maxUTF16Length else {
            return nil
        }
        let utf16 = sourceText.utf16
        guard let start = utf16.index(utf16.startIndex, offsetBy: selection.location, limitedBy: utf16.endIndex),
              let end = utf16.index(start, offsetBy: selection.length, limitedBy: utf16.endIndex),
              let scalarStart = start.samePosition(in: sourceText.unicodeScalars),
              let scalarEnd = end.samePosition(in: sourceText.unicodeScalars) else {
            return nil
        }
        return scalarStart..<scalarEnd
    }

    private static func sanitizeTerminalText(
        _ scalars: String.UnicodeScalarView.SubSequence,
        capacity: Int
    ) -> String {
        var sanitized = String()
        sanitized.reserveCapacity(capacity)
        var previousWasCR = false
        for scalar in scalars {
            appendSanitizedScalar(scalar, previousWasCR: &previousWasCR, into: &sanitized)
        }
        // Never append or forward trailing line breaks so sending text to the terminal NEVER auto-executes Return.
        while sanitized.last == "\n" {
            sanitized.removeLast()
        }
        return sanitized
    }

    private static func appendSanitizedScalar(
        _ scalar: UnicodeScalar,
        previousWasCR: inout Bool,
        into sanitized: inout String
    ) {
        let v = scalar.value
        if v == 0x0D { // CR
            sanitized.unicodeScalars.append(UnicodeScalar(0x0A)!)
            previousWasCR = true
            return
        }
        if v == 0x0A { // LF
            if !previousWasCR {
                sanitized.unicodeScalars.append(scalar)
            }
            previousWasCR = false
            return
        }
        previousWasCR = false
        // Strip C0 control characters (including ESC 0x1B to prevent terminal escape/bracketed-paste breakout)
        // and DEL (0x7F), preserving horizontal tab (0x09).
        if (v < 0x20 && v != 0x09) || v == 0x7F {
            return
        }
        sanitized.unicodeScalars.append(scalar)
    }
}

/// Delimiter pairs offered by the "Surround With…" group.
public enum SurroundStyle: String, CaseIterable, Hashable, Sendable {
    /// `` `text` ``
    case backtick
    /// Fenced block: `` ``` `` on its own line before and after the selection.
    case tripleBacktickFence
    /// `(text)`
    case parentheses
}

/// One selectable row of the contextual menu: stable id, label, monospaced preview and semantic `AppIcon` name.
public struct ElementContextualAction: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Short preview of the result rendered next to the title (display only).
    public let preview: String
    public let iconName: String
    public let kind: ElementContextualActionKind

    public init(id: String, title: String, preview: String, iconName: String, kind: ElementContextualActionKind) {
        self.id = id
        self.title = title
        self.preview = preview
        self.iconName = iconName
        self.kind = kind
    }
}

/// Expandable sub-menu of related actions (e.g. "Surround With…").
public struct ElementContextualActionGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String
    public let actions: [ElementContextualAction]
    /// `true` when every action needs a non-empty selection (hidden when nothing is selected).
    public let requiresSelection: Bool

    public init(id: String, title: String, iconName: String, actions: [ElementContextualAction], requiresSelection: Bool = true) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.actions = actions
        self.requiresSelection = requiresSelection
    }
}

/// Declarative registry of contextual actions plus their pure evaluators (`BC-006`, `SEC-012`).
///
/// Every evaluation yields exactly one `TextEdit` (one `BufferRevision`, one undo step) and leaves the original text
/// selected inside the new delimiters. Binary, degraded, empty or out-of-bounds selections yield `nil` (`CWE-20`).
public enum ElementContextualActionCatalog {
    /// Upper bound of a selection that can be transformed (`CWE-400`).
    public static let maxSelectionUTF16Length = 1_048_576

    public static let surroundGroup = ElementContextualActionGroup(
        id: "surround",
        title: "Surround With…",
        iconName: "code",
        actions: [
            ElementContextualAction(id: "surround.backtick", title: "Backticks", preview: "`…`", iconName: "code", kind: .surround(.backtick)),
            ElementContextualAction(id: "surround.fence", title: "Code Fence", preview: "```…```", iconName: "braces", kind: .surround(.tripleBacktickFence)),
            ElementContextualAction(id: "surround.parentheses", title: "Parentheses", preview: "(…)", iconName: "parentheses", kind: .surround(.parentheses)),
        ]
    )

    public static let terminalGroup = ElementContextualActionGroup(
        id: "terminal",
        title: "Terminal",
        iconName: "terminal",
        actions: [
            ElementContextualAction(
                id: "terminal.sendSelection",
                title: "Send to Terminal",
                preview: "paste (no ↩)",
                iconName: "terminal",
                kind: .sendToTerminal
            ),
        ],
        requiresSelection: true
    )

    /// Action descriptor for duplicating the active document (`REQ-021-05`).
    public static let duplicateDocumentAction = ElementContextualAction(
        id: "document.duplicate",
        title: "Duplicate Document",
        preview: "name copy",
        iconName: "duplicate",
        kind: .duplicateDocument
    )

    /// Action descriptor for revealing the active disk-backed document in the left Folder Navigator (`REQ-031-01`).
    public static let revealInFolderNavigatorAction = ElementContextualAction(
        id: "document.revealInFolderNavigator",
        title: "Reveal in Folder Navigator",
        preview: "sidebar",
        iconName: "folder",
        kind: .revealInFolderNavigator
    )

    /// Action descriptor for starting native macOS Dictation at the current editor caret (`REQ-031-02`).
    public static let startDictationHereAction = ElementContextualAction(
        id: "document.startDictationHere",
        title: "Start Dictation Here",
        preview: "macOS",
        iconName: "microphone",
        kind: .startDictationHere
    )

    public static let documentGroup = ElementContextualActionGroup(
        id: "document",
        title: "Document",
        iconName: "file",
        actions: [
            duplicateDocumentAction,
            revealInFolderNavigatorAction,
            startDictationHereAction,
        ],
        requiresSelection: false
    )

    /// All groups in display order. Append new groups here to extend the menu.
    public static let groups: [ElementContextualActionGroup] = [surroundGroup, terminalGroup, documentGroup]

    /// Groups available for the current caret: selection-only groups disappear when nothing is selected, and conditional document actions are filtered by capability flags (`REQ-021-05`, `REQ-031-01`, `REQ-031-02`).
    public static func groups(
        hasSelection: Bool,
        canRevealInFolderNavigator: Bool = false,
        canStartDictation: Bool = false
    ) -> [ElementContextualActionGroup] {
        var resolved: [ElementContextualActionGroup] = []
        for group in groups where hasSelection || !group.requiresSelection {
            if group.id == documentGroup.id {
                var docActions: [ElementContextualAction] = [duplicateDocumentAction]
                if canRevealInFolderNavigator {
                    docActions.append(revealInFolderNavigatorAction)
                }
                if canStartDictation {
                    docActions.append(startDictationHereAction)
                }
                resolved.append(
                    ElementContextualActionGroup(
                        id: group.id,
                        title: group.title,
                        iconName: group.iconName,
                        actions: docActions,
                        requiresSelection: group.requiresSelection
                    )
                )
            } else {
                resolved.append(group)
            }
        }
        return resolved
    }

    /// Computes the edit for `kind` over `selection`, or `nil` when it does not apply.
    public static func evaluate(_ kind: ElementContextualActionKind, in snapshot: DocumentSnapshot, selection: TextRange) -> MarkdownAuthoringEdit? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText,
              selection.location >= 0, selection.length > 0,
              selection.length <= maxSelectionUTF16Length else { return nil }
        let utf16 = snapshot.text.utf16
        guard let start = utf16.index(utf16.startIndex, offsetBy: selection.location, limitedBy: utf16.endIndex),
              let end = utf16.index(start, offsetBy: selection.length, limitedBy: utf16.endIndex),
              let scalarStart = start.samePosition(in: snapshot.text.unicodeScalars),
              let scalarEnd = end.samePosition(in: snapshot.text.unicodeScalars) else { return nil }
        switch kind {
        case .surround(let style):
            return surround(style, in: snapshot.text, range: scalarStart..<scalarEnd, selection: selection)
        case .sendToTerminal, .duplicateDocument, .revealInFolderNavigator, .startDictationHere:
            return nil
        }
    }

    private static func surround(
        _ style: SurroundStyle,
        in text: String,
        range: Range<String.Index>,
        selection: TextRange
    ) -> MarkdownAuthoringEdit {
        let inner = text[range]
        let opening: String
        let closing: String
        switch style {
        case .backtick:
            opening = "`"
            closing = "`"
        case .parentheses:
            opening = "("
            closing = ")"
        case .tripleBacktickFence:
            let utf16 = text.utf16
            let startsLine = range.lowerBound == utf16.startIndex
                || isLineBreak(utf16[utf16.index(before: range.lowerBound)])
            let endsWithBreak = inner.utf16.last.map(isLineBreak) ?? false
            let endsLine = range.upperBound == utf16.endIndex
                || isLineBreak(utf16[range.upperBound])
            opening = (startsLine ? "" : "\n") + "```\n"
            if endsWithBreak {
                closing = "```\n"
            } else {
                closing = "\n```" + (endsLine ? "" : "\n")
            }
        }
        let openingLength = opening.utf16.count
        var replacement = String()
        replacement.reserveCapacity(opening.utf8.count + inner.utf8.count + closing.utf8.count)
        replacement.append(opening)
        replacement.append(contentsOf: inner)
        replacement.append(closing)
        return MarkdownAuthoringEdit(
            edits: [TextEdit(range: selection, replacement: replacement)],
            newSelection: TextRange(location: selection.location + openingLength, length: selection.length)
        )
    }

    @inline(__always)
    private static func isLineBreak(_ unit: UInt16) -> Bool {
        unit == 0x0A || unit == 0x0D
    }
}
