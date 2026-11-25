import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Core editing callbacks grouped out of `TextKit2EditorView` (`REQ-004`).
@MainActor
struct TextKit2EditorActionHandlers {
    let onTextChange: (String) -> Void
    let onSelectionChange: (SwiftEditCore.TextRange) -> Void
    let onSmartNewline: (Int) -> Int?
    let onListIndent: (Bool) -> SmartListOutcome
    let onTableTab: (Bool) -> TableEditOutcome
}

/// Optional viewport, escape, terminal, line-index, and completion hooks grouped out of `TextKit2EditorView` (`REQ-004`).
@MainActor
struct TextKit2EditorOptionalHooks {
    var onViewportMetricsChange: ((GutterViewportMetrics) -> Void)?
    var onEscape: () -> Bool
    var onSendSelectionToTerminal: ((SwiftEditCore.TextRange, String) -> Void)?
    var onRevealInFolderNavigator: (() -> Void)?
    var onStartDictationHere: (() -> Void)?
    var lineIndexProvider: ((DocumentID, BufferRevision) -> MarkdownLineIndex?)?
    var completionProvider: ((String) -> String?)?
}

/// `@MainActor` TextKit 2 `NSTextView` wrapper enforcing `#FFFFFF`/`#000000` inverted canvas colors, current-line highlight, non-mutating nested bracket and backtick highlights, Markdown smart Enter continuation, `50%..300%` monospaced zoom, and read-only binary protection (`UI-002..008`, `UI-012`).
@MainActor
struct TextKit2EditorView: NSViewRepresentable {
    var documentID: DocumentID
    var bufferRevision: BufferRevision
    let text: String
    let isEditable: Bool
    var isWordOccurrenceHighlightEnabled: Bool
    var isWordWrapEnabled: Bool
    let palette: PurpleThemePalette
    let fontSizePoints: Double
    let highlightProjection: EditorHighlightProjection
    let documentLanguage: DocumentLanguage
    let programmaticSelection: SwiftEditCore.TextRange
    let programmaticSelectionToken: Int
    var lintDiagnostics: [MarkdownLintDiagnostic]
    var undoRegistry: PerTabUndoManagerRegistry?
    var editorFocusRequestToken: Int
    var typography: AppTypography
    var typographyGeneration: Int
    let handlers: TextKit2EditorActionHandlers
    var hooks: TextKit2EditorOptionalHooks
}

