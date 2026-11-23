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

    /// Drops every tracked undo manager and clears recorded actions on teardown.
    public func removeAll() {
        for manager in undoManagersByID.values {
            manager.removeAllActions()
        }
        undoManagersByID.removeAll()
    }

    public func containsUndoManager(for documentID: DocumentID) -> Bool {
        undoManagersByID[documentID] != nil
    }
}

/// Custom TextKit 2 `NSTextView` painting a full-width subtle current-line background highlight (`UI-002`, `UI-012`).
@MainActor
final class SwiftEditNSTextView: NSTextView {
    var currentLineHighlightColor: NSColor = .clear
    /// ESC hook (navigator / distraction-free); returns `true` when consumed.
    var onEscape: (() -> Bool)?
    private var lastHighlightedLineRect: NSRect?

    override func cancelOperation(_ sender: Any?) {
        if onEscape?() == true { return }
        super.cancelOperation(sender)
    }

    /// Selection that existed before the current click sequence started (read by the double-click cycle).
    private var selectionBeforeClick = NSRange(location: 0, length: 0)

    /// Repeated double-click cycle (`REQ-022-05`): word -> whitespace-free token -> no selection.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            selectionBeforeClick = selectedRange()
        } else if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            switch doubleClickOutcome(atCharacterIndex: index, previous: selectionBeforeClick) {
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

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        let previousRange = selectedRange()
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if previousRange != charRange {
            invalidateCurrentLineHighlightRect()
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        let previousRange = selectedRange()
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        if previousRange != selectedRange() {
            invalidateCurrentLineHighlightRect()
        }
    }

    private func invalidateCurrentLineHighlightRect() {
        if let oldRect = lastHighlightedLineRect {
            setNeedsDisplay(oldRect)
        }
        if let newRect = currentLineFullWidthRect(onlyIfInViewport: true) {
            lastHighlightedLineRect = newRect
            setNeedsDisplay(newRect)
        } else {
            lastHighlightedLineRect = nil
        }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard currentLineHighlightColor.alphaComponent > 0 else { return }

        if let lineRect = currentLineFullWidthRect(onlyIfInViewport: true) {
            lastHighlightedLineRect = lineRect
            if lineRect.intersects(rect) {
                currentLineHighlightColor.setFill()
                lineRect.fill()
            }
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

/// `@MainActor` TextKit 2 `NSTextView` wrapper enforcing `#FFFFFF`/`#000000` inverted canvas colors, current-line highlight, non-mutating nested bracket and backtick highlights, Markdown smart Enter continuation, `50%..300%` monospaced zoom, and read-only binary protection (`UI-002..008`, `UI-012`).
@MainActor
struct TextKit2EditorView: NSViewRepresentable {
    var documentID: DocumentID = DocumentID()
    var bufferRevision: BufferRevision = BufferRevision(1)
    let text: String
    let isEditable: Bool
    var isWordWrapEnabled: Bool = true
    let palette: PurpleThemePalette
    let fontSizePoints: Double
    let highlightProjection: EditorHighlightProjection
    let onTextChange: (String) -> Void
    let onSelectionChange: (SwiftEditCore.TextRange) -> Void
    let onSmartNewline: (Int) -> Int?
    let onListIndent: (Bool) -> SmartListOutcome
    /// GFM table `Tab` / `Shift+Tab` handler; evaluated before the list engine in the Tab chain (`Ctrl+Tab` escape is a distinct AppKit selector and is never intercepted).
    let onTableTab: (Bool) -> TableEditOutcome
    /// Syntax language for the rendering validator; `.plainText` disables styling (binary, degraded, quarantined tabs).
    let documentLanguage: DocumentLanguage
    /// Selection requested by a model-side command, adopted once per `programmaticSelectionToken` change.
    let programmaticSelection: SwiftEditCore.TextRange
    let programmaticSelectionToken: Int
    /// Diagnostics (after active-line suppression) drawn as dotted underlines; capped at `1000` by the engine.
    var lintDiagnostics: [MarkdownLintDiagnostic] = []
    var undoRegistry: PerTabUndoManagerRegistry?
    var editorFocusRequestToken: Int = 0
    var onViewportMetricsChange: ((GutterViewportMetrics) -> Void)? = nil
    var onEscape: () -> Bool = { false }
    /// Font resolver and its change counter (`REQ-008`); a new generation restyles the canvas and GFM/YAML faces.
    var typography: AppTypography = AppTypography.fallback
    var typographyGeneration: Int = 0
    /// Shared per-revision line index owned by the workbench (`PERF-017-B3`).
    var lineIndexProvider: ((DocumentID, BufferRevision) -> MarkdownLineIndex?)? = nil
    /// Word-cache lookup returning the suffix that completes a typed prefix (`REQ-020-01`); `nil` disables ghost text.
    var completionProvider: ((String) -> String?)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSmartNewline: onSmartNewline,
            onListIndent: onListIndent,
            onTableTab: onTableTab
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = SwiftEditNSTextView(usingTextLayoutManager: true)
        context.coordinator.undoRegistry = undoRegistry
        context.coordinator.activeDocumentID = documentID
        context.coordinator.activeBufferRevision = bufferRevision
        textView.delegate = context.coordinator
        textView.onEscape = onEscape
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        applyStylingIfNeeded(to: textView, in: scrollView, coordinator: context.coordinator, force: true)
        context.coordinator.applyProgrammaticTextUpdate(text, to: textView, documentID: documentID, isInitialSetup: true)
        context.coordinator.markSynced(documentID: documentID, revision: bufferRevision)
        applyNonMutatingHighlightsIfNeeded(to: textView, coordinator: context.coordinator, force: true)
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.onViewportMetricsChange = onViewportMetricsChange
        context.coordinator.lineIndexProvider = lineIndexProvider
        context.coordinator.completionProvider = completionProvider
        context.coordinator.observeScrollBounds(of: scrollView, textView: textView)
        installGFMValidator(on: textView, coordinator: context.coordinator)
        return scrollView
    }

    /// Detaches delegates, escape handlers, and TextKit 2 rendering validators before teardown to prevent `CWE-416` use-after-free and nil content manager traps (`BUG-001`, `BUG-021`).
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.detachScrollObserver()
        if let textView = scrollView.documentView as? SwiftEditNSTextView {
            textView.delegate = nil
            textView.onEscape = nil
            textView.textLayoutManager?.renderingAttributesValidator = nil
        }
        coordinator.invalidateLineIndex()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SwiftEditNSTextView else { return }
        let coordinator = context.coordinator
        coordinator.onTextChange = onTextChange
        coordinator.onSelectionChange = onSelectionChange
        coordinator.onSmartNewline = onSmartNewline
        coordinator.onListIndent = onListIndent
        coordinator.onTableTab = onTableTab
        coordinator.onViewportMetricsChange = onViewportMetricsChange
        coordinator.lineIndexProvider = lineIndexProvider
        coordinator.completionProvider = isEditable ? completionProvider : nil
        coordinator.undoRegistry = undoRegistry
        coordinator.activeBufferRevision = bufferRevision
        coordinator.syntaxLanguage = documentLanguage
        coordinator.wordOccurrenceRanges = highlightProjection.wordOccurrenceRanges
        coordinator.updateRenderingTableIfNeeded(
            palette: palette,
            fontSizePoints: fontSizePoints,
            typography: typography,
            generation: typographyGeneration
        )

        let stylingChanged = applyStylingIfNeeded(to: textView, in: scrollView, coordinator: coordinator, force: false)
        if stylingChanged || coordinator.activeDocumentID != documentID {
            coordinator.hideGhostCompletion()
        }

        var textMutated = false
        let needsTextSyncCheck = coordinator.activeDocumentID != documentID
            || coordinator.lastSyncedBufferRevision != bufferRevision
            || coordinator.hasPendingLocalEdit
        if needsTextSyncCheck {
            let hadPendingLocalEdit = coordinator.hasPendingLocalEdit
            coordinator.hasPendingLocalEdit = false
            if hadPendingLocalEdit && coordinator.activeDocumentID == documentID && coordinator.isDisplaying(text, in: textView) {
                // Local textDidChange already owns the live NSTextStorage contents (O(1) shared-buffer pointer check).
                coordinator.markSynced(documentID: documentID, revision: bufferRevision)
                coordinator.retagCachedLineIndexRevision(documentID: documentID, revision: bufferRevision, storageLength: textView.textStorage?.length ?? 0)
            } else if coordinator.activeDocumentID != documentID || !coordinator.isDisplaying(text, in: textView) {
                coordinator.applyProgrammaticTextUpdate(text, to: textView, documentID: documentID)
                coordinator.markSynced(documentID: documentID, revision: bufferRevision)
                textMutated = true
            } else {
                coordinator.markSynced(documentID: documentID, revision: bufferRevision)
            }
        }

        var selectionChanged = false
        if coordinator.appliedSelectionToken != programmaticSelectionToken {
            coordinator.appliedSelectionToken = programmaticSelectionToken
            let length = textView.textStorage?.length ?? 0
            if programmaticSelection.location >= 0, programmaticSelection.upperBound <= length {
                coordinator.isApplyingProgrammaticUpdate = true
                Coordinator.revealSelection(NSRange(location: programmaticSelection.location, length: programmaticSelection.length), in: textView)
                coordinator.isApplyingProgrammaticUpdate = false
                selectionChanged = true
            }
        }
        if coordinator.appliedFocusRequestToken != editorFocusRequestToken {
            coordinator.appliedFocusRequestToken = editorFocusRequestToken
            textView.window?.makeFirstResponder(textView)
        }

        let highlightsChanged = applyNonMutatingHighlightsIfNeeded(
            to: textView,
            coordinator: coordinator,
            force: stylingChanged || textMutated
        )
        if stylingChanged || textMutated || highlightsChanged {
            textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
            textView.needsDisplay = true
        }
        if stylingChanged || textMutated || selectionChanged {
            coordinator.emitViewportMetrics(for: scrollView, textView: textView)
        }
    }

    /// Installs the viewport-only GFM `renderingAttributesValidator` (hot path): only the laid-out fragment is scanned, prose keeps `#FFFFFF`/`#000000` (`21:1`), and cached fonts + `>= 4.5:1` palette tokens are applied (`UI-002`, `UI-012`).
    private func installGFMValidator(on textView: SwiftEditNSTextView, coordinator: Coordinator) {
        coordinator.syntaxLanguage = documentLanguage
        coordinator.wordOccurrenceRanges = highlightProjection.wordOccurrenceRanges
        coordinator.updateRenderingTableIfNeeded(
            palette: palette,
            fontSizePoints: fontSizePoints,
            typography: typography,
            generation: typographyGeneration
        )
        textView.textLayoutManager?.renderingAttributesValidator = { [weak coordinator, weak textView] layoutManager, fragment in
            guard let coordinator, let textView,
                  let contentManager = layoutManager.textContentManager else { return }
            let docStart = contentManager.documentRange.location
            let fragLocation = fragment.rangeInElement.location
            let fragStart = contentManager.offset(from: docStart, to: fragLocation)
            let fragEnd = contentManager.offset(from: docStart, to: fragment.rangeInElement.endLocation)
            guard fragEnd > fragStart else { return }
            let table = coordinator.renderingAttributeTable
            if coordinator.syntaxLanguage != .plainText {
                let index = coordinator.renderingLineIndex(
                    for: textView,
                    documentID: coordinator.activeDocumentID,
                    revision: coordinator.activeBufferRevision
                )
                let spans = DocumentSyntaxHighlighter.spans(index: index, visibleRange: SwiftEditCore.TextRange(location: fragStart, length: fragEnd - fragStart), language: coordinator.syntaxLanguage)
                for span in spans {
                    let attributes = table.attributes(for: span.kind)
                    guard !attributes.isEmpty else { continue }
                    let start: (any NSTextLocation)?
                    if span.range.location >= fragStart {
                        start = contentManager.location(fragLocation, offsetBy: span.range.location - fragStart)
                    } else {
                        start = contentManager.location(docStart, offsetBy: span.range.location)
                    }
                    guard let start,
                          let end = contentManager.location(start, offsetBy: span.range.length),
                          let range = NSTextRange(location: start, end: end) else { continue }
                    for attribute in attributes {
                        layoutManager.addRenderingAttribute(attribute.key, value: attribute.value, for: range)
                    }
                }
            }
            // Re-apply soft secondary word occurrence highlights intersecting this fragment so TextKit 2
            // fragment revalidation during layoutViewport() or scrolling never clears them.
            Self.applyWordOccurrences(
                coordinator.wordOccurrenceRanges,
                in: layoutManager,
                contentManager: contentManager,
                docStart: docStart,
                anchorLocation: fragLocation,
                anchorOffset: fragStart,
                rangeStart: fragStart,
                rangeEnd: fragEnd,
                table: table
            )
        }
    }

    private static func applyWordOccurrences(
        _ occurrences: [SwiftEditCore.TextRange],
        in layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager,
        docStart: any NSTextLocation,
        anchorLocation: any NSTextLocation,
        anchorOffset: Int,
        rangeStart: Int,
        rangeEnd: Int,
        table: EditorRenderingAttributeTable
    ) {
        guard !occurrences.isEmpty else { return }
        let occurrenceBg = table.wordOccurrenceBackground
        let occurrenceUnderline = table.wordOccurrenceUnderline
        let underlineStyle = NSUnderlineStyle.single.rawValue
        var lo = 0, hi = occurrences.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if occurrences[mid].upperBound <= rangeStart { lo = mid + 1 } else { hi = mid }
        }
        var idx = lo
        while idx < occurrences.count {
            let occ = occurrences[idx]
            if occ.location >= rangeEnd { break }
            let start: (any NSTextLocation)? = occ.location >= anchorOffset
                ? contentManager.location(anchorLocation, offsetBy: occ.location - anchorOffset)
                : contentManager.location(docStart, offsetBy: occ.location)
            if let start,
               let end = contentManager.location(start, offsetBy: occ.length),
               let range = NSTextRange(location: start, end: end) {
                layoutManager.addRenderingAttribute(.backgroundColor, value: occurrenceBg, for: range)
                layoutManager.addRenderingAttribute(.underlineStyle, value: underlineStyle, for: range)
                layoutManager.addRenderingAttribute(.underlineColor, value: occurrenceUnderline, for: range)
            }
            idx += 1
        }
    }

    /// Applies canvas, selection, insertion-point, and `NSScrollView` scroller appearance tokens ONLY when palette, font size, or editability actually changed (`UI-002`, `UI-003`, `UI-007`, `UI-012`).
    @discardableResult
    private func applyStylingIfNeeded(
        to textView: SwiftEditNSTextView,
        in scrollView: NSScrollView,
        coordinator: Coordinator,
        force: Bool
    ) -> Bool {
        if !force,
           coordinator.lastStyledPalette == palette,
           coordinator.lastStyledFontSize == fontSizePoints,
           coordinator.lastStyledTypographyGeneration == typographyGeneration,
           coordinator.lastStyledIsEditable == isEditable,
           coordinator.lastStyledWordWrap == isWordWrapEnabled {
            return false
        }
        coordinator.lastStyledPalette = palette
        coordinator.lastStyledFontSize = fontSizePoints
        coordinator.lastStyledTypographyGeneration = typographyGeneration
        coordinator.lastStyledIsEditable = isEditable
        coordinator.lastStyledWordWrap = isWordWrapEnabled
        coordinator.updateGFMFontsIfNeeded(fontSizePoints: fontSizePoints, typography: typography, generation: typographyGeneration)

        let editorFont = coordinator.cachedRegularFont
        let canvasBg = palette.editorCanvasBackground.nsColor
        let canvasFg = palette.editorCanvasText.nsColor

        scrollView.drawsBackground = true
        scrollView.backgroundColor = canvasBg
        scrollView.appearance = NSAppearance(named: palette.mode == .black ? .darkAqua : .aqua)
        scrollView.scrollerKnobStyle = (palette.mode == .black) ? .light : .dark
        scrollView.hasHorizontalScroller = !isWordWrapEnabled

        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.isEditable = isEditable
        textView.isHorizontallyResizable = !isWordWrapEnabled
        if isWordWrapEnabled {
            let width = max(120, scrollView.contentSize.width)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            if textView.frame.width != width {
                textView.frame.size.width = width
            }
            if scrollView.documentVisibleRect.origin.x > 0 {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.documentVisibleRect.origin.y))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        textView.backgroundColor = canvasBg
        textView.textColor = canvasFg
        textView.insertionPointColor = canvasFg
        textView.currentLineHighlightColor = palette.currentLineHighlight.nsColor
        textView.font = editorFont
        textView.selectedTextAttributes = [
            .backgroundColor: palette.selectionBackground.nsColor,
            .foregroundColor: palette.selectionForeground.nsColor,
        ]
        textView.typingAttributes = [
            .font: editorFont,
            .foregroundColor: canvasFg,
        ]
        if textView.window?.firstResponder === textView {
            textView.updateInsertionPointStateAndRestartTimer(true)
        }
        return true
    }

    /// Applies non-mutating TextKit 2 rendering attributes strictly over the active viewport range, skipping redundant passes and using binary-searched viewport windows (`PERF-001`, `UI-005`, `UI-006`, `UI-012`).
    @discardableResult
    private func applyNonMutatingHighlightsIfNeeded(
        to textView: SwiftEditNSTextView,
        coordinator: Coordinator,
        force: Bool
    ) -> Bool {
        guard let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager else {
            return false
        }
        let docRange = contentManager.documentRange
        let totalUTF16 = textView.textStorage?.length ?? 0
        guard totalUTF16 > 0 else {
            let cleared = coordinator.hadNonMutatingHighlights
            coordinator.hadNonMutatingHighlights = false
            coordinator.lastHighlightSnapshot = nil
            return cleared
        }

        let targetRange = layoutManager.textViewportLayoutController.viewportRange ?? docRange
        let visStart = max(0, contentManager.offset(from: docRange.location, to: targetRange.location))
        let visEnd = min(totalUTF16, max(visStart, contentManager.offset(from: docRange.location, to: targetRange.endLocation)))
        let visibleStart = max(0, visStart - 256)
        let visibleEnd = min(totalUTF16, visEnd + 256)

        let signature = Coordinator.HighlightRenderSignature(
            documentID: documentID,
            revision: bufferRevision,
            palette: palette,
            fontSizePoints: fontSizePoints,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            highlightProjection: highlightProjection,
            lintDiagnostics: lintDiagnostics
        )
        if !force && coordinator.lastHighlightSnapshot == signature {
            return false
        }
        coordinator.lastHighlightSnapshot = signature

        let hasAnyHighlights = !highlightProjection.backtickSpans.isEmpty
            || !highlightProjection.wordOccurrenceRanges.isEmpty
            || !highlightProjection.bracketPairs.isEmpty
            || highlightProjection.activeBracketPair != nil
            || !lintDiagnostics.isEmpty
            || !highlightProjection.unbalancedBrackets.isEmpty

        if !hasAnyHighlights && !coordinator.hadNonMutatingHighlights {
            return false
        }

        // Clear the full expanded overscan range [visibleStart, visibleEnd] so highlights applied
        // inside the ±256-char margin never linger after selection clear or small scrolls.
        let clearRange: NSTextRange
        if let clearStart = contentManager.location(docRange.location, offsetBy: visibleStart),
           let clearEnd = contentManager.location(clearStart, offsetBy: visibleEnd - visibleStart),
           let expanded = NSTextRange(location: clearStart, end: clearEnd) {
            clearRange = expanded
        } else {
            clearRange = targetRange
        }
        layoutManager.setRenderingAttributes([:], for: clearRange)
        coordinator.hadNonMutatingHighlights = hasAnyHighlights
        guard hasAnyHighlights else { return true }

        func intersectsVisible(_ loc: Int, _ len: Int) -> Bool {
            let end = loc + len
            return end >= visibleStart && loc <= visibleEnd
        }

        func makeTextRange(location: Int, length: Int) -> NSTextRange? {
            guard location >= 0, length > 0, location + length <= totalUTF16,
                  intersectsVisible(location, length) else {
                return nil
            }
            let start: (any NSTextLocation)?
            if location >= visStart {
                start = contentManager.location(targetRange.location, offsetBy: location - visStart)
            } else {
                start = contentManager.location(docRange.location, offsetBy: location)
            }
            guard let start,
                  let end = contentManager.location(start, offsetBy: length) else {
                return nil
            }
            return NSTextRange(location: start, end: end)
        }

        let table = coordinator.renderingAttributeTable

        // 1. Backtick inline and multiline fenced code highlights (sorted by location; binary search to first candidate)
        let backtickSpans = highlightProjection.backtickSpans
        if !backtickSpans.isEmpty {
            let backtickFg = table.backtickForeground
            let inlineBg = table.backtickInlineBackground
            let multilineBg = table.backtickMultilineBackground
            var lo = 0, hi = backtickSpans.count
            while lo < hi {
                let mid = lo + (hi - lo) / 2
                if backtickSpans[mid].range.upperBound < visibleStart { lo = mid + 1 } else { hi = mid }
            }
            var idx = lo
            while idx < backtickSpans.count {
                let span = backtickSpans[idx]
                if span.range.location > visibleEnd { break }
                if let nsTextRange = makeTextRange(location: span.range.location, length: span.range.length) {
                    layoutManager.addRenderingAttribute(.backgroundColor, value: span.kind == .fencedMultiline ? multilineBg : inlineBg, for: nsTextRange)
                    layoutManager.addRenderingAttribute(.foregroundColor, value: backtickFg, for: nsTextRange)
                }
                idx += 1
            }
        }

        // 1b. Soft secondary highlights for other whole-word occurrences of the selected word (binary-searched to visible viewport; WCAG 1.4.1 non-color-only underline cue)
        Self.applyWordOccurrences(
            highlightProjection.wordOccurrenceRanges,
            in: layoutManager,
            contentManager: contentManager,
            docStart: docRange.location,
            anchorLocation: targetRange.location,
            anchorOffset: visStart,
            rangeStart: visibleStart,
            rangeEnd: visibleEnd,
            table: table
        )

        let boldFont = coordinator.cachedBoldFont

        // 2. Nested depth-colored bracket pairs ({}, [], ()) (sorted by openOffset; early-break past visibleEnd and skip pairs whose endpoints are both off-screen)
        let depthColors = table.nestedBracketColors
        let depthCount = depthColors.count
        for pair in highlightProjection.bracketPairs {
            if pair.openOffset > visibleEnd { break }
            guard pair.closeOffset >= visibleStart else { continue }
            let openVisible = pair.openOffset >= visibleStart && pair.openOffset <= visibleEnd
            let closeVisible = pair.closeOffset >= visibleStart && pair.closeOffset <= visibleEnd
            guard openVisible || closeVisible else { continue }
            let depthColor = depthColors[max(0, pair.nestingDepth) % depthCount]
            if openVisible, let openRange = makeTextRange(location: pair.openOffset, length: 1) {
                layoutManager.addRenderingAttribute(.foregroundColor, value: depthColor, for: openRange)
                layoutManager.addRenderingAttribute(.font, value: boldFont, for: openRange)
            }
            if closeVisible, let closeRange = makeTextRange(location: pair.closeOffset, length: 1) {
                layoutManager.addRenderingAttribute(.foregroundColor, value: depthColor, for: closeRange)
                layoutManager.addRenderingAttribute(.font, value: boldFont, for: closeRange)
            }
        }

        // 3. Active caret bracket pair background emphasis
        if let active = highlightProjection.activeBracketPair {
            let activeBg = table.activeBracketHighlight
            if let openRange = makeTextRange(location: active.openOffset, length: 1) {
                layoutManager.addRenderingAttribute(.backgroundColor, value: activeBg, for: openRange)
            }
            if let closeRange = makeTextRange(location: active.closeOffset, length: 1) {
                layoutManager.addRenderingAttribute(.backgroundColor, value: activeBg, for: closeRange)
            }
        }

        // 3b. Prominent lint underlines + tinted range background (`>= 3.0:1` tokens): single viewport-filtered pass,
        // applying visible warnings immediately and deferring only visible errors so errors render on top.
        if !lintDiagnostics.isEmpty {
            let warnStyle = NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue
            let warnColor = table.lintWarnColor
            let warnBackground = table.lintWarnBackground
            let errStyle = NSUnderlineStyle.thick.rawValue
            let errColor = table.lintErrorColor
            let errBackground = table.lintErrorBackground
            var visibleErrorRanges: [NSTextRange] = []
            for diagnostic in lintDiagnostics {
                guard let range = diagnostic.range else { continue }
                let spanLength = range.length > 0 ? min(range.length, 1_024) : 1
                guard let nsRange = makeTextRange(location: range.location, length: spanLength) else { continue }
                if diagnostic.severity == .error {
                    visibleErrorRanges.append(nsRange)
                } else if diagnostic.severity == .warning {
                    layoutManager.addRenderingAttribute(.underlineStyle, value: warnStyle, for: nsRange)
                    layoutManager.addRenderingAttribute(.underlineColor, value: warnColor, for: nsRange)
                    layoutManager.addRenderingAttribute(.backgroundColor, value: warnBackground, for: nsRange)
                }
            }
            for nsRange in visibleErrorRanges {
                layoutManager.addRenderingAttribute(.underlineStyle, value: errStyle, for: nsRange)
                layoutManager.addRenderingAttribute(.underlineColor, value: errColor, for: nsRange)
                layoutManager.addRenderingAttribute(.backgroundColor, value: errBackground, for: nsRange)
            }
        }

        // 4. Unbalanced bracket error emphasis (sorted by offset; binary search to visibleStart)
        let unbalanced = highlightProjection.unbalancedBrackets
        if !unbalanced.isEmpty {
            let errorColor = table.unbalancedBracketForeground
            let errorBg = table.unbalancedBracketBackground
            var lo = 0, hi = unbalanced.count
            while lo < hi {
                let mid = lo + (hi - lo) / 2
                if unbalanced[mid].offset < visibleStart { lo = mid + 1 } else { hi = mid }
            }
            var idx = lo
            while idx < unbalanced.count {
                let stray = unbalanced[idx]
                if stray.offset > visibleEnd { break }
                if let strayRange = makeTextRange(location: stray.offset, length: 1) {
                    layoutManager.addRenderingAttribute(.foregroundColor, value: errorColor, for: strayRange)
                    layoutManager.addRenderingAttribute(.backgroundColor, value: errorBg, for: strayRange)
                    layoutManager.addRenderingAttribute(.font, value: boldFont, for: strayRange)
                }
                idx += 1
            }
        }

        return true
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        /// Applies a `Tab` / `Shift+Tab` list outcome as one coalesced `insertText` replacement so AppKit records a single undo step and the workbench a single `BufferRevision`.
        /// - Returns: `true` when the key was consumed (edit or safe no-op); `false` lets AppKit insert its default tab.
        func handleListIndent(in textView: NSTextView, outdent: Bool) -> Bool {
            guard textView.isEditable else { return false }
            if case .edit(let tableEdit) = onTableTab(outdent), let single = tableEdit.edits.first {
                textView.insertText(single.replacement, replacementRange: NSRange(location: single.range.location, length: single.range.length))
                textView.setSelectedRange(NSRange(location: tableEdit.newSelection.location, length: tableEdit.newSelection.length))
                return true
            }
            switch onListIndent(outdent) {
            case .notApplicable:
                return false
            case .consumedNoOp:
                return true
            case .edit(let listEdit):
                let single = listEdit.coalescedEdit(in: textView.string)
                let range = NSRange(location: single.range.location, length: single.range.length)
                textView.insertText(single.replacement, replacementRange: range)
                textView.setSelectedRange(NSRange(location: listEdit.newSelection.location, length: listEdit.newSelection.length))
                return true
            }
        }

        struct HighlightRenderSignature: Equatable {
            let documentID: DocumentID
            let revision: BufferRevision
            let palette: PurpleThemePalette
            let fontSizePoints: Double
            let visibleStart: Int
            let visibleEnd: Int
            let highlightProjection: EditorHighlightProjection
            let lintDiagnostics: [MarkdownLintDiagnostic]
        }

        var onTextChange: (String) -> Void
        var onSelectionChange: (SwiftEditCore.TextRange) -> Void
        var onSmartNewline: (Int) -> Int?
        var onListIndent: (Bool) -> SmartListOutcome
        var onTableTab: (Bool) -> TableEditOutcome
        var syntaxLanguage: DocumentLanguage = .plainText
        var gfmPalette: PurpleThemePalette = .resolve(appearance: .light, systemPrefersDark: false)
        var gfmFontSize: Double = 13
        var cachedFonts = EditorRenderingFonts(fontSizePoints: 13)
        var renderingAttributeTable = EditorRenderingAttributeTable(
            palette: .resolve(appearance: .light, systemPrefersDark: false),
            fonts: EditorRenderingFonts(fontSizePoints: 13)
        )
        var cachedRegularFont: NSFont { cachedFonts.regular }
        var cachedBoldFont: NSFont { cachedFonts.bold }
        var cachedItalicFont: NSFont { cachedFonts.italic }
        var lastStyledPalette: PurpleThemePalette?
        var lastStyledFontSize: Double?
        var lastStyledTypographyGeneration: Int?
        var lastStyledIsEditable: Bool?
        var lastStyledWordWrap: Bool?
        var wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
        var lastSyncedBufferRevision: BufferRevision?
        var hasPendingLocalEdit = false
        var lastHighlightSnapshot: HighlightRenderSignature?
        var appliedSelectionToken = 0
        var appliedFocusRequestToken = 0
        var undoRegistry: PerTabUndoManagerRegistry?
        var activeDocumentID: DocumentID?
        var activeBufferRevision: BufferRevision?
        var hadNonMutatingHighlights = false
        var completionProvider: ((String) -> String?)?
        /// Visible ghost suggestion: caret location it belongs to and the suffix `Tab` inserts.
        private(set) var ghostSuggestion: (location: Int, suffix: String)?
        private var ghostView: GhostCompletionView?
        /// Replacement string of the edit in flight, captured in `shouldChangeTextIn` (insertions only).
        private var pendingInsertedString: String?
        var onViewportMetricsChange: ((GutterViewportMetrics) -> Void)?
        private var lastEmittedViewportMetrics: GutterViewportMetrics?
        private var scrollBoundsObserver: (any NSObjectProtocol)?
        private var isSwappingTabBuffer = false
        private lazy var tabSwapScratchUndoManager = UndoManager()
        private var cachedLineIndex: MarkdownLineIndex?
        private var cachedIndexDocumentID: DocumentID?
        private var cachedIndexRevision: BufferRevision?
        private var cachedIndexLength = -1

        var gfmTypographyGeneration = -1

        /// Rebuilds editor faces only when the zoomed size or the typography generation changed.
        func updateGFMFontsIfNeeded(fontSizePoints: Double, typography: AppTypography, generation: Int) {
            guard gfmFontSize != fontSizePoints || gfmTypographyGeneration != generation else { return }
            gfmFontSize = fontSizePoints
            gfmTypographyGeneration = generation
            cachedFonts = EditorRenderingFonts(fontSizePoints: fontSizePoints, typography: typography)
            renderingAttributeTable = EditorRenderingAttributeTable(palette: gfmPalette, fonts: cachedFonts)
        }

        /// Rebuilds cached rendering attribute dictionaries only when palette, font size, or typography generation changes.
        func updateRenderingTableIfNeeded(
            palette: PurpleThemePalette,
            fontSizePoints: Double,
            typography: AppTypography,
            generation: Int
        ) {
            let paletteChanged = gfmPalette != palette
            let fontsChanged = gfmFontSize != fontSizePoints || gfmTypographyGeneration != generation
            if paletteChanged { gfmPalette = palette }
            if fontsChanged {
                gfmFontSize = fontSizePoints
                gfmTypographyGeneration = generation
                cachedFonts = EditorRenderingFonts(fontSizePoints: fontSizePoints, typography: typography)
            }
            if paletteChanged || fontsChanged {
                renderingAttributeTable = EditorRenderingAttributeTable(palette: gfmPalette, fonts: cachedFonts)
            }
        }

        func markSynced(documentID: DocumentID, revision: BufferRevision) {
            activeDocumentID = documentID
            lastSyncedBufferRevision = revision
        }

        /// Re-tags an already-rebuilt local `MarkdownLineIndex` after `textDidChange` -> `updateNSView` bumps `BufferRevision` so a single keystroke never builds `MarkdownLineIndex` twice.
        func retagCachedLineIndexRevision(documentID: DocumentID, revision: BufferRevision, storageLength: Int) {
            if cachedLineIndex != nil,
               cachedIndexDocumentID == documentID,
               cachedIndexLength == storageLength {
                cachedIndexRevision = revision
            }
        }

        /// Subscribes to `NSScrollView.contentView` clip bounds changes to keep `LineNumberGutterView` scroll-synchronized (`BUG-012`).
        func observeScrollBounds(of scrollView: NSScrollView, textView: NSTextView) {
            detachScrollObserver()
            let clipView = scrollView.contentView
            scrollBoundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self, weak scrollView, weak textView] _ in
                MainActor.assumeIsolated {
                    guard let self, let scrollView, let textView else { return }
                    self.emitViewportMetrics(for: scrollView, textView: textView)
                }
            }
        }

        func detachScrollObserver() {
            if let observer = scrollBoundsObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollBoundsObserver = nil
            }
        }

        /// Upper bound on gutter rows sampled per pass (`F-017-01`): before the first viewport layout, TextKit 2 reports zero-height
        /// fragment frames, so a "past the visible rect" stop condition never fires and the whole document (20k lines → 20k SwiftUI
        /// rows, 1.1 GB) was enumerated. 512 rows covers a 4K-tall window at 50 % zoom.
        static let maxGutterLineMetrics = 512

        func emitViewportMetrics(for scrollView: NSScrollView, textView: NSTextView) {
            guard let onViewportMetricsChange else { return }
            let storageLen = textView.textStorage?.length ?? 0
            let indexForLookup = (cachedLineIndex != nil && cachedIndexLength == storageLen) ? cachedLineIndex : nil
            let metrics = Self.captureGutterViewportMetrics(in: scrollView, textView: textView, cachedLineIndex: indexForLookup)
            guard metrics != lastEmittedViewportMetrics else { return }
            lastEmittedViewportMetrics = metrics
            onViewportMetricsChange(metrics)
        }

        /// Samples visible TextKit 2 layout fragments (`O(log L + viewport)` when cached index is present) so `LineNumberGutterView` aligns with both scroll offset and soft-wrapped paragraphs (`BUG-012`).
        static func captureGutterViewportMetrics(
            in scrollView: NSScrollView,
            textView: NSTextView,
            cachedLineIndex: MarkdownLineIndex? = nil
        ) -> GutterViewportMetrics {
            let visibleRect = scrollView.documentVisibleRect
            let scrollY = max(0, visibleRect.origin.y)
            guard let textLayoutManager = textView.textLayoutManager,
                  let contentManager = textLayoutManager.textContentManager else {
                return GutterViewportMetrics(scrollOffsetY: scrollY, visibleLines: [])
            }
            let docStart = contentManager.documentRange.location
            let startLocation = textLayoutManager.textViewportLayoutController.viewportRange?.location ?? docStart
            let originY = textView.textContainerOrigin.y
            let startOffset = max(0, contentManager.offset(from: docStart, to: startLocation))

            let baseLine: Int
            if startOffset == 0 {
                baseLine = 1
            } else if let cachedLineIndex {
                baseLine = cachedLineIndex.line(containing: startOffset) + 1
            } else {
                // Fast UTF-8 byte scan fallback when no MarkdownLineIndex is cached (non-Markdown files or standalone tests).
                let text = textView.string
                if let countedLine = text.utf8.withContiguousStorageIfAvailable({ buf -> Int in
                    guard let base = buf.baseAddress else { return 1 }
                    let count = buf.count
                    var line = 1
                    var utf16Pos = 0
                    var i = 0
                    while i < count && utf16Pos < startOffset {
                        let b = base[i]
                        if b == 0x0A {
                            line += 1
                            utf16Pos += 1
                            i += 1
                        } else if b == 0x0D {
                            line += 1
                            if i + 1 < count && base[i + 1] == 0x0A && utf16Pos + 1 < startOffset {
                                utf16Pos += 2
                                i += 2
                            } else {
                                utf16Pos += 1
                                i += 1
                            }
                        } else if b < 0x80 {
                            utf16Pos += 1
                            i += 1
                        } else if b < 0xE0 {
                            utf16Pos += 1
                            i += 2
                        } else if b < 0xF0 {
                            utf16Pos += 1
                            i += 3
                        } else {
                            utf16Pos += 2
                            i += 4
                        }
                    }
                    return line
                }) {
                    baseLine = countedLine
                } else {
                    let textUnits = text.utf16
                    var line = 1
                    var idx = textUnits.startIndex
                    var counted = 0
                    while idx < textUnits.endIndex, counted < startOffset {
                        let u = textUnits[idx]
                        if u == 0x0A {
                            line += 1
                            idx = textUnits.index(after: idx)
                            counted += 1
                        } else if u == 0x0D {
                            line += 1
                            let next = textUnits.index(after: idx)
                            if next < textUnits.endIndex, textUnits[next] == 0x0A, counted + 1 < startOffset {
                                idx = textUnits.index(after: next)
                                counted += 2
                            } else {
                                idx = next
                                counted += 1
                            }
                        } else {
                            idx = textUnits.index(after: idx)
                            counted += 1
                        }
                    }
                    baseLine = line
                }
            }

            var metrics: [GutterLineMetric] = []
            var currentLine = baseLine
            textLayoutManager.enumerateTextLayoutFragments(from: startLocation, options: []) { fragment in
                let frame = fragment.layoutFragmentFrame
                let minY = originY + frame.minY
                if frame.maxY >= visibleRect.minY - 64 {
                    metrics.append(GutterLineMetric(lineNumber: currentLine, minY: minY, height: frame.height))
                }
                currentLine += 1
                if frame.minY > visibleRect.maxY + 64 || metrics.count >= maxGutterLineMetrics {
                    return false
                }
                return true
            }
            return GutterViewportMetrics(scrollOffsetY: scrollY, visibleLines: metrics)
        }

        /// Provides the dedicated per-tab `UndoManager` so tabs never share `NSWindow.undoManager` with closed editors or modal bars (`BUG-001`, `CWE-416`).
        func undoManager(for view: NSTextView) -> UndoManager? {
            if isSwappingTabBuffer {
                return tabSwapScratchUndoManager
            }
            guard let activeDocumentID, let undoRegistry else { return nil }
            return undoRegistry.undoManager(for: activeDocumentID)
        }

        /// Replaces editor text cleanly: same-tab updates register atomic undoable steps via `shouldChangeText` while preserving selection length; cross-tab switches swap buffers without mutating existing per-tab undo stacks (`BUG-001`, `BUG-005`).
        func applyProgrammaticTextUpdate(
            _ newText: String,
            to textView: NSTextView,
            documentID: DocumentID,
            isInitialSetup: Bool = false
        ) {
            let previousSelection = textView.selectedRange()
            let targetLocation = pendingProgrammaticCaret ?? previousSelection.location
            let targetLength = (pendingProgrammaticCaret != nil) ? 0 : previousSelection.length
            pendingProgrammaticCaret = nil

            let isSameDocument = !isInitialSetup && activeDocumentID == documentID
            isApplyingProgrammaticUpdate = true
            defer {
                isApplyingProgrammaticUpdate = false
                invalidateLineIndex()
            }

            if isSameDocument {
                let currentLength = textView.textStorage?.length ?? 0
                let oldText = currentNativeText(of: textView)
                if oldText != newText {
                    // Replace only the differing middle range (common prefix/suffix kept): TextKit 2 re-lays out just the
                    // touched paragraphs, live log tails append in O(delta), and the single undo step stays exact.
                    let edit = Self.minimalReplacement(from: oldText, to: newText)
                        ?? (NSRange(location: 0, length: currentLength), newText)
                    if !textView.isEditable {
                        // Read-only views (log tail): no undo registration, no delegate edit notifications.
                        textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
                    } else if textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) {
                        textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
                        textView.didChangeText()
                    } else {
                        textView.string = newText
                    }
                }
            } else {
                isSwappingTabBuffer = true
                activeDocumentID = documentID
                textView.string = newText
                tabSwapScratchUndoManager.removeAllActions()
                isSwappingTabBuffer = false
            }

            updateNativeTextMirror(newText)
            let newLength = nativeTextMirror?.utf16Length ?? newText.utf16.count
            let clampedLocation = min(max(0, targetLocation), newLength)
            let clampedLength = min(max(0, targetLength), newLength - clampedLocation)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
        }

        /// Smallest UTF-16 range of `old` (and its replacement) that turns `old` into `new`, keeping the longest common
        /// prefix and suffix on Unicode-scalar boundaries; `nil` when `old` has no contiguous UTF-8 storage.
        static func minimalReplacement(from old: String, to new: String) -> (range: NSRange, replacement: String)? {
            var a = old, b = new
            let bounds: (prefix: Int, suffix: Int)? = a.withUTF8 { x in
                b.withUTF8 { y in
                    guard let xb = x.baseAddress ?? (x.isEmpty ? UnsafePointer(bitPattern: 1) : nil),
                          let yb = y.baseAddress ?? (y.isEmpty ? UnsafePointer(bitPattern: 1) : nil) else { return nil }
                    let la = x.count, lb = y.count, limit = min(la, lb)
                    // Common prefix: memcmp on 4 KiB blocks, then bytes inside the first differing block.
                    var p = 0
                    while p + 4096 <= limit, memcmp(xb + p, yb + p, 4096) == 0 { p += 4096 }
                    while p < limit, x[p] == y[p] { p += 1 }
                    while p > 0, p < la, (x[p] & 0xC0) == 0x80 { p -= 1 }
                    // Common suffix (not overlapping the prefix), same strategy from the end.
                    let maxSuffix = limit - p
                    var q = 0
                    while q + 4096 <= maxSuffix, memcmp(xb + la - q - 4096, yb + lb - q - 4096, 4096) == 0 { q += 4096 }
                    while q < maxSuffix, x[la - 1 - q] == y[lb - 1 - q] { q += 1 }
                    while q > 0, (x[la - q] & 0xC0) == 0x80 { q -= 1 }
                    return (p, q)
                }
            }
            guard let bounds else { return nil }
            // UTF-8 → UTF-16 offsets through String indices (breadcrumb-accelerated for native strings).
            let oldStart = a.utf8.index(a.utf8.startIndex, offsetBy: bounds.prefix)
            let oldEnd = a.utf8.index(a.utf8.endIndex, offsetBy: -bounds.suffix)
            let newStart = b.utf8.index(b.utf8.startIndex, offsetBy: bounds.prefix)
            let newEnd = b.utf8.index(b.utf8.endIndex, offsetBy: -bounds.suffix)
            let location = a.utf16.distance(from: a.utf16.startIndex, to: oldStart)
            let length = a.utf16.distance(from: oldStart, to: oldEnd)
            return (NSRange(location: location, length: length), String(b[newStart..<newEnd]))
        }

        /// Native UTF-8 copy of the text-storage contents, refreshed on every `textDidChange` and programmatic update (`PERF-B3`).
        ///
        /// Invariant: every storage mutation either posts `textDidChange` (typing, undo/redo, Find & Replace, `insertText`)
        /// or goes through `applyProgrammaticTextUpdate`, so the mirror is current whenever its UTF-16 length matches the
        /// storage; on a length mismatch callers fall back to the bridged `textView.string`.
        private(set) var nativeTextMirror: (text: String, utf16Length: Int)?

        func updateNativeTextMirror(_ text: String) {
            let native = NativeTextNormalizer.native(text)
            nativeTextMirror = (native, native.utf16.count)
        }

        /// Native text for `textView` when the mirror is current, else the bridged storage string.
        func currentNativeText(of textView: NSTextView) -> String {
            if let mirror = nativeTextMirror, mirror.utf16Length == (textView.textStorage?.length ?? -1) { return mirror.text }
            return textView.string
        }

        var lineIndexProvider: ((DocumentID, BufferRevision) -> MarkdownLineIndex?)?

        /// Validator line index: the workbench's shared per-revision index when it matches the storage, otherwise one
        /// built from native text instead of re-bridging `textView.string` on every revision.
        func renderingLineIndex(for textView: NSTextView, documentID: DocumentID?, revision: BufferRevision?) -> MarkdownLineIndex {
            let length = textView.textStorage?.length ?? 0
            if let documentID, let revision, !hasPendingLocalEdit,
               let shared = lineIndexProvider?(documentID, revision), shared.units.count == length {
                return shared
            }
            return lineIndex(textProvider: { currentNativeText(of: textView) }, expectedLength: length, documentID: documentID, revision: revision)
        }

        /// `true` when the editor already shows `text`; compares native storage (memcmp) instead of a bridged `O(N)` walk.
        func isDisplaying(_ text: String, in textView: NSTextView) -> Bool {
            currentNativeText(of: textView) == text
        }

        /// Selects `range` (clamped to the text) and scrolls it into view (Navigator jumps, Find, Go to Line).
        ///
        /// TextKit 2 positions unlaid-out text by estimate, so a first `scrollRangeToVisible` can land beside a far target;
        /// when the target fragment is still outside the visible rect, only that fragment is laid out (never the whole
        /// document, `UI-012`) and the scroll is repeated.
        static func revealSelection(_ range: NSRange, in textView: NSTextView) {
            let length = textView.textStorage?.length ?? (textView.string as NSString).length
            let location = min(max(0, range.location), length)
            let clamped = NSRange(location: location, length: min(max(0, range.length), length - location))
            textView.setSelectedRange(clamped)
            textView.scrollRangeToVisible(clamped)
            guard let tlm = textView.textLayoutManager, let tcm = tlm.textContentManager,
                  let start = tcm.location(tcm.documentRange.location, offsetBy: location),
                  let target = NSTextRange(location: start, end: tcm.location(start, offsetBy: min(1, length - location)) ?? start),
                  let scrollView = textView.enclosingScrollView else { return }
            let visible = scrollView.documentVisibleRect
            if let fragment = tlm.textLayoutFragment(for: start), visible.intersects(fragment.layoutFragmentFrame) { return }
            tlm.ensureLayout(for: target)
            if let fragment = tlm.textLayoutFragment(for: start) {
                let targetY = max(0, textView.textContainerOrigin.y + fragment.layoutFragmentFrame.minY - visible.height * 0.25)
                let maxScrollY = max(0, textView.frame.height - visible.height)
                scrollView.contentView.scroll(to: NSPoint(x: visible.origin.x, y: min(targetY, maxScrollY)))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            tlm.textViewportLayoutController.layoutViewport()
            textView.scrollRangeToVisible(clamped)
            textView.needsDisplay = true
        }

        /// Zero-bridge cache lookup used by `renderingAttributesValidator`: avoids touching `textView.string` completely on cache hits.
        func lineIndex(
            textProvider: () -> String,
            expectedLength: Int,
            documentID: DocumentID?,
            revision: BufferRevision?
        ) -> MarkdownLineIndex {
            if let cachedLineIndex,
               cachedIndexLength == expectedLength,
               cachedIndexDocumentID == documentID,
               cachedIndexRevision == revision,
               revision != nil || (documentID == nil && cachedIndexLength == expectedLength) {
                return cachedLineIndex
            }
            let text = textProvider()
            let index = MarkdownLineIndex(text: text)
            cachedLineIndex = index
            cachedIndexDocumentID = documentID
            cachedIndexRevision = revision
            cachedIndexLength = index.units.count
            return index
        }

        /// Line index cached by `(DocumentID, BufferRevision, utf16Count)` so same-length edits invalidate deterministically without scanning every keystroke when unchanged (`BUG-015`).
        func lineIndex(
            for text: String,
            documentID: DocumentID? = nil,
            revision: BufferRevision? = nil
        ) -> MarkdownLineIndex {
            let length = text.utf16.count
            if let cachedLineIndex,
               cachedIndexLength == length,
               cachedIndexDocumentID == documentID,
               cachedIndexRevision == revision,
               revision != nil || (documentID == nil && cachedIndexLength == length) {
                return cachedLineIndex
            }
            let index = MarkdownLineIndex(text: text)
            cachedLineIndex = index
            cachedIndexDocumentID = documentID
            cachedIndexRevision = revision
            cachedIndexLength = length
            return index
        }

        func invalidateLineIndex() {
            cachedLineIndex = nil
            cachedIndexDocumentID = nil
            cachedIndexRevision = nil
            cachedIndexLength = -1
        }

        var isApplyingProgrammaticUpdate = false
        var pendingProgrammaticCaret: Int?

        init(
            onTextChange: @escaping (String) -> Void,
            onSelectionChange: @escaping (SwiftEditCore.TextRange) -> Void,
            onSmartNewline: @escaping (Int) -> Int?,
            onListIndent: @escaping (Bool) -> SmartListOutcome,
            onTableTab: @escaping (Bool) -> TableEditOutcome = { _ in .notApplicable }
        ) {
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
            self.onSmartNewline = onSmartNewline
            self.onListIndent = onListIndent
            self.onTableTab = onTableTab
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            invalidateLineIndex()
            hasPendingLocalEdit = true
            updateNativeTextMirror(textView.string)
            onTextChange(nativeTextMirror?.text ?? textView.string)
            let inserted = pendingInsertedString
            pendingInsertedString = nil
            refreshGhostCompletion(in: textView, inserted: inserted)
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            pendingInsertedString = affectedCharRange.length == 0 ? replacementString : nil
            return true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            if let ghost = ghostSuggestion, range.length != 0 || range.location != ghost.location {
                hideGhostCompletion()
            }
            onSelectionChange(SwiftEditCore.TextRange(location: range.location, length: range.length))
        }

        // MARK: Ghost-text completion (`REQ-020-01`)

        /// Shows a suggestion only right after a single typed character that ends a word prefix of `>= 2` units.
        func refreshGhostCompletion(in textView: NSTextView, inserted: String?) {
            guard let provider = completionProvider, textView.isEditable, !textView.hasMarkedText(),
                  let inserted, inserted.count == 1 else {
                hideGhostCompletion()
                return
            }
            let selection = textView.selectedRange()
            let text = ((nativeTextMirror?.text ?? textView.textStorage?.string) ?? "") as NSString
            guard selection.length == 0,
                  let match = WordCompletionIndex.wordPrefix(endingAt: selection.location, in: text),
                  let suffix = provider(match.prefix) else {
                hideGhostCompletion()
                return
            }
            showGhostCompletion(suffix, at: selection.location, in: textView)
        }

        private func showGhostCompletion(_ suffix: String, at location: Int, in textView: NSTextView) {
            guard let window = textView.window else { return }
            let screenRect = textView.firstRect(forCharacterRange: NSRange(location: location, length: 0), actualRange: nil)
            guard screenRect != .zero else {
                hideGhostCompletion()
                return
            }
            let caretRect = textView.convert(window.convertFromScreen(screenRect), from: nil)
            let view = ghostView ?? GhostCompletionView()
            if view.superview !== textView {
                textView.addSubview(view)
            }
            ghostView = view
            view.configure(
                suffix: suffix,
                font: cachedRegularFont,
                textColor: gfmPalette.editorCanvasText.nsColor.withAlphaComponent(0.42),
                canvasColor: gfmPalette.editorCanvasBackground.nsColor
            )
            view.frame = NSRect(x: caretRect.minX + 1, y: caretRect.minY, width: view.preferredWidth, height: max(caretRect.height, cachedRegularFont.boundingRectForFont.height))
            view.isHidden = false
            ghostSuggestion = (location, suffix)
        }

        func hideGhostCompletion() {
            ghostSuggestion = nil
            ghostView?.isHidden = true
        }

        /// Inserts the visible suggestion as one undoable `insertText` (one `BufferRevision`); `false` when none applies.
        func acceptGhostCompletion(in textView: NSTextView) -> Bool {
            guard let ghost = ghostSuggestion, textView.isEditable else { return false }
            let selection = textView.selectedRange()
            guard selection.length == 0, selection.location == ghost.location else {
                hideGhostCompletion()
                return false
            }
            hideGhostCompletion()
            textView.insertText(ghost.suffix, replacementRange: selection)
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)), acceptGhostCompletion(in: textView) {
                return true
            }
            if ghostSuggestion != nil,
               commandSelector == #selector(NSResponder.cancelOperation(_:)) || commandSelector == #selector(NSTextView.complete(_:)) {
                hideGhostCompletion()
                return true
            }
            if ghostSuggestion != nil {
                hideGhostCompletion()
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) || commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return handleListIndent(in: textView, outdent: commandSelector == #selector(NSResponder.insertBacktab(_:)))
            }
            guard commandSelector == #selector(NSResponder.insertNewline(_:)),
                  textView.isEditable,
                  textView.selectedRange().length == 0 else {
                return false
            }
            if let newCaret = onSmartNewline(textView.selectedRange().location) {
                pendingProgrammaticCaret = newCaret
                return true
            }
            return false
        }
    }
}
#endif

