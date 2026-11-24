import Foundation
import SwiftEditCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension SwiftEditWorkbenchModel {
    public var embeddedTerminalRegistry: EmbeddedTerminalRegistry {
        runtimeHooks.embeddedTerminalRegistry
    }
    public var userHomeDirectoryProvider: () -> URL {
        get { runtimeHooks.userHomeDirectoryProvider }
        set { runtimeHooks.userHomeDirectoryProvider = newValue }
    }
    public var logFileReader: any LogFileReading {
        get { runtimeHooks.logFileReader }
        set { runtimeHooks.logFileReader = newValue }
    }
    public var updateInstaller: AppUpdateInstaller {
        get { runtimeHooks.updateInstaller }
        set { runtimeHooks.updateInstaller = newValue }
    }

    public var terminalSessions: [TerminalPanelSession] {
        get { terminalSessionController.sessions }
        set { terminalSessionController.sessions = newValue }
    }

    public var isTerminalPanelVisible: Bool {
        get { terminalSessionController.isPanelVisible }
        set { terminalSessionController.isPanelVisible = newValue }
    }

    public var selectedTerminalSessionID: UUID? {
        get { terminalSessionController.selectedSessionID }
        set { terminalSessionController.selectedSessionID = newValue }
    }

    public var terminalPanelHeight: CGFloat {
        get { terminalSessionController.panelHeight }
        set { terminalSessionController.panelHeight = newValue }
    }

    public var pendingMultilineTerminalSend: TerminalSelectionPayload? {
        get { terminalSessionController.pendingMultilineSend }
        set { terminalSessionController.pendingMultilineSend = newValue }
    }

    public var isCheckingForUpdates: Bool {
        get { updateController.isCheckingForUpdates }
        set { updateController.isCheckingForUpdates = newValue }
    }

    public var updateCheckOutcome: UpdateCheckOutcome? {
        get { updateController.updateCheckOutcome }
        set { updateController.updateCheckOutcome = newValue }
    }

    public var isUpdateDialogPresented: Bool {
        get { updateController.isDialogPresented }
        set { updateController.isDialogPresented = newValue }
    }

    public var isInstallingUpdate: Bool {
        get { updateController.isInstallingUpdate }
        set { updateController.isInstallingUpdate = newValue }
    }

    /// Prepares the selected text for the embedded terminal: single-line sends immediately (without Return),
    /// while multiline selections require explicit user confirmation (`CWE-78`, `CWE-150`).
    @discardableResult
    public func requestSendSelectionToTerminal(
        selection: SwiftEditCore.TextRange? = nil,
        sourceText: String? = nil
    ) -> Bool {
        let resolvedText: String
        let isBinary: Bool
        if let sourceText {
            resolvedText = sourceText
            isBinary = (activeBinaryInspection != nil)
        } else if let tail = activeLogTail {
            resolvedText = tail.text
            isBinary = false
        } else if let session = activeDocumentSession {
            resolvedText = session.text
            isBinary = session.isBinaryReadOnly
        } else {
            return false
        }
        let targetRange = selection ?? currentSelection
        guard let payload = TerminalSelectionPayload.prepare(
            selection: targetRange,
            in: resolvedText,
            isBinaryReadOnly: isBinary
        ) else {
            statusBannerMessage = "Send to Terminal requires a non-empty text selection."
            return false
        }
        if payload.isMultiline {
            pendingMultilineTerminalSend = payload
            statusBannerMessage = "Warning: selected text spans \(payload.lineCount) lines — confirm before sending to terminal."
            return true
        }
        deliverTerminalPayload(payload)
        return true
    }

    /// Confirms and writes the staged multiline selection into the active embedded terminal (using Bracketed Paste, no Return).
    public func confirmPendingMultilineTerminalSend() {
        guard let payload = pendingMultilineTerminalSend else { return }
        pendingMultilineTerminalSend = nil
        deliverTerminalPayload(payload)
    }

    /// Cancels a staged multiline Send to Terminal confirmation without touching the terminal.
    public func cancelPendingMultilineTerminalSend() {
        pendingMultilineTerminalSend = nil
        statusBannerMessage = "Send to Terminal cancelled."
        requestEditorFocus()
    }

    func deliverTerminalPayload(_ payload: TerminalSelectionPayload) {
        if !isTerminalPanelVisible {
            isTerminalPanelVisible = true
        }
        let targetID: UUID
        if let selected = selectedTerminalSessionID,
           terminalSessions.contains(where: { $0.id == selected }) {
            targetID = selected
        } else if let existing = terminalSessions.last {
            selectedTerminalSessionID = existing.id
            targetID = existing.id
        } else {
            let created = openTerminalSession()
            targetID = created.id
        }
        embeddedTerminalRegistry.sendPayload(payload, to: targetID)
        embeddedTerminalRegistry.focusTerminal(for: targetID)
        statusBannerMessage = payload.isMultiline
            ? "Sent \(payload.lineCount) lines to terminal (review and press Return to execute)."
            : nil
    }
}

