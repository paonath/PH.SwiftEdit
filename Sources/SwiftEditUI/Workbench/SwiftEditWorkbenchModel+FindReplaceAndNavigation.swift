import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension SwiftEditWorkbenchModel {
    public var programmaticSelectionToken: Int {
        get { overlayState.programmaticSelectionToken }
        set { overlayState.programmaticSelectionToken = newValue }
    }
    public internal(set) var editorFocusRequestToken: Int {
        get { overlayState.editorFocusRequestToken }
        set { overlayState.editorFocusRequestToken = newValue }
    }
    public var navigatorState: DocumentNavigatorState? {
        get { overlayState.navigatorState }
        set { overlayState.navigatorState = newValue }
    }
    public var isDistractionFree: Bool {
        get { overlayState.isDistractionFree }
        set { overlayState.isDistractionFree = newValue }
    }
    public var headerSubmenu: HeaderSubmenuStateMachine {
        get { overlayState.headerSubmenu }
        set { overlayState.headerSubmenu = newValue }
    }

    public var findReplaceState: FindReplaceBarState {
        get { findAndNavigationController.state }
        set { findAndNavigationController.state = newValue }
    }

    /// Evaluates and applies a Markdown smart Enter continuation or empty-marker exit edit atomically on the active document (`BC-004`, `BC-006`).
    /// - Returns: The updated UTF-16 caret offset when smart newline handled the keystroke, or `nil` when standard newline insertion should proceed.
    public func applySmartNewlineIfApplicable(at caretLocation: Int) -> Int? {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly else {
            return nil
        }
        let language = activeDocumentLanguage
        // YAML context (`.yaml` tab or Markdown frontmatter) takes precedence over Markdown list continuation.
        guard let smart = YAMLSmartIndentEngine.evaluateNewline(in: session.snapshot, caretLocation: caretLocation, language: language)
            ?? MarkdownSmartNewlineEngine.evaluateNewline(
                in: session.snapshot,
                caretLocation: caretLocation,
                isMarkdownDocument: language == .markdown
            ) else {
            return nil
        }
        do {
            _ = try session.applyTextEdits([smart.edit], expectedRevision: session.revision)
            sessionsByID[activeID] = session
            currentSelection = SwiftEditCore.TextRange(location: smart.newCaretLocation, length: 0)
            try? tabSession.updateTabState(
                id: activeID,
                isDirty: session.isDirty,
                caretLocation: smart.newCaretLocation,
                revision: session.revision
            )
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            return smart.newCaretLocation
        } catch {
            return nil
        }
    }


    public func presentFindBar(mode: FindBarPresentationMode) {
        findReplaceState.mode = mode
        if mode == .hidden {
            requestEditorFocus()
        }
    }

    func applyProgrammaticSelection(_ range: SwiftEditCore.TextRange, focusEditor: Bool) {
        handleSelectionChanged(range)
        programmaticSelectionToken += 1
        if focusEditor {
            requestEditorFocus()
        }
    }

    /// Evaluates literal search matches for `findReplaceState.query` in the active document and selects the first match (`BC-004`, `BC-011`, `BUG-008`).
    public func executeFind() {
        guard let session = activeDocumentSession else { return }
        let options = SearchOptions(isCaseSensitive: findReplaceState.isCaseSensitive)
        switch DocumentSearchEngine.find(query: findReplaceState.query, in: session.snapshot, options: options) {
        case .completed(let ranges):
            findReplaceState.matches = ranges
            findReplaceState.activeMatchIndex = 0
            if let first = ranges.first {
                applyProgrammaticSelection(first, focusEditor: false)
            }
            statusBannerMessage = nil
        case .degradedOrTimedOut(let reason):
            findReplaceState.matches = []
            statusBannerMessage = "Search skipped: \(reason)"
        }
    }

    /// Selects the next literal match in `findReplaceState.matches` (`BUG-008`).
    public func findNextMatch() {
        if let next = findReplaceState.selectNextMatch() {
            applyProgrammaticSelection(next, focusEditor: false)
        }
    }

    /// Selects the previous literal match in `findReplaceState.matches` (`BUG-008`).
    public func findPreviousMatch() {
        if let previous = findReplaceState.selectPreviousMatch() {
            applyProgrammaticSelection(previous, focusEditor: false)
        }
    }

    /// Replaces the currently selected match in one `BufferRevision` step and re-runs `Find` to highlight the next occurrence (`BUG-009`).
    public func executeReplaceSingle() {
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              !findReplaceState.query.isEmpty,
              !findReplaceState.matches.isEmpty else { return }
        let idx = min(max(0, findReplaceState.activeMatchIndex), findReplaceState.matches.count - 1)
        let targetRange = findReplaceState.matches[idx]
        let edit = TextEdit(range: targetRange, replacement: findReplaceState.replacement)
        do {
            let expectedRev = session.revision
            _ = try session.applyTextEdits([edit], expectedRevision: expectedRev)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            let replacedSelection = SwiftEditCore.TextRange(
                location: targetRange.location,
                length: (findReplaceState.replacement as NSString).length
            )
            applyProgrammaticSelection(replacedSelection, focusEditor: false)
            statusBannerMessage = "Replaced 1 occurrence."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            executeFind()
        } catch {
            statusBannerMessage = "Replace failed: \(error)"
        }
    }

    /// Replaces all literal matches of `findReplaceState.query` with `findReplaceState.replacement` in one atomic revision (`BC-004`).
    public func executeReplaceAll() {
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID] else { return }
        let snap = session.snapshot
        let options = SearchOptions(isCaseSensitive: findReplaceState.isCaseSensitive)
        guard let edits = DocumentSearchEngine.replaceAll(
            query: findReplaceState.query,
            with: findReplaceState.replacement,
            in: snap,
            options: options
        ).completedValue else {
            statusBannerMessage = "Replace All skipped (binary, degraded, or match limit exceeded)."
            return
        }
        guard !edits.isEmpty else { return }
        do {
            _ = try session.applyTextEdits(edits, expectedRevision: snap.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            findReplaceState.matches = []
            statusBannerMessage = "Replaced \(edits.count) occurrence(s)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Replace All failed: \(error)"
        }
    }

    /// Moves the selection to the 1-based line parsed from `findReplaceState.goToLineText` (`Cmd+G`, `BUG-008`).
    public func executeGoToLine() {
        guard let session = activeDocumentSession,
              let targetLine = Int(findReplaceState.goToLineText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let range = DocumentSearchEngine.goToLine(targetLine, in: session.snapshot) else {
            statusBannerMessage = "Line number out of range."
            return
        }
        applyProgrammaticSelection(range, focusEditor: true)
        statusBannerMessage = nil
    }

    /// Updates the active document's wire `LineEnding` (`LF`, `CRLF`, `CR`) and marks the tab dirty (`DATA-004`).

    public func listIndentationOutcome(outdent: Bool) -> SmartListOutcome {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, safetyBanner.canSave else {
            return .notApplicable
        }
        let yaml = YAMLSmartIndentEngine.evaluateTab(in: session.snapshot, selection: currentSelection, outdent: outdent, language: activeDocumentLanguage)
        if yaml != .notApplicable { return yaml }
        return MarkdownSmartListEngine.evaluateIndent(
            in: session.snapshot,
            selection: currentSelection,
            outdent: outdent,
            isMarkdownDocument: (activeDocumentLanguage == .markdown)
        )
    }

    /// Applies list indentation to the active session as exactly one `BufferRevision` and translates `currentSelection`.
    ///
    /// The editor view applies the same outcome through `NSTextView.insertText` to keep a single native undo step; this model-level path serves headless callers and tests.
    /// - Returns: `true` when the key was consumed (edit applied or safe no-op), `false` when default handling should proceed.
    @discardableResult
    public func applyListIndentation(outdent: Bool) -> Bool {
        switch listIndentationOutcome(outdent: outdent) {
        case .notApplicable:
            return false
        case .consumedNoOp:
            return true
        case .edit(let listEdit):
            guard let activeID = tabSession.activeTabID, var session = sessionsByID[activeID] else { return false }
            do {
                _ = try session.applyTextEdits(listEdit.edits, expectedRevision: session.revision)
                sessionsByID[activeID] = session
                try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
                syncUntitledTabTitleIfNeeded(for: activeID, session: session)
                currentSelection = listEdit.newSelection
                persistRecoveryState()
                refreshDiagnosticsForActiveDocument()
                return true
            } catch {
                statusBannerMessage = "List indentation failed: \(error)"
                return true
            }
        }
    }

    /// Debounce window for per-keystroke `SessionRecovery` writes; tab switch, close, and other lifecycle events flush immediately (`UI-012`, `DATA-005`).

    /// Monotonic token bumped whenever the model requests a caret/selection the editor view must adopt (`currentSelection`).
    /// Monotonic token bumped whenever dismissing bars, sheets, Navigator, or Distraction-Free requires returning focus to `SwiftEditNSTextView` (`BUG-009`).

    // MARK: Document deps.navigator & distraction-free (014)

    /// Open deps.navigator palette state; `nil` while closed (nothing is parsed or retained when closed).
    /// `true` while only the active editor is visible in full screen.
    /// Window seams injected by the root view (kept closures so the model stays AppKit-free and testable).

    /// `Option+\`: toggles the deps.navigator (Markdown headings or YAML top-level keys) of the active writable, non-binary tab.
    public func toggleDocumentNavigator() {
        if navigatorState != nil { closeDocumentNavigator(); return }
        guard editorSyntaxLanguage != .plainText, let session = activeDocumentSession else { return }
        switch editorSyntaxLanguage {
        case .markdown: navigatorState = DocumentNavigatorState(headings: MarkdownHeadingOutlineEngine.outline(index: activeLineIndex() ?? MarkdownLineIndex(text: session.text)))
        case .yaml: navigatorState = DocumentNavigatorState(headings: YAMLOutlineEngine.outline(index: activeLineIndex() ?? MarkdownLineIndex(text: session.text)))
        case .plainText, .log: return
        }
    }

    public func closeDocumentNavigator() {
        navigatorState = nil
        requestEditorFocus()
    }

    /// Jumps the caret to the selected heading (clamped to the current text) and closes the deps.navigator, returning focus to the editor.
    public func confirmDocumentNavigator() {
        defer { navigatorState = nil }
        guard let state = navigatorState, let session = activeDocumentSession,
              let offset = state.confirm(documentLength: session.text.utf16.count) else {
            requestEditorFocus()
            return
        }
        applyProgrammaticSelection(SwiftEditCore.TextRange(location: offset, length: 0), focusEditor: true)
    }

    /// `Option+1`: enters or leaves distraction-free mode; full screen is toggled only when the state differs.
    public func toggleDistractionFree() {
        if isDistractionFree {
            isDistractionFree = false
            if !caches.fullScreenWasActiveBeforeDistractionFree, windowFullScreenQuery() { windowFullScreenToggle() }
            requestEditorFocus()
        } else {
            caches.fullScreenWasActiveBeforeDistractionFree = windowFullScreenQuery()
            isDistractionFree = true
            navigatorState = nil
            if !caches.fullScreenWasActiveBeforeDistractionFree { windowFullScreenToggle() }
        }
    }

    /// Resyncs the flag when the user leaves full screen with the system control.
    public func windowDidExitFullScreen() {
        isDistractionFree = false
        requestEditorFocus()
    }

    /// Dismisses the header submenu overlay and restores editor focus cleanly (`BUG-006`, `BUG-009`).
    public func dismissHeaderSubmenu() {
        headerSubmenu.escapePressed()
        requestEditorFocus()
    }

}

#endif
