import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Markdown preview projection, frontmatter properties, lint quick-fix commands, GFM authoring, and two-tab compare helpers (`UI-005`, `BC-004`, `SEC-012`).
extension SwiftEditWorkbenchModel {
    public var showMarkdownPreview: Bool {
        get { overlayState.showMarkdownPreview }
        set { overlayState.showMarkdownPreview = newValue }
    }
    public var showDiffPane: Bool {
        get { overlayState.showDiffPane }
        set { overlayState.showDiffPane = newValue }
    }
    public var isDiagnosticsPopoverPresented: Bool {
        get { overlayState.isDiagnosticsPopoverPresented }
        set { overlayState.isDiagnosticsPopoverPresented = newValue }
    }
    public internal(set) var previewGeneration: Int {
        get { overlayState.previewGeneration }
        set { overlayState.previewGeneration = newValue }
    }
    public internal(set) var compareSourceTabID: DocumentID? {
        get { overlayState.compareSourceTabID }
        set { overlayState.compareSourceTabID = newValue }
    }
    public internal(set) var compareDestinationTabID: DocumentID? {
        get { overlayState.compareDestinationTabID }
        set { overlayState.compareDestinationTabID = newValue }
    }

    /// Waits for the in-flight background preview projection, if any (tests and headless callers).
    public func awaitPendingPreview() async {
        await caches.previewTask?.value
    }

    /// Awaits any in-flight background diagnostic pass for deterministic verification (`PERF-006`, `N11`).
    public func awaitPendingDiagnostics() async {
        await caches.diagnosticsTask?.value
    }

    /// Parsed frontmatter of the active writable Markdown tab, cached per `(DocumentID, BufferRevision)`; `nil` otherwise.
    public var propertiesModel: FrontmatterPropertyModel? {
        guard editorSyntaxLanguage == .markdown, let session = activeDocumentSession else { return nil }
        if let cache = caches.propertiesCache, cache.id == session.id, cache.revision == session.revision { return cache.model }
        let parsed = FrontmatterPropertyParser.parse(snapshot: session.snapshot)
        caches.propertiesCache = (session.id, session.revision, parsed)
        return parsed
    }

    /// `true` only for a writable, non-binary Markdown tab whose buffer starts with a frontmatter block (`REQ-009`).
    public var isPropertiesPanelVisible: Bool { !overlayState.isDistractionFree && propertiesModel != nil }

