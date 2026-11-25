import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit


/// Isolates `NSUndoManager` instances per `DocumentID` so tab closures, FindBar edits, and multi-tab switches never share or dangle ObjC undo targets (`BUG-001`, `CWE-416`, `AR-010`).
@MainActor
public final class PerTabUndoManagerRegistry {
    private var undoManagersByID: [DocumentID: UndoManager] = [:]

    public init() {}

    /// Returns the dedicated `UndoManager` for `documentID`, creating one lazily if needed.
    public func undoManager(for documentID: DocumentID) -> UndoManager {
        if let existing = undoManagersByID[documentID] {
            return existing
        }
        let manager = UndoManager()
        undoManagersByID[documentID] = manager
        return manager
    }

    /// Clears all undo/redo registrations and removes the manager when a tab closes (`CWE-416`).
    public func removeUndoManager(for documentID: DocumentID) {
        if let manager = undoManagersByID.removeValue(forKey: documentID) {
            manager.removeAllActions()
        }
    }

    /// Drops every tracked undo manager and clears recorded actions on teardown (`AR-006`).
    public func clearAllUndoManagers() {
        for manager in undoManagersByID.values {
            manager.removeAllActions()
        }
        undoManagersByID.removeAll()
    }

    public func containsUndoManager(for documentID: DocumentID) -> Bool {
        undoManagersByID[documentID] != nil
    }
}

/// Mutable scan/click tracking fields grouped out of `SwiftEditNSTextView` (`REQ-004`).
private struct TextViewScanTrackingState {
    var lastHighlightedLineRect: NSRect?
    var lastScannedSelection = NSRange(location: NSNotFound, length: 0)
    var lastScannedStorageLength: Int = -1
    var lastScannedMutationToken: UInt64 = 0
    var textMutationToken: UInt64 = 1
    var selectionBeforeClick = NSRange(location: 0, length: 0)
}

/// Custom TextKit 2 `NSTextView` painting a full-width subtle current-line background highlight and synchronous secondary word-occurrence highlights (`UI-002`, `UI-012`).
@MainActor
final class SwiftEditNSTextView: NSTextView {
    var currentLineHighlightColor: NSColor = .clear
    var primarySelectionBackgroundColor: NSColor = .clear
    var wordOccurrenceBackgroundColor: NSColor = .clear
    var wordOccurrenceUnderlineColor: NSColor = .clear
    var isWordOccurrenceHighlightEnabled: Bool = true
    var externalWordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    /// Synchronous callback invoked whenever `liveWordOccurrenceRanges` changes so TextKit 2 rendering attributes update immediately without waiting for a SwiftUI render cycle.
    var onWordOccurrencesUpdated: (([SwiftEditCore.TextRange]) -> Void)?
    /// ESC hook (navigator / distraction-free); returns `true` when consumed.
    var onEscape: (() -> Bool)?
    /// Context-menu hook invoked by right-click "Send to Terminal" when text is selected.
    var onSendSelectionToTerminal: ((NSRange, String) -> Void)?
    /// Context-menu hook invoked by right-click "Reveal in Folder Navigator" when available for the active disk-backed document (`REQ-031-01`).
    var onRevealInFolderNavigator: (() -> Void)?
    /// Context-menu hook invoked by right-click "Start Dictation Here" when the active document is writable (`REQ-031-02`).
    var onStartDictationHere: (() -> Void)?
    private(set) var liveWordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    fileprivate var scanState = TextViewScanTrackingState()

