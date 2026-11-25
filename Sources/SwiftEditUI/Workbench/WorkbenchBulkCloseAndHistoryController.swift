import Foundation
import Observation
import SwiftEditCore

#if os(macOS)
/// `@MainActor @Observable` leaf sub-controller owning sequential bulk-close queue state and the bounded recently-closed file ring (`REQ-002`, `BC-006`, `BC-008`, `SEC-003`).
@MainActor
@Observable
public final class WorkbenchBulkCloseAndHistoryController {
    /// Maximum number of closed file-backed URLs retained in session memory for `Shift+Cmd+T` reopen (`REQ-002`).
    public static let maxClosedHistory = 20

    public private(set) var pendingQueue: [DocumentID] = []
    public private(set) var isForcePinned: Bool = false
    public private(set) var closedFileURLs: [URL] = []

    public init() {}

    /// Replaces any active bulk-close queue with `ids` and records whether pinned tabs should be force-closed (`Close All Tabs`).
    public func enqueueBulkClose(_ ids: [DocumentID], forcePinned: Bool) {
        pendingQueue = ids
        isForcePinned = forcePinned
    }

    /// Pops and returns the next queued `DocumentID`, or `nil` when the queue is drained.
    public func dequeueNext() -> DocumentID? {
        guard !pendingQueue.isEmpty else { return nil }
        return pendingQueue.removeFirst()
    }

    /// Clears all pending queued tab IDs and resets `isForcePinned` (e.g. when the user selects `Cancel`).
    public func cancelBulkClose() {
        pendingQueue.removeAll()
        isForcePinned = false
    }

    /// Records a closed file-backed URL at the front of the MRU closed-tab stack, deduplicating by canonical standardized path and capping at `maxClosedHistory`.
    public func recordClosedFileURL(_ url: URL?) {
        guard let url else { return }
        let standardized = url.standardizedFileURL
        closedFileURLs.removeAll { $0.standardizedFileURL.path == standardized.path }
        closedFileURLs.insert(standardized, at: 0)
        if closedFileURLs.count > Self.maxClosedHistory {
            closedFileURLs.removeLast(closedFileURLs.count - Self.maxClosedHistory)
        }
    }

    /// Pops and returns the most recently closed file URL, or `nil` when the stack is empty.
    public func popMostRecentClosedFileURL() -> URL? {
        guard !closedFileURLs.isEmpty else { return nil }
        return closedFileURLs.removeFirst()
    }
}
#endif
