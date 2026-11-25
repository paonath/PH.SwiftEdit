import Foundation
import SwiftEditCore

#if os(macOS)
/// Quick Open (`Cmd+T`), multi-file Find in Folder (`Ctrl+Shift+F`), and `Opt+Cmd+E` Use Selection for Find commands (`REQ-007`, `REQ-008`).
extension SwiftEditWorkbenchModel {
    /// Toggles the workspace Quick Open (`Cmd+T`) overlay (`REQ-007`).
    public func toggleQuickOpen() {
        if quickOpenController.isQuickOpenPresented {
            closeQuickOpen()
            return
        }
        guard let root = grantedScopeRootURL ?? selectedFolderURL else {
            statusBannerMessage = "Open a workspace folder first to use Quick Open."
            return
        }
        quickOpenController.isFolderSearchPresented = false
        let indexed = WorkspaceFolderSearchEngine.indexWorkspaceFiles(rootURL: root, fileSystem: deps.fileSystem)
        quickOpenController.indexedFiles = indexed.files
        quickOpenController.quickOpenQuery = ""
        quickOpenController.quickOpenSelectedIndex = 0
        quickOpenController.candidates = WorkspaceFolderSearchEngine.rankQuickOpen(query: "", files: indexed.files)
        quickOpenController.isQuickOpenPresented = true
    }

    public func closeQuickOpen() {
        quickOpenController.isQuickOpenPresented = false
        requestEditorFocus()
    }

    /// Re-ranks Quick Open candidates for `query` (`REQ-007`).
    public func updateQuickOpenQuery(_ query: String) {
        quickOpenController.quickOpenQuery = query
        quickOpenController.quickOpenSelectedIndex = 0
        quickOpenController.candidates = WorkspaceFolderSearchEngine.rankQuickOpen(
            query: query,
            files: quickOpenController.indexedFiles
        )
    }

    public func moveQuickOpenSelection(delta: Int) {
        let count = quickOpenController.candidates.count
        guard count > 0 else { return }
        quickOpenController.quickOpenSelectedIndex = (quickOpenController.quickOpenSelectedIndex + delta + count) % count
    }

    /// Opens the highlighted Quick Open file inside the granted workspace scope (`REQ-007`).
    public func confirmQuickOpenSelection(at index: Int? = nil) {
        let idx = index ?? quickOpenController.quickOpenSelectedIndex
        guard quickOpenController.candidates.indices.contains(idx) else {
            closeQuickOpen()
            return
        }
        let chosen = quickOpenController.candidates[idx]
        quickOpenController.isQuickOpenPresented = false
        openFile(at: chosen.url, withinScope: grantedScopeRootURL ?? selectedFolderURL)
        requestEditorFocus()
    }

    /// Toggles the multi-file Find in Folder (`Ctrl+Shift+F`) overlay (`REQ-007`).
    public func toggleFindInFolder() {
        if quickOpenController.isFolderSearchPresented {
            closeFindInFolder()
            return
        }
        guard grantedScopeRootURL != nil || selectedFolderURL != nil else {
            statusBannerMessage = "Open a workspace folder first to search across files."
            return
        }
        quickOpenController.isQuickOpenPresented = false
        quickOpenController.isFolderSearchPresented = true
    }

    public func closeFindInFolder() {
        quickOpenController.isFolderSearchPresented = false
        requestEditorFocus()
    }

    /// Runs bounded literal multi-file search across the active workspace folder (`REQ-007`, `CWE-1333`).
    public func executeFindInFolder() {
        guard let root = grantedScopeRootURL ?? selectedFolderURL else { return }
        quickOpenController.folderSearchResult = WorkspaceFolderSearchEngine.searchInFolder(
            query: quickOpenController.folderSearchQuery,
            rootURL: root,
            fileSystem: deps.fileSystem,
            isCaseSensitive: quickOpenController.folderSearchCaseSensitive,
            isWholeWord: quickOpenController.folderSearchWholeWord
        )
    }

    /// Opens `match.fileURL` inside workspace scope and moves the caret/selection to `match.lineNumber` (`REQ-007`).
    public func openFolderSearchMatch(_ match: FolderSearchMatch) {
        let scope = grantedScopeRootURL ?? selectedFolderURL
        quickOpenController.isFolderSearchPresented = false
        openFile(at: match.fileURL, withinScope: scope)
        if let session = activeDocumentSession,
           let lineRange = DocumentSearchEngine.goToLine(match.lineNumber, in: session.snapshot) {
            currentSelection = SwiftEditCore.TextRange(location: lineRange.location, length: 0)
            overlayState.programmaticSelectionToken += 1
            requestEditorFocus()
        }
    }

    /// Copies the active editor selection (`<= 1024` UTF-16 units) into `findReplaceState.query` and executes Find (`Opt+Cmd+E`, `REQ-008`).
    public func useSelectionForFind() {
        guard let session = activeDocumentSession,
              !session.isBinaryReadOnly,
              currentSelection.length > 0,
              currentSelection.length <= DocumentSearchEngine.maxQueryUTF16Units else { return }
        let nsText = session.text as NSString
        guard currentSelection.location >= 0,
              currentSelection.location + currentSelection.length <= nsText.length else { return }
        let selected = nsText.substring(with: NSRange(location: currentSelection.location, length: currentSelection.length))
        guard !selected.isEmpty else { return }
        if findReplaceState.mode == .hidden {
            findReplaceState.mode = .find
        }
        findReplaceState.isInSelection = false
        findReplaceState.scopedSelectionRange = nil
        findReplaceState.query = selected
        executeFind()
    }
}
#endif
