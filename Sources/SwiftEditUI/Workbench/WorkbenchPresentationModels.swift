import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Non-mutating `@MainActor` visual highlight snapshot projecting active line, nested brackets, active pair, unbalanced brackets, and backtick code spans (`UI-005`, `UI-006`, `UI-012`).
public struct EditorHighlightProjection: Equatable, Sendable {
    public let activeLineRange: SwiftEditCore.TextRange
    public let bracketPairs: [BracketPairSpan]
    public let activeBracketPair: BracketPairSpan?
    public let unbalancedBrackets: [UnbalancedBracket]
    public let backtickSpans: [BacktickHighlightSpan]
    public let wordOccurrenceRanges: [SwiftEditCore.TextRange]

    public init(
        activeLineRange: SwiftEditCore.TextRange = SwiftEditCore.TextRange(location: 0, length: 0),
        bracketPairs: [BracketPairSpan] = [],
        activeBracketPair: BracketPairSpan? = nil,
        unbalancedBrackets: [UnbalancedBracket] = [],
        backtickSpans: [BacktickHighlightSpan] = [],
        wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    ) {
        self.activeLineRange = activeLineRange
        self.bracketPairs = bracketPairs
        self.activeBracketPair = activeBracketPair
        self.unbalancedBrackets = unbalancedBrackets
        self.backtickSpans = backtickSpans
        self.wordOccurrenceRanges = wordOccurrenceRanges
    }

    /// `O(log L)` variant reusing a per-revision `DocumentTextIndex` (zero `NSString` bridging per caret move).
    public static func evaluate(
        index: DocumentTextIndex,
        caretLocation: Int,
        bracketResult: BracketBalanceResult?,
        backtickResult: BacktickHighlightResult?,
        wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    ) -> EditorHighlightProjection {
        EditorHighlightProjection(
            activeLineRange: index.lineContentRange(atUTF16Offset: caretLocation),
            bracketPairs: bracketResult?.matchedPairs ?? [],
            activeBracketPair: bracketResult?.activePair,
            unbalancedBrackets: bracketResult?.unbalancedBrackets ?? [],
            backtickSpans: backtickResult?.spans ?? [],
            wordOccurrenceRanges: wordOccurrenceRanges
        )
    }

    /// Computes a deterministic highlight projection without mutating `session`, incrementing `BufferRevision`, or copying the full UTF-16 buffer (`PERF-007`).
    public static func evaluate(
        text: String,
        caretLocation: Int,
        bracketResult: BracketBalanceResult?,
        backtickResult: BacktickHighlightResult?,
        wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    ) -> EditorHighlightProjection {
        let nsString = text as NSString
        let clampedCaret = min(max(0, caretLocation), nsString.length)
        var lineRange = nsString.lineRange(for: NSRange(location: clampedCaret, length: 0))
        while lineRange.length > 0 {
            let unit = nsString.character(at: lineRange.location + lineRange.length - 1)
            if unit == 0x0A || unit == 0x0D {
                lineRange.length -= 1
            } else {
                break
            }
        }
        return EditorHighlightProjection(
            activeLineRange: SwiftEditCore.TextRange(location: lineRange.location, length: lineRange.length),
            bracketPairs: bracketResult?.matchedPairs ?? [],
            activeBracketPair: bracketResult?.activePair,
            unbalancedBrackets: bracketResult?.unbalancedBrackets ?? [],
            backtickSpans: backtickResult?.spans ?? [],
            wordOccurrenceRanges: wordOccurrenceRanges
        )
    }
}

/// Strictly percentage-based left sidebar sizing geometry avoiding hardcoded pixel bounds across displays (`UI-001`, `UI-005`).
public enum SidebarLayoutGeometry {
    /// Minimum sidebar width as a fraction (`12%`) of the window/container width.
    public static let minWidthRatio: Double = 0.12
    /// Maximum sidebar width as a fraction (`65%`) of the window/container width.
    public static let maxWidthRatio: Double = 0.65
    /// Default expanded sidebar width as a fraction (`22%`) of the window/container width.
    public static let defaultWidthRatio: Double = 0.22

