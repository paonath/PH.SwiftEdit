import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension SwiftEditWorkbenchModel {
    public internal(set) var statusBannerMessage: String? {
        get { overlayState.statusBannerMessage }
        set { overlayState.statusBannerMessage = newValue }
    }
    public internal(set) var pendingDirtyCloseTabID: DocumentID? {
        get { overlayState.pendingDirtyCloseTabID }
        set { overlayState.pendingDirtyCloseTabID = newValue }
    }
    public internal(set) var isPendingTerminationPrompt: Bool {
        get { overlayState.isPendingTerminationPrompt }
        set { overlayState.isPendingTerminationPrompt = newValue }
    }

    /// Reorders the tab matching `id` one slot left inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    public func moveTabLeft(id: DocumentID) {
        do {
            try tabSession.moveTabLeft(id: id)
            persistRecoveryState()
        } catch {
            statusBannerMessage = "Reorder tab failed: \(error)"
        }
    }

    /// Reorders the tab matching `id` one slot right inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    public func moveTabRight(id: DocumentID) {
        do {
            try tabSession.moveTabRight(id: id)
            persistRecoveryState()
        } catch {
            statusBannerMessage = "Reorder tab failed: \(error)"
        }
    }

    /// Reorders the tab matching `id` to `destinationIndex` inside its pinned or unpinned partition (`BC-006`, `BC-008`).
    public func moveTab(id: DocumentID, toIndex destinationIndex: Int) {
        do {
            try tabSession.moveTab(id: id, toIndex: destinationIndex)
            persistRecoveryState()
        } catch {
            statusBannerMessage = "Reorder tab failed: \(error)"
        }
    }

    public func newUntitledTab() {
        caches.asyncOpenGeneration &+= 1
        activeBinaryInspection = nil
        let session = DocumentSession(text: "")
        sessionsByID[session.id] = session
        savedBaselineByID[session.id] = session.snapshot
        try? tabSession.openOrActivate(
            snapshot: session.snapshot,
            title: TabTitleDeriver.untitledTitle(from: ""),
            isDirty: false
        )
        statusBannerMessage = nil
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    public func togglePin(id: DocumentID) {
        guard id != activeBinaryInspection?.id,
              let tab = tabSession.tabs.first(where: { $0.id == id }) else { return }
        try? tabSession.setPinned(!tab.isPinned, for: id)
        persistRecoveryState()
    }

    public func closeTab(id: DocumentID, forcePinned: Bool = false) {
        caches.asyncOpenGeneration &+= 1
        let closingFileURL = tabSession.tabs.first(where: { $0.id == id })?.fileURL
        logTails.removeValue(forKey: id)?.stop()
        logTailOnlyTabIDs.remove(id)
        externalFileMonitor.unwatch(tabID: id)
        do {
            _ = try tabSession.closeTab(id: id, forcePinned: forcePinned)
            domainControllers.bulkCloseHistory.recordClosedFileURL(closingFileURL)
            sessionsByID.removeValue(forKey: id)
            savedBaselineByID.removeValue(forKey: id)
            undoRegistry.removeUndoManager(for: id)
            if caches.bracketTopologyCache?.id == id { caches.bracketTopologyCache = nil }
            if caches.backtickCache?.id == id { caches.backtickCache = nil }
            if caches.previewCache?.id == id { caches.previewCache = nil }
            if tabSession.tabs.isEmpty {
                caches.diagnosticsTask?.cancel()
                diffCoordinator.clear()
                PreviewThumbnailCache.shared.clear()
            }
            try? deps.recoveryStore.removeRecoverySnapshot(for: id)
            caches.lastPersistedRecoveryRevisions.removeValue(forKey: id)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch DomainError.pinnedTabCloseForbidden {
            statusBannerMessage = "Pinned tab cannot be closed. Unpin it first."
        } catch {
            statusBannerMessage = "Close failed: \(error)"
        }
    }

    public func handleEditorTextChanged(_ editorText: String) {
        // TextKit hands over an NSString-bridged buffer; normalize once so comparison and every downstream scan stay native (`PERF-B1`).
        let newText = NativeTextNormalizer.native(editorText)
        guard activeBinaryInspection == nil,
              let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              (try? session.replaceFullTextIfChanged(newText)) == true else { return }
        session.reconcileDirtyState(against: savedBaselineByID[activeID])
        sessionsByID[activeID] = session
        try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
        syncUntitledTabTitleIfNeeded(for: activeID, session: session)
        scheduleRecoveryPersist()
        refreshDiagnosticsForActiveDocument()
        scheduleWordCompletionRebuild()
    }

    public func performCommandD() {
        guard activeLogTail == nil else {
            statusBannerMessage = "Duplicate blocked while live log tail is active."
            return
        }
        guard let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Duplicate blocked: binary read-only file."
            return
        }
        do {
            _ = try session.duplicateLineOrSelection(selection: currentSelection)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            statusBannerMessage = nil
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Cmd+D failed: \(error)"
        }
    }

    public func formatActiveDocument() {
        guard activeLogTail == nil else {
            statusBannerMessage = "Format blocked while live log tail is active."
            return
        }
        guard let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canFormat else {
            statusBannerMessage = "Format blocked: binary read-only file."
            return
        }
        let snap = session.snapshot
        if activeDocumentLanguage == .json {
            guard let jsonEdit = JSONFormatter.prettyPrint(snapshot: snap) else {
                statusBannerMessage = "JSON format skipped: invalid, deeply nested (> 128), or already formatted JSON."
                return
            }
            if (try? session.applyTextEdits([jsonEdit], expectedRevision: snap.revision)) != nil {
                session.reconcileDirtyState(against: savedBaselineByID[activeID])
                sessionsByID[activeID] = session
                try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
                statusBannerMessage = "Formatted JSON document."
                persistRecoveryState()
                refreshDiagnosticsForActiveDocument()
            }
            return
        }
        guard let batch = MarkdownLintAndFormatEngine.formatDocument(snapshot: snap).completedValue else {
            statusBannerMessage = "Formatting skipped (degraded, binary, AST depth > 128, or > 250 ms)."
            return
        }
        do {
            _ = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            statusBannerMessage = batch.edits.isEmpty ? "Markdown already formatted." : "Formatted \(batch.edits.count) line(s)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Format failed: \(error)"
        }
    }

    public func saveActiveDocument() {
        guard let activeID = tabSession.activeTabID,
              let session = sessionsByID[activeID] else { return }
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Save blocked: binary read-only file."
            return
        }

        let targetURL: URL
        if let existingURL = session.fileURL {
            targetURL = existingURL
        } else {
            guard let chosen = deps.savePanelProvider(activeTabTitle) else { return }
            targetURL = chosen
        }
        saveDocument(to: targetURL)
    }

    /// Prompts for a destination via the injected save-panel seam and saves the active document there; rejected fail-closed on binary read-only and tail-only buffers before any panel is shown (`DATA-003`, `UI-008`).
    public func saveActiveDocumentAsViaPanel() {
        guard let activeID = tabSession.activeTabID,
              let session = activeDocumentSession else { return }
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save As blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
        guard !session.isBinaryReadOnly, safetyBanner.canSave else {
            statusBannerMessage = "Save As blocked: binary read-only file."
            return
        }
        guard let chosen = deps.savePanelProvider(activeTabTitle) else { return }
        saveDocument(to: chosen)
    }

    public func saveDocument(to targetURL: URL) {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
        guard !session.isBinaryReadOnly else {
            statusBannerMessage = "Save blocked: binary read-only file."
            return
        }
        if trimTrailingWhitespaceOnSave, !session.isDegradedPlainText {
            let trimEdits = LineEditCommands.trimTrailingWhitespace(in: session.snapshot)
            if !trimEdits.isEmpty {
                _ = try? session.applyTextEdits(trimEdits, expectedRevision: session.revision)
            }
        }
        let standardizedTarget = targetURL.standardizedFileURL
        let effectiveScope = resolveSaveScope(for: standardizedTarget)
        do {
            let saved = try deps.loader.save(session, to: standardizedTarget, withinScope: effectiveScope)
            sessionsByID[activeID] = saved
            savedBaselineByID[activeID] = saved.snapshot
            externalFileMonitor.clearConflict(for: activeID)
            externalFileMonitor.registerWatch(tabID: activeID, url: standardizedTarget, scopeURL: effectiveScope, knownText: saved.text)
            try? tabSession.updateTabState(id: activeID, title: standardizedTarget.lastPathComponent, fileURL: .some(standardizedTarget), isDirty: false, revision: saved.revision)
            try? deps.recoveryStore.removeRecoverySnapshot(for: activeID)
            caches.lastPersistedRecoveryRevisions.removeValue(forKey: activeID)
            recordRecentFileIfEligible(url: standardizedTarget, withinScope: effectiveScope)
            statusBannerMessage = "Saved \(standardizedTarget.lastPathComponent)."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            refreshFolderEntries()
        } catch {
            statusBannerMessage = "Save failed: \(error)"
        }
    }

    func resolveSaveScope(for targetURL: URL) -> URL {
        if let scopeRoot = grantedScopeRootURL {
            let scopePath = scopeRoot.resolvingSymlinksInPath().standardizedFileURL.path
            let targetDirPath = targetURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
            if targetDirPath == scopePath || targetDirPath.hasPrefix(scopePath + "/") {
                return scopeRoot
            }
        }
        return targetURL.deletingLastPathComponent()
    }
}

