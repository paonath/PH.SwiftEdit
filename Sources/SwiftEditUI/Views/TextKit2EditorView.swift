import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Custom TextKit 2 `NSTextView` painting a full-width subtle current-line background highlight (`UI-002`, `UI-012`).
@MainActor
final class SwiftEditNSTextView: NSTextView {
    var currentLineHighlightColor: NSColor = .clear
    /// ESC hook (navigator / distraction-free); returns `true` when consumed.
    var onEscape: (() -> Bool)?

    override func cancelOperation(_ sender: Any?) {
        if onEscape?() == true { return }
        super.cancelOperation(sender)
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        needsDisplay = true
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        needsDisplay = true
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard currentLineHighlightColor.alphaComponent > 0 else { return }

        if let lineRect = currentLineFullWidthRect() {
            currentLineHighlightColor.setFill()
            lineRect.fill()
        }
    }

    private func currentLineFullWidthRect() -> NSRect? {
        let origin = textContainerOrigin
        let fallbackHeight = max(14.0, (font?.ascender ?? 12.0) - (font?.descender ?? -3.0) + (font?.leading ?? 2.0))
        guard let textLayoutManager,
              let contentManager = textLayoutManager.textContentManager else {
            return NSRect(x: 0, y: origin.y, width: bounds.width, height: fallbackHeight)
        }

        let caretOffset = min(selectedRange().location, (string as NSString).length)
        guard let caretLocation = contentManager.location(contentManager.documentRange.location, offsetBy: caretOffset) else {
            return NSRect(x: 0, y: origin.y, width: bounds.width, height: fallbackHeight)
        }

        var resolvedRect: NSRect?
        textLayoutManager.enumerateTextLayoutFragments(from: caretLocation, options: [.ensuresLayout]) { fragment in
            let fragmentOrigin = fragment.layoutFragmentFrame.origin
            for lineFragment in fragment.textLineFragments {
                let lineFrame = lineFragment.typographicBounds
                let y = origin.y + fragmentOrigin.y + lineFrame.minY
                resolvedRect = NSRect(x: 0, y: y, width: bounds.width, height: max(lineFrame.height, fallbackHeight))
                return false
            }
            let fallbackY = origin.y + fragmentOrigin.y
            resolvedRect = NSRect(x: 0, y: fallbackY, width: bounds.width, height: max(fragment.layoutFragmentFrame.height, fallbackHeight))
            return false
        }
        return resolvedRect ?? NSRect(x: 0, y: origin.y, width: bounds.width, height: fallbackHeight)
    }
}

/// `@MainActor` TextKit 2 `NSTextView` wrapper enforcing `#FFFFFF`/`#000000` inverted canvas colors, current-line highlight, non-mutating nested bracket and backtick highlights, Markdown smart Enter continuation, `50%..300%` monospaced zoom, and read-only binary protection (`UI-002..008`, `UI-012`).
@MainActor
struct TextKit2EditorView: NSViewRepresentable {
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
    let isMarkdownDocument: Bool
    /// Selection requested by a model-side command, adopted once per `programmaticSelectionToken` change.
    let programmaticSelection: SwiftEditCore.TextRange
    let programmaticSelectionToken: Int
    /// Diagnostics (after active-line suppression) drawn as dotted underlines; capped at `1000` by the engine.
    var lintDiagnostics: [MarkdownLintDiagnostic] = []
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

        applyStyling(to: textView, in: scrollView)
        textView.string = text
        applyNonMutatingHighlights(to: textView)
        scrollView.documentView = textView
        installGFMValidator(on: textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SwiftEditNSTextView else { return }
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onSmartNewline = onSmartNewline
        context.coordinator.onListIndent = onListIndent
        context.coordinator.onTableTab = onTableTab
        context.coordinator.gfmEnabled = isMarkdownDocument
        context.coordinator.gfmPalette = palette
        context.coordinator.gfmFontSize = fontSizePoints

        applyStyling(to: textView, in: scrollView)
        if textView.string != text {
            let previousSelection = textView.selectedRange()
            let targetLocation = context.coordinator.pendingProgrammaticCaret ?? previousSelection.location
            context.coordinator.pendingProgrammaticCaret = nil
            context.coordinator.isApplyingProgrammaticUpdate = true
            textView.string = text
            let clampedLocation = min(max(0, targetLocation), (text as NSString).length)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            context.coordinator.isApplyingProgrammaticUpdate = false
            context.coordinator.invalidateLineIndex()
        }
        if context.coordinator.appliedSelectionToken != programmaticSelectionToken {
            context.coordinator.appliedSelectionToken = programmaticSelectionToken
            let length = (textView.string as NSString).length
            if programmaticSelection.location >= 0, programmaticSelection.upperBound <= length {
                context.coordinator.isApplyingProgrammaticUpdate = true
                textView.setSelectedRange(NSRange(location: programmaticSelection.location, length: programmaticSelection.length))
                context.coordinator.isApplyingProgrammaticUpdate = false
                textView.scrollRangeToVisible(NSRange(location: programmaticSelection.location, length: programmaticSelection.length))
                textView.window?.makeFirstResponder(textView)
            }
        }
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        applyNonMutatingHighlights(to: textView)
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        textView.needsDisplay = true
    }

