import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Pure viewport range helpers and decomposed `@MainActor` TextKit 2 rendering-attribute highlight passes (`UI-006`, `UI-007`, `UI-012`).
public enum TextKit2ViewportHighlightApplier {

    /// Returns `true` when `[location, location + length)` intersects `visibleRange` (or when `visibleRange` is unbounded).
    public static func intersectsVisible(location: Int, length: Int, visibleRange: NSRange?) -> Bool {
        guard length > 0 else { return false }
        guard let visibleRange else { return true }
        let spanEnd = location + length
        return spanEnd > visibleRange.location && location < visibleRange.location + visibleRange.length
    }

    /// Clamps `[location, location + length)` into `[0, storageLength]`, returning `nil` when empty or out of bounds.
    public static func clampedRange(location: Int, length: Int, storageLength: Int) -> NSRange? {
        guard length > 0, location >= 0, location < storageLength else { return nil }
        let clampedLength = min(length, storageLength - location)
        guard clampedLength > 0 else { return nil }
        return NSRange(location: location, length: clampedLength)
    }

    /// Shared immutable geometry for a single viewport highlight pass.
    @MainActor
    fileprivate struct ViewportContext {
        let layoutManager: NSTextLayoutManager
        let contentManager: NSTextContentManager
        let docRange: NSTextRange
        let targetRange: NSTextRange
        let totalUTF16: Int
        let visStart: Int
        let visibleStart: Int
        let visibleEnd: Int
        let table: EditorRenderingAttributeTable
        let boldFont: NSFont

        func makeTextRange(location: Int, length: Int) -> NSTextRange? {
            guard location >= 0, length > 0, location + length <= totalUTF16,
                  location + length >= visibleStart && location <= visibleEnd else {
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
    }

    /// Applies non-mutating TextKit 2 rendering attributes strictly over the active viewport range (`±256` UTF-16 overscan),
    /// skipping redundant passes when `HighlightRenderSignature` matches `coordinator.lastHighlightSnapshot` (`REQ-004`, `UI-007`).
    @MainActor
    @discardableResult
    static func applyNonMutatingHighlightsIfNeeded(
        to textView: SwiftEditNSTextView,
        coordinator: TextKit2EditorView.Coordinator,
        documentID: DocumentID,
        bufferRevision: BufferRevision,
        palette: PurpleThemePalette,
        fontSizePoints: Double,
        highlightProjection: EditorHighlightProjection,
        lintDiagnostics: [MarkdownLintDiagnostic],
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

        let signature = TextKit2EditorView.Coordinator.HighlightRenderSignature(
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

        let effectiveOccurrences = textView.effectiveWordOccurrenceRanges
        coordinator.wordOccurrenceRanges = effectiveOccurrences

        let hasAnyHighlights = !highlightProjection.backtickSpans.isEmpty
            || !effectiveOccurrences.isEmpty
            || !highlightProjection.bracketPairs.isEmpty
            || highlightProjection.activeBracketPair != nil
            || !lintDiagnostics.isEmpty
            || !highlightProjection.unbalancedBrackets.isEmpty

        if !hasAnyHighlights && !coordinator.hadNonMutatingHighlights {
            return false
        }

        let clearRange = resolveExpandedClearRange(
            contentManager: contentManager,
            docRange: docRange,
            targetRange: targetRange,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd
        )
        layoutManager.setRenderingAttributes([:], for: clearRange)
        layoutManager.invalidateRenderingAttributes(for: clearRange)
        coordinator.hadNonMutatingHighlights = hasAnyHighlights
        guard hasAnyHighlights else {
            layoutManager.invalidateLayout(for: clearRange)
            return true
        }

        let ctx = ViewportContext(
            layoutManager: layoutManager,
            contentManager: contentManager,
            docRange: docRange,
            targetRange: targetRange,
            totalUTF16: totalUTF16,
            visStart: visStart,
            visibleStart: visibleStart,
            visibleEnd: visibleEnd,
            table: coordinator.renderingAttributeTable,
            boldFont: coordinator.cachedBoldFont
        )

        applyBacktickSpans(highlightProjection.backtickSpans, in: ctx)
        applyWordOccurrences(
            effectiveOccurrences,
            selectedRange: textView.selectedRange(),
            in: layoutManager,
            contentManager: contentManager,
            docStart: docRange.location,
            anchorLocation: targetRange.location,
            anchorOffset: visStart,
            rangeStart: visibleStart,
            rangeEnd: visibleEnd,
            table: ctx.table
        )
        applyNestedBracketPairs(highlightProjection.bracketPairs, in: ctx)
        applyActiveBracketPair(highlightProjection.activeBracketPair, in: ctx)
        applyLintUnderlines(lintDiagnostics, in: ctx)
        applyUnbalancedBrackets(highlightProjection.unbalancedBrackets, in: ctx)

        layoutManager.invalidateLayout(for: clearRange)
        return true
    }

    @MainActor
    static func applyWordOccurrences(
        _ occurrences: [SwiftEditCore.TextRange],
        selectedRange: NSRange,
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
        applyPrimarySelectedWordUnderline(
            selectedRange: selectedRange,
            in: layoutManager,
            contentManager: contentManager,
            docStart: docStart,
            anchorLocation: anchorLocation,
            anchorOffset: anchorOffset,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            table: table
        )
        let firstIdx = lowerBoundOccurrenceIndex(occurrences, rangeStart: rangeStart)
        for idx in firstIdx..<occurrences.count {
            let occ = occurrences[idx]
            if occ.location >= rangeEnd { break }
            guard let range = makeAnchoredTextRange(
                location: occ.location,
                length: occ.length,
                contentManager: contentManager,
                docStart: docStart,
                anchorLocation: anchorLocation,
                anchorOffset: anchorOffset
            ) else { continue }
            layoutManager.addRenderingAttribute(.backgroundColor, value: table.wordOccurrenceBackground, for: range)
            layoutManager.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, for: range)
            layoutManager.addRenderingAttribute(.underlineColor, value: table.wordOccurrenceUnderline, for: range)
        }
    }

    private static func lowerBoundOccurrenceIndex(_ occurrences: [SwiftEditCore.TextRange], rangeStart: Int) -> Int {
        var lo = 0, hi = occurrences.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if occurrences[mid].upperBound <= rangeStart { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    @MainActor
    private static func applyPrimarySelectedWordUnderline(
        selectedRange: NSRange,
        in layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager,
        docStart: any NSTextLocation,
        anchorLocation: any NSTextLocation,
        anchorOffset: Int,
        rangeStart: Int,
        rangeEnd: Int,
        table: EditorRenderingAttributeTable
    ) {
        guard selectedRange.length > 0, selectedRange.location < rangeEnd, NSMaxRange(selectedRange) > rangeStart,
              let selTextRange = makeAnchoredTextRange(
                  location: selectedRange.location,
                  length: selectedRange.length,
                  contentManager: contentManager,
                  docStart: docStart,
                  anchorLocation: anchorLocation,
                  anchorOffset: anchorOffset
              ) else { return }
        layoutManager.addRenderingAttribute(.foregroundColor, value: table.primarySelectionBackground, for: selTextRange)
        layoutManager.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.thick.rawValue, for: selTextRange)
        layoutManager.addRenderingAttribute(.underlineColor, value: table.primarySelectionBackground, for: selTextRange)
    }

    @MainActor
    private static func makeAnchoredTextRange(
        location: Int,
        length: Int,
        contentManager: NSTextContentManager,
        docStart: any NSTextLocation,
        anchorLocation: any NSTextLocation,
        anchorOffset: Int
    ) -> NSTextRange? {
        let start = location >= anchorOffset
            ? contentManager.location(anchorLocation, offsetBy: location - anchorOffset)
            : contentManager.location(docStart, offsetBy: location)
        guard let start, let end = contentManager.location(start, offsetBy: length) else { return nil }
        return NSTextRange(location: start, end: end)
    }

    @MainActor
    private static func resolveExpandedClearRange(
        contentManager: NSTextContentManager,
        docRange: NSTextRange,
        targetRange: NSTextRange,
        visibleStart: Int,
        visibleEnd: Int
    ) -> NSTextRange {
        if let clearStart = contentManager.location(docRange.location, offsetBy: visibleStart),
           let clearEnd = contentManager.location(clearStart, offsetBy: visibleEnd - visibleStart),
           let expanded = NSTextRange(location: clearStart, end: clearEnd) {
            return expanded
        }
        return targetRange
    }
}

extension TextKit2ViewportHighlightApplier {
    @MainActor
    fileprivate static func applyBacktickSpans(_ backtickSpans: [BacktickHighlightSpan], in ctx: ViewportContext) {
        guard !backtickSpans.isEmpty else { return }
        let backtickFg = ctx.table.backtickForeground
        let inlineBg = ctx.table.backtickInlineBackground
        let multilineBg = ctx.table.backtickMultilineBackground
        var lo = 0, hi = backtickSpans.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if backtickSpans[mid].range.upperBound < ctx.visibleStart { lo = mid + 1 } else { hi = mid }
        }
        var idx = lo
        while idx < backtickSpans.count {
            let span = backtickSpans[idx]
            if span.range.location > ctx.visibleEnd { break }
            if let nsTextRange = ctx.makeTextRange(location: span.range.location, length: span.range.length) {
                ctx.layoutManager.addRenderingAttribute(.backgroundColor, value: span.kind == .fencedMultiline ? multilineBg : inlineBg, for: nsTextRange)
                ctx.layoutManager.addRenderingAttribute(.foregroundColor, value: backtickFg, for: nsTextRange)
            }
            idx += 1
        }
    }

    @MainActor
    private static func applyNestedBracketPairs(_ bracketPairs: [BracketPairSpan], in ctx: ViewportContext) {
        let depthColors = ctx.table.nestedBracketColors
        guard !depthColors.isEmpty else { return }
        for pair in bracketPairs {
            if pair.openOffset > ctx.visibleEnd { break }
            if pair.closeOffset >= ctx.visibleStart {
                paintVisibleBracketPair(pair, depthColors: depthColors, in: ctx)
            }
        }
    }

    @MainActor
    private static func paintVisibleBracketPair(_ pair: BracketPairSpan, depthColors: [NSColor], in ctx: ViewportContext) {
        let depthColor = depthColors[max(0, pair.nestingDepth) % depthColors.count]
        if pair.openOffset >= ctx.visibleStart, pair.openOffset <= ctx.visibleEnd,
           let openRange = ctx.makeTextRange(location: pair.openOffset, length: 1) {
            ctx.layoutManager.addRenderingAttribute(.foregroundColor, value: depthColor, for: openRange)
            ctx.layoutManager.addRenderingAttribute(.font, value: ctx.boldFont, for: openRange)
        }
        if pair.closeOffset >= ctx.visibleStart, pair.closeOffset <= ctx.visibleEnd,
           let closeRange = ctx.makeTextRange(location: pair.closeOffset, length: 1) {
            ctx.layoutManager.addRenderingAttribute(.foregroundColor, value: depthColor, for: closeRange)
            ctx.layoutManager.addRenderingAttribute(.font, value: ctx.boldFont, for: closeRange)
        }
    }

    @MainActor
    private static func applyActiveBracketPair(_ active: BracketPairSpan?, in ctx: ViewportContext) {
        guard let active else { return }
        let activeBg = ctx.table.activeBracketHighlight
        if let openRange = ctx.makeTextRange(location: active.openOffset, length: 1) {
            ctx.layoutManager.addRenderingAttribute(.backgroundColor, value: activeBg, for: openRange)
        }
        if let closeRange = ctx.makeTextRange(location: active.closeOffset, length: 1) {
            ctx.layoutManager.addRenderingAttribute(.backgroundColor, value: activeBg, for: closeRange)
        }
    }

    @MainActor
    private static func applyLintUnderlines(_ lintDiagnostics: [MarkdownLintDiagnostic], in ctx: ViewportContext) {
        guard !lintDiagnostics.isEmpty else { return }
        var visibleErrorRanges: [NSTextRange] = []
        for diagnostic in lintDiagnostics {
            collectOrApplyDiagnosticUnderline(diagnostic, in: ctx, errorRanges: &visibleErrorRanges)
        }
        for nsRange in visibleErrorRanges {
            applyDiagnosticStyle(
                nsRange,
                style: NSUnderlineStyle.thick.rawValue,
                color: ctx.table.lintErrorColor,
                background: ctx.table.lintErrorBackground,
                in: ctx.layoutManager
            )
        }
    }

    @MainActor
    private static func collectOrApplyDiagnosticUnderline(
        _ diagnostic: MarkdownLintDiagnostic,
        in ctx: ViewportContext,
        errorRanges: inout [NSTextRange]
    ) {
        guard let range = diagnostic.range else { return }
        let spanLength = range.length > 0 ? min(range.length, 1_024) : 1
        guard let nsRange = ctx.makeTextRange(location: range.location, length: spanLength) else { return }
        if diagnostic.severity == .error {
            errorRanges.append(nsRange)
        } else if diagnostic.severity == .warning {
            applyDiagnosticStyle(
                nsRange,
                style: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue,
                color: ctx.table.lintWarnColor,
                background: ctx.table.lintWarnBackground,
                in: ctx.layoutManager
            )
        }
    }

    @MainActor
    private static func applyDiagnosticStyle(
        _ nsRange: NSTextRange,
        style: Int,
        color: NSColor,
        background: NSColor,
        in layoutManager: NSTextLayoutManager
    ) {
        layoutManager.addRenderingAttribute(.underlineStyle, value: style, for: nsRange)
        layoutManager.addRenderingAttribute(.underlineColor, value: color, for: nsRange)
        layoutManager.addRenderingAttribute(.backgroundColor, value: background, for: nsRange)
    }

    @MainActor
    private static func applyUnbalancedBrackets(_ unbalanced: [UnbalancedBracket], in ctx: ViewportContext) {
        guard !unbalanced.isEmpty else { return }
        let errorColor = ctx.table.unbalancedBracketForeground
        let errorBg = ctx.table.unbalancedBracketBackground
        var lo = 0, hi = unbalanced.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if unbalanced[mid].offset < ctx.visibleStart { lo = mid + 1 } else { hi = mid }
        }
        var idx = lo
        while idx < unbalanced.count {
            let stray = unbalanced[idx]
            if stray.offset > ctx.visibleEnd { break }
            if let strayRange = ctx.makeTextRange(location: stray.offset, length: 1) {
                ctx.layoutManager.addRenderingAttribute(.foregroundColor, value: errorColor, for: strayRange)
                ctx.layoutManager.addRenderingAttribute(.backgroundColor, value: errorBg, for: strayRange)
                ctx.layoutManager.addRenderingAttribute(.font, value: ctx.boldFont, for: strayRange)
            }
            idx += 1
        }
    }
}

/// Scoped TextKit 2 styling and facade delegation to `TextKit2ViewportHighlightApplier` for `TextKit2EditorView` (`UI-006`, `UI-007`).
extension TextKit2EditorView {
    /// Applies canvas, selection, insertion-point, and `NSScrollView` scroller appearance tokens ONLY when palette, font size, or editability actually changed (`UI-002`, `UI-003`, `UI-007`, `UI-012`).
    @discardableResult
    func applyStylingIfNeeded(
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
        textView.isSelectable = true
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
        textView.primarySelectionBackgroundColor = palette.selectionBackground.nsColor
        textView.wordOccurrenceBackgroundColor = palette.wordOccurrenceBackground.nsColor
        textView.wordOccurrenceUnderlineColor = palette.wordOccurrenceUnderline.nsColor
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

    /// Delegates non-mutating TextKit 2 viewport highlight passes to `TextKit2ViewportHighlightApplier` (`REQ-004`).
    @discardableResult
    func applyNonMutatingHighlightsIfNeeded(
        to textView: SwiftEditNSTextView,
        coordinator: Coordinator,
        force: Bool
    ) -> Bool {
        TextKit2ViewportHighlightApplier.applyNonMutatingHighlightsIfNeeded(
            to: textView,
            coordinator: coordinator,
            documentID: documentID,
            bufferRevision: bufferRevision,
            palette: palette,
            fontSizePoints: fontSizePoints,
            highlightProjection: highlightProjection,
            lintDiagnostics: lintDiagnostics,
            force: force
        )
    }
}

#endif
