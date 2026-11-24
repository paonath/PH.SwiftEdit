import Foundation
import SwiftEditCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Outcome returned when evaluating whether a text selection can be sent immediately to the embedded terminal (`SEC-004`).
public enum TerminalSendEvaluationOutcome: Equatable, Sendable {
    case emptySelection
    case deliverImmediately(TerminalSelectionPayload)
    case requiresMultilineConfirmation(TerminalSelectionPayload)
}

/// `@MainActor @Observable` sub-controller owning the per-document word completion cache and debounced background rebuild task (`REQ-020-01`, `UI-005`).
@MainActor
@Observable
public final class WorkbenchWordCompletionController {
    /// Delay after the last edit before the word cache is rebuilt off the main actor (`UI-012`).
    public nonisolated static let rebuildDebounce: Duration = .milliseconds(350)

    @ObservationIgnored var cache: (id: DocumentID, revision: BufferRevision, index: WordCompletionIndex)?
    @ObservationIgnored var rebuildTask: Task<Void, Never>?

    public init() {}

    /// Returns the completion suffix for `prefix` when the active document is eligible and cached, or `nil` otherwise.
    public func completionSuffix(
        forPrefix prefix: String,
        documentID: DocumentID,
        isEligible: Bool
    ) -> String? {
        guard isEligible, prefix.count >= 2 else { return nil }
        guard let cache, cache.id == documentID else { return nil }
        return cache.index.completionSuffix(forPrefix: prefix)
    }

    /// Returns `true` when the cache is missing or belongs to a different document.
    public func needsRebuild(for documentID: DocumentID) -> Bool {
        guard let cache else { return true }
        return cache.id != documentID
    }

    /// Synchronously rebuilds the word completion index for a document snapshot.
    public func rebuildIndexNow(
        documentID: DocumentID,
        revision: BufferRevision,
        text: String,
        caretLocation: Int
    ) {
        rebuildTask?.cancel()
        cache = (
            documentID,
            revision,
            WordCompletionIndex.build(from: text, excluding: SwiftEditCore.TextRange(location: caretLocation, length: 0))
        )
    }

    /// Schedules a debounced background rebuild of the word completion index.
    public func scheduleRebuild(
        debounce: Duration = WorkbenchWordCompletionController.rebuildDebounce,
        targetID: DocumentID,
        targetRevision: BufferRevision,
        snapshotProvider: @escaping @MainActor () -> (id: DocumentID, revision: BufferRevision, text: String, caret: Int)?
    ) {
        if let cache, cache.id == targetID, cache.revision == targetRevision { return }
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor [weak self] in
            if debounce > .zero {
                try? await Task.sleep(for: debounce)
            }
            guard !Task.isCancelled,
                  let self,
                  let current = snapshotProvider(),
                  current.id == targetID else { return }
            if let cache = self.cache, cache.id == current.id, cache.revision == current.revision { return }
            let revision = current.revision
            let text = current.text
            let caret = current.caret
            let worker = Task.detached(priority: .utility) {
                WordCompletionIndex.build(from: text, excluding: SwiftEditCore.TextRange(location: caret, length: 0))
            }
            let index = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled,
                  let latest = snapshotProvider(),
                  latest.id == targetID else { return }
            self.cache = (targetID, revision, index)
        }
    }

    /// Cancels any in-flight rebuild task and clears cached entries for `documentID`.
    public func invalidate(documentID: DocumentID? = nil) {
        if documentID == nil || cache?.id == documentID {
            rebuildTask?.cancel()
            cache = nil
        }
    }
}

/// `@MainActor @Observable` sub-controller managing Find/Replace bar state and Go-to-Line offset resolution (`UI-005`).
@MainActor
@Observable
public final class WorkbenchFindAndNavigationController {
    public var state = FindReplaceBarState()

    public init() {}

    /// Presents the Find/Replace/Go-to-Line bar in the requested mode.
    public func presentFindBar(mode: FindBarPresentationMode) {
        state.mode = mode
    }