extension SwiftEditWorkbenchModel {
    public func setActiveDocumentLineEnding(_ lineEnding: LineEnding) {
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID] else { return }
        do {
            try session.setLineEnding(lineEnding)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Cannot change line ending: \(error)"
        }
    }

    /// Requests closing the active binary inspection overlay or currently active document tab (`Shift+Cmd+W`).
    public func requestCloseActiveTab() {
        if activeBinaryInspection != nil {
            dismissBinaryInspection()
            return
        }
        guard let activeID = tabSession.activeTabID else { return }
        requestCloseTab(id: activeID)
    }

    /// Initiates single-tab closure, pausing for `Save / Don't Save / Cancel` confirmation only when `tab.isDirty` is `true` (`REQ-001`, `BC-008`, `DATA-006`).
    public func requestCloseTab(id: DocumentID) {
        domainControllers.bulkCloseHistory.cancelBulkClose()
        guard let tab = tabSession.tabs.first(where: { $0.id == id }) else { return }
        if tab.isPinned {
            statusBannerMessage = "Pinned tab cannot be closed. Unpin it first."
            return
        }
        if tab.isDirty {
            pendingDirtyCloseTabID = id
            isPendingTerminationPrompt = false
            return
        }
        closeTab(id: id)
    }

    /// Applies the user's `Save / Don't Save / Cancel` decision for a pending single/bulk dirty tab close or application quit prompt (`REQ-002`, `DATA-006`).
    public func resolvePendingDirtyClose(_ decision: DirtyCloseDecision) {
        if isPendingTerminationPrompt {
            resolvePendingTermination(decision)
            return
        }
        guard let tabID = pendingDirtyCloseTabID else { return }
        let forcePinned = domainControllers.bulkCloseHistory.isForcePinned
        switch decision {
        case .cancel:
            pendingDirtyCloseTabID = nil
            domainControllers.bulkCloseHistory.cancelBulkClose()
        case .dontSave:
            pendingDirtyCloseTabID = nil
            closeTab(id: tabID, forcePinned: forcePinned)
            advanceBulkCloseQueue()
        case .save:
            pendingDirtyCloseTabID = nil
            activateTab(id: tabID)
            saveActiveDocument()
            if sessionsByID[tabID]?.isDirty == false {
                closeTab(id: tabID, forcePinned: forcePinned)
                advanceBulkCloseQueue()
            } else {
                domainControllers.bulkCloseHistory.cancelBulkClose()
            }
        }
    }

    func advanceBulkCloseQueue() {
        let forcePinned = domainControllers.bulkCloseHistory.isForcePinned
        while let nextID = domainControllers.bulkCloseHistory.dequeueNext() {
            guard let tab = tabSession.tabs.first(where: { $0.id == nextID }) else { continue }
            if tab.isPinned && !forcePinned { continue }
            if tab.isDirty {
                pendingDirtyCloseTabID = nextID
                isPendingTerminationPrompt = false
                return
            }
            closeTab(id: nextID, forcePinned: forcePinned)
        }
        domainControllers.bulkCloseHistory.cancelBulkClose()
    }

    func resolvePendingTermination(_ decision: DirtyCloseDecision) {
        switch decision {
        case .cancel:
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            completeTerminationPrompt(allowQuit: false)
        case .dontSave:
            // Route dirty-termination teardown through unified `closeTab(id:forcePinned:)` so `.recovery` snapshots, `LogTailController` descriptors, undo stacks, and preview/diff caches release deterministically (`SEC-007`, `SEC-011`).
            domainControllers.bulkCloseHistory.cancelBulkClose()
            for id in tabSession.tabs.map(\.id) {
                closeTab(id: id, forcePinned: true)
            }
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            persistRecoveryState()
            completeTerminationPrompt(allowQuit: true)
        case .save:
            if let targetID = pendingDirtyCloseTabID {
                activateTab(id: targetID)
                saveActiveDocument()
                if sessionsByID[targetID]?.isDirty == true {
                    isPendingTerminationPrompt = false
                    pendingDirtyCloseTabID = nil
                    completeTerminationPrompt(allowQuit: false)
                    return
                }
            }
            if let nextDirty = tabSession.tabs.first(where: \.isDirty) {
                pendingDirtyCloseTabID = nextDirty.id
                isPendingTerminationPrompt = true
                return
            }
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            persistRecoveryState()
            completeTerminationPrompt(allowQuit: true)
        }
    }

    func completeTerminationPrompt(allowQuit: Bool) {
        let handler = caches.terminationReplyHandler
        caches.terminationReplyHandler = nil
        handler?(allowQuit)
    }

    /// Returns `true` when the application may terminate immediately, or `false` while staging sequential dirty-tab prompts (`Cmd+Q`) (`BUG-003`, `BUG-010`).
    public func requestApplicationTermination(reply: (@MainActor (Bool) -> Void)? = nil) -> Bool {
        if let firstDirty = tabSession.tabs.first(where: \.isDirty) {
            caches.terminationReplyHandler = reply
            pendingDirtyCloseTabID = firstDirty.id
            isPendingTerminationPrompt = true
            return false
        }
        caches.terminationReplyHandler = nil
        return true
    }
}

