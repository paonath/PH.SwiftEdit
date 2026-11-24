import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Action and lookup closures bound onto `TextKit2EditorView.Coordinator` (`UI-005`, `UI-006`).
@MainActor
struct EditorCoordinatorCallbacks {
    var onTextChange: (String) -> Void
    var onSelectionChange: (SwiftEditCore.TextRange) -> Void
    var onSmartNewline: (Int) -> Int?
    var onListIndent: (Bool) -> SmartListOutcome
    var onTableTab: (Bool) -> TableEditOutcome
    var onViewportMetricsChange: ((GutterViewportMetrics) -> Void)?
    var lineIndexProvider: ((DocumentID, BufferRevision) -> MarkdownLineIndex?)?
    var completionProvider: ((String) -> String?)?
}

/// Cached typography, palette, and rendering attribute state owned by `TextKit2EditorView.Coordinator` (`UI-002`, `UI-007`).
@MainActor
struct EditorCoordinatorStyleState {
    var syntaxLanguage: DocumentLanguage = .plainText
    var gfmPalette: PurpleThemePalette = .resolve(appearance: .light, systemPrefersDark: false)
    var gfmFontSize: Double = 13
    var gfmTypographyGeneration: Int = -1
    var cachedFonts = EditorRenderingFonts(fontSizePoints: 13)
    var renderingAttributeTable = EditorRenderingAttributeTable(
        palette: .resolve(appearance: .light, systemPrefersDark: false),
        fonts: EditorRenderingFonts(fontSizePoints: 13)
    )
    var lastStyledPalette: PurpleThemePalette?
    var lastStyledFontSize: Double?
    var lastStyledTypographyGeneration: Int?
    var lastStyledIsEditable: Bool?
    var lastStyledWordWrap: Bool?
}

/// Buffer revision synchronization, native text mirror, and ghost-completion transient state for `TextKit2EditorView.Coordinator` (`UI-006`).
@MainActor
struct EditorCoordinatorSyncState {
    var isApplyingProgrammaticUpdate: Bool = false
    var pendingProgrammaticCaret: Int?
    var lastSyncedBufferRevision: BufferRevision?
    var hasPendingLocalEdit: Bool = false
    var appliedSelectionToken: Int = 0
    var appliedFocusRequestToken: Int = 0
    var activeDocumentID: DocumentID?
    var activeBufferRevision: BufferRevision?
    var isSwappingTabBuffer: Bool = false
    var nativeTextMirror: (text: String, utf16Length: Int)?
    var ghostSuggestion: (location: Int, suffix: String)?
    var ghostView: GhostCompletionView?
    var pendingInsertedString: String?
}

/// Viewport highlight signature, scroll observer, and per-revision `MarkdownLineIndex` cache for `TextKit2EditorView.Coordinator` (`UI-007`, `UI-012`).
@MainActor
struct EditorCoordinatorViewportState {
    var wordOccurrenceRanges: [SwiftEditCore.TextRange] = []
    var lastHighlightSnapshot: TextKit2EditorView.Coordinator.HighlightRenderSignature?
    var hadNonMutatingHighlights: Bool = false
    var lastEmittedViewportMetrics: GutterViewportMetrics?
    var scrollBoundsObserver: (any NSObjectProtocol)?
    var cachedLineIndex: MarkdownLineIndex?
    var cachedIndexDocumentID: DocumentID?
    var cachedIndexRevision: BufferRevision?
    var cachedIndexLength: Int = -1
}

/// `@MainActor` `NSTextViewDelegate` coordinator managing TextKit 2 viewport metrics, undo, and programmatic text updates (`UI-005`, `UI-007`).
extension TextKit2EditorView {
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
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

        /// Upper bound on gutter rows sampled per pass (`F-017-01`): 512 rows covers a 4K-tall window at 50% zoom.
        static let maxGutterLineMetrics = 512

        var callbacks: EditorCoordinatorCallbacks
        var styleState = EditorCoordinatorStyleState()
        var syncState = EditorCoordinatorSyncState()
        var viewportState = EditorCoordinatorViewportState()
        var undoRegistry: PerTabUndoManagerRegistry?
        private lazy var tabSwapScratchUndoManager = UndoManager()

