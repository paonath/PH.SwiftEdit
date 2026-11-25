import Foundation
import SwiftEditCore

#if os(macOS)
/// Confined external file change handling, conflict resolution (`Reload from Disk`, `Keep Mine`, `Compare`), and manual `Revert to Saved` (`REQ-006`, `BC-008`, `DATA-006`, `SEC-003`).
extension SwiftEditWorkbenchModel {
    /// `true` when the active tab has an unresolved external disk modification conflict (`REQ-006`).
    public var activeTabHasExternalConflict: Bool {
        guard let id = tabSession.activeTabID else { return false }
        return externalFileMonitor.conflictedTabIDs.contains(id)
    }

    /// Deterministic synchronous scan over all watched file-backed tabs (used on window focus and in unit tests).
    public func checkExternalChangesNow() {
        for tabID in externalFileMonitor.watchedTabIDs {
            handleExternalDiskChange(for: tabID)
        }
    }

    /// Evaluates an external modification signal for `tabID`, enforcing canonical `resolvingSymlinksInPath` scope confinement (`SEC-003`) and `8 KiB` NUL binary quarantine (`DATA-003`) before auto-reloading clean buffers or staging a non-destructive conflict on dirty buffers (`REQ-006`).
    public func handleExternalDiskChange(for tabID: DocumentID) {
        guard !logTailOnlyTabIDs.contains(tabID),
              let session = sessionsByID[tabID],
              let fileURL = session.fileURL else { return }
        let scope = externalFileMonitor.watchedScope(for: tabID) ?? grantedScopeRootURL ?? fileURL.deletingLastPathComponent()
        guard Self.isCanonicalURLConfined(fileURL, within: scope) else {
            externalFileMonitor.unwatch(tabID: tabID)
            statusBannerMessage = "External reload blocked: \(fileURL.lastPathComponent) escaped workspace scope."
            return
        }
        let loaded: DocumentSession
        do {
            loaded = try deps.loader.load(from: fileURL, withinScope: scope)
        } catch DomainError.securityScopeViolation {
            externalFileMonitor.unwatch(tabID: tabID)
            statusBannerMessage = "External reload blocked: \(fileURL.lastPathComponent) escaped workspace scope."
            return
        } catch {
            return
        }
        externalFileMonitor.rearmIfRenamedOrDeleted(tabID: tabID)
        let diskDigest = ExternalFileChangeMonitor.fnv1aDigest(loaded.text)
        if diskDigest == externalFileMonitor.lastKnownDigest(for: tabID), loaded.lineEnding == session.lineEnding {
            return
        }
        if loaded.isBinaryReadOnly {
            handleExternalBinaryOverwrite(for: tabID, session: session, fileURL: fileURL, scope: scope)
            return
        }
        if !session.isDirty {
            applyLoadedDiskBaseline(loaded, to: tabID, clearConflict: true)
            statusBannerMessage = "Reloaded \(fileURL.lastPathComponent) from disk."
        } else {
            let diskSnap = DocumentSnapshot(
                id: tabID,
                revision: loaded.revision,
                text: loaded.text,
                encoding: loaded.encoding,
                lineEnding: loaded.lineEnding,
                isDegradedPlainText: loaded.isDegradedPlainText,
                isBinaryReadOnly: false
            )
            externalFileMonitor.stageConflict(for: tabID, diskSnapshot: diskSnap)
        }
    }

    private static func isCanonicalURLConfined(_ fileURL: URL, within scope: URL) -> Bool {
        let canonicalFile = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalScope = scope.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = canonicalScope.hasSuffix("/") ? canonicalScope : canonicalScope + "/"
        return canonicalFile == canonicalScope || canonicalFile.hasPrefix(prefix)
    }

