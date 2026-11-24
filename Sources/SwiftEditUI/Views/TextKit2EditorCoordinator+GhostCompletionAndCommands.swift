import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Line-index caching, ghost-text completion, list/table indentation, and keyboard command routing for `TextKit2EditorView.Coordinator` (`REQ-020-01`, `UI-006`).
extension TextKit2EditorView.Coordinator {
    /// Applies a `Tab` / `Shift+Tab` list or GFM table outcome as one coalesced `insertText` replacement (`UI-006`).
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

    /// Validator line index: the workbench's shared per-revision index when it matches the storage, otherwise one built from native text.
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

    /// Line index cached by `(DocumentID, BufferRevision, utf16Count)` so same-length edits invalidate deterministically (`BUG-015`).
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

    func showGhostCompletion(_ suffix: String, at location: Int, in textView: NSTextView) {
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

#endif