    /// Clamps any candidate sidebar ratio into `0.12...0.65`.
    public static func clampedRatio(_ rawRatio: Double) -> Double {
        guard rawRatio.isFinite else { return defaultWidthRatio }
        return min(max(rawRatio, minWidthRatio), maxWidthRatio)
    }

    /// Computes proportional sidebar width strictly from `containerWidth * clampedRatio(ratio)`; returns `0` for non-positive container widths.
    public static func resolvedWidth(forContainerWidth containerWidth: Double, ratio: Double) -> Double {
        guard containerWidth.isFinite, containerWidth > 0 else { return 0 }
        return containerWidth * clampedRatio(ratio)
    }

    /// Computes a clamped percentage ratio after dragging the divider by `dragDeltaWidth` inside `containerWidth`.
    public static func updatedRatio(currentRatio: Double, dragDeltaWidth: Double, containerWidth: Double) -> Double {
        guard containerWidth.isFinite, containerWidth > 0, dragDeltaWidth.isFinite else {
            return clampedRatio(currentRatio)
        }
        return clampedRatio(currentRatio + (dragDeltaWidth / containerWidth))
    }
}

/// Authoritative Help menu command titles exposed by `SwiftEditCommands` (`UI-009`, `UI-010`, `AR-014`).
public enum SwiftEditHelpMenuCatalog {
    public static let itemTitles: [String] = [
        "Keyboard Shortcuts CheatSheet",
        "About SwiftEdit",
    ]
}

/// Transient read-only presentation for NUL-bearing binary files excluded from persistent tabs, pinning, and `SessionRecovery` (`BUG-007`, `MEM-002`, `DATA-003`).
public struct BinaryInspectionPresentation: Equatable, Sendable {
    public let id: DocumentID
    public let title: String
    public let fileURL: URL
    public let snapshot: DocumentSnapshot

    public init(id: DocumentID, title: String, fileURL: URL, snapshot: DocumentSnapshot) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.snapshot = snapshot
    }
}

#endif

/// Presentation mode of the inline Find / Find & Replace / Go-to-Line bar (`Cmd+F`, `Opt+Cmd+F`, `Cmd+G`) (`UI-009`).
public enum FindBarPresentationMode: String, Equatable, Sendable {
    case hidden
    case find
    case findAndReplace
    case goToLine
}

/// User resolution choice for closing a dirty tab (`Cmd+W`) or quitting with unsaved changes (`Cmd+Q`) (`BC-008`, `DATA-006`).
public enum DirtyCloseDecision: Equatable, Sendable {
    case save
    case dontSave
    case cancel
}

/// Value-type state backing `FindReplaceGoToLineBar` and `SwiftEditWorkbenchModel` search/navigation operations (`BC-004`, `BC-011`).
public struct FindReplaceBarState: Equatable, Sendable {
    public var mode: FindBarPresentationMode = .hidden
    public var query: String = ""
    public var replacement: String = ""
    public var isCaseSensitive: Bool = false
    public var goToLineText: String = ""
    public var matches: [SwiftEditCore.TextRange] = []
    public var activeMatchIndex: Int = 0

    public init() {}

    /// Advances `activeMatchIndex` forward modulo `matches.count` and returns the selected `TextRange` (`nil` when `matches` is empty).
    public mutating func selectNextMatch() -> SwiftEditCore.TextRange? {
        guard !matches.isEmpty else { return nil }
        activeMatchIndex = (activeMatchIndex + 1) % matches.count
        return matches[activeMatchIndex]
    }

    /// Moves `activeMatchIndex` backward modulo `matches.count` and returns the selected `TextRange` (`nil` when `matches` is empty).
    public mutating func selectPreviousMatch() -> SwiftEditCore.TextRange? {
        guard !matches.isEmpty else { return nil }
        activeMatchIndex = (activeMatchIndex - 1 + matches.count) % matches.count
        return matches[activeMatchIndex]
    }
}

/// Keyboard-driven state of the `Cmd+Return` contextual action palette (`REQ-020-04`, `AR-006`).
public struct ElementContextualMenuState: Equatable, Sendable {
    public enum Row: Equatable, Identifiable, Sendable {
        case group(ElementContextualActionGroup, isExpanded: Bool)
        case action(ElementContextualAction, groupID: String)