extension SwiftEditWorkbenchModel {
    /// Duplicates the active document next to its tab (`REQ-021-05`).
    ///
    /// - File-backed: writes the current buffer (unsaved edits included) to `name copy.ext` in the same folder through the
    // MARK: Terminal panel (Cmd+J — Embedded SwiftTerm PTY Emulator)

    /// Embedded terminal sessions of the bottom panel; each owns an in-app `SwiftTerm.LocalProcessTerminalView` PTY
    /// that terminates cleanly when its tab, the panel, or SwiftEdit closes (never leaving orphan terminals open).
    /// User-resizable height of the bottom embedded terminal panel (clamped `120...720 pt`).

    public func setTerminalPanelHeight(_ height: CGFloat, maxAvailableHeight: CGFloat? = nil, persist: Bool = true) {
        let upperBound: CGFloat
        if let maxAvailableHeight, maxAvailableHeight.isFinite, maxAvailableHeight > Self.minTerminalPanelHeight {
            upperBound = min(Self.maxTerminalPanelHeight, max(Self.minTerminalPanelHeight, maxAvailableHeight))
        } else {
            upperBound = Self.maxTerminalPanelHeight
        }
        let clamped = min(max(Self.minTerminalPanelHeight, height), upperBound)
        if abs(clamped - terminalPanelHeight) > 0.25 {
            terminalPanelHeight = clamped
            if persist { savePreferences() }
        } else if persist {
            savePreferences()
        }
    }

    /// `Cmd+J`: opening shows the embedded terminal panel and starts a shell session; closing hides it and terminates every child shell cleanly.
    public func toggleTerminalPanel() {
        if isTerminalPanelVisible {
            isTerminalPanelVisible = false
            embeddedTerminalRegistry.terminateAll()
            terminalSessions.removeAll()
            selectedTerminalSessionID = nil
            requestEditorFocus()
        } else {
            isTerminalPanelVisible = true
            if terminalSessions.isEmpty { openTerminalSession() }
        }
    }

    /// Adds an embedded terminal session running the user's interactive shell in the current folder (or home when no folder is open).
    @discardableResult
    public func openTerminalSession() -> TerminalPanelSession {
        terminalSessionController.sessionCounter += 1
        let directory = (selectedFolderURL ?? userHomeDirectoryProvider()).standardizedFileURL
        let shellPath = EmbeddedTerminalRegistry.defaultShellPath()
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        var session = TerminalPanelSession(title: "Terminal \(terminalSessionController.sessionCounter)", directory: directory)
        session.state = .running(appName: shellName, since: Date())
        terminalSessions.append(session)
        selectedTerminalSessionID = session.id
        isTerminalPanelVisible = true
        return session
    }