    /// Replaces the conflicted dirty buffer of `id` with the latest confined disk contents (`Reload from Disk`, `REQ-006`).
    public func reloadConflictedTabFromDisk(id: DocumentID) {
        guard let session = sessionsByID[id], let fileURL = session.fileURL else { return }
        let scope = externalFileMonitor.watchedScope(for: id) ?? grantedScopeRootURL ?? fileURL.deletingLastPathComponent()
        guard let loaded = try? deps.loader.load(from: fileURL, withinScope: scope), !loaded.isBinaryReadOnly else {
            statusBannerMessage = "Reload from disk blocked."
            return
        }
        applyLoadedDiskBaseline(loaded, to: id, clearConflict: true)
        statusBannerMessage = "Reloaded \(fileURL.lastPathComponent) from disk."
    }

    /// Dismisses the external conflict banner for `id` while keeping unsaved local edits (`Keep Mine`, `REQ-006`).
    public func keepLocalEditsForConflictedTab(id: DocumentID) {
        if let diskSnap = externalFileMonitor.diskSnapshotsByTabID[id] {
            savedBaselineByID[id] = diskSnap
            externalFileMonitor.recordKnownText(diskSnap.text, for: id)
        }
        externalFileMonitor.clearConflict(for: id)
        if var session = sessionsByID[id] {
            session.reconcileDirtyState(against: savedBaselineByID[id])
            sessionsByID[id] = session
            try? tabSession.updateTabState(id: id, isDirty: session.isDirty, revision: session.revision)
        }
    }

    /// Opens the Side-by-Side Diff pane comparing the external disk snapshot against local unsaved edits (`Compare`, `REQ-006`).
    public func compareConflictedTabWithDisk(id: DocumentID) {
        guard let session = sessionsByID[id],
              let diskSnap = externalFileMonitor.diskSnapshotsByTabID[id] else { return }
        compareSourceTabID = id
        compareDestinationTabID = nil
        showDiffPane = true
        diffCoordinator.clear()
        diffCoordinator.compare(lhs: diskSnap, rhs: session.snapshot)
    }

    /// Discards local unsaved edits on the active file-backed tab and reloads its last saved on-disk version (`File -> Revert to Saved`, `REQ-006`).
    public func revertActiveDocumentToSaved() {
        guard let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              let session = sessionsByID[activeID],
              let fileURL = session.fileURL else { return }
        let scope = externalFileMonitor.watchedScope(for: activeID) ?? grantedScopeRootURL ?? fileURL.deletingLastPathComponent()
        guard let loaded = try? deps.loader.load(from: fileURL, withinScope: scope), !loaded.isBinaryReadOnly else {
            statusBannerMessage = "Revert to Saved failed."
            return
        }
        applyLoadedDiskBaseline(loaded, to: activeID, clearConflict: true)
        statusBannerMessage = "Reverted \(fileURL.lastPathComponent) to saved version."
    }

    private func applyLoadedDiskBaseline(_ loaded: DocumentSession, to tabID: DocumentID, clearConflict: Bool) {
        let updated = DocumentSession(
            id: tabID,
            fileURL: loaded.fileURL,
            revision: sessionsByID[tabID]?.revision.next() ?? BufferRevision(1),
            text: loaded.text,
            encoding: loaded.encoding,
            lineEnding: loaded.lineEnding,
            isDirty: false,
            isDegradedPlainText: loaded.isDegradedPlainText,
            isBinaryReadOnly: false
        )
        sessionsByID[tabID] = updated
        savedBaselineByID[tabID] = updated.snapshot
        if clearConflict {
            externalFileMonitor.clearConflict(for: tabID)
        }
        externalFileMonitor.recordKnownText(updated.text, for: tabID)
        try? tabSession.updateTabState(id: tabID, isDirty: false, revision: updated.revision)
        try? deps.recoveryStore.removeRecoverySnapshot(for: tabID)
        caches.lastPersistedRecoveryRevisions.removeValue(forKey: tabID)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    private func handleExternalBinaryOverwrite(
        for tabID: DocumentID,
        session: DocumentSession,
        fileURL: URL,
        scope: URL
    ) {
        externalFileMonitor.unwatch(tabID: tabID)
        if session.isDirty {
            statusBannerMessage = "External binary overwrite ignored to protect unsaved edits in \(fileURL.lastPathComponent)."
            return
        }
        closeTab(id: tabID, forcePinned: true)
        openFile(at: fileURL, withinScope: scope)
    }
}
#endif