        public var id: String {
            switch self {
            case .group(let group, _): return "group:" + group.id
            case .action(let action, _): return "action:" + action.id
            }
        }
    }

    /// Selection captured when the palette opened; every action transforms exactly this range.
    public let selection: SwiftEditCore.TextRange
    /// Top-left anchor (window content coordinates, y down) just below the selection; `nil` centers the palette.
    public let anchor: CGPoint?
    public let groups: [ElementContextualActionGroup]
    public private(set) var query: String = ""
    public private(set) var expandedGroupIDs: Set<String>
    public private(set) var highlightedRowID: String?

    public init(
        selection: SwiftEditCore.TextRange,
        anchor: CGPoint? = nil,
        groups: [ElementContextualActionGroup]? = nil
    ) {
        self.selection = selection
        self.anchor = anchor
        let available = groups ?? ElementContextualActionCatalog.groups(hasSelection: selection.length > 0)
        self.groups = available
        expandedGroupIDs = Set(available.map(\.id))
        highlightedRowID = nil
        let initialRows = rows
        highlightedRowID = initialRows.first(where: { if case .action = $0 { return true } else { return false } })?.id ?? initialRows.first?.id
    }

    /// Visible rows in display order.
    public var rows: [Row] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        var result: [Row] = []
        for group in groups {
            if needle.isEmpty {
                let expanded = expandedGroupIDs.contains(group.id)
                result.append(.group(group, isExpanded: expanded))
                if expanded {
                    result.append(contentsOf: group.actions.map { .action($0, groupID: group.id) })
                }
            } else {
                let groupMatches = group.title.localizedCaseInsensitiveContains(needle)
                let matchingActions = group.actions.filter {
                    groupMatches || $0.title.localizedCaseInsensitiveContains(needle) || $0.preview.contains(needle)
                }
                guard !matchingActions.isEmpty else { continue }
                result.append(.group(group, isExpanded: true))
                result.append(contentsOf: matchingActions.map { .action($0, groupID: group.id) })
            }
        }
        return result
    }

    public var highlightedRow: Row? {
        rows.first { $0.id == highlightedRowID }
    }

    public mutating func setQuery(_ newValue: String) {
        query = String(newValue.prefix(80))
        let visible = rows
        let hasFilter = !query.trimmingCharacters(in: .whitespaces).isEmpty
        if hasFilter || !visible.contains(where: { $0.id == highlightedRowID }) {
            highlightedRowID = visible.first(where: { if case .action = $0 { return true } else { return false } })?.id ?? visible.first?.id
        }
    }

    /// Moves the highlight by `delta` rows, wrapping around.
    public mutating func moveHighlight(_ delta: Int) {
        let visible = rows
        guard !visible.isEmpty else { highlightedRowID = nil; return }
        if let current = visible.firstIndex(where: { $0.id == highlightedRowID }) {
            let next = ((current + delta) % visible.count + visible.count) % visible.count
            highlightedRowID = visible[next].id
        } else {
            let next = delta >= 0
                ? (delta > 0 ? (delta - 1) % visible.count : 0)
                : ((visible.count + (delta % visible.count)) % visible.count)
            highlightedRowID = visible[next].id
        }
    }

    public mutating func highlight(rowID: String) {
        if rows.contains(where: { $0.id == rowID }) { highlightedRowID = rowID }
    }

    /// Expands (`true`) or collapses (`false`) the group owning the highlighted row.
    public mutating func setHighlightedGroupExpanded(_ expanded: Bool) {
        guard let row = highlightedRow else { return }
        let groupID: String
        switch row {
        case .group(let group, _): groupID = group.id
        case .action(_, let owner): groupID = owner
        }
        if expanded {
            expandedGroupIDs.insert(groupID)
        } else {
            expandedGroupIDs.remove(groupID)
            highlightedRowID = "group:" + groupID
        }
    }

    public mutating func toggleGroup(_ groupID: String) {
        if expandedGroupIDs.contains(groupID) {
            expandedGroupIDs.remove(groupID)
        } else {
            expandedGroupIDs.insert(groupID)
        }
        highlightedRowID = "group:" + groupID
    }
}
