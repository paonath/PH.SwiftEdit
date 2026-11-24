import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit

/// Foundational acyclic core pipeline for `SwiftEditWorkbenchModel`: session recovery persistence, untitled title sync, focus/selection synchronization, shared `MarkdownLineIndex` lookup, and background/synchronous diagnostics refresh (`AR-006`, `AR-010`, `UI-005`).
extension SwiftEditWorkbenchModel {

    /// Requests first-responder restoration onto the active `SwiftEditNSTextView` after dismissing modal chrome or bars (`BUG-009`).
    public func requestEditorFocus() {
        overlayState.editorFocusRequestToken += 1
    }

    /// Updates `currentSelection`, refreshes cached bracket balance, and records tab caret state (`UI-005`).
    public func handleSelectionChanged(_ range: SwiftEditCore.TextRange) {
        currentSelection = range
        guard let session = activeDocumentSession else { return }
        if let cached = caches.bracketTopologyCache, cached.id == session.id, cached.revision == session.revision {
            bracketResult = SearchDiffAndBracketEngine.balanceResult(from: cached.topology, caretLocation: range.location)
        } else if session.text.utf8.count <= Self.syncDiagnosticThresholdUTF8 {
            if let topology = SearchDiffAndBracketEngine.scanTopology(in: session.snapshot).completedValue {
                caches.bracketTopologyCache = (session.id, session.revision, topology)
                bracketResult = SearchDiffAndBracketEngine.balanceResult(from: topology, caretLocation: range.location)
            } else {
                bracketResult = nil
            }
        }
        try? tabSession.updateTabState(id: session.id, caretLocation: range.location)
    }

    /// Activates the tab matching `id`, resets transient binary inspection, persists session recovery, and refreshes diagnostics.
    public func activateTab(id: DocumentID) {
        caches.asyncOpenGeneration &+= 1
        workspaceState.activeBinaryInspection = nil
        try? tabSession.activateTab(id: id)
        currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
    }

    func syncUntitledTabTitleIfNeeded(for id: DocumentID, session: DocumentSession) {
        guard let tab = tabSession.tabs.first(where: { $0.id == id }),
              tab.fileURL == nil else {
            return
        }
        let derived = TabTitleDeriver.untitledTitle(from: session.text)
        if tab.title != derived {
            try? tabSession.updateUntitledDisplayTitle(id: id, title: derived)
        }
    }

    /// Language handed to the TextKit 2 validator: `.plainText` for binary, degraded or quarantined buffers (`DATA-003`).
    public var editorSyntaxLanguage: DocumentLanguage {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, !session.isDegradedPlainText, safetyBanner.canSave else { return .plainText }
        return activeDocumentLanguage
    }

    /// `true` only for a writable, non-binary Markdown tab; gates the `Markdown` menu, table `Tab`, and preview (`DATA-003`, `UI-005`).
    public var isMarkdownMenuEnabled: Bool {
        guard let session = activeDocumentSession, !session.isBinaryReadOnly, safetyBanner.canSave else { return false }
        return (activeDocumentLanguage == .markdown)
    }

    /// One `MarkdownLineIndex` per `(DocumentID, BufferRevision)` shared by the editor validator, the navigator, and the YAML outline (`PERF-017-B3`).
    public func activeLineIndex() -> MarkdownLineIndex? {
        guard let session = activeDocumentSession else { return nil }
        return lineIndex(for: session.id, revision: session.revision)
    }

    /// Shared index for `(id, revision)` when it matches the live session, else `nil`.
    public func lineIndex(for id: DocumentID, revision: BufferRevision) -> MarkdownLineIndex? {
        if let cache = caches.lineIndexCache, cache.id == id, cache.revision == revision { return cache.index }
        guard let session = sessionsByID[id] ?? activeDocumentSession.flatMap({ $0.id == id ? $0 : nil }),
              session.revision == revision else { return nil }
        let index = MarkdownLineIndex(text: session.text)
        caches.lineIndexCache = (id, revision, index)
        return index
    }

    /// Language-dispatched lint shared by the synchronous and background refresh paths (`REQ-003`, `REQ-004`).
    nonisolated static func lintDiagnostics(for snap: DocumentSnapshot, language: DocumentLanguage) -> [MarkdownLintDiagnostic] {
        switch language {
        case .plainText, .log:
            return []
        case .yaml:
            return YAMLStructureLinter.lint(snapshot: snap)
        case .markdown:
            var lint: [MarkdownLintDiagnostic]
            switch MarkdownLintAndFormatEngine.lint(snapshot: snap, profile: .allConstructs) {
            case .completed(let result):
                lint = result.diagnostics
            case .degradedOrTimedOut(.deadlineExceeded):
                lint = MarkdownLintAndFormatEngine.lintSecurityFastPath(snapshot: snap).completedValue?.diagnostics ?? []
            case .degradedOrTimedOut:
                lint = []
            }
            lint += YAMLStructureLinter.lint(snapshot: snap, frontmatterOnly: true)
            return lint
        }
    }

