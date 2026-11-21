import Foundation
import Observation
import SwiftEditCore

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// `@MainActor` TextKit 2 buffer adapter keeping live text inside `NSTextContentStorage` and applying scoped `performEditingTransaction` updates without whole-document `ensureLayout` calls (`AR-003`, `UI-006`, `UI-007`, `UI-012`).
@MainActor
public final class TextKit2BufferAdapter {
    private static let viewportHighlightKey = NSAttributedString.Key("PH.SwiftEdit.ViewportHighlight")

    #if os(macOS) || os(iOS)
    public let textContentStorage = NSTextContentStorage()
    #else
    private var fallbackString: String = ""
    #endif

    public private(set) var scopedTransactionCount: Int = 0
    public private(set) var lastHighlightedRange: SwiftEditCore.TextRange?

    public init(initialText: String = "") {
        replaceEntireStorage(with: initialText)
    }

    /// Current buffer string backed directly by `NSTextContentStorage` without per-keystroke SwiftUI copies (`UI-006`).
    public var currentString: String {
        #if os(macOS) || os(iOS)
        return textContentStorage.textStorage?.string ?? ""
        #else
        return fallbackString
        #endif
    }

    /// Replaces the entire `NSTextContentStorage` string inside a single editing transaction.
    public func replaceEntireStorage(with text: String) {
        #if os(macOS) || os(iOS)
        textContentStorage.performEditingTransaction {
            if let storage = textContentStorage.textStorage {
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            } else {
                textContentStorage.attributedString = NSAttributedString(string: text)
            }
        }
        #else
        fallbackString = text
        #endif
        scopedTransactionCount += 1
    }

    /// Applies an ordered batch of `TextEdit` replacements inside a single `NSTextContentStorage.performEditingTransaction` (`UI-007`).
    public func applyScopedEdits(_ edits: [TextEdit]) {
        guard !edits.isEmpty else { return }
        let sorted = edits.sorted { $0.range.location > $1.range.location }
        #if os(macOS) || os(iOS)
        textContentStorage.performEditingTransaction {
            guard let storage = textContentStorage.textStorage else { return }
            for edit in sorted {
                let nsRange = NSRange(location: edit.range.location, length: edit.range.length)
                if NSMaxRange(nsRange) <= storage.length {
                    storage.replaceCharacters(in: nsRange, with: edit.replacement)
                }
            }
        }
        #else
        for edit in sorted {
            if let range = Range(NSRange(location: edit.range.location, length: edit.range.length), in: fallbackString) {
                fallbackString.replaceSubrange(range, with: edit.replacement)
            }
        }
        #endif
        scopedTransactionCount += 1
    }

    /// Applies highlight attributes strictly to `viewportRange` inside `performEditingTransaction` without invoking whole-document layout (`UI-007`, `UI-012`).
    public func applyViewportHighlight(in viewportRange: SwiftEditCore.TextRange) {
        #if os(macOS) || os(iOS)
        let maxLen = textContentStorage.textStorage?.length ?? 0
        let clampedStart = min(max(0, viewportRange.location), maxLen)
        let clampedLen = min(max(0, viewportRange.length), maxLen - clampedStart)
        let clampedRange = SwiftEditCore.TextRange(location: clampedStart, length: clampedLen)
        guard clampedRange != lastHighlightedRange else { return }
        let previousRange = lastHighlightedRange
        textContentStorage.performEditingTransaction {
            guard let storage = textContentStorage.textStorage else { return }
            if let prev = previousRange, prev.length > 0 {
                let prevStart = min(max(0, prev.location), storage.length)
                let prevLen = min(prev.length, storage.length - prevStart)
                if prevLen > 0 {
                    storage.removeAttribute(Self.viewportHighlightKey, range: NSRange(location: prevStart, length: prevLen))
                }
            }
            if clampedRange.length > 0 {
                storage.addAttribute(
                    Self.viewportHighlightKey,
                    value: true,
                    range: NSRange(location: clampedRange.location, length: clampedRange.length)
                )
            }
        }
        #else
        let clampedRange = viewportRange
        guard clampedRange != lastHighlightedRange else { return }
        #endif
        lastHighlightedRange = clampedRange
        scopedTransactionCount += 1
    }
}

