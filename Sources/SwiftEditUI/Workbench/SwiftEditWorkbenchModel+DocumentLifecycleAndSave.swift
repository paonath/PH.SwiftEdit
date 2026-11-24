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
            isDirty: true
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

    public func closeTab(id: DocumentID) {
        caches.asyncOpenGeneration &+= 1
        logTails.removeValue(forKey: id)?.stop()
        logTailOnlyTabIDs.remove(id)
        do {
            _ = try tabSession.closeTab(id: id)
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
        guard let batch = MarkdownLintAndFormatEngine.formatDocument(snapshot: snap).completedValue else {
            statusBannerMessage = "Formatting skipped (degraded, binary, AST depth > 128, or > 250 ms)."
            return
        }
        do {
            _ = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)
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
              let session = sessionsByID[activeID] else { return }
        guard !logTailOnlyTabIDs.contains(activeID) else {
            statusBannerMessage = "Save blocked: this log is too large to edit and is shown as a live tail only."
            return
        }
        guard !session.isBinaryReadOnly else {
            statusBannerMessage = "Save blocked: binary read-only file."
            return
        }
        let standardizedTarget = targetURL.standardizedFileURL
        let effectiveScope = resolveSaveScope(for: standardizedTarget)
        do {
            let saved = try deps.loader.save(session, to: standardizedTarget, withinScope: effectiveScope)
            sessionsByID[activeID] = saved
            savedBaselineByID[activeID] = saved.snapshot
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
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            statusBannerMessage = "Cannot change line ending: \(error)"
        }
    }

    /// Requests closing the active binary inspection overlay or currently active document tab (`Cmd+W`).
    public func requestCloseActiveTab() {
        if activeBinaryInspection != nil {
            dismissBinaryInspection()
            return
        }
        guard let activeID = tabSession.activeTabID else { return }
        requestCloseTab(id: activeID)
    }

    /// Initiates tab closure (`Cmd+W`), pausing for `Save / Don't Save / Cancel` confirmation when `tab.isDirty` is `true` (`BC-008`, `DATA-006`).
    public func requestCloseTab(id: DocumentID) {
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

    /// Applies the user's `Save / Don't Save / Cancel` decision for a pending dirty tab close or application quit prompt (`DATA-006`).
    public func resolvePendingDirtyClose(_ decision: DirtyCloseDecision) {
        if isPendingTerminationPrompt {
            resolvePendingTermination(decision)
            return
        }
        guard let tabID = pendingDirtyCloseTabID else { return }
        switch decision {
        case .cancel:
            pendingDirtyCloseTabID = nil
        case .dontSave:
            pendingDirtyCloseTabID = nil
            closeTab(id: tabID)
        case .save:
            pendingDirtyCloseTabID = nil
            activateTab(id: tabID)
            saveActiveDocument()
            if sessionsByID[tabID]?.isDirty == false {
                closeTab(id: tabID)
            }
        }
    }

    func resolvePendingTermination(_ decision: DirtyCloseDecision) {
        switch decision {
        case .cancel:
            isPendingTerminationPrompt = false
            pendingDirtyCloseTabID = nil
            completeTerminationPrompt(allowQuit: false)
        case .dontSave:
            for id in tabSession.tabs.map(\.id) {
                _ = try? tabSession.closeTab(id: id, forcePinned: true)
                sessionsByID.removeValue(forKey: id)
                savedBaselineByID.removeValue(forKey: id)
                undoRegistry.removeUndoManager(for: id)
                try? deps.recoveryStore.removeRecoverySnapshot(for: id)
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

#endif