    /// Runs a literal search over `snapshot` and stores matches in `state`, returning the first match range if found.
    @discardableResult
    public func executeFind(in snapshot: DocumentSnapshot) -> SwiftEditCore.TextRange? {
        let options = SearchOptions(isCaseSensitive: state.isCaseSensitive)
        switch DocumentSearchEngine.find(query: state.query, in: snapshot, options: options) {
        case .completed(let ranges):
            state.matches = ranges
            state.activeMatchIndex = 0
            return ranges.first
        case .degradedOrTimedOut:
            state.matches = []
            state.activeMatchIndex = 0
            return nil
        }
    }

    /// Resolves a 1-based line number query into a UTF-16 range in `snapshot`, returning `nil` on invalid or out-of-range input.
    public func resolveGoToLineRange(query: String, in snapshot: DocumentSnapshot) -> SwiftEditCore.TextRange? {
        guard let targetLine = Int(query.trimmingCharacters(in: .whitespacesAndNewlines)), targetLine >= 1 else {
            return nil
        }
        return DocumentSearchEngine.goToLine(targetLine, in: snapshot)
    }
}

/// `@MainActor @Observable` sub-controller owning embedded terminal session state, height clamping, and multiline send gating (`SEC-004`, `UI-005`).
@MainActor
@Observable
public final class WorkbenchTerminalSessionController {
    public static let minPanelHeight: CGFloat = 120
    public static let maxPanelHeight: CGFloat = 720

    public var sessions: [TerminalPanelSession] = []
    public var isPanelVisible: Bool = false
    public var selectedSessionID: UUID?
    public var panelHeight: CGFloat = 240
    /// Pending multiline selection awaiting user confirmation before writing into the embedded terminal (`CWE-78`).
    public var pendingMultilineSend: TerminalSelectionPayload?
    @ObservationIgnored var sessionCounter: Int = 0
    @ObservationIgnored var terminationObserver: (any NSObjectProtocol)?

    public init() {}

    /// Clamps `height` into `[minPanelHeight, effectiveMax]`.
    public func clampHeight(_ height: CGFloat, maxAvailableHeight: CGFloat? = nil) -> CGFloat {
        let cap: CGFloat
        if let available = maxAvailableHeight, available.isFinite, available > 0 {
            cap = min(Self.maxPanelHeight, max(Self.minPanelHeight, available * 0.65))
        } else {
            cap = Self.maxPanelHeight
        }
        return min(max(height, Self.minPanelHeight), cap)
    }

    /// Creates and activates a new embedded PTY terminal session rooted at `initialDirectory`.
    @discardableResult
    public func openSession(initialDirectory: URL) -> TerminalPanelSession {
        sessionCounter += 1
        var session = TerminalPanelSession(title: "Terminal \(sessionCounter)", directory: initialDirectory.standardizedFileURL)
        let shellName = URL(fileURLWithPath: EmbeddedTerminalRegistry.defaultShellPath()).lastPathComponent
        session.state = .running(appName: shellName, since: Date())
        sessions.append(session)
        selectedSessionID = session.id
        isPanelVisible = true
        return session
    }

    /// Evaluates whether a selection payload can be sent immediately or requires multiline confirmation (`CWE-78`).
    public func evaluateSendSelection(
        selection: SwiftEditCore.TextRange,
        in text: String,
        isBinaryReadOnly: Bool = false
    ) -> TerminalSendEvaluationOutcome {
        guard let payload = TerminalSelectionPayload.prepare(
            selection: selection,
            in: text,
            isBinaryReadOnly: isBinaryReadOnly
        ) else {
            return .emptySelection
        }
        if payload.isMultiline {
            pendingMultilineSend = payload
            return .requiresMultilineConfirmation(payload)
        }
        return .deliverImmediately(payload)
    }

    /// Consumes and clears the pending multiline payload upon user confirmation.
    public func confirmPendingMultilineSend() -> TerminalSelectionPayload? {
        defer { pendingMultilineSend = nil }
        return pendingMultilineSend
    }