#if os(macOS)
/// Editor font set cached once per zoom level so the rendering validator never creates fonts per fragment (`UI-012`).
struct EditorRenderingFonts {
    let regular: NSFont
    let bold: NSFont
    let italic: NSFont
    /// YAML keys use a lighter (not ultra-light) weight to read as secondary while staying legible at `50%` zoom (`REQ-010`).
    let yamlKey: NSFont

    /// Editor faces resolved through `AppTypography` (`REQ-008`); the YAML key face uses a lighter weight (`REQ-010`).
    @MainActor
    init(fontSizePoints: Double, typography: AppTypography) {
        let size = CGFloat(fontSizePoints)
        regular = typography.nsFont(.editor, size: size)
        bold = typography.nsFont(.editor, size: size, weight: .bold)
        italic = typography.nsFont(.editor, size: size, italic: true)
        yamlKey = typography.nsFont(.editor, size: size, weight: .light)
    }

    /// Default-choice faces (monospaced system font).
    @MainActor
    init(fontSizePoints: Double) {
        self.init(fontSizePoints: fontSizePoints, typography: AppTypography.fallback)
    }
}

/// Pre-built per-`(palette, fonts)` attribute cache so `renderingAttributesValidator` allocates zero `NSColor`s or arrays per span.
@MainActor
struct EditorRenderingAttributeTable {
    typealias Entries = [(key: NSAttributedString.Key, value: Any)]