    /// Applies one Properties panel operation as a single `TextEdit` and `BufferRevision` on the active tab.
    @discardableResult
    public func applyPropertyOperation(_ operation: FrontmatterPropertyOperation) -> FrontmatterWriteResult {
        guard let model = propertiesModel,
              let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return .rejected(.readOnly) }
        let result = FrontmatterPropertyWriter.apply(operation, model: model, snapshot: session.snapshot)
        guard case .edit(let edit) = result else {
            overlayState.statusBannerMessage = "Property not changed: \(result)"
            return result
        }
        do {
            _ = try session.applyTextEdits([edit], expectedRevision: model.revision)
        } catch {
            return .staleRevision
        }
        session.reconcileDirtyState(against: savedBaselineByID[activeID])
        sessionsByID[activeID] = session
        try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
        syncUntitledTabTitleIfNeeded(for: activeID, session: session)
        persistRecoveryState()
        refreshDiagnosticsForActiveDocument()
        return result
    }

    /// `true` when the Document Navigator (`Option+\`) can open for the active Markdown or YAML tab.
    public var isNavigatorEnabled: Bool {
        editorSyntaxLanguage != .plainText
    }

    /// Preview projection for the active tab; `nil` while `showMarkdownPreview == false` or on binary and non-Markdown tabs (`SEC-004`, `SEC-012`).
    public var markdownPreviewDocument: GFMPreviewDocument? {
        _ = previewGeneration
        guard showMarkdownPreview, isMarkdownMenuEnabled, let session = activeDocumentSession else { return nil }
        if let cache = caches.previewCache, cache.id == session.id, cache.revision == session.revision, let doc = cache.document {
            return doc
        }
        guard session.text.utf8.count <= Self.syncPreviewThresholdUTF8 else {
            return caches.previewCache?.id == session.id ? caches.previewCache?.document : nil
        }
        let idx = activeLineIndex()
        let document = MarkdownPreviewProjector.project(snapshot: session.snapshot, showPreview: true, lineIndex: idx)
        let enriched = caches.previewCache?.id == session.id && caches.previewCache?.revision == session.revision ? caches.previewCache?.enriched : nil
        caches.previewCache = (session.id, session.revision, document, enriched)
        return document
    }

    /// Enriched preview projection carrying structured YAML frontmatter metadata, fence languages, and pre-laid-out native diagrams (`REQ-003`, `REQ-004`).
    public var enrichedMarkdownPreviewDocument: GFMPreviewEnrichedDocument? {
        _ = previewGeneration
        guard showMarkdownPreview, isMarkdownMenuEnabled, let session = activeDocumentSession else { return nil }
        if let cache = caches.previewCache, cache.id == session.id, cache.revision == session.revision, let enriched = cache.enriched {
            return enriched
        }
        guard session.text.utf8.count <= Self.syncPreviewThresholdUTF8 else {
            return caches.previewCache?.id == session.id ? caches.previewCache?.enriched : nil
        }
        let idx = activeLineIndex()
        let existingDoc = caches.previewCache?.id == session.id && caches.previewCache?.revision == session.revision ? caches.previewCache?.document : nil
        let document = existingDoc ?? MarkdownPreviewProjector.project(snapshot: session.snapshot, showPreview: true, lineIndex: idx)
        let enriched = MarkdownPreviewProjector.projectEnriched(snapshot: session.snapshot, showPreview: true, lineIndex: idx)
        caches.previewCache = (session.id, session.revision, document, enriched)
        return enriched
    }

    /// Copies the exact raw fenced code block text (excluding opening/closing backtick fences) to the system clipboard (`REQ-003`).
    public func copyPreviewCodeBlock(_ code: String) {
        deps.clipboardWriter(code)
    }

    /// 1-based source line of the caret counting `\r\n`, `\n`, and `\r`, cached per `(DocumentID, BufferRevision, caretLocation)` (`BUG-016`, `UI-007`).
    public var previewSourceLine: Int {
        guard let session = activeDocumentSession else { return 0 }
        let caret = currentSelection.location
        if let cached = caches.cachedPreviewSourceLine,
           cached.id == session.id,
           cached.revision == session.revision,
           cached.caret == caret {
            return cached.value
        }
        guard caret > 0 else {
            caches.cachedPreviewSourceLine = (session.id, session.revision, caret, 1)
            return 1
        }
        let idx = caches.textIndexCache.index(for: session.snapshot)
        let clampedCaret = min(caret, idx.utf16Count)
        let line = idx.cursorLineAndColumn(caret: clampedCaret)?.line ?? 1
        caches.cachedPreviewSourceLine = (session.id, session.revision, caret, line)
        return line
    }

    /// Image and link gate bound to the active file's directory and the granted workspace scope (`SEC-002`, `SEC-003`).
    public var previewResourceGate: PreviewResourceAndLinkGate? {
        guard let scope = workspaceState.grantedScopeRootURL, let fileURL = activeDocumentSession?.fileURL else { return nil }
        return PreviewResourceAndLinkGate(fileSystem: deps.fileSystem, scopeRoot: scope, documentDirectory: fileURL.deletingLastPathComponent())
    }

    func resolvedVisibleLintCache() -> (visible: [MarkdownLintDiagnostic], severityByLine: [Int: MarkdownLintSeverity]) {
        let caretLine = previewSourceLine
        if let cached = caches.cachedVisibleLint, cached.caretLine == caretLine, cached.generation == caches.lintGeneration {
            return (cached.visible, cached.severityByLine)
        }
        let visible = ActiveLineLintSuppressionPolicy.visibleDiagnostics(lintDiagnostics, caretLine: caretLine)
        var severityByLine: [Int: MarkdownLintSeverity] = Dictionary(minimumCapacity: visible.count)
        for d in visible where severityByLine[d.line] != .error {
            severityByLine[d.line] = d.severity
        }
        caches.cachedVisibleLint = (caches.lintGeneration, caretLine, visible, severityByLine)
        return (visible, severityByLine)
    }

    /// Diagnostics for inline underlines and gutter badges after active-line suppression of transient warnings.
    public var visibleLintDiagnostics: [MarkdownLintDiagnostic] {
        resolvedVisibleLintCache().visible
    }

    /// Worst severity per 1-based line (errors win) for gutter badges.
    public var gutterSeverityByLine: [Int: MarkdownLintSeverity] {
        resolvedVisibleLintCache().severityByLine
    }

    /// Hover text per line for the gutter lint badge.
    public var gutterLintDetailsByLine: [Int: String] {
        let caretLine = previewSourceLine
        if let cached = caches.cachedLintDetails, cached.generation == caches.lintGeneration, cached.caretLine == caretLine { return cached.details }
        let details = Self.lintDetails(resolvedVisibleLintCache().visible)
        caches.cachedLintDetails = (caches.lintGeneration, caretLine, details)
        return details
    }

    nonisolated static func lintDetails(_ diagnostics: [MarkdownLintDiagnostic]) -> [Int: String] {
        var grouped: [Int: [String]] = [:]
        for d in diagnostics {
            let message = d.message.hasPrefix(d.rule.code) ? d.message : "\(d.rule.code): \(d.message)"
            grouped[d.line, default: []].append("\(message)\n\(d.rule.explanation)")
        }
        return grouped.mapValues { $0.joined(separator: "\n\n") }
    }
}

