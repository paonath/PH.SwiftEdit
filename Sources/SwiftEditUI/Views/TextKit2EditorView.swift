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

/// `@MainActor` TextKit 2 `NSTextView` wrapper enforcing `#FFFFFF`/`#000000` inverted canvas colors, current-line highlight, non-mutating nested bracket and backtick highlights, Markdown smart Enter continuation, `50%..300%` monospaced zoom, and read-only binary protection (`UI-002..008`, `UI-012`).
@MainActor
struct TextKit2EditorView: NSViewRepresentable {
    var documentID: DocumentID = DocumentID()
    var bufferRevision: BufferRevision = BufferRevision(1)
    let text: String
    let isEditable: Bool
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
        coordinator.undoRegistry = undoRegistry
        coordinator.activeBufferRevision = bufferRevision
        coordinator.syntaxLanguage = documentLanguage
        coordinator.gfmPalette = palette
        coordinator.updateGFMFontsIfNeeded(fontSizePoints: fontSizePoints)

        let stylingChanged = applyStylingIfNeeded(to: textView, in: scrollView, coordinator: coordinator, force: false)

        var textMutated = false
        let needsTextSyncCheck = coordinator.activeDocumentID != documentID
            || coordinator.lastSyncedBufferRevision != bufferRevision
            || coordinator.hasPendingLocalEdit
        if needsTextSyncCheck {
            if coordinator.hasPendingLocalEdit && coordinator.activeDocumentID == documentID {
                // Local textDidChange already owns the live NSTextStorage contents; re-stamp revision without O(N) full-string compare.
                coordinator.hasPendingLocalEdit = false
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
                textView.setSelectedRange(NSRange(location: programmaticSelection.location, length: programmaticSelection.length))
                coordinator.isApplyingProgrammaticUpdate = false
                textView.scrollRangeToVisible(NSRange(location: programmaticSelection.location, length: programmaticSelection.length))
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
        coordinator.gfmPalette = palette
        coordinator.updateGFMFontsIfNeeded(fontSizePoints: fontSizePoints)
        textView.textLayoutManager?.renderingAttributesValidator = { [weak coordinator, weak textView] layoutManager, fragment in
            guard let coordinator, let textView, coordinator.syntaxLanguage != .plainText,
                  let contentManager = layoutManager.textContentManager else { return }
            let docStart = contentManager.documentRange.location
            let fragStart = contentManager.offset(from: docStart, to: fragment.rangeInElement.location)
            let fragEnd = contentManager.offset(from: docStart, to: fragment.rangeInElement.endLocation)
            guard fragEnd > fragStart else { return }
            let index = coordinator.renderingLineIndex(
                for: textView,
                documentID: coordinator.activeDocumentID,
                revision: coordinator.activeBufferRevision
            )
            let spans = DocumentSyntaxHighlighter.spans(index: index, visibleRange: SwiftEditCore.TextRange(location: fragStart, length: fragEnd - fragStart), language: coordinator.syntaxLanguage)
            guard !spans.isEmpty else { return }
            let palette = coordinator.gfmPalette
            let fonts = coordinator.cachedFonts
            for span in spans {
                let attributes = EditorRenderingAttributes.attributes(for: span.kind, palette: palette, fonts: fonts)
                guard !attributes.isEmpty,
                      let start = contentManager.location(docStart, offsetBy: span.range.location),
                      let end = contentManager.location(start, offsetBy: span.range.length),
                      let range = NSTextRange(location: start, end: end) else { continue }
                for attribute in attributes {
                    layoutManager.addRenderingAttribute(attribute.key, value: attribute.value, for: range)
                }
            }
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
           coordinator.lastStyledIsEditable == isEditable {
            return false
        }
        coordinator.lastStyledPalette = palette
        coordinator.lastStyledFontSize = fontSizePoints
        coordinator.lastStyledIsEditable = isEditable
        coordinator.updateGFMFontsIfNeeded(fontSizePoints: fontSizePoints)

        let editorFont = coordinator.cachedRegularFont
        let canvasBg = palette.editorCanvasBackground.nsColor
        let canvasFg = palette.editorCanvasText.nsColor

        scrollView.drawsBackground = true
        scrollView.backgroundColor = canvasBg
        scrollView.appearance = NSAppearance(named: palette.mode == .black ? .darkAqua : .aqua)
        scrollView.scrollerKnobStyle = (palette.mode == .black) ? .light : .dark

        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.isEditable = isEditable
        textView.backgroundColor = canvasBg
        textView.textColor = canvasFg
        textView.insertionPointColor = canvasFg
        textView.currentLineHighlightColor = palette.currentLineHighlight.nsColor
        textView.font = editorFont
        textView.selectedTextAttributes = [
            .backgroundColor: palette.selectionBackground.nsColor,
            .foregroundColor: canvasFg,
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
            || !highlightProjection.bracketPairs.isEmpty
            || highlightProjection.activeBracketPair != nil
            || !lintDiagnostics.isEmpty
            || !highlightProjection.unbalancedBrackets.isEmpty

        if !hasAnyHighlights && !coordinator.hadNonMutatingHighlights {
            return false
        }

        layoutManager.setRenderingAttributes([:], for: targetRange)
        coordinator.hadNonMutatingHighlights = hasAnyHighlights
        guard hasAnyHighlights else { return true }

        func intersectsVisible(_ loc: Int, _ len: Int) -> Bool {
            let end = loc + len
            return end >= visibleStart && loc <= visibleEnd
        }

        func makeTextRange(location: Int, length: Int) -> NSTextRange? {
            guard location >= 0, length > 0, location + length <= totalUTF16,
                  intersectsVisible(location, length),
                  let start = contentManager.location(docRange.location, offsetBy: location),
                  let end = contentManager.location(start, offsetBy: length) else {
                return nil
            }
            return NSTextRange(location: start, end: end)
        }

        // 1. Backtick inline and multiline fenced code highlights (sorted by location; binary search to first candidate)
        let backtickSpans = highlightProjection.backtickSpans
        if !backtickSpans.isEmpty {
            let backtickFg = palette.backtickForeground.nsColor
            let inlineBg = palette.backtickInlineBackground.nsColor
            let multilineBg = palette.backtickMultilineBackground.nsColor
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

        let boldFont = coordinator.cachedBoldFont

        // 2. Nested depth-colored bracket pairs ({}, [], ()) (sorted by openOffset; early-break past visibleEnd)
        for pair in highlightProjection.bracketPairs {
            if pair.openOffset > visibleEnd { break }
            guard pair.closeOffset >= visibleStart else { continue }
            let depthColor = palette.nestedBracketColor(forDepth: pair.nestingDepth).nsColor
            if let openRange = makeTextRange(location: pair.openOffset, length: 1) {
                layoutManager.addRenderingAttribute(.foregroundColor, value: depthColor, for: openRange)
                layoutManager.addRenderingAttribute(.font, value: boldFont, for: openRange)
            }
            if let closeRange = makeTextRange(location: pair.closeOffset, length: 1) {
                layoutManager.addRenderingAttribute(.foregroundColor, value: depthColor, for: closeRange)
                layoutManager.addRenderingAttribute(.font, value: boldFont, for: closeRange)
            }
        }

        // 3. Active caret bracket pair background emphasis
        if let active = highlightProjection.activeBracketPair {
            let activeBg = palette.activeBracketHighlight.nsColor
            if let openRange = makeTextRange(location: active.openOffset, length: 1) {
                layoutManager.addRenderingAttribute(.backgroundColor, value: activeBg, for: openRange)
            }
            if let closeRange = makeTextRange(location: active.closeOffset, length: 1) {
                layoutManager.addRenderingAttribute(.backgroundColor, value: activeBg, for: closeRange)
            }
        }

        // 3b. Lint dotted underlines (`>= 3.0:1` tokens): draw warnings then errors without allocating/sorting.
        if !lintDiagnostics.isEmpty {
            let warnStyle = NSUnderlineStyle.patternDot.rawValue | NSUnderlineStyle.single.rawValue
            let warnColor = palette.bidiWarningForeground.nsColor
            let errStyle = NSUnderlineStyle.patternDot.rawValue | NSUnderlineStyle.thick.rawValue
            let errColor = palette.unbalancedBracketHighlight.nsColor
            for diagnostic in lintDiagnostics where diagnostic.severity == .warning {
                guard let range = diagnostic.range, let nsRange = makeTextRange(location: range.location, length: min(range.length, 1_024)) else { continue }
                layoutManager.addRenderingAttribute(.underlineStyle, value: warnStyle, for: nsRange)
                layoutManager.addRenderingAttribute(.underlineColor, value: warnColor, for: nsRange)
            }
            for diagnostic in lintDiagnostics where diagnostic.severity == .error {
                guard let range = diagnostic.range, let nsRange = makeTextRange(location: range.location, length: min(range.length, 1_024)) else { continue }
                layoutManager.addRenderingAttribute(.underlineStyle, value: errStyle, for: nsRange)
                layoutManager.addRenderingAttribute(.underlineColor, value: errColor, for: nsRange)
            }
        }

        // 4. Unbalanced bracket error emphasis (sorted by offset; binary search to visibleStart)
        let unbalanced = highlightProjection.unbalancedBrackets
        if !unbalanced.isEmpty {
            let errorColor = palette.unbalancedBracketHighlight.nsColor
            let errorBg = palette.unbalancedBracketBackground.nsColor
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
        var cachedRegularFont: NSFont { cachedFonts.regular }
        var cachedBoldFont: NSFont { cachedFonts.bold }
        var cachedItalicFont: NSFont { cachedFonts.italic }
        var lastStyledPalette: PurpleThemePalette?
        var lastStyledFontSize: Double?
        var lastStyledIsEditable: Bool?
        var lastSyncedBufferRevision: BufferRevision?
        var hasPendingLocalEdit = false
        var lastHighlightSnapshot: HighlightRenderSignature?
        var appliedSelectionToken = 0
        var appliedFocusRequestToken = 0
        var undoRegistry: PerTabUndoManagerRegistry?
        var activeDocumentID: DocumentID?
        var activeBufferRevision: BufferRevision?
        var hadNonMutatingHighlights = false
        var onViewportMetricsChange: ((GutterViewportMetrics) -> Void)?
        private var lastEmittedViewportMetrics: GutterViewportMetrics?
        private var scrollBoundsObserver: (any NSObjectProtocol)?
        private var isSwappingTabBuffer = false
        private lazy var tabSwapScratchUndoManager = UndoManager()
        private var cachedLineIndex: MarkdownLineIndex?
        private var cachedIndexDocumentID: DocumentID?
        private var cachedIndexRevision: BufferRevision?
        private var cachedIndexLength = -1

        func updateGFMFontsIfNeeded(fontSizePoints: Double) {
            guard gfmFontSize != fontSizePoints else { return }
            gfmFontSize = fontSizePoints
            cachedFonts = EditorRenderingFonts(fontSizePoints: fontSizePoints)
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
                if frame.minY > visibleRect.maxY + 64 {
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
                let fullRange = NSRange(location: 0, length: currentLength)
                if !isDisplaying(newText, in: textView) {
                    if textView.shouldChangeText(in: fullRange, replacementString: newText) {
                        textView.textStorage?.replaceCharacters(in: fullRange, with: newText)
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
            let newLength = (newText as NSString).length
            let clampedLocation = min(max(0, targetLocation), newLength)
            let clampedLength = min(max(0, targetLength), newLength - clampedLocation)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
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

        /// Validator line index built from native text instead of re-bridging `textView.string` on every revision.
        func renderingLineIndex(for textView: NSTextView, documentID: DocumentID?, revision: BufferRevision?) -> MarkdownLineIndex {
            lineIndex(textProvider: { currentNativeText(of: textView) }, expectedLength: textView.textStorage?.length ?? 0, documentID: documentID, revision: revision)
        }

        /// `true` when the editor already shows `text`; compares native storage (memcmp) instead of a bridged `O(N)` walk.
        func isDisplaying(_ text: String, in textView: NSTextView) -> Bool {
            currentNativeText(of: textView) == text
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
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            onSelectionChange(SwiftEditCore.TextRange(location: range.location, length: range.length))
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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

    init(fontSizePoints: Double) {
        regular = NSFont.monospacedSystemFont(ofSize: fontSizePoints, weight: .regular)
        bold = NSFont.monospacedSystemFont(ofSize: fontSizePoints, weight: .bold)
        italic = NSFontManager.shared.convert(regular, toHaveTrait: .italicFontMask)
        yamlKey = NSFont.monospacedSystemFont(ofSize: fontSizePoints, weight: .light)
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
            return [(.backgroundColor, palette.backtickInlineBackground.nsColor)]
        case .link, .image:
            return [(.underlineStyle, NSUnderlineStyle.single.rawValue), (.foregroundColor, palette.primaryAccent.nsColor)]
        case .inlineHTML:
            return [(.foregroundColor, palette.inertHTMLWarningForeground.nsColor)]
        case .task, .blockquote, .tableRow, .thematicBreak, .yamlPunctuation, .yamlComment:
            return [(.foregroundColor, palette.secondaryForeground.nsColor)]
        case .yamlKey:
            return [(.foregroundColor, palette.yamlKeyForeground.nsColor), (.font, fonts.yamlKey)]
        case .yamlValue:
            return []
        }
    }
}
#endif