    /// Starts (or keeps) one background preview projection for the active revision; superseded revisions are discarded.
    func schedulePreviewProjectionIfNeeded() {
        guard overlayState.showMarkdownPreview, isMarkdownMenuEnabled, let session = activeDocumentSession,
              session.text.utf8.count > Self.syncPreviewThresholdUTF8 else { return }
        if let cache = caches.previewCache, cache.id == session.id, cache.revision == session.revision { return }
        if let target = caches.previewTaskTarget, target.id == session.id, target.revision == session.revision { return }
        caches.previewTask?.cancel()
        let snapshot = session.snapshot
        let cachedIndex = (caches.lineIndexCache?.id == snapshot.id && caches.lineIndexCache?.revision == snapshot.revision) ? caches.lineIndexCache?.index : nil
        caches.previewTaskTarget = (snapshot.id, snapshot.revision)
        caches.previewTask = Task { @MainActor [weak self] in
            let document = await Task.detached(priority: .userInitiated) {
                MarkdownPreviewProjector.project(snapshot: snapshot, showPreview: true, lineIndex: cachedIndex)
            }.value
            guard let self else { return }
            if self.caches.previewTaskTarget?.id == snapshot.id && self.caches.previewTaskTarget?.revision == snapshot.revision {
                self.caches.previewTaskTarget = nil
            }
            guard !Task.isCancelled,
                  let current = self.activeDocumentSession, current.id == snapshot.id, current.revision == snapshot.revision else { return }
            self.caches.previewCache = (snapshot.id, snapshot.revision, document)
            self.overlayState.previewGeneration &+= 1
        }
    }

    /// Recomputes the side-by-side rows for source vs destination, or source saved vs current when no destination.
    public func refreshCompare() {
        guard overlayState.showDiffPane else { return }
        let openIDs = Set(tabSession.tabs.map(\.id))
        if let source = overlayState.compareSourceTabID, !openIDs.contains(source) {
            overlayState.compareSourceTabID = tabSession.activeTabID
            overlayState.compareDestinationTabID = nil
        }
        if overlayState.compareSourceTabID == nil { overlayState.compareSourceTabID = tabSession.activeTabID }
        if let destination = overlayState.compareDestinationTabID, !openIDs.contains(destination) || destination == overlayState.compareSourceTabID {
            overlayState.compareDestinationTabID = nil
        }
        guard let sourceID = overlayState.compareSourceTabID, let source = sessionsByID[sourceID] else {
            diffCoordinator.clear()
            return
        }
        if let destinationID = overlayState.compareDestinationTabID, let destination = sessionsByID[destinationID] {
            diffCoordinator.compare(lhs: source.snapshot, rhs: destination.snapshot)
        } else if let baseline = savedBaselineByID[sourceID] {
            diffCoordinator.compare(lhs: baseline, rhs: source.snapshot)
        }
    }

    private typealias AsyncDiagnosticsPayload = (
        lint: [MarkdownLintDiagnostic],
        topology: BracketTopology?,
        backticks: BacktickHighlightResult?,
        safety: InspectionSafetyBannerState
    )

    /// Refreshes lint, bracket topology, backticks, safety banner, and diff state synchronously below `4096` UTF-8 bytes and off-`@MainActor` above (`PERF-002`, `PERF-006`).
    public func refreshDiagnosticsForActiveDocument() {
        schedulePreviewProjectionIfNeeded()
        caches.diagnosticsTask?.cancel()
        caches.diagnosticsTask = nil
        guard let session = activeDocumentSession else {
            resetDiagnosticsWhenNoActiveSession()
            return
        }
        let snap = session.snapshot
        let caret = currentSelection.location
        let language = activeDocumentLanguage
        if snap.text.utf8.count <= Self.syncDiagnosticThresholdUTF8 {
            applySynchronousDiagnostics(snap: snap, caret: caret, language: language)
            refreshCompare()
            return
        }
        scheduleAsynchronousDiagnostics(snap: snap, caret: caret, language: language)
        refreshCompare()
    }