extension SwiftEditWorkbenchModel {
    public var bulkCloseAndHistoryController: WorkbenchBulkCloseAndHistoryController {
        domainControllers.bulkCloseHistory
    }

    /// Closes all unpinned tabs strictly to the right of `id`, prompting sequentially on dirty tabs (`REQ-002`).
    public func requestCloseTabsToTheRight(of id: DocumentID) {
        startBulkClose(ids: tabSession.unpinnedTabIDsToTheRight(of: id).reversed(), forcePinned: false)
    }

    /// Closes all unpinned tabs other than `id`, preserving `id` and all pinned tabs (`REQ-002`).
    public func requestCloseOtherTabs(keeping id: DocumentID) {
        startBulkClose(ids: tabSession.unpinnedOtherTabIDs(keeping: id).reversed(), forcePinned: false)
    }

    /// Closes all unpinned tabs while preserving every pinned tab (`REQ-002`).
    public func requestCloseAllUnpinnedTabs() {
        startBulkClose(ids: tabSession.unpinnedTabIDs().reversed(), forcePinned: false)
    }

    /// Closes all open tabs — including pinned tabs (`forcePinned: true`) — prompting sequentially on dirty tabs (`REQ-002`).
    public func requestCloseAllTabs() {
        startBulkClose(ids: tabSession.allTabIDs().reversed(), forcePinned: true)
    }