extension TextKit2EditorView {
    init(
        documentID: DocumentID = DocumentID(),
        bufferRevision: BufferRevision = BufferRevision(1),
        text: String,
        isEditable: Bool,
        isWordOccurrenceHighlightEnabled: Bool = true,
        isWordWrapEnabled: Bool = true,
        palette: PurpleThemePalette,
        fontSizePoints: Double,
        highlightProjection: EditorHighlightProjection,
        onTextChange: @escaping (String) -> Void,
        onSelectionChange: @escaping (SwiftEditCore.TextRange) -> Void,
        onSmartNewline: @escaping (Int) -> Int?,
        onListIndent: @escaping (Bool) -> SmartListOutcome,
        onTableTab: @escaping (Bool) -> TableEditOutcome,
        documentLanguage: DocumentLanguage,
        programmaticSelection: SwiftEditCore.TextRange,
        programmaticSelectionToken: Int,
        lintDiagnostics: [MarkdownLintDiagnostic] = [],
        undoRegistry: PerTabUndoManagerRegistry? = nil,
        editorFocusRequestToken: Int = 0,
        onViewportMetricsChange: ((GutterViewportMetrics) -> Void)? = nil,
        onEscape: @escaping () -> Bool = { false },
        onSendSelectionToTerminal: ((SwiftEditCore.TextRange, String) -> Void)? = nil,
        onRevealInFolderNavigator: (() -> Void)? = nil,
        onStartDictationHere: (() -> Void)? = nil,
        typography: AppTypography = AppTypography.fallback,
        typographyGeneration: Int = 0,
        lineIndexProvider: ((DocumentID, BufferRevision) -> MarkdownLineIndex?)? = nil,
        completionProvider: ((String) -> String?)? = nil
    ) {
        self.documentID = documentID
        self.bufferRevision = bufferRevision
        self.text = text
        self.isEditable = isEditable
        self.isWordOccurrenceHighlightEnabled = isWordOccurrenceHighlightEnabled
        self.isWordWrapEnabled = isWordWrapEnabled
        self.palette = palette
        self.fontSizePoints = fontSizePoints
        self.highlightProjection = highlightProjection
        self.documentLanguage = documentLanguage
        self.programmaticSelection = programmaticSelection
        self.programmaticSelectionToken = programmaticSelectionToken
        self.lintDiagnostics = lintDiagnostics
        self.undoRegistry = undoRegistry
        self.editorFocusRequestToken = editorFocusRequestToken
        self.typography = typography
        self.typographyGeneration = typographyGeneration
        self.handlers = TextKit2EditorActionHandlers(
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSmartNewline: onSmartNewline,
            onListIndent: onListIndent,
            onTableTab: onTableTab
        )
        self.hooks = TextKit2EditorOptionalHooks(
            onViewportMetricsChange: onViewportMetricsChange,
            onEscape: onEscape,
            onSendSelectionToTerminal: onSendSelectionToTerminal,
            onRevealInFolderNavigator: onRevealInFolderNavigator,
            onStartDictationHere: onStartDictationHere,
            lineIndexProvider: lineIndexProvider,
            completionProvider: completionProvider
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: handlers.onTextChange,
            onSelectionChange: handlers.onSelectionChange,
            onSmartNewline: handlers.onSmartNewline,
            onListIndent: handlers.onListIndent,
            onTableTab: handlers.onTableTab
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
        textView.onEscape = hooks.onEscape
        textView.onSendSelectionToTerminal = hooks.onSendSelectionToTerminal.map { handler in
            { nsRange, text in
                handler(SwiftEditCore.TextRange(location: nsRange.location, length: nsRange.length), text)
            }
        }
        textView.onRevealInFolderNavigator = hooks.onRevealInFolderNavigator
        textView.onStartDictationHere = isEditable ? hooks.onStartDictationHere : nil
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
        textView.externalWordOccurrenceRanges = highlightProjection.wordOccurrenceRanges
        textView.isWordOccurrenceHighlightEnabled = isWordOccurrenceHighlightEnabled
        let initLength = textView.textStorage?.length ?? 0
        if programmaticSelection.location >= 0, programmaticSelection.upperBound <= initLength, programmaticSelection.length > 0 {
            context.coordinator.isApplyingProgrammaticUpdate = true
            textView.setSelectedRange(NSRange(location: programmaticSelection.location, length: programmaticSelection.length))
            context.coordinator.isApplyingProgrammaticUpdate = false
        }
        textView.updateLiveWordOccurrencesAndInvalidate(force: true)
        let coordinatorRef = context.coordinator
        textView.onWordOccurrencesUpdated = { [weak coordinatorRef, weak textView] ranges in
            guard let coordinatorRef, let textView else { return }
            coordinatorRef.wordOccurrenceRanges = ranges
            coordinatorRef.lastHighlightSnapshot = nil
            if let layoutManager = textView.textLayoutManager,
               let contentManager = layoutManager.textContentManager {
                let docRange = contentManager.documentRange
                let targetRange = layoutManager.textViewportLayoutController.viewportRange ?? docRange
                if ranges.isEmpty {
                    layoutManager.setRenderingAttributes([:], for: targetRange)
                }
                layoutManager.invalidateRenderingAttributes(for: targetRange)
                layoutManager.invalidateLayout(for: targetRange)
                layoutManager.textViewportLayoutController.layoutViewport()
            }
        }
        applyNonMutatingHighlightsIfNeeded(to: textView, coordinator: context.coordinator, force: true)
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.onViewportMetricsChange = hooks.onViewportMetricsChange
        context.coordinator.lineIndexProvider = hooks.lineIndexProvider
        context.coordinator.completionProvider = hooks.completionProvider
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
            textView.onSendSelectionToTerminal = nil
            textView.onRevealInFolderNavigator = nil
            textView.onStartDictationHere = nil
            textView.onWordOccurrencesUpdated = nil
            textView.textLayoutManager?.renderingAttributesValidator = nil
        }
        coordinator.invalidateLineIndex()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SwiftEditNSTextView else { return }
        let coordinator = context.coordinator
        bindCoordinatorAndTextViewCallbacks(coordinator: coordinator, textView: textView)
        let stylingChanged = applyStylingIfNeeded(to: textView, in: scrollView, coordinator: coordinator, force: false)
        if stylingChanged || coordinator.activeDocumentID != documentID {
            coordinator.hideGhostCompletion()
        }
        let textMutated = syncDocumentTextIfNeeded(to: textView, coordinator: coordinator)
        let selectionChanged = syncSelectionAndFocus(in: textView, coordinator: coordinator)
        let highlightsChanged = applyNonMutatingHighlightsIfNeeded(
            to: textView,
            coordinator: coordinator,
            force: stylingChanged || textMutated
        )
        if stylingChanged || textMutated || highlightsChanged {
            textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
            SwiftEditNSTextView.markSubviewsAndLayersNeedsDisplay(textView)
        }
        if stylingChanged || textMutated || selectionChanged {
            coordinator.emitViewportMetrics(for: scrollView, textView: textView)
        }
    }
}

