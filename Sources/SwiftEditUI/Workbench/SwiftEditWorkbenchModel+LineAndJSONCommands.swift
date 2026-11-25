import Foundation
import SwiftEditCore

#if os(macOS)
/// Atomic line commands (`Option+Up`/`Down`, `Ctrl+Shift+K`, `Ctrl+J`, Sort, Trim) and JSON formatting commands (`REQ-009`, `REQ-010`).
extension SwiftEditWorkbenchModel {
    /// Moves the active or selected line(s) up one row in 1 `BufferRevision` (`Option+Up`, `REQ-009`).
    public func moveActiveLinesUp() {
        applyLineCommandOutcome(evaluate: { LineEditCommands.moveLines(in: $0, selection: currentSelection, up: true) })
    }

    /// Moves the active or selected line(s) down one row in 1 `BufferRevision` (`Option+Down`, `REQ-009`).
    public func moveActiveLinesDown() {
        applyLineCommandOutcome(evaluate: { LineEditCommands.moveLines(in: $0, selection: currentSelection, up: false) })
    }

    /// Deletes the active or selected line(s) in 1 `BufferRevision` (`Ctrl+Shift+K`, `REQ-009`).
    public func deleteActiveLines() {
        applyLineCommandOutcome(evaluate: { LineEditCommands.deleteLines(in: $0, selection: currentSelection) })
    }

    /// Joins the active line with the following line (or selected lines) in 1 `BufferRevision` (`Ctrl+J`, `REQ-009`).
    public func joinActiveLines() {
        applyLineCommandOutcome(evaluate: { LineEditCommands.joinLines(in: $0, selection: currentSelection) })
    }

    /// Sorts selected lines (or all lines) ascending or descending in 1 `BufferRevision` (`REQ-009`).
    public func sortActiveLines(ascending: Bool) {
        applyLineCommandOutcome(evaluate: { LineEditCommands.sortLines(in: $0, selection: currentSelection, ascending: ascending) })
    }

    /// Trims trailing spaces and tabs across the active document in 1 `BufferRevision` (`REQ-009`).
    public func trimActiveDocumentTrailingWhitespace() {
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              safetyBanner.canSave else { return }
        let edits = LineEditCommands.trimTrailingWhitespace(in: session.snapshot)
        guard !edits.isEmpty else { return }
        do {
            _ = try session.applyTextEdits(edits, expectedRevision: session.revision)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            overlayState.statusBannerMessage = "Trim trailing whitespace failed: \(error)"
        }
    }

    /// Formats the active `.json` document with 2-space indentation and sorted keys in 1 `BufferRevision` (`REQ-010`).
    public func formatActiveJSONDocument() {
        applyJSONSingleEdit(
            transform: JSONFormatter.prettyPrint,
            successMessage: "Formatted JSON document.",
            blockedMessage: "JSON format skipped: invalid, deeply nested (> 128), or already formatted JSON."
        )
    }

    /// Minifies the active `.json` document onto one compact line in 1 `BufferRevision` (`REQ-010`).
    public func minifyActiveJSONDocument() {
        applyJSONSingleEdit(
            transform: JSONFormatter.minify,
            successMessage: "Minified JSON document.",
            blockedMessage: "JSON minify skipped: invalid, deeply nested (> 128), or already minified JSON."
        )
    }

    private func applyLineCommandOutcome(evaluate: (DocumentSnapshot) -> LineCommandOutcome?) {
        guard activeLogTail == nil,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              safetyBanner.canSave,
              let outcome = evaluate(session.snapshot),
              !outcome.edits.isEmpty else { return }
        do {
            _ = try session.applyTextEdits(outcome.edits, expectedRevision: session.revision)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            let updatedTitle: String? = session.fileURL == nil ? TabTitleDeriver.untitledTitle(from: session.text) : nil
            try? tabSession.updateTabState(id: activeID, title: updatedTitle, isDirty: session.isDirty, revision: session.revision)
            currentSelection = outcome.newSelection
            overlayState.programmaticSelectionToken += 1
            scheduleRecoveryPersist()
            refreshDiagnosticsForActiveDocument()
        } catch {
            overlayState.statusBannerMessage = "Line edit failed: \(error)"
        }
    }

    private func applyJSONSingleEdit(
        transform: (DocumentSnapshot) -> TextEdit?,
        successMessage: String,
        blockedMessage: String
    ) {
        guard activeLogTail == nil,
              activeDocumentLanguage == .json,
              let activeID = tabSession.activeTabID,
              !logTailOnlyTabIDs.contains(activeID),
              var session = sessionsByID[activeID],
              !session.isBinaryReadOnly,
              safetyBanner.canFormat else { return }
        guard let edit = transform(session.snapshot) else {
            overlayState.statusBannerMessage = blockedMessage
            return
        }
        do {
            _ = try session.applyTextEdits([edit], expectedRevision: session.revision)
            session.reconcileDirtyState(against: savedBaselineByID[activeID])
            sessionsByID[activeID] = session
            try? tabSession.updateTabState(id: activeID, isDirty: session.isDirty, revision: session.revision)
            overlayState.statusBannerMessage = successMessage
            persistRecoveryState()
            refreshDiagnosticsForActiveDocument()
        } catch {
            overlayState.statusBannerMessage = "JSON format failed: \(error)"
        }
    }
}
#endif