    override func cancelOperation(_ sender: Any?) {
        if onEscape?() == true { return }
        super.cancelOperation(sender)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let selectionBeforeMenu = selectedRange()
        let baseMenu = super.menu(for: event) ?? NSMenu()
        var customItems: [NSMenuItem] = []
        if selectionBeforeMenu.length > 0, onSendSelectionToTerminal != nil {
            if selectedRange() != selectionBeforeMenu {
                setSelectedRange(selectionBeforeMenu)
            }
            let item = NSMenuItem(
                title: "Send to Terminal",
                action: #selector(handleSendSelectionToTerminalMenuAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = NSValue(range: selectionBeforeMenu)
            customItems.append(item)
        }
        if onRevealInFolderNavigator != nil {
            let item = NSMenuItem(
                title: "Reveal in Folder Navigator",
                action: #selector(handleRevealInFolderNavigatorMenuAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            customItems.append(item)
        }
        if isEditable, onStartDictationHere != nil {
            let item = NSMenuItem(
                title: "Start Dictation Here",
                action: #selector(handleStartDictationHereMenuAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            customItems.append(item)
        }
        if !customItems.isEmpty {
            baseMenu.insertItem(NSMenuItem.separator(), at: 0)
            for item in customItems.reversed() {
                baseMenu.insertItem(item, at: 0)
            }
        }
        return baseMenu
    }

    override func didChangeText() {
        scanState.textMutationToken &+= 1
        super.didChangeText()
        updateLiveWordOccurrencesAndInvalidate(force: true)
    }

    /// Repeated double-click cycle (`REQ-022-05`): word -> whitespace-free token -> no selection.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            scanState.selectionBeforeClick = selectedRange()
        } else if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            switch doubleClickOutcome(atCharacterIndex: index, previous: scanState.selectionBeforeClick) {
            case .selectToken(let token):
                setSelectedRange(NSRange(location: token.location, length: token.length))
                return
            case .deselect(let caret):
                setSelectedRange(NSRange(location: caret, length: 0))
                return
            case .selectWord:
                break
            }
        }
        super.mouseDown(with: event)
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        let previousRange = selectedRange()
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if previousRange != charRange {
            invalidateCurrentLineHighlightRect()
            updateLiveWordOccurrencesAndInvalidate()
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        let previousRange = selectedRange()
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        if previousRange != selectedRange() {
            invalidateCurrentLineHighlightRect()
            updateLiveWordOccurrencesAndInvalidate()
        }
    }

    override func drawBackground(in rect: NSRect) {
        let highlightAlpha = currentLineHighlightColor.alphaComponent
        super.drawBackground(in: rect)
        if highlightAlpha > 0,
           let lineRect = currentLineFullWidthRect(onlyIfInViewport: true) {
            scanState.lastHighlightedLineRect = lineRect
            if lineRect.intersects(rect) {
                currentLineHighlightColor.setFill()
                lineRect.fill()
            }
        }
        drawWordOccurrencesBackground(in: rect)
    }
}

extension SwiftEditNSTextView {
    var effectiveWordOccurrenceRanges: [SwiftEditCore.TextRange] {
        selectedRange().length >= WordOccurrenceScanner.minWordUTF16Length
            ? liveWordOccurrenceRanges
            : []
    }

    @objc fileprivate func handleSendSelectionToTerminalMenuAction(_ sender: Any?) {
        let captured = (sender as? NSMenuItem)?.representedObject as? NSValue
        let sel = captured?.rangeValue ?? selectedRange()
        guard sel.length > 0 else { return }
        onSendSelectionToTerminal?(sel, textStorage?.string ?? string)
    }

    @objc fileprivate func handleRevealInFolderNavigatorMenuAction(_ sender: Any?) {
        onRevealInFolderNavigator?()
    }

    @objc fileprivate func handleStartDictationHereMenuAction(_ sender: Any?) {
        guard isEditable else { return }
        onStartDictationHere?()
    }

    func notifyProgrammaticTextOrStyleMutation() {
        scanState.textMutationToken &+= 1
        updateLiveWordOccurrencesAndInvalidate(force: true)
    }

    /// Outcome of a double-click at `index` given the selection before the click (headless-testable).
    func doubleClickOutcome(atCharacterIndex index: Int, previous: NSRange) -> DoubleClickSelectionCycle.Outcome {
        let text = (textStorage?.string ?? "") as NSString
        guard index >= 0, index <= text.length, text.length > 0 else { return .selectWord }
        let probe = min(index, text.length - 1)
        let word = selectionRange(forProposedRange: NSRange(location: probe, length: 0), granularity: .selectByWord)
        guard word.length > 0 else { return .selectWord }
        let wordRange = SwiftEditCore.TextRange(location: word.location, length: word.length)
        let token = DoubleClickSelectionCycle.token(around: wordRange, in: text)
        return DoubleClickSelectionCycle.outcome(
            previous: SwiftEditCore.TextRange(location: previous.location, length: previous.length),
            word: wordRange,
            token: token
        )
    }