        init(
            onTextChange: @escaping (String) -> Void,
            onSelectionChange: @escaping (SwiftEditCore.TextRange) -> Void,
            onSmartNewline: @escaping (Int) -> Int?,
            onListIndent: @escaping (Bool) -> SmartListOutcome,
            onTableTab: @escaping (Bool) -> TableEditOutcome = { _ in .notApplicable }
        ) {
            self.callbacks = EditorCoordinatorCallbacks(
                onTextChange: onTextChange,
                onSelectionChange: onSelectionChange,
                onSmartNewline: onSmartNewline,
                onListIndent: onListIndent,
                onTableTab: onTableTab
            )
        }

        /// Rebuilds editor faces only when the zoomed size or the typography generation changed.
        func updateGFMFontsIfNeeded(fontSizePoints: Double, typography: AppTypography, generation: Int) {
            guard styleState.gfmFontSize != fontSizePoints || styleState.gfmTypographyGeneration != generation else { return }
            styleState.gfmFontSize = fontSizePoints
            styleState.gfmTypographyGeneration = generation
            styleState.cachedFonts = EditorRenderingFonts(fontSizePoints: fontSizePoints, typography: typography)
            styleState.renderingAttributeTable = EditorRenderingAttributeTable(
                palette: styleState.gfmPalette,
                fonts: styleState.cachedFonts
            )
        }

        /// Rebuilds cached rendering attribute dictionaries only when palette, font size, or typography generation changes.
        func updateRenderingTableIfNeeded(
            palette: PurpleThemePalette,
            fontSizePoints: Double,
            typography: AppTypography,
            generation: Int
        ) {
            let paletteChanged = styleState.gfmPalette != palette
            let fontsChanged = styleState.gfmFontSize != fontSizePoints || styleState.gfmTypographyGeneration != generation
            if paletteChanged { styleState.gfmPalette = palette }
            if fontsChanged {
                styleState.gfmFontSize = fontSizePoints
                styleState.gfmTypographyGeneration = generation
                styleState.cachedFonts = EditorRenderingFonts(fontSizePoints: fontSizePoints, typography: typography)
            }
            if paletteChanged || fontsChanged {
                styleState.renderingAttributeTable = EditorRenderingAttributeTable(
                    palette: styleState.gfmPalette,
                    fonts: styleState.cachedFonts
                )
            }
        }

        func markSynced(documentID: DocumentID, revision: BufferRevision) {
            syncState.activeDocumentID = documentID
            syncState.lastSyncedBufferRevision = revision
        }

        /// Re-tags an already-rebuilt local `MarkdownLineIndex` after `textDidChange` -> `updateNSView` bumps `BufferRevision`.
        func retagCachedLineIndexRevision(documentID: DocumentID, revision: BufferRevision, storageLength: Int) {
            if viewportState.cachedLineIndex != nil,
               viewportState.cachedIndexDocumentID == documentID,
               viewportState.cachedIndexLength == storageLength {
                viewportState.cachedIndexRevision = revision
            }
        }