extension SwiftEditWorkbenchModel {
    /// Status-bar lint state: Off for plain-text and binary tabs, Paused for degraded buffers, Active otherwise (`DATA-003`).
    public var activeLintStatus: ActiveLintStatus {
        guard let session = activeDocumentSession else { return .off }
        return ActiveLintStatus.classify(
            language: activeDocumentLanguage,
            snapshot: session.snapshot,
            diagnosticCount: lintDiagnostics.count
        )
    }

    /// Toggles the diagnostics popover (`⇧⌘M`); ignored while lint is Off or Paused.
    public func toggleDiagnosticsPopover() {
        guard case .active = activeLintStatus else { isDiagnosticsPopoverPresented = false; return }
        isDiagnosticsPopoverPresented.toggle()
    }

    /// Programmatically selects `range` in the active tab and asks the editor to adopt it; out-of-bounds ranges are ignored (`CWE-20`).
    public func selectRange(_ range: SwiftEditCore.TextRange) {
        guard let session = activeDocumentSession, range.location >= 0, range.length >= 0,
              range.upperBound <= session.text.utf16.count else { return }
        handleSelectionChanged(range)
        overlayState.programmaticSelectionToken += 1
    }

    /// Moves the selection to `diagnostic.range` (Jump-to-Range) and asks the editor to adopt it.
    public func jumpToDiagnostic(_ diagnostic: MarkdownLintDiagnostic) {
        guard let range = diagnostic.range, let session = activeDocumentSession, range.upperBound <= session.text.utf16.count else { return }
        currentSelection = SwiftEditCore.TextRange(location: range.location, length: 0)
        overlayState.programmaticSelectionToken += 1
    }

    /// Applies the diagnostic's own `quickFix` as one revision; security diagnostics have none (`SEC-004`).
    @discardableResult
    public func applyQuickFix(_ diagnostic: MarkdownLintDiagnostic) -> Bool {
        guard let fix = diagnostic.quickFix else { return false }
        return applyLintEdit(MarkdownAuthoringEdit(edits: [fix], newSelection: SwiftEditCore.TextRange(location: fix.range.location + (fix.replacement as NSString).length, length: 0)))
    }

    /// Applies the idempotent revision-pinned Fix All as exactly one `BufferRevision` (`CWE-362`, `DATA-003`).
    @discardableResult
    public func applyFixAll() -> Bool {
        guard isMarkdownMenuEnabled, let session = activeDocumentSession else { return false }
        guard case .edit(let edit) = MarkdownQuickFixResolver.fixAll(snapshot: session.snapshot, expectedRevision: session.revision) else { return false }
        return applyLintEdit(edit)
    }

