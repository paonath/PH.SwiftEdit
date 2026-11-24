import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)

/// Leaf word-completion suffix lookup and background index rebuild for `SwiftEditWorkbenchModel` (`REQ-020-01`, `UI-012`, `SEC-012`).
extension SwiftEditWorkbenchModel {

    /// Suffix completing the word prefix typed just before the caret, or `nil` (binary/degraded tabs, log tail, no match).
    ///
    /// O(log n) lookup on the last built cache; a cache from another document triggers an immediate rebuild instead.
    public func wordCompletionSuffix(forPrefix prefix: String) -> String? {
        guard activeLogTail == nil, let session = activeDocumentSession,
              session.isBinaryReadOnly == false, session.snapshot.isDegradedPlainText == false else { return nil }
        guard let cache = wordCompletionController.cache, cache.id == session.id else {
            scheduleWordCompletionRebuild(debounce: .zero)
            return nil
        }
        return cache.index.completionSuffix(forPrefix: prefix)
    }

    /// Rebuilds the active document's word cache on a background task, excluding the word under the caret.
    public func scheduleWordCompletionRebuild(debounce: Duration = SwiftEditWorkbenchModel.wordCompletionRebuildDebounce) {
        guard activeLogTail == nil,
              let session = activeDocumentSession,
              session.isBinaryReadOnly == false,
              session.isDegradedPlainText == false else { return }
        if let cache = wordCompletionController.cache, cache.id == session.id, cache.revision == session.revision { return }
        let targetID = session.id
        wordCompletionController.rebuildTask?.cancel()
        wordCompletionController.rebuildTask = Task { @MainActor [weak self] in
            if debounce > .zero {
                try? await Task.sleep(for: debounce)
            }
            guard Task.isCancelled == false,
                  let self,
                  self.activeLogTail == nil,
                  let current = self.activeDocumentSession,
                  current.id == targetID,
                  current.isBinaryReadOnly == false,
                  current.isDegradedPlainText == false else { return }
            if let cache = self.wordCompletionController.cache, cache.id == current.id, cache.revision == current.revision { return }
            let revision = current.revision
            let text = current.text
            let caret = self.currentSelection.location
            let worker = Task.detached(priority: .utility) {
                WordCompletionIndex.build(from: text, excluding: SwiftEditCore.TextRange(location: caret, length: 0))
            }
            let index = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard Task.isCancelled == false,
                  let latest = self.activeDocumentSession,
                  latest.id == targetID else { return }
            self.wordCompletionController.cache = (targetID, revision, index)
        }
    }

    /// Synchronously rebuilds the active word cache (tests and first-open paths).
    public func rebuildWordCompletionIndexNow() {
        guard activeLogTail == nil,
              let session = activeDocumentSession,
              session.isBinaryReadOnly == false,
              session.isDegradedPlainText == false else { return }
        wordCompletionController.rebuildTask?.cancel()
        wordCompletionController.cache = (
            session.id,
            session.revision,
            WordCompletionIndex.build(from: session.text, excluding: SwiftEditCore.TextRange(location: currentSelection.location, length: 0))
        )
    }
}

#endif