    private func resetDiagnosticsWhenNoActiveSession() {
        safetyBanner = InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: false,
            canSave: false,
            canFormat: false,
            canPinTab: false,
            bidiWarnings: []
        )
        lintDiagnostics = []
        bracketResult = nil
        backtickResult = nil
    }

    private func applySynchronousDiagnostics(snap: DocumentSnapshot, caret: Int, language: DocumentLanguage) {
        let safety = InspectionSafetyBannerState.evaluate(snapshot: snap)
        let lint = Self.lintDiagnostics(for: snap, language: language)
        let topology = SearchDiffAndBracketEngine.scanTopology(in: snap).completedValue
        let backticks = BacktickHighlightScanner.scan(in: snap).completedValue
        commitComputedDiagnostics((lint, topology, backticks, safety), targetID: snap.id, targetRevision: snap.revision, caret: caret)
    }

    private func scheduleAsynchronousDiagnostics(snap: DocumentSnapshot, caret: Int, language: DocumentLanguage) {
        safetyBanner = InspectionSafetyBannerState(
            isBinaryReadOnlyBannerVisible: snap.isBinaryReadOnly,
            canSave: !snap.isBinaryReadOnly,
            canFormat: !snap.isBinaryReadOnly && !snap.isDegradedPlainText,
            canPinTab: !snap.isBinaryReadOnly,
            bidiWarnings: safetyBanner.bidiWarnings
        )
        if let cached = caches.bracketTopologyCache, cached.id == snap.id, cached.revision == snap.revision {
            bracketResult = SearchDiffAndBracketEngine.balanceResult(from: cached.topology, caretLocation: caret)
        }
        if language == .plainText {
            lintDiagnostics = []
            overlayState.isDiagnosticsPopoverPresented = false
        }
        let targetID = snap.id
        let targetRevision = snap.revision
        let reusableTopology = (caches.bracketTopologyCache?.id == targetID && caches.bracketTopologyCache?.revision == targetRevision) ? caches.bracketTopologyCache?.topology : nil
        let hasReusableBackticks = (caches.backtickCache?.id == targetID && caches.backtickCache?.revision == targetRevision)
        let reusableBackticks = hasReusableBackticks ? caches.backtickCache?.result : nil
        caches.diagnosticsTask = Task { @MainActor [weak self] in
            let computed = await Self.runDetachedDiagnosticsWorker(
                snap: snap,
                language: language,
                reusableTopology: reusableTopology,
                hasReusableBackticks: hasReusableBackticks,
                reusableBackticks: reusableBackticks
            )
            guard let self, let computed, !Task.isCancelled,
                  let current = self.activeDocumentSession,
                  current.id == targetID, current.revision == targetRevision else { return }
            self.commitComputedDiagnostics(computed, targetID: targetID, targetRevision: targetRevision, caret: self.currentSelection.location)
        }
    }

    private static func runDetachedDiagnosticsWorker(
        snap: DocumentSnapshot,
        language: DocumentLanguage,
        reusableTopology: BracketTopology?,
        hasReusableBackticks: Bool,
        reusableBackticks: BacktickHighlightResult?
    ) async -> AsyncDiagnosticsPayload? {
        let worker = Task.detached(priority: .userInitiated) { () -> AsyncDiagnosticsPayload? in
            guard !Task.isCancelled else { return nil }
            let safety = InspectionSafetyBannerState.evaluate(snapshot: snap)
            guard !Task.isCancelled else { return nil }
            let lint = Self.lintDiagnostics(for: snap, language: language)
            guard !Task.isCancelled else { return nil }
            let topology = reusableTopology ?? SearchDiffAndBracketEngine.scanTopology(in: snap).completedValue
            guard !Task.isCancelled else { return nil }
            let backticks = hasReusableBackticks ? reusableBackticks : BacktickHighlightScanner.scan(in: snap).completedValue
            return (lint, topology, backticks, safety)
        }
        return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }

    private func commitComputedDiagnostics(
        _ computed: AsyncDiagnosticsPayload,
        targetID: DocumentID,
        targetRevision: BufferRevision,
        caret: Int
    ) {
        safetyBanner = computed.safety
        lintDiagnostics = computed.lint
        if computed.safety.isBinaryReadOnlyBannerVisible || activeDocumentLanguage == .plainText || activeDocumentLanguage == .log {
            overlayState.isDiagnosticsPopoverPresented = false
        }
        if let topology = computed.topology {
            caches.bracketTopologyCache = (targetID, targetRevision, topology)
            bracketResult = SearchDiffAndBracketEngine.balanceResult(from: topology, caretLocation: caret)
        } else {
            caches.bracketTopologyCache = nil
            bracketResult = nil
        }
        caches.backtickCache = (targetID, targetRevision, computed.backticks)
        backtickResult = computed.backticks
    }

    func restoreSessionRecoveryIfPresent() {
        guard let manifest = try? deps.recoveryStore.loadManifest(), !manifest.tabs.isEmpty else {
            _ = try? deps.recoveryStore.purgeOrphanedSnapshots(keeping: Set(sessionsByID.keys))
            return
        }
        var restoredTabs: [TabDescriptor] = []
        var restoredSessions: [DocumentID: DocumentSession] = [:]
        var restoredBaselines: [DocumentID: DocumentSnapshot] = [:]

        for tab in manifest.tabs {
            if let recovered = try? deps.recoveryStore.loadRecoverySnapshot(for: tab.id) {
                let session = DocumentSession(
                    id: recovered.id,
                    fileURL: tab.fileURL,
                    revision: recovered.revision,
                    text: recovered.text,
                    encoding: recovered.encoding,
                    lineEnding: recovered.lineEnding,
                    isDirty: tab.isDirty
                )
                restoredTabs.append(tab)
                restoredSessions[tab.id] = session
                restoredBaselines[tab.id] = session.snapshot
            } else if tab.isPinned,
                      let fileURL = tab.fileURL,
                      let diskSession = try? deps.loader.load(from: fileURL) {
                let session = DocumentSession(
                    id: tab.id,
                    fileURL: diskSession.fileURL,
                    revision: diskSession.revision,
                    text: diskSession.text,
                    encoding: diskSession.encoding,
                    lineEnding: diskSession.lineEnding,
                    isDirty: false,
                    isDegradedPlainText: diskSession.isDegradedPlainText,
                    isBinaryReadOnly: diskSession.isBinaryReadOnly
                )
                restoredTabs.append(tab)
                restoredSessions[tab.id] = session
                restoredBaselines[tab.id] = session.snapshot
            }
        }

        if !restoredTabs.isEmpty {
            tabSession = WorkspaceTabSession(tabs: restoredTabs, activeTabID: manifest.activeTabID)
            sessionsByID = restoredSessions
            savedBaselineByID = restoredBaselines
        }
        _ = try? deps.recoveryStore.purgeOrphanedSnapshots(keeping: Set(restoredTabs.map(\.id)))
    }

    func persistRecoveryState() {
        caches.recoveryDebounceTask?.cancel()
        let manifest = SessionRecoveryManifest(tabs: tabSession.tabs, activeTabID: tabSession.activeTabID)
        try? deps.recoveryStore.saveManifest(manifest)
        for tab in tabSession.tabs {
            if let session = sessionsByID[tab.id], (session.isDirty || session.fileURL == nil), !session.isBinaryReadOnly {
                if caches.lastPersistedRecoveryRevisions[tab.id] != session.revision {
                    if (try? deps.recoveryStore.saveRecoverySnapshot(session.snapshot)) != nil {
                        caches.lastPersistedRecoveryRevisions[tab.id] = session.revision
                    }
                }
            }
        }
    }

    func scheduleRecoveryPersist() {
        caches.recoveryDebounceTask?.cancel()
        let delay = recoveryDebounceNanoseconds
        caches.recoveryDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.persistRecoveryState()
        }
    }
}