    /// Restarts the embedded PTY shell for `id` in its working directory.
    public func relaunchTerminalSession(id: UUID) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        let shellName = URL(fileURLWithPath: EmbeddedTerminalRegistry.defaultShellPath()).lastPathComponent
        terminalSessions[index].state = .running(appName: shellName, since: Date())
        embeddedTerminalRegistry.restart(sessionID: id, directory: terminalSessions[index].directory)
    }

    /// Updates a session's state when its embedded PTY child shell exits (`exit`, `Ctrl+D`, or signal).
    public func embeddedTerminalDidTerminate(id: UUID, exitCode: Int32?) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        if exitCode == 0 {
            // Normal shell exit (`exit` / `Ctrl+D`): close the tab cleanly so no dead terminal remains.
            closeTerminalSession(id: id)
        } else {
            let detail = exitCode.map { "exited with code \($0)" } ?? "terminated"
            terminalSessions[index].state = .failed(message: "Shell \(detail). Click Restart to open a new shell.")
        }
    }

    /// Records a launch failure from `LocalProcessTerminalViewDelegate` without crashing the editor.
    public func embeddedTerminalDidFail(id: UUID, message: String) {
        guard let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        terminalSessions[index].state = .failed(message: "Terminal could not start: \(message)")
    }

    /// Updates the working directory tracked for an embedded terminal session when the shell emits OSC 7.
    public func embeddedTerminalDidUpdateDirectory(id: UUID, directory: String?) {
        guard let directory, !directory.isEmpty,
              let index = terminalSessions.firstIndex(where: { $0.id == id }) else { return }
        let url: URL?
        if directory.hasPrefix("file://") {
            url = URL(string: directory)
        } else {
            url = URL(fileURLWithPath: directory, isDirectory: true)
        }
        if let url {
            terminalSessions[index].directory = url.standardizedFileURL
        }
    }


    /// Records that an external terminal with `bundleIdentifier` terminated (kept for sidebar external handoff compatibility).
    func terminalApplicationDidTerminate(bundleIdentifier: String?) {
        guard let bundleIdentifier else { return }
        for index in terminalSessions.indices where terminalSessions[index].bundleIdentifier == bundleIdentifier {
            if case .running(let name, _) = terminalSessions[index].state {
                terminalSessions[index].state = .failed(message: "\(name) quit or crashed. Use Restart to reopen it.")
            }
        }
    }

    public func closeTerminalSession(id: UUID) {
        embeddedTerminalRegistry.terminate(sessionID: id)
        terminalSessions.removeAll { $0.id == id }
        if selectedTerminalSessionID == id { selectedTerminalSessionID = terminalSessions.last?.id }
        if terminalSessions.isEmpty { isTerminalPanelVisible = false; requestEditorFocus() }
    }

    // MARK: Log function (live tail)

    /// Live tails keyed by tab; a tab keeps its controller (and last snapshot) until the panel is closed.
    /// Tabs opened as tail-only because the log exceeds the open size gate: never editable or savable.

    /// Log panel controller of the active tab, if the Log function was started on it.
    public var activeLogTail: LogTailController? {
        guard activeBinaryInspection == nil, let id = tabSession.activeTabID else { return nil }
        return logTails[id]
    }

    /// `⌘L` (direct) / `⌘⇧L` (inverse): starts — or switches the mode of — the live tail of the active file-backed tab.
    /// The tail runs in the background; other tabs stay fully usable and the file stays writable by other processes.
    public func startLogTail(mode: LogTailMode) {
        guard activeBinaryInspection == nil, let id = tabSession.activeTabID,
              let url = tabSession.tabs.first(where: { $0.id == id })?.fileURL else {
            statusBannerMessage = "Log: save the document to a file first."
            return
        }
        if let existing = logTails[id] {
            existing.setMode(mode)
            existing.start()
            requestEditorFocus()
            return
        }
        let controller = LogTailController(tabID: id, url: url, mode: mode, reader: logFileReader)
        logTails[id] = controller
        controller.start()
        requestEditorFocus()
    }

    /// Pauses the live tail of the active tab (the last snapshot stays visible).
    public func stopLogTail() { activeLogTail?.stop() }

    /// Closes the Log panel and returns to the normal editor (tail-only tabs keep their stopped tail visible).
    public func closeLogTail() {
        guard let id = tabSession.activeTabID, let controller = logTails[id] else { return }
        controller.stop()
        guard !logTailOnlyTabIDs.contains(id) else { return }
        logTails.removeValue(forKey: id)
        requestEditorFocus()
    }

    public var currentAppVersionString: String {
        AboutSheetDescriptor.resolveFromMainBundle().fullVersion
    }

    /// Queries GitHub Releases (`paonath/PH.SwiftEdit`) on user request and presents the update status dialog (`SEC-001`, `SEC-004`).
    public func checkForUpdates() {
        updateController.updateCheckTask?.cancel()
        isCheckingForUpdates = true
        updateCheckOutcome = nil
        isUpdateDialogPresented = true
        updateController.updateCheckTask = Task { @MainActor [weak self] in
            await self?.performUpdateCheck()
        }
    }

    /// Async core for `checkForUpdates()` enabling deterministic awaiting in headless tests (`TEST-004`).
    public func performUpdateCheck(currentVersionOverride: String? = nil, presentDialog: Bool = true) async {
        isCheckingForUpdates = true
        let version = currentVersionOverride ?? currentAppVersionString
        let outcome = await updateController.updateChecker.evaluateReleaseUpdate(currentVersion: version)
        guard !Task.isCancelled else { return }
        isCheckingForUpdates = false
        updateCheckOutcome = outcome
        if presentDialog {
            isUpdateDialogPresented = true
        }
    }

    public func dismissUpdateDialog() {
        updateController.updateCheckTask?.cancel()
        isCheckingForUpdates = false
        isUpdateDialogPresented = false
    }

    public func openVerifiedUpdateURL(_ url: URL) {
        guard let verified = GitHubReleaseUpdateChecker.verifiedGitHubHTTPSURL(url.absoluteString) else { return }
        NSWorkspace.shared.open(verified)
    }


    /// Downloads, verifies SHA-256, schedules atomic replacement (preserving quarantine-free status), and quits SwiftEdit to relaunch automatically.
    public func installUpdateAndRelaunch(downloadURL: URL) {
        guard !isInstallingUpdate else { return }
        isInstallingUpdate = true
        updateController.updateCheckTask?.cancel()
        updateController.updateCheckTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.updateInstaller.stageAndScheduleInstall(downloadURL: downloadURL)
                self.isInstallingUpdate = false
                NSApp.terminate(nil)
            } catch {
                self.isInstallingUpdate = false
                self.updateCheckOutcome = .error(message: "Automatic update failed: \(error)")
            }
        }
    }


}

#endif