extension TextKit2EditorView {
    fileprivate func bindCoordinatorAndTextViewCallbacks(coordinator: Coordinator, textView: SwiftEditNSTextView) {
        coordinator.onTextChange = handlers.onTextChange
        coordinator.onSelectionChange = handlers.onSelectionChange
        coordinator.onSmartNewline = handlers.onSmartNewline
        coordinator.onListIndent = handlers.onListIndent
        coordinator.onTableTab = handlers.onTableTab
        coordinator.onViewportMetricsChange = hooks.onViewportMetricsChange
        coordinator.lineIndexProvider = hooks.lineIndexProvider
        coordinator.completionProvider = isEditable ? hooks.completionProvider : nil
        coordinator.undoRegistry = undoRegistry
        coordinator.activeBufferRevision = bufferRevision
        coordinator.syntaxLanguage = documentLanguage
        textView.onSendSelectionToTerminal = hooks.onSendSelectionToTerminal.map { handler in
            { nsRange, text in
                handler(SwiftEditCore.TextRange(location: nsRange.location, length: nsRange.length), text)
            }
        }
        textView.onRevealInFolderNavigator = hooks.onRevealInFolderNavigator
        textView.onStartDictationHere = isEditable ? hooks.onStartDictationHere : nil
        textView.isWordOccurrenceHighlightEnabled = isWordOccurrenceHighlightEnabled
        textView.externalWordOccurrenceRanges = highlightProjection.wordOccurrenceRanges
        coordinator.wordOccurrenceRanges = textView.effectiveWordOccurrenceRanges
        coordinator.updateRenderingTableIfNeeded(
            palette: palette,
            fontSizePoints: fontSizePoints,
            typography: typography,
            generation: typographyGeneration
        )
    }

    private func syncDocumentTextIfNeeded(to textView: SwiftEditNSTextView, coordinator: Coordinator) -> Bool {
        let needsTextSyncCheck = coordinator.activeDocumentID != documentID
            || coordinator.lastSyncedBufferRevision != bufferRevision
            || coordinator.hasPendingLocalEdit
        guard needsTextSyncCheck else { return false }
        let hadPendingLocalEdit = coordinator.hasPendingLocalEdit
        coordinator.hasPendingLocalEdit = false
        if hadPendingLocalEdit && coordinator.activeDocumentID == documentID && coordinator.isDisplaying(text, in: textView) {
            coordinator.markSynced(documentID: documentID, revision: bufferRevision)
            coordinator.retagCachedLineIndexRevision(documentID: documentID, revision: bufferRevision, storageLength: textView.textStorage?.length ?? 0)
            return false
        }
        if coordinator.activeDocumentID != documentID || !coordinator.isDisplaying(text, in: textView) {
            coordinator.applyProgrammaticTextUpdate(text, to: textView, documentID: documentID)
            coordinator.markSynced(documentID: documentID, revision: bufferRevision)
            return true
        }
        coordinator.markSynced(documentID: documentID, revision: bufferRevision)
        return false
    }