    /// Synchronously scans for other occurrences of the currently selected word/token and invalidates both the canvas background and TextKit 2 fragment subviews.
    func updateLiveWordOccurrencesAndInvalidate(force: Bool = false) {
        let sel = selectedRange()
        let totalLength = textStorage?.length ?? 0
        if !force,
           sel == scanState.lastScannedSelection,
           totalLength == scanState.lastScannedStorageLength,
           scanState.textMutationToken == scanState.lastScannedMutationToken {
            return
        }
        let previousSelection = scanState.lastScannedSelection
        let selectionLengthChanged = (previousSelection.length > 0 || sel.length > 0) && previousSelection != sel
        scanState.lastScannedSelection = sel
        scanState.lastScannedStorageLength = totalLength
        scanState.lastScannedMutationToken = scanState.textMutationToken

        let newRanges: [SwiftEditCore.TextRange]
        if isWordOccurrenceHighlightEnabled,
           sel.location >= 0,
           sel.length >= WordOccurrenceScanner.minWordUTF16Length,
           sel.length <= WordOccurrenceScanner.maxWordUTF16Length,
           NSMaxRange(sel) <= totalLength {
            let currentString = textStorage?.string ?? string
            let snap = DocumentSnapshot(
                id: DocumentID(),
                revision: BufferRevision(scanState.textMutationToken),
                text: currentString,
                encoding: .utf8,
                lineEnding: .lf,
                isDegradedPlainText: false,
                isBinaryReadOnly: false
            )
            newRanges = WordOccurrenceScanner.scan(
                selection: SwiftEditCore.TextRange(location: sel.location, length: sel.length),
                in: snap
            )
        } else {
            newRanges = []
        }

        let changed = (newRanges != liveWordOccurrenceRanges)
        liveWordOccurrenceRanges = newRanges
        if changed || selectionLengthChanged || (force && (!newRanges.isEmpty || sel.length > 0)) {
            onWordOccurrencesUpdated?(newRanges)
            needsDisplay = true
            Self.markSubviewsAndLayersNeedsDisplay(self)
        }
    }

    /// Fail-closed visitation cap (`4,096` nodes) defending against `CWE-674` (uncontrolled recursion) and `CWE-400` (CPU/heap exhaustion) on pathological `NSView`/`CALayer` trees (`REQ-007`, `SEC-012`).
    public static let maxTraversalVisitedNodes = 4_096

    /// Iteratively marks `view`, its descendant subviews, and any backing `CALayer` subtrees as needing display, halting fail-closed at `maxVisitedNodes` with `ObjectIdentifier` cycle protection (`UI-007`, `SEC-012`).
    @discardableResult
    static func markSubviewsAndLayersNeedsDisplay(_ view: NSView, maxVisitedNodes: Int = maxTraversalVisitedNodes) -> Int {
        guard maxVisitedNodes > 0 else { return 0 }
        let initialCapacity = min(32, maxVisitedNodes)
        var worklist: [NSView] = []
        worklist.reserveCapacity(initialCapacity)
        worklist.append(view)
        var visited = Set<ObjectIdentifier>(minimumCapacity: initialCapacity)
        while let current = worklist.popLast(), visited.count < maxVisitedNodes {
            guard visited.insert(ObjectIdentifier(current)).inserted else { continue }
            current.needsDisplay = true
            if let layer = current.layer {
                _ = markLayerTreeNeedsDisplay(layer, maxVisitedNodes: maxVisitedNodes)
            }
            for subview in current.subviews.reversed() where !visited.contains(ObjectIdentifier(subview)) {
                worklist.append(subview)
            }
        }
        return visited.count
    }