        /// Subscribes to `NSScrollView.contentView` clip bounds changes to keep `LineNumberGutterView` scroll-synchronized (`BUG-012`).
        func observeScrollBounds(of scrollView: NSScrollView, textView: NSTextView) {
            detachScrollObserver()
            let clipView = scrollView.contentView
            viewportState.scrollBoundsObserver = NotificationCenter.default.addObserver(
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
            if let observer = viewportState.scrollBoundsObserver {
                NotificationCenter.default.removeObserver(observer)
                viewportState.scrollBoundsObserver = nil
            }
        }

        func emitViewportMetrics(for scrollView: NSScrollView, textView: NSTextView) {
            guard let onViewportMetricsChange = callbacks.onViewportMetricsChange else { return }
            let storageLen = textView.textStorage?.length ?? 0
            let indexForLookup = (viewportState.cachedLineIndex != nil && viewportState.cachedIndexLength == storageLen)
                ? viewportState.cachedLineIndex
                : nil
            let metrics = Self.captureGutterViewportMetrics(in: scrollView, textView: textView, cachedLineIndex: indexForLookup)
            guard metrics != viewportState.lastEmittedViewportMetrics else { return }
            viewportState.lastEmittedViewportMetrics = metrics
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
            let baseLine = resolveGutterBaseLine(startOffset: startOffset, cachedLineIndex: cachedLineIndex, textView: textView)
            let metrics = collectFragmentLineMetrics(
                textLayoutManager: textLayoutManager,
                startLocation: startLocation,
                originY: originY,
                visibleRect: visibleRect,
                baseLine: baseLine
            )
            return GutterViewportMetrics(scrollOffsetY: scrollY, visibleLines: metrics)
        }

        /// Provides the dedicated per-tab `UndoManager` so tabs never share `NSWindow.undoManager` (`BUG-001`, `CWE-416`).
        func undoManager(for view: NSTextView) -> UndoManager? {
            if syncState.isSwappingTabBuffer {
                return tabSwapScratchUndoManager
            }
            guard let activeDocumentID = syncState.activeDocumentID, let undoRegistry else { return nil }
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
            let targetLocation = syncState.pendingProgrammaticCaret ?? previousSelection.location
            let targetLength = (syncState.pendingProgrammaticCaret != nil) ? 0 : previousSelection.length
            syncState.pendingProgrammaticCaret = nil

            let isSameDocument = !isInitialSetup && syncState.activeDocumentID == documentID
            syncState.isApplyingProgrammaticUpdate = true
            defer {
                syncState.isApplyingProgrammaticUpdate = false
                invalidateLineIndex()
            }

            if isSameDocument {
                applySameDocumentProgrammaticUpdate(
                    newText,
                    to: textView,
                    previousSelection: previousSelection,
                    targetLocation: targetLocation,
                    targetLength: targetLength
                )
                return
            }
            swapTabBufferContents(newText, to: textView, documentID: documentID, targetLocation: targetLocation, targetLength: targetLength)
        }

        /// Smallest UTF-16 range of `old` (and its replacement) that turns `old` into `new`, keeping the longest common prefix and suffix on Unicode-scalar boundaries.
        static func minimalReplacement(from old: String, to new: String) -> (range: NSRange, replacement: String)? {
            var a = old, b = new
            let bounds: (prefix: Int, suffix: Int)? = a.withUTF8 { x in
                b.withUTF8 { y in
                    guard let xb = x.baseAddress ?? (x.isEmpty ? UnsafePointer(bitPattern: 1) : nil),
                          let yb = y.baseAddress ?? (y.isEmpty ? UnsafePointer(bitPattern: 1) : nil) else { return nil }
                    let la = x.count, lb = y.count, limit = min(la, lb)
                    var p = 0
                    while p + 4096 <= limit, memcmp(xb + p, yb + p, 4096) == 0 { p += 4096 }
                    while p < limit, x[p] == y[p] { p += 1 }
                    while p > 0, p < la, (x[p] & 0xC0) == 0x80 { p -= 1 }
                    let maxSuffix = limit - p
                    var q = 0
                    while q + 4096 <= maxSuffix, memcmp(xb + la - q - 4096, yb + lb - q - 4096, 4096) == 0 { q += 4096 }
                    while q < maxSuffix, x[la - 1 - q] == y[lb - 1 - q] { q += 1 }
                    while q > 0, (x[la - q] & 0xC0) == 0x80 { q -= 1 }
                    return (p, q)
                }
            }
            guard let bounds else { return nil }
            let oldStart = a.utf8.index(a.utf8.startIndex, offsetBy: bounds.prefix)
            let oldEnd = a.utf8.index(a.utf8.endIndex, offsetBy: -bounds.suffix)
            let newStart = b.utf8.index(b.utf8.startIndex, offsetBy: bounds.prefix)
            let newEnd = b.utf8.index(b.utf8.endIndex, offsetBy: -bounds.suffix)
            let location = a.utf16.distance(from: a.utf16.startIndex, to: oldStart)
            let length = a.utf16.distance(from: oldStart, to: oldEnd)
            return (NSRange(location: location, length: length), String(b[newStart..<newEnd]))
        }
    }
}