    /// Middle-click handler on a tab strip item: delegates to standard pinned-guarded `requestCloseTab(id:)` (`REQ-002`).
    public func handleMiddleClickTab(id: DocumentID) {
        requestCloseTab(id: id)
    }

    /// Reopens the most recently closed file-backed tab (`Shift+Cmd+T`), verifying canonical symlink confinement via `FileSystemProviding` before loading (`REQ-002`, `SEC-003`).
    @discardableResult
    public func reopenLastClosedTab() -> Bool {
        while let candidateURL = domainControllers.bulkCloseHistory.popMostRecentClosedFileURL() {
            let scope = workspaceState.grantedScopeRootURL ?? candidateURL.deletingLastPathComponent()
            guard (try? deps.fileSystem.fileAttributes(at: candidateURL, withinScope: scope)) != nil else {
                continue
            }
            let countBefore = tabSession.tabs.count
            let activeBefore = tabSession.activeTabID
            openFile(at: candidateURL, withinScope: scope)
            if tabSession.tabs.count > countBefore || tabSession.activeTabID != activeBefore {
                return true
            }
        }
        return false
    }

    /// Cycles to the next open tab (`Shift+Cmd+]` / `Ctrl+Tab`) (`REQ-002`).
    public func selectNextTab() {
        guard !tabSession.tabs.isEmpty else { return }
        var updated = tabSession
        updated.activateAdjacentTab(offset: 1)
        if let target = updated.activeTabID {
            activateTab(id: target)
        }
    }

    /// Cycles to the previous open tab (`Shift+Cmd+[` / `Ctrl+Shift+Tab`) (`REQ-002`).
    public func selectPreviousTab() {
        guard !tabSession.tabs.isEmpty else { return }
        var updated = tabSession
        updated.activateAdjacentTab(offset: -1)
        if let target = updated.activeTabID {
            activateTab(id: target)
        }
    }

    /// Activates a tab by 1-based shortcut index (`Cmd+1..9`, where `9` selects the rightmost tab) (`REQ-002`).
    public func selectTabAtShortcutIndex(_ oneBasedIndex: Int) {
        guard !tabSession.tabs.isEmpty else { return }
        var updated = tabSession
        updated.activateTabAtShortcutIndex(oneBasedIndex)
        if let target = updated.activeTabID {
            activateTab(id: target)
        }
    }