extension SwiftEditWorkbenchModel {
    /// Refreshes shallow workspace entries using `.skipAndReport` so one external symlink never hides valid siblings while folder-root escape remains fail-closed (`BUG-017`, `SEC-003`).
    public func refreshFolderEntries() {
        caches.cachedParentNavigation = nil
        guard let folderURL = selectedFolderURL else { return }
        let scope = grantedScopeRootURL ?? folderURL
        do {
            let listing = try deps.navigator.listEntriesWithDiagnostics(
                in: folderURL,
                withinScope: scope,
                symlinkPolicy: .skipAndReport
            )
            folderEntries = listing.entries
            statusBannerMessage = listing.skippedExternalSymlinkCount > 0
                ? "Skipped \(listing.skippedExternalSymlinkCount) external symlink(s) outside workspace scope."
                : nil
        } catch {
            statusBannerMessage = "Folder access error: \(error)"
        }
    }

    /// Dismisses transient binary read-only inspection, releasing the inspection buffer immediately and restoring the underlying active tab (`BUG-007`, `MEM-002`).
    public func dismissBinaryInspection() {
        caches.asyncOpenGeneration &+= 1
        guard let bin = activeBinaryInspection else { return }
        activeBinaryInspection = nil
        undoRegistry.removeUndoManager(for: bin.id)
        currentSelection = SwiftEditCore.TextRange(location: 0, length: 0)
        programmaticSelectionToken += 1
        statusBannerMessage = nil
        refreshDiagnosticsForActiveDocument()
    }

    func recordRecentFileIfEligible(url: URL, withinScope scope: URL?) {
        if let updated = try? deps.recentFilesStore.record(url: url, withinScope: scope) {
            recentFiles = updated
        } else {
            recentFiles = deps.recentFilesStore.entries()
        }
    }
}

#endif