    func applyLintEdit(_ edit: MarkdownAuthoringEdit) -> Bool {
        guard isMarkdownMenuEnabled, let activeID = tabSession.activeTabID, var session = sessionsByID[activeID] else { return false }
        do {
            _ = try session.applyTextEdits(edit.edits, expectedRevision: session.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            currentSelection = edit.newSelection
            overlayState.programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            overlayState.statusBannerMessage = "Lint fix failed: \(error)"
            return false
        }
    }

    /// Evaluates GFM table `Tab` / `Shift+Tab` for the active tab; anything else defers to the list engine (`notApplicable`).
    public func tableTabOutcome(backward: Bool) -> TableEditOutcome {
        guard isMarkdownMenuEnabled, let session = activeDocumentSession else { return .notApplicable }
        return GFMTableEditEngine.evaluateTab(in: session.snapshot, selection: currentSelection, backward: backward, isMarkdownDocument: true)
    }

    /// Applies a `Markdown` menu command as one `BufferRevision` on the active tab (`BC-006`, `DATA-003`).
    @discardableResult
    public func applyMarkdownCommand(_ command: MarkdownAuthoringCommand) -> Bool {
        guard isMarkdownMenuEnabled, let activeID = tabSession.activeTabID, var session = sessionsByID[activeID],
              let edit = MarkdownAuthoringCommands.evaluate(command, in: session.snapshot, selection: currentSelection, isMarkdownDocument: true) else { return false }
        do {
            _ = try session.applyTextEdits(edit.edits, expectedRevision: session.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            currentSelection = edit.newSelection
            overlayState.programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
            return true
        } catch {
            overlayState.statusBannerMessage = "Markdown command failed: \(error)"
            return false
        }
    }

    /// Toggles the offline native Markdown preview (`Cmd+P`, default off) and evicts preview + thumbnail caches immediately on hide (`MEM-001`, `SEC-004`).
    public func toggleMarkdownPreview() {
        showMarkdownPreview.toggle()
        if !showMarkdownPreview {
            caches.previewTask?.cancel()
            caches.previewTaskTarget = nil
            caches.previewCache = nil
            PreviewThumbnailCache.shared.clear()
        } else {
            schedulePreviewProjectionIfNeeded()
        }
    }

    /// Formats only the Markdown lines intersecting `currentSelection` in one atomic `BufferRevision` step (`Option+Shift+Cmd+F`).
    public func formatActiveSection() {
        guard let activeID = tabSession.activeTabID,
              var session = sessionsByID[activeID] else { return }
        guard !session.isBinaryReadOnly, safetyBanner.canFormat else {
            overlayState.statusBannerMessage = "Format blocked: binary read-only file."
            return
        }
        let snap = session.snapshot
        do {
            guard let batch = try MarkdownLintAndFormatEngine.formatSection(snapshot: snap, range: currentSelection).completedValue else {
                overlayState.statusBannerMessage = "Section formatting skipped (degraded, AST depth > 128, or > 250 ms)."
                return
            }
            guard !batch.edits.isEmpty else {
                overlayState.statusBannerMessage = "Markdown section already formatted."
                return
            }
            _ = try session.applyTextEdits(batch.edits, expectedRevision: snap.revision)
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            syncUntitledTabTitleIfNeeded(for: activeID, session: session)
            overlayState.statusBannerMessage = "Formatted \(batch.edits.count) line(s) in selection."
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            overlayState.statusBannerMessage = "Section format failed: \(error)"
        }
    }

    public func toggleDiffPane() {
        showDiffPane.toggle()
        if showDiffPane {
            compareSourceTabID = tabSession.activeTabID
            compareDestinationTabID = nil
        } else {
            compareSourceTabID = nil
            compareDestinationTabID = nil
            diffCoordinator.clear()
        }
        refreshDiagnosticsForActiveDocument()
        refreshCompare()
    }

    /// Open text tabs selectable as destination (never the source, binary or tail-only tabs).
    public var compareDestinationCandidates: [TabDescriptor] {
        tabSession.tabs.filter { tab in
            tab.id != compareSourceTabID && !logTailOnlyTabIDs.contains(tab.id)
                && sessionsByID[tab.id].map { !$0.isBinaryReadOnly } == true
        }
    }

    public func title(ofTab id: DocumentID?) -> String? {
        guard let id else { return nil }
        return tabSession.tabs.first { $0.id == id }?.title
    }

    /// Picks the destination tab (`nil` returns to saved vs current); the destination tab itself stays open.
    public func setCompareDestination(_ id: DocumentID?) {
        if let id, !compareDestinationCandidates.contains(where: { $0.id == id }) { return }
        compareDestinationTabID = id
        diffCoordinator.clear()
        refreshCompare()
    }

    /// Advances to the next contiguous difference hunk in the Side-by-Side Diff pane (`F7`, `REQ-005`).
    public func selectNextDiffHunk() {
        diffCoordinator.selectNextHunk()
    }

    /// Moves to the previous contiguous difference hunk in the Side-by-Side Diff pane (`Shift+F7`, `REQ-005`).
    public func selectPreviousDiffHunk() {
        diffCoordinator.selectPreviousHunk()
    }

    /// Toggles context-folded `Only Differences` display in the Side-by-Side Diff pane (`REQ-005`).
    public func toggleDiffOnlyDifferences() {
        diffCoordinator.setOnlyDifferences(!diffCoordinator.onlyDifferences)
    }
}

#endif