    private func startBulkClose(ids: [DocumentID], forcePinned: Bool) {
        guard !ids.isEmpty else { return }
        domainControllers.bulkCloseHistory.enqueueBulkClose(ids, forcePinned: forcePinned)
        advanceBulkCloseQueue()
    }
}

/// Enriched status-bar selection/word metrics, interactive Encoding conversion/reopen, and confined `.git/HEAD` branch badge (`REQ-012`, `SEC-003`, `SEC-004`, `DATA-006`).
extension SwiftEditWorkbenchModel {
    /// Selection character/line counters and Markdown word count for the active tab (`REQ-012`).
    public var activeEnrichedStatusBarMetrics: EnrichedStatusBarMetrics {
        guard let activeID = tabSession.activeTabID,
              workspaceState.activeBinaryInspection == nil,
              let session = sessionsByID[activeID] else { return EnrichedStatusBarMetrics() }
        let lang = tabSession.tabs.first { $0.id == activeID }?.language ?? .plainText
        return EnrichedStatusBarMetrics.evaluate(
            snapshot: session.snapshot,
            selection: currentSelection,
            isMarkdown: lang == .markdown
        )
    }

    /// Current Git branch read via confined zero-subprocess `.git/HEAD` lookup inside the granted workspace scope (`REQ-012`, `SEC-004`).
    public var activeGitBranchName: String? {
        guard let scope = workspaceState.grantedScopeRootURL ?? workspaceState.selectedFolderURL else { return nil }
        let activeFileDir = tabSession.activeTabID.flatMap { sessionsByID[$0]?.fileURL?.deletingLastPathComponent() }
        let startURL = activeFileDir ?? workspaceState.selectedFolderURL ?? scope
        return GitHeadBranchReader.readBranchName(startingAt: startURL, withinScope: scope, fileSystem: deps.fileSystem)
    }

    /// Sets the target `TextEncoding` for the active writable tab's next Save (`REQ-012`, `DATA-004`).
    public func setActiveDocumentEncoding(_ encoding: TextEncoding) {
        guard let activeID = tabSession.activeTabID,
              logTails[activeID] == nil,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID] else { return }
        do {
            try session.setEncoding(encoding)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            overlayState.statusBannerMessage = "Cannot change encoding: \(error)"
        }
    }

    /// Re-decodes the active file-backed tab from disk using `encoding`, blocking unconfirmed dirty tabs to prevent silent data loss (`REQ-012`, `DATA-006`, `N13`).
    @discardableResult
    public func reopenActiveDocumentWithEncoding(_ encoding: TextEncoding, forceDiscardDirty: Bool = false) -> Bool {
        guard let activeID = tabSession.activeTabID,
              logTails[activeID] == nil,
              !logTailOnlyTabIDs.contains(activeID),
              let session = sessionsByID[activeID],
              let fileURL = session.fileURL else { return false }
        if session.isDirty && !forceDiscardDirty {
            overlayState.statusBannerMessage = "Save or revert unsaved edits before reopening with another encoding."
            return false
        }
        let scope = workspaceState.grantedScopeRootURL ?? workspaceState.selectedFolderURL ?? fileURL.deletingLastPathComponent()
        do {
            let loaded = try deps.loader.load(from: fileURL, explicitEncoding: encoding, withinScope: scope)
            let updated = DocumentSession(
                id: activeID,
                fileURL: fileURL,
                revision: session.revision.next(),
                text: loaded.text,
                encoding: loaded.encoding,
                lineEnding: loaded.lineEnding,
                isDirty: false,
                isDegradedPlainText: loaded.isDegradedPlainText,
                isBinaryReadOnly: false
            )
            sessionsByID[activeID] = updated
            savedBaselineByID[activeID] = updated.snapshot
            externalFileMonitor.clearConflict(for: activeID)
            externalFileMonitor.recordKnownText(updated.text, for: activeID)
            try? tabSession.updateTabState(id: activeID, isDirty: false, revision: updated.revision)
            try? deps.recoveryStore.removeRecoverySnapshot(for: activeID)
            caches.lastPersistedRecoveryRevisions.removeValue(forKey: activeID)
            overlayState.statusBannerMessage = "Reopened \(fileURL.lastPathComponent) (\(encoding.rawValue))."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            overlayState.statusBannerMessage = "Reopen with encoding failed: \(error)"
            return false
        }
    }
}

#endif