    let bold: Entries
    let italic: Entries
    let strikethrough: Entries
    let code: Entries
    let link: Entries
    let inlineHTML: Entries
    let secondary: Entries
    let yamlKey: Entries
    let logTrace: Entries
    let logDebug: Entries
    let logInfo: Entries
    let logWarn: Entries
    let logError: Entries
    let logCritical: Entries
    let logTimestamp: Entries
    let logGuid: Entries
    let logString: Entries
    let logException: Entries

    // Cached NSColors for non-mutating viewport highlights (backticks, brackets, lint underlines)
    let backtickForeground: NSColor
    let backtickInlineBackground: NSColor
    let backtickMultilineBackground: NSColor
    let wordOccurrenceBackground: NSColor
    let wordOccurrenceUnderline: NSColor
    let nestedBracketColors: [NSColor]
    let activeBracketHighlight: NSColor
    let lintWarnColor: NSColor
    let lintWarnBackground: NSColor
    let lintErrorColor: NSColor
    let lintErrorBackground: NSColor
    let unbalancedBracketForeground: NSColor
    let unbalancedBracketBackground: NSColor

    init(palette: PurpleThemePalette, fonts: EditorRenderingFonts) {
        bold = [(.font, fonts.bold)]
        italic = [(.font, fonts.italic)]
        strikethrough = [(.strikethroughStyle, NSUnderlineStyle.single.rawValue)]
        let inlineBg = palette.backtickInlineBackground.nsColor
        let backtickFg = palette.backtickForeground.nsColor
        code = [(.backgroundColor, inlineBg), (.foregroundColor, backtickFg)]
        link = [(.underlineStyle, NSUnderlineStyle.single.rawValue), (.foregroundColor, palette.linkForeground.nsColor)]
        inlineHTML = [(.foregroundColor, palette.inertHTMLWarningForeground.nsColor)]
        secondary = [(.foregroundColor, palette.secondaryForeground.nsColor)]
        yamlKey = [(.foregroundColor, palette.yamlKeyForeground.nsColor), (.font, fonts.yamlKey)]
        logTrace = [(.foregroundColor, palette.logTraceForeground.nsColor)]
        logDebug = [(.foregroundColor, palette.logDebugForeground.nsColor)]
        logInfo = [(.foregroundColor, palette.logInfoForeground.nsColor)]
        logWarn = [(.foregroundColor, palette.logWarnForeground.nsColor), (.font, fonts.bold)]
        logError = [(.foregroundColor, palette.logErrorForeground.nsColor), (.font, fonts.bold)]
        logCritical = [
            (.foregroundColor, palette.logCriticalForeground.nsColor),
            (.backgroundColor, palette.logCriticalBackground.nsColor),
            (.font, fonts.bold),
        ]
        logTimestamp = [(.foregroundColor, palette.logTimestampForeground.nsColor)]
        logGuid = [(.foregroundColor, palette.logGuidForeground.nsColor)]
        logString = [(.foregroundColor, palette.logStringForeground.nsColor)]
        logException = [(.foregroundColor, palette.logExceptionForeground.nsColor), (.font, fonts.italic)]

        backtickForeground = backtickFg
        backtickInlineBackground = inlineBg
        backtickMultilineBackground = palette.backtickMultilineBackground.nsColor
        wordOccurrenceBackground = palette.wordOccurrenceBackground.nsColor
        wordOccurrenceUnderline = palette.wordOccurrenceUnderline.nsColor
        nestedBracketColors = palette.nestedBracketPalette.isEmpty
            ? [palette.primaryAccent.nsColor]
            : palette.nestedBracketPalette.map(\.nsColor)
        activeBracketHighlight = palette.activeBracketHighlight.nsColor
        let warnColor = palette.bidiWarningForeground.nsColor
        lintWarnColor = warnColor
        lintWarnBackground = warnColor.withAlphaComponent(0.18)
        let errColor = palette.unbalancedBracketHighlight.nsColor
        lintErrorColor = errColor
        lintErrorBackground = errColor.withAlphaComponent(0.24)
        unbalancedBracketForeground = errColor
        unbalancedBracketBackground = palette.unbalancedBracketBackground.nsColor
    }