/// Callback, style, and native-text mirror forwarding accessors on `TextKit2EditorView.Coordinator` (`UI-005`, `UI-006`).
extension TextKit2EditorView.Coordinator {
    var onTextChange: (String) -> Void {
        get { callbacks.onTextChange }
        set { callbacks.onTextChange = newValue }
    }
    var onSelectionChange: (SwiftEditCore.TextRange) -> Void {
        get { callbacks.onSelectionChange }
        set { callbacks.onSelectionChange = newValue }
    }
    var onSmartNewline: (Int) -> Int? {
        get { callbacks.onSmartNewline }
        set { callbacks.onSmartNewline = newValue }
    }
    var onListIndent: (Bool) -> SmartListOutcome {
        get { callbacks.onListIndent }
        set { callbacks.onListIndent = newValue }
    }
    var onTableTab: (Bool) -> TableEditOutcome {
        get { callbacks.onTableTab }
        set { callbacks.onTableTab = newValue }
    }
    var onViewportMetricsChange: ((GutterViewportMetrics) -> Void)? {
        get { callbacks.onViewportMetricsChange }
        set { callbacks.onViewportMetricsChange = newValue }
    }
    var lineIndexProvider: ((DocumentID, BufferRevision) -> MarkdownLineIndex?)? {
        get { callbacks.lineIndexProvider }
        set { callbacks.lineIndexProvider = newValue }
    }
    var completionProvider: ((String) -> String?)? {
        get { callbacks.completionProvider }
        set { callbacks.completionProvider = newValue }
    }
    var syntaxLanguage: DocumentLanguage {
        get { styleState.syntaxLanguage }
        set { styleState.syntaxLanguage = newValue }
    }
    var gfmPalette: PurpleThemePalette {
        get { styleState.gfmPalette }
        set { styleState.gfmPalette = newValue }
    }
    var gfmFontSize: Double {
        get { styleState.gfmFontSize }
        set { styleState.gfmFontSize = newValue }
    }
    var gfmTypographyGeneration: Int {
        get { styleState.gfmTypographyGeneration }
        set { styleState.gfmTypographyGeneration = newValue }
    }
    var cachedFonts: EditorRenderingFonts {
        get { styleState.cachedFonts }
        set { styleState.cachedFonts = newValue }
    }
    var renderingAttributeTable: EditorRenderingAttributeTable {
        get { styleState.renderingAttributeTable }
        set { styleState.renderingAttributeTable = newValue }
    }
    var cachedRegularFont: NSFont { styleState.cachedFonts.regular }
    var cachedBoldFont: NSFont { styleState.cachedFonts.bold }
    var cachedItalicFont: NSFont { styleState.cachedFonts.italic }
    var lastStyledPalette: PurpleThemePalette? {
        get { styleState.lastStyledPalette }
        set { styleState.lastStyledPalette = newValue }
    }
    var lastStyledFontSize: Double? {
        get { styleState.lastStyledFontSize }
        set { styleState.lastStyledFontSize = newValue }
    }
    var lastStyledTypographyGeneration: Int? {
        get { styleState.lastStyledTypographyGeneration }
        set { styleState.lastStyledTypographyGeneration = newValue }
    }
    var lastStyledIsEditable: Bool? {
        get { styleState.lastStyledIsEditable }
        set { styleState.lastStyledIsEditable = newValue }
    }
    var lastStyledWordWrap: Bool? {
        get { styleState.lastStyledWordWrap }
        set { styleState.lastStyledWordWrap = newValue }
    }

    func updateNativeTextMirror(_ text: String) {
        let native = NativeTextNormalizer.native(text)
        syncState.nativeTextMirror = (native, native.utf16.count)
    }

    /// Native text for `textView` when the mirror is current, else the bridged storage string.
    func currentNativeText(of textView: NSTextView) -> String {
        if let mirror = syncState.nativeTextMirror, mirror.utf16Length == (textView.textStorage?.length ?? -1) {
            return mirror.text
        }
        return textView.string
    }

    func invalidateLineIndex() {
        viewportState.cachedLineIndex = nil
        viewportState.cachedIndexDocumentID = nil
        viewportState.cachedIndexRevision = nil
        viewportState.cachedIndexLength = -1
    }
}

