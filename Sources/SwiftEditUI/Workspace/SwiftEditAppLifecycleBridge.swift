import Foundation
import SwiftEditCore

/// Coordinates macOS AppDelegate external document opens (`application(_:open:)`) and multi-tab dirty quit negotiation (`applicationShouldTerminate(_:)`) with the active `SwiftEditWorkbenchModel` (`BUG-002`, `BUG-003`, `BUG-010`, `AR-006`).
@MainActor
public final class SwiftEditAppLifecycleBridge {
    /// Shared bridge used by `SwiftEditAppDelegate` and the primary macOS window scene.
    public static let shared = SwiftEditAppLifecycleBridge()

    public private(set) weak var activeWorkbench: SwiftEditWorkbenchModel?
    private var pendingOpenURLs: [URL] = []

    public init() {}

    /// Registers `workbench` as the active target and drains any cold-launch external file URLs received prior to scene mount.
    public func attach(workbench: SwiftEditWorkbenchModel) {
        activeWorkbench = workbench
        guard !pendingOpenURLs.isEmpty else { return }
        let queued = pendingOpenURLs
        pendingOpenURLs.removeAll()
        openExternalURLs(queued, on: workbench)
    }

    /// Receives external Finder/LaunchServices document URLs, opening them immediately when attached or queuing them until `attach(workbench:)` completes (`BUG-002`).
    public func receiveExternalOpenURLs(_ urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return }
        guard let workbench = activeWorkbench else {
            pendingOpenURLs.append(contentsOf: fileURLs)
            return
        }
        openExternalURLs(fileURLs, on: workbench)
    }

    /// Evaluates dirty-tab termination state synchronously when clean or delegates to asynchronous save/cancel prompts when dirty tabs exist (`BUG-003`, `BUG-010`).
    /// - Returns: `true` when termination may proceed immediately (`.terminateNow`); `false` when deferred to `reply` (`.terminateLater`).
    @discardableResult
    public func beginApplicationTermination(reply: @escaping @MainActor (Bool) -> Void) -> Bool {
        guard let workbench = activeWorkbench else { return true }
        return workbench.requestApplicationTermination(reply: reply)
    }

    private func openExternalURLs(_ urls: [URL], on workbench: SwiftEditWorkbenchModel) {
        workbench.openDroppedURLs(urls)
    }
}