    /// Cancels the pending multiline payload without writing to PTY stdin.
    public func cancelPendingMultilineSend() {
        pendingMultilineSend = nil
    }
}

/// `@MainActor @Observable` sub-controller executing symlink-confined sidebar file and folder CRUD (`SEC-003`, `UI-005`).
@MainActor
@Observable
public final class WorkbenchSidebarFileController {
    public var clipboard: SidebarFileClipboard?
    public var pendingTrashItemURL: URL?
    public var lastErrorMessage: String?
    @ObservationIgnored private let fileSystem: any FileSystemProviding

    public init(fileSystem: any FileSystemProviding) {
        self.fileSystem = fileSystem
    }

    private func isWithinScope(_ candidateURL: URL, scopeRoot: URL?) -> Bool {
        guard let scopeRoot else { return true }
        let candidate = candidateURL.resolvingSymlinksInPath().standardizedFileURL.path
        let root = scopeRoot.resolvingSymlinksInPath().standardizedFileURL.path
        return candidate == root || candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    /// Creates a new file inside `parentURL` strictly confined to `scopeRoot`.
    @discardableResult
    public func createFile(named name: String, in parentURL: URL, scopeRoot: URL?) -> URL? {
        guard isWithinScope(parentURL, scopeRoot: scopeRoot) else {
            lastErrorMessage = "Create file failed: target directory outside workspace scope."
            return nil
        }
        do {
            lastErrorMessage = nil
            return try fileSystem.createFile(named: name, contents: Data(), in: parentURL, withinScope: scopeRoot)
        } catch {
            lastErrorMessage = "Create file failed: \(error)"
            return nil
        }
    }

    /// Creates a new folder inside `parentURL` strictly confined to `scopeRoot`.
    @discardableResult
    public func createFolder(named name: String, in parentURL: URL, scopeRoot: URL?) -> URL? {
        guard isWithinScope(parentURL, scopeRoot: scopeRoot) else {
            lastErrorMessage = "Create folder failed: target directory outside workspace scope."
            return nil
        }
        do {
            lastErrorMessage = nil
            return try fileSystem.createDirectory(named: name, in: parentURL, withinScope: scopeRoot)
        } catch {
            lastErrorMessage = "Create folder failed: \(error)"
            return nil
        }
    }

    /// Renames `itemURL` to `newName` strictly confined to `scopeRoot`.
    @discardableResult
    public func renameItem(at itemURL: URL, to newName: String, scopeRoot: URL?) -> URL? {
        guard isWithinScope(itemURL, scopeRoot: scopeRoot) else {
            lastErrorMessage = "Rename failed: target item outside workspace scope."
            return nil
        }
        do {
            lastErrorMessage = nil
            return try fileSystem.renameItem(at: itemURL, toName: newName, withinScope: scopeRoot)
        } catch {
            lastErrorMessage = "Rename failed: \(error)"
            return nil
        }
    }

    /// Records `itemURL` in the sidebar clipboard for Cut or Copy.
    public func stageClipboard(itemURL: URL, mode: PasteMode) {
        clipboard = SidebarFileClipboard(sourceURL: itemURL, mode: mode)
    }
}

/// `@MainActor @Observable` sub-controller owning GitHub release update-check and dialog state (`SEC-001`, `UI-005`).
@MainActor
@Observable
public final class WorkbenchUpdateController {
    public var isCheckingForUpdates: Bool = false
    public var updateCheckOutcome: UpdateCheckOutcome?
    public var isDialogPresented: Bool = false
    public var isInstallingUpdate: Bool = false
    @ObservationIgnored var updateCheckTask: Task<Void, Never>?
    @ObservationIgnored let updateChecker: GitHubReleaseUpdateChecker

    public init(updateChecker: GitHubReleaseUpdateChecker) {
        self.updateChecker = updateChecker
    }

    /// Dismisses the update check dialog.
    public func dismissDialog() {
        isDialogPresented = false
    }

    /// Cancels any active update check task.
    public func cancelPendingCheck() {
        updateCheckTask?.cancel()
        updateCheckTask = nil
    }
}