/// AST-projected Markdown preview block (`UI-006`).
public struct MarkdownPreviewBlock: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case heading
        case paragraph
        case codeBlock
        case rawHTML
    }

    public let kind: Kind
    public let text: String
    public let isInertPlainTextHTML: Bool

    public init(kind: Kind, text: String, isInertPlainTextHTML: Bool) {
        self.kind = kind
        self.text = text
        self.isInertPlainTextHTML = isInertPlainTextHTML
    }
}

/// VoiceOver accessibility metadata exposed by `WorkspaceEditorCoordinator` (`UI-010`).
public struct VoiceOverAccessibilityDescriptor: Equatable, Sendable {
    public let editorRoleLabel: String
    public let activeTabAnnouncement: String
    public let safetyWarningAnnouncement: String?

    public init(editorRoleLabel: String, activeTabAnnouncement: String, safetyWarningAnnouncement: String?) {
        self.editorRoleLabel = editorRoleLabel
        self.activeTabAnnouncement = activeTabAnnouncement
        self.safetyWarningAnnouncement = safetyWarningAnnouncement
    }
}

/// `@MainActor @Observable` workspace coordinator binding `DocumentSession`, `WorkspaceTabSession`, `PurpleThemePalette`, `EditorZoomController`, and `TextKit2BufferAdapter` (`UI-005..012`).
@MainActor
@Observable
public final class WorkspaceEditorCoordinator {
    public private(set) var activeSession: DocumentSession
    public private(set) var tabSession: WorkspaceTabSession
    public private(set) var appearanceMode: AppearanceMode
    public private(set) var palette: PurpleThemePalette
    public var zoomController: EditorZoomController
    public let bufferAdapter: TextKit2BufferAdapter
    public private(set) var safetyBanner: InspectionSafetyBannerState
    public private(set) var activeBracketPair: BracketPairSpan?
    public private(set) var lastErrorBannerMessage: String?
    public private(set) var reduceMotionEnabled: Bool = false
    public private(set) var bufferReloadCount: Int = 0
    private let systemDarkDetector: @MainActor () -> Bool
    @ObservationIgnored private var cachedBracketTopology: BracketTopology?
    @ObservationIgnored private var cachedPreviewKey: (DocumentID, BufferRevision)?
    @ObservationIgnored private var cachedPreviewBlocks: [MarkdownPreviewBlock] = []

    /// Returns `false` when system Reduce Motion is enabled (`UI-011`).
    public var shouldAnimateTransitions: Bool {
        !reduceMotionEnabled
    }