/// Sync, ghost-completion, and viewport cache forwarding accessors on `TextKit2EditorView.Coordinator` (`UI-006`, `UI-007`).
extension TextKit2EditorView.Coordinator {
    var isApplyingProgrammaticUpdate: Bool {
        get { syncState.isApplyingProgrammaticUpdate }
        set { syncState.isApplyingProgrammaticUpdate = newValue }
    }
    var pendingProgrammaticCaret: Int? {
        get { syncState.pendingProgrammaticCaret }
        set { syncState.pendingProgrammaticCaret = newValue }
    }
    var lastSyncedBufferRevision: BufferRevision? {
        get { syncState.lastSyncedBufferRevision }
        set { syncState.lastSyncedBufferRevision = newValue }
    }
    var hasPendingLocalEdit: Bool {
        get { syncState.hasPendingLocalEdit }
        set { syncState.hasPendingLocalEdit = newValue }
    }
    var appliedSelectionToken: Int {
        get { syncState.appliedSelectionToken }
        set { syncState.appliedSelectionToken = newValue }
    }
    var appliedFocusRequestToken: Int {
        get { syncState.appliedFocusRequestToken }
        set { syncState.appliedFocusRequestToken = newValue }
    }
    var activeDocumentID: DocumentID? {
        get { syncState.activeDocumentID }
        set { syncState.activeDocumentID = newValue }
    }
    var activeBufferRevision: BufferRevision? {
        get { syncState.activeBufferRevision }
        set { syncState.activeBufferRevision = newValue }
    }
    var isSwappingTabBuffer: Bool {
        get { syncState.isSwappingTabBuffer }
        set { syncState.isSwappingTabBuffer = newValue }
    }
    var nativeTextMirror: (text: String, utf16Length: Int)? {
        get { syncState.nativeTextMirror }
        set { syncState.nativeTextMirror = newValue }
    }
    var ghostSuggestion: (location: Int, suffix: String)? {
        get { syncState.ghostSuggestion }
        set { syncState.ghostSuggestion = newValue }
    }
    var ghostView: GhostCompletionView? {
        get { syncState.ghostView }
        set { syncState.ghostView = newValue }
    }
    var pendingInsertedString: String? {
        get { syncState.pendingInsertedString }
        set { syncState.pendingInsertedString = newValue }
    }
    var wordOccurrenceRanges: [SwiftEditCore.TextRange] {
        get { viewportState.wordOccurrenceRanges }
        set { viewportState.wordOccurrenceRanges = newValue }
    }
    var lastHighlightSnapshot: HighlightRenderSignature? {
        get { viewportState.lastHighlightSnapshot }
        set { viewportState.lastHighlightSnapshot = newValue }
    }
    var hadNonMutatingHighlights: Bool {
        get { viewportState.hadNonMutatingHighlights }
        set { viewportState.hadNonMutatingHighlights = newValue }
    }
    var lastEmittedViewportMetrics: GutterViewportMetrics? {
        get { viewportState.lastEmittedViewportMetrics }
        set { viewportState.lastEmittedViewportMetrics = newValue }
    }
    var scrollBoundsObserver: (any NSObjectProtocol)? {
        get { viewportState.scrollBoundsObserver }
        set { viewportState.scrollBoundsObserver = newValue }
    }
    var cachedLineIndex: MarkdownLineIndex? {
        get { viewportState.cachedLineIndex }
        set { viewportState.cachedLineIndex = newValue }
    }
    var cachedIndexDocumentID: DocumentID? {
        get { viewportState.cachedIndexDocumentID }
        set { viewportState.cachedIndexDocumentID = newValue }
    }
    var cachedIndexRevision: BufferRevision? {
        get { viewportState.cachedIndexRevision }
        set { viewportState.cachedIndexRevision = newValue }
    }
    var cachedIndexLength: Int {
        get { viewportState.cachedIndexLength }
        set { viewportState.cachedIndexLength = newValue }
    }
}

extension TextKit2EditorView.Coordinator {
    static func resolveGutterBaseLine(
        startOffset: Int,
        cachedLineIndex: MarkdownLineIndex?,
        textView: NSTextView
    ) -> Int {
        if startOffset == 0 { return 1 }
        if let cachedLineIndex { return cachedLineIndex.line(containing: startOffset) + 1 }
        return LineNumberGutterProjection.evaluate(
            text: textView.string,
            caretLocation: startOffset,
            fontSizePoints: 13
        ).activeLine
    }

    static func collectFragmentLineMetrics(
        textLayoutManager: NSTextLayoutManager,
        startLocation: any NSTextLocation,
        originY: CGFloat,
        visibleRect: NSRect,
        baseLine: Int
    ) -> [GutterLineMetric] {
        var metrics: [GutterLineMetric] = []
        var currentLine = baseLine
        textLayoutManager.enumerateTextLayoutFragments(from: startLocation, options: []) { fragment in
            let frame = fragment.layoutFragmentFrame
            if frame.maxY >= visibleRect.minY - 64 {
                metrics.append(GutterLineMetric(lineNumber: currentLine, minY: originY + frame.minY, height: frame.height))
            }
            currentLine += 1
            return !(frame.minY > visibleRect.maxY + 64 || metrics.count >= maxGutterLineMetrics)
        }
        return metrics
    }