    /// Iteratively marks `layer` and its descendant `CALayer` tree as needing display using an explicit LIFO worklist bounded by `maxVisitedNodes` (`UI-007`, `SEC-012`).
    @discardableResult
    static func markLayerTreeNeedsDisplay(_ layer: CALayer, maxVisitedNodes: Int = maxTraversalVisitedNodes) -> Int {
        guard maxVisitedNodes > 0 else { return 0 }
        let initialCapacity = min(32, maxVisitedNodes)
        var worklist: [CALayer] = []
        worklist.reserveCapacity(initialCapacity)
        worklist.append(layer)
        var visited = Set<ObjectIdentifier>(minimumCapacity: initialCapacity)
        while let current = worklist.popLast(), visited.count < maxVisitedNodes {
            guard visited.insert(ObjectIdentifier(current)).inserted else { continue }
            current.setNeedsDisplay()
            if let sublayers = current.sublayers {
                for sub in sublayers.reversed() where !visited.contains(ObjectIdentifier(sub)) {
                    worklist.append(sub)
                }
            }
        }
        return visited.count
    }

    fileprivate func invalidateCurrentLineHighlightRect() {
        if let oldRect = scanState.lastHighlightedLineRect {
            setNeedsDisplay(oldRect)
        }
        if let newRect = currentLineFullWidthRect(onlyIfInViewport: true) {
            scanState.lastHighlightedLineRect = newRect
            setNeedsDisplay(newRect)
        } else {
            scanState.lastHighlightedLineRect = nil
        }
    }