    public init(
        session: DocumentSession,
        title: String = "Untitled",
        appearanceMode: AppearanceMode = .black,
        systemDarkDetector: @escaping @MainActor () -> Bool = {
            #if os(macOS)
            return MacOSAppearanceSynchronizer.readUnmaskedSystemPrefersDark()
            #else
            return true
            #endif
        }
    ) {
        self.activeSession = session
        self.tabSession = WorkspaceTabSession()
        self.appearanceMode = appearanceMode
        self.systemDarkDetector = systemDarkDetector
        let initialDark = systemDarkDetector()
        self.palette = PurpleThemePalette.resolve(appearance: appearanceMode, systemPrefersDark: initialDark)
        self.zoomController = EditorZoomController()
        self.bufferAdapter = TextKit2BufferAdapter(initialText: session.text)
        self.bufferReloadCount = 1
        self.safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: session.snapshot)
        if !session.isBinaryReadOnly {
            try? self.tabSession.openOrActivate(
                snapshot: session.snapshot,
                title: title,
                fileURL: session.fileURL,
                isDirty: session.isDirty
            )
        }
    }

    /// Updates `appearanceMode` and `palette` dynamically without reloading open document buffers (`UI-003`).
    public func setAppearanceMode(_ mode: AppearanceMode, systemPrefersDark: Bool? = nil) {
        appearanceMode = mode
        let resolvedDark = systemPrefersDark ?? systemDarkDetector()
        palette = PurpleThemePalette.resolve(appearance: mode, systemPrefersDark: resolvedDark)
    }

    /// Updates Reduce Motion preference (`UI-011`).
    public func setReduceMotionEnabled(_ enabled: Bool) {
        reduceMotionEnabled = enabled
    }

    /// Executes `Cmd+D` smart duplication on `activeSession` or surfaces a non-destructive warning banner on read-only binary buffers (`UI-008`, `UI-009`).
    public func performCommandD(selection: SwiftEditCore.TextRange) {
        guard safetyBanner.canSave else {
            lastErrorBannerMessage = "Read-only binary file: Cmd+D duplication is disabled."
            return
        }
        do {
            _ = try activeSession.duplicateLineOrSelection(selection: selection)
            bufferAdapter.replaceEntireStorage(with: activeSession.text)
            refreshDerivedStateAfterMutation()
        } catch {
            lastErrorBannerMessage = "Invalid selection range for Cmd+D duplication."
        }
    }

    /// Formats the active Markdown buffer atomically or surfaces a non-destructive warning banner when formatting is disabled (`UI-008`, `UI-009`).
    public func formatDocument() {
        guard safetyBanner.canFormat else {
            lastErrorBannerMessage = "Formatting is disabled for binary or degraded plain-text files."
            return
        }
        let snap = activeSession.snapshot
        guard let batch = MarkdownLintAndFormatEngine.formatDocument(snapshot: snap).completedValue else {
            lastErrorBannerMessage = "Markdown formatting timed out or exceeded AST depth limits."
            return
        }
        do {
            _ = try activeSession.applyTextEdits(batch.edits, expectedRevision: snap.revision)
            bufferAdapter.applyScopedEdits(batch.edits)
            refreshDerivedStateAfterMutation()
        } catch {
            lastErrorBannerMessage = "Unable to apply Markdown formatting edits."
        }
    }

    /// Evaluates active bracket highlights at `caretLocation` in `O(log P + depth)` using a revision-cached `BracketTopology` and applies scoped viewport highlight attributes (`UI-007`, `PERF-002`).
    public func updateCaretAndHighlightViewport(caretLocation: Int, viewportRange: SwiftEditCore.TextRange) {
        let topology: BracketTopology?
        if let cached = cachedBracketTopology,
           cached.documentID == activeSession.id,
           cached.revision == activeSession.revision {
            topology = cached
        } else if let scanned = SearchDiffAndBracketEngine.scanTopology(in: activeSession.snapshot).completedValue {
            cachedBracketTopology = scanned
            topology = scanned
        } else {
            cachedBracketTopology = nil
            topology = nil
        }

        activeBracketPair = topology.flatMap {
            SearchDiffAndBracketEngine.resolveActivePair(in: $0, caretLocation: caretLocation)
        }
        bufferAdapter.applyViewportHighlight(in: viewportRange)
        try? tabSession.updateTabState(id: activeSession.id, caretLocation: caretLocation)
    }

    /// Projects Markdown blocks for native zero-WebKit preview, rendering raw HTML (`<script>`, `<iframe>`, etc.) strictly as inert literal plain text (`UI-006`, `SEC-004`).
    public func projectMarkdownPreview(from snapshot: DocumentSnapshot) -> [MarkdownPreviewBlock] {
        guard !snapshot.isBinaryReadOnly else { return [] }
        if let key = cachedPreviewKey, key.0 == snapshot.id, key.1 == snapshot.revision {
            return cachedPreviewBlocks
        }

        var blocks: [MarkdownPreviewBlock] = []
        var activeFence: (marker: Character, count: Int)?
        var codeBuffer: [Substring] = []

        let text = snapshot.text
        let utf8 = text.utf8
        var lineStart = utf8.startIndex
        var cursor = lineStart

        func processLine(_ line: Substring) {
            if let currentFence = activeFence {
                if Self.isClosingFence(line, marker: currentFence.marker, minCount: currentFence.count) {
                    blocks.append(MarkdownPreviewBlock(
                        kind: .codeBlock,
                        text: codeBuffer.joined(separator: "\n"),
                        isInertPlainTextHTML: false
                    ))
                    codeBuffer.removeAll(keepingCapacity: true)
                    activeFence = nil
                } else {
                    codeBuffer.append(line)
                }
                return
            }

            if let openedFence = Self.parseOpeningFence(line) {
                activeFence = openedFence
                codeBuffer.removeAll(keepingCapacity: true)
                return
            }

            let trimmed = Self.trimHorizontalWhitespace(line)
            guard !trimmed.isEmpty else { return }

            if let headingText = Self.extractATXHeadingText(from: trimmed) {
                blocks.append(MarkdownPreviewBlock(kind: .heading, text: headingText, isInertPlainTextHTML: false))
            } else if Self.containsRawHTMLTag(trimmed) {
                blocks.append(MarkdownPreviewBlock(kind: .rawHTML, text: String(trimmed), isInertPlainTextHTML: true))
            } else {
                blocks.append(MarkdownPreviewBlock(kind: .paragraph, text: String(trimmed), isInertPlainTextHTML: false))
            }
        }

        while cursor < utf8.endIndex {
            let b = utf8[cursor]
            if b == 0x0A {
                processLine(text[lineStart..<cursor])
                cursor = utf8.index(after: cursor)
                lineStart = cursor
            } else if b == 0x0D {
                processLine(text[lineStart..<cursor])
                let next = utf8.index(after: cursor)
                cursor = (next < utf8.endIndex && utf8[next] == 0x0A) ? utf8.index(after: next) : next
                lineStart = cursor
            } else {
                cursor = utf8.index(after: cursor)
            }
        }
        processLine(text[lineStart..<utf8.endIndex])

        if activeFence != nil {
            blocks.append(MarkdownPreviewBlock(
                kind: .codeBlock,
                text: codeBuffer.joined(separator: "\n"),
                isInertPlainTextHTML: false
            ))
        }

        cachedPreviewKey = (snapshot.id, snapshot.revision)
        cachedPreviewBlocks = blocks
        return blocks
    }

    private static func trimHorizontalWhitespace(_ line: Substring) -> Substring {
        var lo = line.startIndex
        var hi = line.endIndex
        while lo < hi && (line[lo] == " " || line[lo] == "\t") {
            lo = line.index(after: lo)
        }
        while hi > lo {
            let prev = line.index(before: hi)
            if line[prev] == " " || line[prev] == "\t" {
                hi = prev
            } else {
                break
            }
        }
        return line[lo..<hi]
    }

    private static func parseOpeningFence(_ line: Substring) -> (marker: Character, count: Int)? {
        var idx = line.startIndex
        var leadingSpaces = 0
        while idx < line.endIndex && line[idx] == " " && leadingSpaces < 4 {
            idx = line.index(after: idx)
            leadingSpaces += 1
        }
        guard leadingSpaces <= 3, idx < line.endIndex else { return nil }
        let first = line[idx]
        guard first == "`" || first == "~" else { return nil }
        var count = 0
        while idx < line.endIndex && line[idx] == first {
            idx = line.index(after: idx)
            count += 1
        }
        guard count >= 3 else { return nil }
        if first == "`" && line[idx...].contains("`") { return nil }
        return (first, count)
    }

    private static func isClosingFence(_ line: Substring, marker: Character, minCount: Int) -> Bool {
        var idx = line.startIndex
        var leadingSpaces = 0
        while idx < line.endIndex && line[idx] == " " && leadingSpaces < 4 {
            idx = line.index(after: idx)
            leadingSpaces += 1
        }
        guard leadingSpaces <= 3 else { return false }
        var count = 0
        while idx < line.endIndex && line[idx] == marker {
            idx = line.index(after: idx)
            count += 1
        }
        guard count >= minCount else { return false }
        while idx < line.endIndex {
            let ch = line[idx]
            if ch != " " && ch != "\t" { return false }
            idx = line.index(after: idx)
        }
        return true
    }

    private static func extractATXHeadingText(from trimmedLine: Substring) -> String? {
        var idx = trimmedLine.startIndex
        var hashCount = 0
        while idx < trimmedLine.endIndex && trimmedLine[idx] == "#" {
            idx = trimmedLine.index(after: idx)
            hashCount += 1
        }
        guard (1...6).contains(hashCount), idx < trimmedLine.endIndex else { return nil }
        let first = trimmedLine[idx]
        guard first == " " || first == "\t" else { return nil }
        while idx < trimmedLine.endIndex && (trimmedLine[idx] == " " || trimmedLine[idx] == "\t") {
            idx = trimmedLine.index(after: idx)
        }
        return String(trimmedLine[idx...])
    }

    private static func containsRawHTMLTag(_ line: Substring) -> Bool {
        guard let openIdx = line.firstIndex(of: "<"),
              let closeIdx = line[openIdx...].firstIndex(of: ">") else {
            return false
        }
        let afterOpen = line.index(after: openIdx)
        guard afterOpen < closeIdx else { return false }
        let firstTagChar = line[afterOpen]
        return firstTagChar.isLetter || firstTagChar == "/" || firstTagChar == "!"
    }

    /// Builds VoiceOver accessibility labels and safety warning announcements (`UI-010`).
    public func accessibilityDescriptor(activeTitle: String) -> VoiceOverAccessibilityDescriptor {
        let warning: String?
        if safetyBanner.isBinaryReadOnlyBannerVisible {
            warning = "Read-only binary file inspection"
        } else if !safetyBanner.bidiWarnings.isEmpty {
            warning = "Bidirectional control characters detected"
        } else {
            warning = nil
        }
        return VoiceOverAccessibilityDescriptor(
            editorRoleLabel: "SwiftEdit TextKit 2 Editor",
            activeTabAnnouncement: "Active tab: \(activeTitle)",
            safetyWarningAnnouncement: warning
        )
    }

    private func refreshDerivedStateAfterMutation() {
        lastErrorBannerMessage = nil
        safetyBanner = InspectionSafetyBannerState.evaluate(snapshot: activeSession.snapshot)
        try? tabSession.updateTabState(
            id: activeSession.id,
            isDirty: activeSession.isDirty,
            revision: activeSession.revision
        )
    }
}