    func attributes(for kind: MarkdownSyntaxKind) -> Entries {
        switch kind {
        case .heading, .bold: return bold
        case .italic: return italic
        case .strikethrough: return strikethrough
        case .inlineCode, .codeBlock: return code
        case .link, .image: return link
        case .inlineHTML: return inlineHTML
        case .task, .blockquote, .tableRow, .thematicBreak, .yamlPunctuation, .yamlComment: return secondary
        case .yamlKey: return yamlKey
        case .yamlValue: return []
        case .logLevel(let level):
            switch level {
            case .trace: return logTrace
            case .debug: return logDebug
            case .info: return logInfo
            case .warn: return logWarn
            case .error: return logError
            case .critical: return logCritical
            }
        case .logTimestamp: return logTimestamp
        case .logGuid: return logGuid
        case .logString: return logString
        case .logException: return logException
        }
    }
}

/// Single source of truth mapping every `MarkdownSyntaxKind` (GFM and YAML) to non-mutating TextKit 2 rendering attributes.
///
/// Prose and YAML values receive no foreground attribute so they keep the `#FFFFFF`/`#000000` canvas text (`21:1`, `UI-002`).
enum EditorRenderingAttributes {
    static func attributes(for kind: MarkdownSyntaxKind, palette: PurpleThemePalette, fonts: EditorRenderingFonts) -> [(key: NSAttributedString.Key, value: Any)] {
        switch kind {
        case .heading, .bold:
            return [(.font, fonts.bold)]
        case .italic:
            return [(.font, fonts.italic)]
        case .strikethrough:
            return [(.strikethroughStyle, NSUnderlineStyle.single.rawValue)]
        case .inlineCode, .codeBlock:
            return [(.backgroundColor, palette.backtickInlineBackground.nsColor), (.foregroundColor, palette.backtickForeground.nsColor)]
        case .link, .image:
            return [(.underlineStyle, NSUnderlineStyle.single.rawValue), (.foregroundColor, palette.linkForeground.nsColor)]
        case .inlineHTML:
            return [(.foregroundColor, palette.inertHTMLWarningForeground.nsColor)]
        case .task, .blockquote, .tableRow, .thematicBreak, .yamlPunctuation, .yamlComment:
            return [(.foregroundColor, palette.secondaryForeground.nsColor)]
        case .yamlKey:
            return [(.foregroundColor, palette.yamlKeyForeground.nsColor), (.font, fonts.yamlKey)]
        case .yamlValue:
            return []
        case .logLevel(let level):
            switch level {
            case .trace: return [(.foregroundColor, palette.logTraceForeground.nsColor)]
            case .debug: return [(.foregroundColor, palette.logDebugForeground.nsColor)]
            case .info: return [(.foregroundColor, palette.logInfoForeground.nsColor)]
            case .warn: return [(.foregroundColor, palette.logWarnForeground.nsColor), (.font, fonts.bold)]
            case .error: return [(.foregroundColor, palette.logErrorForeground.nsColor), (.font, fonts.bold)]
            case .critical:
                return [(.foregroundColor, palette.logCriticalForeground.nsColor), (.backgroundColor, palette.logCriticalBackground.nsColor), (.font, fonts.bold)]
            }
        case .logTimestamp:
            return [(.foregroundColor, palette.logTimestampForeground.nsColor)]
        case .logGuid:
            return [(.foregroundColor, palette.logGuidForeground.nsColor)]
        case .logString:
            return [(.foregroundColor, palette.logStringForeground.nsColor)]
        case .logException:
            return [(.foregroundColor, palette.logExceptionForeground.nsColor), (.font, fonts.italic)]
        }
    }
}
#endif