    func applySameDocumentProgrammaticUpdate(
        _ newText: String,
        to textView: NSTextView,
        previousSelection: NSRange,
        targetLocation: Int,
        targetLength: Int
    ) {
        let oldText = currentNativeText(of: textView)
        let preservedLogSelection = capturePreservedLogSelection(in: textView, oldText: oldText, previousSelection: previousSelection)
        if oldText != newText {
            replaceNativeStorageText(from: oldText, to: newText, in: textView)
        }
        updateNativeTextMirror(newText)
        let newLength = syncState.nativeTextMirror?.utf16Length ?? newText.utf16.count
        var resolvedLocation = min(max(0, targetLocation), newLength)
        var resolvedLength = min(max(0, targetLength), newLength - resolvedLocation)
        if let preserved = preservedLogSelection,
           let relocated = Self.relocatePreservedLogToken(
               preserved.token,
               ordinal: preserved.ordinal,
               in: newText,
               defaultRange: NSRange(location: resolvedLocation, length: resolvedLength)
           ) {
            resolvedLocation = relocated.location
            resolvedLength = relocated.length
        }
        textView.setSelectedRange(NSRange(location: resolvedLocation, length: resolvedLength))
        if resolvedLength > 0, let win = textView.window, win.firstResponder !== textView {
            win.makeFirstResponder(textView)
        }
        (textView as? SwiftEditNSTextView)?.notifyProgrammaticTextOrStyleMutation()
    }

    func swapTabBufferContents(
        _ newText: String,
        to textView: NSTextView,
        documentID: DocumentID,
        targetLocation: Int,
        targetLength: Int
    ) {
        syncState.isSwappingTabBuffer = true
        syncState.activeDocumentID = documentID
        textView.string = newText
        tabSwapScratchUndoManager.removeAllActions()
        syncState.isSwappingTabBuffer = false
        updateNativeTextMirror(newText)
        let newLength = syncState.nativeTextMirror?.utf16Length ?? newText.utf16.count
        let clampedLocation = min(max(0, targetLocation), newLength)
        let clampedLength = min(max(0, targetLength), newLength - clampedLocation)
        textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
        (textView as? SwiftEditNSTextView)?.notifyProgrammaticTextOrStyleMutation()
    }

    private func capturePreservedLogSelection(
        in textView: NSTextView,
        oldText: String,
        previousSelection: NSRange
    ) -> (token: String, ordinal: Int)? {
        guard !textView.isEditable,
              previousSelection.location >= 0,
              previousSelection.length >= WordOccurrenceScanner.minWordUTF16Length,
              previousSelection.length <= WordOccurrenceScanner.maxWordUTF16Length else { return nil }
        let oldNS = oldText as NSString
        guard NSMaxRange(previousSelection) <= oldNS.length else { return nil }
        let token = oldNS.substring(with: previousSelection)
        guard !token.isEmpty else { return nil }
        let ordinal = Self.countLiteralOccurrences(of: token, in: oldNS, limitOffset: previousSelection.location)
        return (token, ordinal)
    }

    private static func countLiteralOccurrences(of token: String, in text: NSString, limitOffset: Int) -> Int {
        var count = 0
        var scanOffset = 0
        while scanOffset < limitOffset {
            let hit = text.range(of: token, options: [.literal], range: NSRange(location: scanOffset, length: limitOffset - scanOffset))
            if hit.location == NSNotFound { break }
            count += 1
            scanOffset = max(hit.location + 1, NSMaxRange(hit))
        }
        return count
    }

    private func replaceNativeStorageText(from oldText: String, to newText: String, in textView: NSTextView) {
        let currentLength = textView.textStorage?.length ?? 0
        let edit = Self.minimalReplacement(from: oldText, to: newText) ?? (NSRange(location: 0, length: currentLength), newText)
        if !textView.isEditable {
            textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
        } else if textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) {
            textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
            textView.didChangeText()
        } else {
            textView.string = newText
        }
    }

    private static func relocatePreservedLogToken(
        _ token: String,
        ordinal: Int,
        in newText: String,
        defaultRange: NSRange
    ) -> NSRange? {
        let newNS = newText as NSString
        if defaultRange.length == (token as NSString).length,
           NSMaxRange(defaultRange) <= newNS.length,
           newNS.substring(with: defaultRange) == token {
            return defaultRange
        }
        var matches: [NSRange] = []
        var scanOffset = 0
        while scanOffset < newNS.length {
            let hit = newNS.range(of: token, options: [.literal], range: NSRange(location: scanOffset, length: newNS.length - scanOffset))
            if hit.location == NSNotFound { break }
            matches.append(hit)
            scanOffset = max(hit.location + 1, NSMaxRange(hit))
        }
        guard !matches.isEmpty else { return nil }
        return matches[min(ordinal, matches.count - 1)]
    }
}

#endif