/// Single aligned row for VS Code-style Side-by-Side File Compare views (`UI-007`).
public struct SideBySideDiffRow: Equatable, Sendable {
    public let lhsLineNumber: Int?
    public let lhsText: String?
    public let rhsLineNumber: Int?
    public let rhsText: String?
    public let kind: DiffHunkKind
    /// Left-hand pane semantic highlight kind (`BUG-020`: `.removed` for modified pairs).
    public let lhsKind: DiffHunkKind
    /// Right-hand pane semantic highlight kind (`BUG-020`: `.inserted` for modified pairs).
    public let rhsKind: DiffHunkKind

    public init(
        lhsLineNumber: Int?,
        lhsText: String?,
        rhsLineNumber: Int?,
        rhsText: String?,
        kind: DiffHunkKind,
        lhsKind: DiffHunkKind? = nil,
        rhsKind: DiffHunkKind? = nil
    ) {
        self.lhsLineNumber = lhsLineNumber
        self.lhsText = lhsText
        self.rhsLineNumber = rhsLineNumber
        self.rhsText = rhsText
        self.kind = kind
        self.lhsKind = lhsKind ?? ((kind == .inserted && lhsText != nil && rhsText != nil) ? .removed : kind)
        self.rhsKind = rhsKind ?? kind
    }
}