    /// Installs the viewport-only GFM `renderingAttributesValidator` (hot path): only the laid-out fragment is scanned, prose keeps `#FFFFFF`/`#000000` (`21:1`), and only traits plus `>= 4.5:1` palette tokens are applied (`UI-002`, `UI-012`).
    private func installGFMValidator(on textView: SwiftEditNSTextView, coordinator: Coordinator) {
        coordinator.gfmEnabled = isMarkdownDocument
        coordinator.gfmPalette = palette
        coordinator.gfmFontSize = fontSizePoints
        textView.textLayoutManager?.renderingAttributesValidator = { [weak coordinator, weak textView] layoutManager, fragment in
            guard let coordinator, let textView, coordinator.gfmEnabled,
                  let contentManager = layoutManager.textContentManager else { return }
            let docStart = contentManager.documentRange.location
            let fragStart = contentManager.offset(from: docStart, to: fragment.rangeInElement.location)
            let fragEnd = contentManager.offset(from: docStart, to: fragment.rangeInElement.endLocation)
            guard fragEnd > fragStart else { return }
            let index = coordinator.lineIndex(for: textView.string)
            let spans = MarkdownSyntaxHighlighter.spans(index: index, visibleRange: SwiftEditCore.TextRange(location: fragStart, length: fragEnd - fragStart))
            let palette = coordinator.gfmPalette
            let size = coordinator.gfmFontSize
            for span in spans {
                guard let start = contentManager.location(docStart, offsetBy: span.range.location),
                      let end = contentManager.location(start, offsetBy: span.range.length) else { continue }
                guard let range = NSTextRange(location: start, end: end) else { continue }
                switch span.kind {
                case .heading, .bold:
                    layoutManager.addRenderingAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .bold), for: range)
                case .italic:
                    let base = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
                    let italic = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
                    layoutManager.addRenderingAttribute(.font, value: italic, for: range)
                case .strikethrough:
                    layoutManager.addRenderingAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, for: range)
                case .inlineCode, .codeBlock:
                    layoutManager.addRenderingAttribute(.backgroundColor, value: palette.backtickInlineBackground.nsColor, for: range)
                case .link, .image:
                    layoutManager.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, for: range)
                    layoutManager.addRenderingAttribute(.foregroundColor, value: palette.primaryAccent.nsColor, for: range)
                case .inlineHTML:
                    layoutManager.addRenderingAttribute(.foregroundColor, value: palette.inertHTMLWarningForeground.nsColor, for: range)
                case .task, .blockquote, .tableRow, .thematicBreak:
                    layoutManager.addRenderingAttribute(.foregroundColor, value: palette.secondaryForeground.nsColor, for: range)
                }
            }
        }
    }

    /// Applies canvas, selection, insertion-point, and `NSScrollView` scroller appearance tokens in `O(viewport)` without invoking whole-document `ensureLayout` (`UI-002`, `UI-003`, `UI-007`, `UI-012`).
    ///
    /// Disables `usesAdaptiveColorMappingForDarkAppearance` so AppKit never auto-inverts explicit `#FFFFFF`/`#000000` canvas tokens, and restarts the insertion-point blink timer when `textView` is first responder so caret color updates immediately.
    private func applyStyling(to textView: SwiftEditNSTextView, in scrollView: NSScrollView) {
        let editorFont = NSFont.monospacedSystemFont(ofSize: fontSizePoints, weight: .regular)
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
    }

    /// Applies non-mutating TextKit 2 rendering attributes for backtick code spans, nested depth-colored brackets, active bracket pair, and unbalanced brackets without mutating `NSTextStorage` (`UI-005`, `UI-006`, `UI-012`).
    private func applyNonMutatingHighlights(to textView: SwiftEditNSTextView) {
        guard let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager else {
            return
        }
        let docRange = contentManager.documentRange
        let totalUTF16 = (textView.string as NSString).length
        guard totalUTF16 > 0 else { return }

        layoutManager.setRenderingAttributes([:], for: docRange)

        func makeTextRange(location: Int, length: Int) -> NSTextRange? {
            guard location >= 0, length > 0, location + length <= totalUTF16,
                  let start = contentManager.location(docRange.location, offsetBy: location),
                  let end = contentManager.location(start, offsetBy: length) else {
                return nil
            }
            return NSTextRange(location: start, end: end)
        }

        // 1. Backtick inline and multiline fenced code highlights
        for span in highlightProjection.backtickSpans {
            guard let nsTextRange = makeTextRange(location: span.range.location, length: span.range.length) else { continue }
            let bgColor = span.kind == .fencedMultiline
                ? palette.backtickMultilineBackground.nsColor
                : palette.backtickInlineBackground.nsColor
            layoutManager.addRenderingAttribute(.backgroundColor, value: bgColor, for: nsTextRange)
            layoutManager.addRenderingAttribute(.foregroundColor, value: palette.backtickForeground.nsColor, for: nsTextRange)
        }

        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSizePoints, weight: .bold)

        // 2. Nested depth-colored bracket pairs ({}, [], ())
        for pair in highlightProjection.bracketPairs {
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

        // 3b. Lint dotted underlines (`>= 3.0:1` tokens), errors drawn last so they win overlaps.
        for diagnostic in lintDiagnostics.sorted(by: { $0.severity == .warning && $1.severity == .error }) {
            guard let range = diagnostic.range, let nsRange = makeTextRange(location: range.location, length: min(range.length, 1_024)) else { continue }
            let thick = diagnostic.severity == .error ? NSUnderlineStyle.thick.rawValue : NSUnderlineStyle.single.rawValue
            layoutManager.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.rawValue | thick, for: nsRange)
            layoutManager.addRenderingAttribute(.underlineColor, value: (diagnostic.severity == .error ? palette.unbalancedBracketHighlight : palette.bidiWarningForeground).nsColor, for: nsRange)
        }

        // 4. Unbalanced bracket error emphasis
        let errorColor = palette.unbalancedBracketHighlight.nsColor
        let errorBg = palette.unbalancedBracketBackground.nsColor
        for stray in highlightProjection.unbalancedBrackets {
            if let strayRange = makeTextRange(location: stray.offset, length: 1) {
                layoutManager.addRenderingAttribute(.foregroundColor, value: errorColor, for: strayRange)
                layoutManager.addRenderingAttribute(.backgroundColor, value: errorBg, for: strayRange)
                layoutManager.addRenderingAttribute(.font, value: boldFont, for: strayRange)
            }
        }
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

        var onTextChange: (String) -> Void
        var onSelectionChange: (SwiftEditCore.TextRange) -> Void
        var onSmartNewline: (Int) -> Int?
        var onListIndent: (Bool) -> SmartListOutcome
        var onTableTab: (Bool) -> TableEditOutcome
        var gfmEnabled = false
        var gfmPalette: PurpleThemePalette = .resolve(appearance: .light, systemPrefersDark: false)
        var gfmFontSize: Double = 13
        var appliedSelectionToken = 0
        private var cachedLineIndex: MarkdownLineIndex?
        private var cachedIndexLength = -1

        /// Line index cached per text revision so each laid-out fragment costs `O(fragment)` plus `O(log F)` fence lookups instead of a document rescan.
        func lineIndex(for text: String) -> MarkdownLineIndex {
            let length = text.utf16.count
            if let cachedLineIndex, cachedIndexLength == length { return cachedLineIndex }
            let index = MarkdownLineIndex(text: text)
            cachedLineIndex = index
            cachedIndexLength = length
            return index
        }

        func invalidateLineIndex() { cachedLineIndex = nil; cachedIndexLength = -1 }

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
            onTextChange(textView.string)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            onSelectionChange(SwiftEditCore.TextRange(location: range.location, length: range.length))
            textView.needsDisplay = true
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