    private func syncSelectionAndFocus(in textView: SwiftEditNSTextView, coordinator: Coordinator) -> Bool {
        var selectionChanged = false
        if coordinator.appliedSelectionToken != programmaticSelectionToken {
            coordinator.appliedSelectionToken = programmaticSelectionToken
            let preserveActiveLogSelection = !isEditable
                && documentLanguage == .log
                && programmaticSelection.length == 0
                && textView.selectedRange().length >= WordOccurrenceScanner.minWordUTF16Length
            let length = textView.textStorage?.length ?? 0
            if !preserveActiveLogSelection, programmaticSelection.location >= 0, programmaticSelection.upperBound <= length {
                coordinator.isApplyingProgrammaticUpdate = true
                Coordinator.revealSelection(NSRange(location: programmaticSelection.location, length: programmaticSelection.length), in: textView)
                coordinator.isApplyingProgrammaticUpdate = false
                selectionChanged = true
            }
        }
        if coordinator.appliedFocusRequestToken != editorFocusRequestToken {
            coordinator.appliedFocusRequestToken = editorFocusRequestToken
            textView.window?.makeFirstResponder(textView)
        } else if !isEditable, documentLanguage == .log,
                  textView.selectedRange().length >= WordOccurrenceScanner.minWordUTF16Length,
                  let win = textView.window, win.firstResponder !== textView {
            win.makeFirstResponder(textView)
        }
        return selectionChanged
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
            guard let coordinator, let textView else { return }
            Self.validateLayoutFragmentAttributes(layoutManager: layoutManager, fragment: fragment, coordinator: coordinator, textView: textView)
        }
    }

    @MainActor
    private static func validateLayoutFragmentAttributes(
        layoutManager: NSTextLayoutManager,
        fragment: NSTextLayoutFragment,
        coordinator: Coordinator,
        textView: SwiftEditNSTextView
    ) {
        guard let contentManager = layoutManager.textContentManager else { return }
        let docStart = contentManager.documentRange.location
        let fragLocation = fragment.rangeInElement.location
        let fragStart = contentManager.offset(from: docStart, to: fragLocation)
        let fragEnd = contentManager.offset(from: docStart, to: fragment.rangeInElement.endLocation)
        guard fragEnd > fragStart else { return }
        let table = coordinator.renderingAttributeTable
        if coordinator.syntaxLanguage != .plainText {
            applyFragmentSyntaxSpans(
                layoutManager: layoutManager,
                contentManager: contentManager,
                coordinator: coordinator,
                textView: textView,
                docStart: docStart,
                fragLocation: fragLocation,
                fragStart: fragStart,
                fragEnd: fragEnd,
                table: table
            )
        }
        TextKit2ViewportHighlightApplier.applyWordOccurrences(
            coordinator.wordOccurrenceRanges,
            selectedRange: textView.selectedRange(),
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

    @MainActor
    private static func applyFragmentSyntaxSpans(
        layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager,
        coordinator: Coordinator,
        textView: SwiftEditNSTextView,
        docStart: any NSTextLocation,
        fragLocation: any NSTextLocation,
        fragStart: Int,
        fragEnd: Int,
        table: EditorRenderingAttributeTable
    ) {
        let index = coordinator.renderingLineIndex(
            for: textView,
            documentID: coordinator.activeDocumentID,
            revision: coordinator.activeBufferRevision
        )
        let spans = DocumentSyntaxHighlighter.spans(
            index: index,
            visibleRange: SwiftEditCore.TextRange(location: fragStart, length: fragEnd - fragStart),
            language: coordinator.syntaxLanguage
        )
        for span in spans {
            let attributes = table.attributes(for: span.kind)
            guard !attributes.isEmpty,
                  let range = resolveFragmentTextRange(
                      contentManager: contentManager,
                      docStart: docStart,
                      fragLocation: fragLocation,
                      fragStart: fragStart,
                      spanRange: span.range
                  ) else { continue }
            for attribute in attributes {
                layoutManager.addRenderingAttribute(attribute.key, value: attribute.value, for: range)
            }
        }
    }

    @MainActor
    private static func resolveFragmentTextRange(
        contentManager: NSTextContentManager,
        docStart: any NSTextLocation,
        fragLocation: any NSTextLocation,
        fragStart: Int,
        spanRange: SwiftEditCore.TextRange
    ) -> NSTextRange? {
        let start = spanRange.location >= fragStart
            ? contentManager.location(fragLocation, offsetBy: spanRange.location - fragStart)
            : contentManager.location(docStart, offsetBy: spanRange.location)
        guard let start, let end = contentManager.location(start, offsetBy: spanRange.length) else { return nil }
        return NSTextRange(location: start, end: end)
    }
}

#endif