/// `@MainActor @Observable` coordinator projecting Myers `DiffHunk` sequences into Side-by-Side comparison rows (`UI-005`, `UI-007`).
@MainActor
@Observable
public final class DiffPaneCoordinator {
    public private(set) var rows: [SideBySideDiffRow] = []
    public private(set) var hasDifferences: Bool = false
    public private(set) var degradedReason: DegradedEvaluationReason?
    @ObservationIgnored private var lastComparedKey: (lhsID: DocumentID, lhsRev: BufferRevision, rhsID: DocumentID, rhsRev: BufferRevision)?

    public init() {}

    /// Evaluates `SearchDiffAndBracketEngine.computeMyersDiff` (with revision-pair memoization) and aligns adjacent `.removed`/`.inserted` pairs into Side-by-Side rows.
    public func compare(lhs: DocumentSnapshot, rhs: DocumentSnapshot) {
        if let last = lastComparedKey,
           last.lhsID == lhs.id, last.lhsRev == lhs.revision,
           last.rhsID == rhs.id, last.rhsRev == rhs.revision {
            return
        }
        switch SearchDiffAndBracketEngine.computeMyersDiff(lhs: lhs, rhs: rhs) {
        case .completed(let result):
            degradedReason = nil
            hasDifferences = result.hasDifferences
            rows = Self.alignSideBySideRows(from: result.hunks)
        case .degradedOrTimedOut(let reason):
            degradedReason = reason
            hasDifferences = false
            rows = []
        }
        lastComparedKey = (lhs.id, lhs.revision, rhs.id, rhs.revision)
    }