    /// Paints rounded secondary occurrence boxes and non-color-only bottom underlines directly on the `NSTextView` background canvas for all occurrences intersecting `rect`.
    private func drawWordOccurrencesBackground(in rect: NSRect) {
        let activeOccurrences = effectiveWordOccurrenceRanges
        guard !activeOccurrences.isEmpty,
              wordOccurrenceBackgroundColor.alphaComponent > 0,
              let textLayoutManager,
              let contentManager = textLayoutManager.textContentManager else {
            return
        }
        let docRange = contentManager.documentRange
        let totalUTF16 = textStorage?.length ?? 0
        guard totalUTF16 > 0 else { return }

        let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange ?? docRange
        let visStart = max(0, contentManager.offset(from: docRange.location, to: viewportRange.location))
        let visEnd = min(totalUTF16, max(visStart, contentManager.offset(from: docRange.location, to: viewportRange.endLocation)))
        let rangeStart = max(0, visStart - 256)
        let rangeEnd = min(totalUTF16, visEnd + 256)
        let origin = textContainerOrigin

        var lo = 0
        var hi = activeOccurrences.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if activeOccurrences[mid].upperBound <= rangeStart {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        let hasUnderline = wordOccurrenceUnderlineColor.alphaComponent > 0
        var idx = lo
        while idx < activeOccurrences.count {
            let occ = activeOccurrences[idx]
            if occ.location >= rangeEnd { break }
            let startLoc: (any NSTextLocation)? = occ.location >= visStart
                ? contentManager.location(viewportRange.location, offsetBy: occ.location - visStart)
                : contentManager.location(docRange.location, offsetBy: occ.location)
            if let startLoc,
               let endLoc = contentManager.location(startLoc, offsetBy: occ.length),
               let nsTextRange = NSTextRange(location: startLoc, end: endLoc) {
                textLayoutManager.enumerateTextSegments(in: nsTextRange, type: .standard, options: []) { _, segmentFrame, _, _ in
                    let segRect = NSRect(
                        x: origin.x + segmentFrame.origin.x,
                        y: origin.y + segmentFrame.origin.y,
                        width: segmentFrame.width,
                        height: segmentFrame.height
                    )
                    if segRect.width > 0, segRect.height > 0, segRect.intersects(rect) {
                        wordOccurrenceBackgroundColor.setFill()
                        let pill = NSBezierPath(roundedRect: segRect.insetBy(dx: -1.0, dy: 0), xRadius: 2.5, yRadius: 2.5)
                        pill.fill()
                        if hasUnderline {
                            wordOccurrenceUnderlineColor.setFill()
                            let underlineRect = NSRect(
                                x: segRect.minX,
                                y: segRect.maxY - 1.5,
                                width: segRect.width,
                                height: 1.5
                            )
                            underlineRect.fill()
                        }
                    }
                    return true
                }
            }
            idx += 1
        }
    }

    /// Computes full-width highlight rect covering every wrapped `textLineFragment` of the active paragraph/line (`BUG-013`).
    func currentLineFullWidthRect(onlyIfInViewport: Bool = false) -> NSRect? {
        let origin = textContainerOrigin
        let fallbackHeight = max(14.0, (font?.ascender ?? 12.0) - (font?.descender ?? -3.0) + (font?.leading ?? 2.0))
        guard let textLayoutManager,
              let contentManager = textLayoutManager.textContentManager else {
            return NSRect(x: 0, y: origin.y, width: bounds.width, height: fallbackHeight)
        }

        let totalLength = textStorage?.length ?? 0
        let caretOffset = min(selectedRange().location, totalLength)
        guard let caretLocation = contentManager.location(contentManager.documentRange.location, offsetBy: caretOffset) else {
            return NSRect(x: 0, y: origin.y, width: bounds.width, height: fallbackHeight)
        }

        // During scroll redraws, skip forcing `.ensuresLayout` on off-screen paragraphs far outside the active viewport.
        if onlyIfInViewport, let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange {
            if caretLocation.compare(viewportRange.location) == .orderedAscending
                || caretLocation.compare(viewportRange.endLocation) == .orderedDescending {
                return nil
            }
        }

        var resolvedRect: NSRect?
        let options: NSTextLayoutFragment.EnumerationOptions = onlyIfInViewport ? [] : [.ensuresLayout]
        textLayoutManager.enumerateTextLayoutFragments(from: caretLocation, options: options) { fragment in
            let fragmentOrigin = fragment.layoutFragmentFrame.origin
            if !fragment.textLineFragments.isEmpty {
                var minLineY = CGFloat.greatestFiniteMagnitude
                var maxLineY: CGFloat = 0
                for lineFragment in fragment.textLineFragments {
                    let frame = lineFragment.typographicBounds
                    minLineY = min(minLineY, frame.minY)
                    maxLineY = max(maxLineY, frame.maxY)
                }
                let y = origin.y + fragmentOrigin.y + minLineY
                let height = max(maxLineY - minLineY, fallbackHeight)
                resolvedRect = NSRect(x: 0, y: y, width: bounds.width, height: height)
                return false
            }
            let fallbackY = origin.y + fragmentOrigin.y
            resolvedRect = NSRect(x: 0, y: fallbackY, width: bounds.width, height: max(fragment.layoutFragmentFrame.height, fallbackHeight))
            return false
        }
        if onlyIfInViewport && resolvedRect == nil {
            return nil
        }
        return resolvedRect ?? NSRect(x: 0, y: origin.y, width: bounds.width, height: fallbackHeight)
    }
}

/// Inline ghost-text completion drawn right after the caret (`REQ-020-01`).
///
/// A non-interactive overlay subview of the text view: it never touches `NSTextContentStorage`, so the document, undo
/// stack and `BufferRevision` stay untouched until `Tab` accepts it (`UI-006`). Opaque canvas background keeps it legible.
@MainActor
final class GhostCompletionView: NSView {
    private(set) var suffix: String = ""
    private var attributes: [NSAttributedString.Key: Any] = [:]
    private var canvasColor: NSColor = .clear

    override var isFlipped: Bool { true }

    func configure(suffix: String, font: NSFont, textColor: NSColor, canvasColor: NSColor) {
        self.suffix = suffix
        self.canvasColor = canvasColor
        attributes = [.font: font, .foregroundColor: textColor]
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Completion suggestion: \(suffix). Press Tab to accept.")
        needsDisplay = true
    }

    var preferredWidth: CGFloat {
        ceil((suffix as NSString).size(withAttributes: attributes).width) + 2
    }

    override func draw(_ dirtyRect: NSRect) {
        canvasColor.setFill()
        bounds.fill()
        (suffix as NSString).draw(at: .zero, withAttributes: attributes)
    }

    /// Clicks always reach the text view underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}


#endif
