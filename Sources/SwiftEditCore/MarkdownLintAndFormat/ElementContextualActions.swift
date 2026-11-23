import Foundation

/// Pure text transformation behind one `ElementContextualMenu` action (`REQ-020-04`).
///
/// New action families are added as new cases plus one `ElementContextualActionCatalog` group, without touching the UI.
public enum ElementContextualActionKind: Hashable, Sendable {
    case surround(SurroundStyle)
    /// Workbench action (not a text edit): duplicate the active document next to itself (`REQ-021-05`).
    case duplicateDocument
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

    public static let documentGroup = ElementContextualActionGroup(
        id: "document",
        title: "Document",
        iconName: "file",
        actions: [
            ElementContextualAction(id: "document.duplicate", title: "Duplicate Document", preview: "name copy", iconName: "duplicate", kind: .duplicateDocument),
        ],
        requiresSelection: false
    )

    /// All groups in display order. Append new groups here to extend the menu.
    public static let groups: [ElementContextualActionGroup] = [surroundGroup, documentGroup]

    /// Groups available for the current caret: selection-only groups disappear when nothing is selected (`REQ-021-05`).
    public static func groups(hasSelection: Bool) -> [ElementContextualActionGroup] {
        groups.filter { hasSelection || !$0.requiresSelection }
    }

    /// Computes the edit for `kind` over `selection`, or `nil` when it does not apply.
    public static func evaluate(_ kind: ElementContextualActionKind, in snapshot: DocumentSnapshot, selection: TextRange) -> MarkdownAuthoringEdit? {
        guard !snapshot.isBinaryReadOnly, !snapshot.isDegradedPlainText,
              selection.location >= 0, selection.length > 0,
              selection.length <= maxSelectionUTF16Length else { return nil }
        let text = snapshot.text as NSString
        guard selection.upperBound <= text.length else { return nil }
        switch kind {
        case .surround(let style):
            return surround(style, text: text, selection: selection)
        case .duplicateDocument:
            return nil
        }
    }

    private static func surround(_ style: SurroundStyle, text: NSString, selection: TextRange) -> MarkdownAuthoringEdit {
        let inner = text.substring(with: NSRange(location: selection.location, length: selection.length))
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
            let startsLine = selection.location == 0 || isLineBreak(text.character(at: selection.location - 1))
            let endsWithBreak = inner.hasSuffix("\n") || inner.hasSuffix("\r")
            let endsLine = selection.upperBound == text.length || isLineBreak(text.character(at: selection.upperBound))
            opening = (startsLine ? "" : "\n") + "```\n"
            if endsWithBreak {
                closing = "```\n"
            } else {
                closing = "\n```" + (endsLine ? "" : "\n")
            }
        }
        let openingLength = (opening as NSString).length
        return MarkdownAuthoringEdit(
            edits: [TextEdit(range: selection, replacement: opening + inner + closing)],
            newSelection: TextRange(location: selection.location + openingLength, length: selection.length)
        )
    }

    private static func isLineBreak(_ unit: unichar) -> Bool {
        unit == 0x0A || unit == 0x0D
    }
}