    /// Releases computed diff rows and error state when closing the diff pane or closing tabs (`MEM-003`).
    public func clear() {
        lastComparedKey = nil
        rows = []
        hasDifferences = false
        degradedReason = nil
    }

    private static func alignSideBySideRows(from hunks: [DiffHunk]) -> [SideBySideDiffRow] {
        var aligned: [SideBySideDiffRow] = []
        aligned.reserveCapacity(hunks.count)
        var index = 0

        while index < hunks.count {
            let current = hunks[index]
            switch current.kind {
            case .unchanged:
                aligned.append(SideBySideDiffRow(
                    lhsLineNumber: current.lhsLineNumber,
                    lhsText: current.lineText,
                    rhsLineNumber: current.rhsLineNumber,
                    rhsText: current.lineText,
                    kind: .unchanged
                ))
                index += 1
            case .removed:
                if index + 1 < hunks.count, hunks[index + 1].kind == .inserted {
                    let next = hunks[index + 1]
                    aligned.append(SideBySideDiffRow(
                        lhsLineNumber: current.lhsLineNumber,
                        lhsText: current.lineText,
                        rhsLineNumber: next.rhsLineNumber,
                        rhsText: next.lineText,
                        kind: .inserted,
                        lhsKind: .removed,
                        rhsKind: .inserted
                    ))
                    index += 2
                } else {
                    aligned.append(SideBySideDiffRow(
                        lhsLineNumber: current.lhsLineNumber,
                        lhsText: current.lineText,
                        rhsLineNumber: nil,
                        rhsText: nil,
                        kind: .removed
                    ))
                    index += 1
                }
            case .inserted:
                aligned.append(SideBySideDiffRow(
                    lhsLineNumber: nil,
                    lhsText: nil,
                    rhsLineNumber: current.rhsLineNumber,
                    rhsText: current.lineText,
                    kind: .inserted
                ))
                index += 1
            }
        }
        return aligned
    }
}
